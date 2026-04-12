//+------------------------------------------------------------------+
//|                                                   AutoTrade6.mq5 |
//|                             The Deep Thinking Agent (Tri-Radar)  |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "7.00"

#include <Trade\Trade.mqh>
CTrade trade;

input string   InpServerUrl        = "http://103.93.129.117:8880/"; // Gunakan Base URL agar tembus
input double   InpInitialLot       = 0.01;      // Ukuran Lot Kesatuan
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat Martingale
input int      InpBaseGridStep     = 1500;      // Poin Lapis Jaring AI
input double   InpTargetProfitUSD  = 3.0;       // Target Bersih Keranjang
input ulong    InpMagicNum         = 606606;
input bool     InpSessionFilter    = true;      // Aktifkan Filter Sesi London+NY?
input int      InpSessionStartUTC  = 7;         // Mulai Sesi (UTC Hour, Default: 7 = 14:00 WIB)
input int      InpSessionEndUTC    = 21;        // Akhir Sesi (UTC Hour, Default: 21 = 04:00 WIB)
input int      InpAITimeoutMs      = 8000;      // Timeout AI (ms) — kasih ruang untuk Grounding RSS

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   EventSetTimer(1);
   Print("✅ AutoTrade7 [The Oracle v7]: Sistem Multi-Pair Intelligence Aktif!");
   Print("   Session Filter: ", InpSessionFilter ? "AKTIF (London+NY saja)" : "NONAKTIF (24 jam)");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         trade.PositionClose(ticket);
        }
     }
  }

double NormalizeLot(double lot)
  {
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double safe = MathRound(lot / step) * step;
   safe = MathMax(min, MathMin(safe, max));
   return safe;
  }

// Cek apakah sudah ada pending order aktif milik EA ini
bool HasPendingOrder()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNum)
         return true;
     }
   return false;
  }

// Batalkan semua pending order milik EA ini (untuk refresh Oracle terbaru)
void CancelAllPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNum)
        {
         trade.OrderDelete(ticket);
         Print("🗑️ [Oracle] Pending Order lama dibatalkan. Menunggu instruksi Oracle terbaru.");
        }
     }
}

// Hitung total posisi khusus EA dan pair ini saja
int GetEAPositionsTotal()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
         count++;
     }
   return count;
  }

// Mengirim hasil akhir trade ke server Oracle
void SendFeedback(string result, double profit, double balance)
  {
   string payload = StringFormat("%s|%s|%.2f|%.2f|%s", _Symbol, result, profit, balance, "BASKET_CLOSED");
   char data[], res[];
   StringToCharArray(payload, data, 0, StringLen(payload));
   string headers = "Content-Type: text/plain\r\n";
   string feedbackUrl = InpServerUrl;
   if(StringSubstr(feedbackUrl, StringLen(feedbackUrl)-1) != "/") feedbackUrl += "/";
   feedbackUrl += "feedback";
   
   int httpRes = WebRequest("POST", feedbackUrl, headers, 4000, data, res, headers);
   if(httpRes == 200) 
      Print("💬 [Oracle Feedback] Laporan terkirim: ", result, " | Profit: $", DoubleToString(profit, 2));
   else
      Print("❌ [Oracle Feedback] Gagal mengirim laporan. HTTP: ", httpRes);
  }

// ==========================================
// CEK HARI WEEKEND (SABTU & MINGGU)
// ==========================================
bool IsWeekend()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   // day_of_week: 0=Sun, 1=Mon, ..., 6=Sat
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
  }

// ==========================================
// CEK SESI TRADING (London + New York)
// ==========================================
bool IsActiveSession()
  {
   // WEEKEND GATE: Blok absolut saat Sabtu & Minggu
   if(IsWeekend()) return false;
   
   if(!InpSessionFilter) return true; // Filter dinonaktifkan, trading 24 jam
   
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;
   
   // London: 07:00 — 16:00 UTC
   // New York: 13:00 — 22:00 UTC
   // Overlap terpanas: 13:00 — 16:00 UTC (paling besar volume)
   bool london = (hour >= InpSessionStartUTC && hour < 16);
   bool newyork = (hour >= 13 && hour < InpSessionEndUTC);
   return (london || newyork);
  }

//+------------------------------------------------------------------+
//| KESELAMATAN: MARTINGALE JARING OTOMATIS (Tanpa AI)               |
//+------------------------------------------------------------------+
void OnTick()
  {
   // WEEKEND GATE: Jangan sentuh apapun saat weekend
   if(IsWeekend())
     {
      static datetime last_weekend_log = 0;
      if(TimeCurrent() - last_weekend_log > 3600) // log sekali per jam
        {
         Print("🌙 [Oracle] Weekend. Pasar Forex Tutup. Robot Istirahat.");
         last_weekend_log = TimeCurrent();
        }
      return;
     }

   int total_pos = 0;
   double total_profit = 0.0;
   long grid_type = -1; 
   double extreme_price = 0.0; 
   double highest_lot = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         total_pos++;
         total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         grid_type = PositionGetInteger(POSITION_TYPE);
         
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double vol = PositionGetDouble(POSITION_VOLUME);
         
         if(highest_lot < vol) highest_lot = vol;

         if(grid_type == POSITION_TYPE_BUY)
            extreme_price = (extreme_price == 0 || open_price < extreme_price) ? open_price : extreme_price;
         else if(grid_type == POSITION_TYPE_SELL)
            extreme_price = (extreme_price == 0 || open_price > extreme_price) ? open_price : extreme_price;
        }
     }

   if(total_pos > 0 && total_profit >= InpTargetProfitUSD)
     {
      CloseAllPositions();
      return; 
     }

   if(total_pos > 0)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distance = InpBaseGridStep * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(grid_type == POSITION_TYPE_BUY && (extreme_price - ask >= distance))
         trade.Buy(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, ask, 0, 0, "Drone Layer [Buy]");
      else if(grid_type == POSITION_TYPE_SELL && (bid - extreme_price >= distance))
         trade.Sell(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, bid, 0, 0, "Drone Layer [Sell]");
     }
  }

//+------------------------------------------------------------------+
//| DEEP THINKING TRIGGER: PEMBACAAN SETIAP GANTI LILIN 1-MENIT      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Biarkan pasukan Martingale berperang. Jangan ajak bicara AI jika portofolio sedang bahaya/berjalan, KECUALI SETIAP 15 MENIT UNTUK AUDIT.
   // if(PositionsTotal() > 0) return; // Dihapus, karena AI sekarang pintar memanajemen portofolio!

   static datetime last_m1_bar = 0;
   datetime current_m1_bar = iTime(_Symbol, PERIOD_M1, 0);

   // TRIGGER: Mengeksekusi Laporan HANYA saat lilin (candle) 1-Menit baru berlalu (Tepat 60 Detik Sinkron)
   if(current_m1_bar != last_m1_bar)
     {
      last_m1_bar = current_m1_bar;
      
      // ==========================================
      // BASKET PNL TRACKER & FEEDBACK LOOP
      // ==========================================
      int current_pos = GetEAPositionsTotal();
      static int last_pos = 0;
      static double last_balance = 0;
      
      if(last_pos == 0 && current_pos > 0)
        {
         // Waktu pertama kali buka posisi, catat balance awal
         last_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        }
      else if(last_pos > 0 && current_pos == 0)
        {
         // Semua posisi tertutup (karena TP, SL, atau Cut Loss)
         double profit = AccountInfoDouble(ACCOUNT_BALANCE) - last_balance;
         string result = "LOSS";
         if(profit > 0) result = "WIN";
         else if(profit == 0) result = "CUT";
         
         SendFeedback(result, profit, AccountInfoDouble(ACCOUNT_BALANCE));
        }
      last_pos = current_pos;
      
      if(current_pos > 0) {
          static int skip_count = 0;
          skip_count++;
          if(skip_count < 15) return;
          skip_count = 0;
      }

      // ==========================================
      // SESSION GATE: Block jika di luar jam ramai
      // ==========================================
      if(!IsActiveSession())
        {
         MqlDateTime dt;
         TimeToStruct(TimeGMT(), dt);
         Print("💤 [Oracle] Jam tidak aktif (UTC ", dt.hour, ":00). Session London+NY belum buka. HOLD.");
         return;
        }
      
      // Mengukur Kekuatan Pergerakan Lintas Waktu (Shift in Points)
      double m1_open = iOpen(_Symbol, PERIOD_M1, 1);
      double m1_close = iClose(_Symbol, PERIOD_M1, 1);
      double m1_shift = (m1_close - m1_open) / _Point;

      double m15_open = iOpen(_Symbol, PERIOD_M15, 1);
      double m15_close = iClose(_Symbol, PERIOD_M15, 1);
      double m15_shift = (m15_close - m15_open) / _Point;

      double h1_open = iOpen(_Symbol, PERIOD_H1, 1);
      double h1_close = iClose(_Symbol, PERIOD_H1, 1);
      double h1_shift = (h1_close - h1_open) / _Point;
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      long   spread_cur = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); // dalam poin (long)
      
      int total_pos = PositionsTotal();
      double floating_profit = AccountInfoDouble(ACCOUNT_PROFIT);
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double d1_high = iHigh(_Symbol, PERIOD_D1, 0);
      double d1_low  = iLow(_Symbol, PERIOD_D1, 0);
      
      // ATR (Average True Range) = ukuran volatilitas pasar saat ini (pip)
      int atr_handle = iATR(_Symbol, PERIOD_H1, 14);
      double atr_buf[]; ArraySetAsSeries(atr_buf, true);
      double atr_pips = 0;
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_buf) > 0)
         atr_pips = atr_buf[0] / _Point;
      IndicatorRelease(atr_handle);

      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      string session = (dt.hour >= 13 && dt.hour < 16) ? "LONDON+NY_OVERLAP" :
                       (dt.hour >= 7 && dt.hour < 16)  ? "LONDON" :
                       (dt.hour >= 16 && dt.hour < 22) ? "NEW_YORK" : "ASIA";

      Print("⏳ [Oracle v7] ", _Symbol, " | Sesi: ", session, " | Spread: ", spread_cur, " poin | ATR: ", DoubleToString(atr_pips, 0), " pip | Menunggu AI...");

      // Membuat Surat Pengajuan ke Meja Oracle
      // Mengirimkan format yang menyertakan 'SYMBOL:' agar server.go bisa memilah memory berdasarkan pair
      string portofolio = StringFormat("POS:%d|FLOAT:%.2f|BAL:%.2f|F_MARG:%.2f", current_pos, floating_profit, balance, free_margin);
      string structure  = StringFormat("D1_H:%.5f|D1_L:%.5f|ASK:%.5f|SPREAD:%d|ATR_PIP:%.0f", d1_high, d1_low, ask, spread_cur, atr_pips);
      string session_info = StringFormat("SESSION:%s", session);

      string reportStruct = StringFormat("SYMBOL:%s PORTFOLIO[%s] STRUCTURE[%s] SESSION[%s] DELTA[M1:%.0f|M15:%.0f|H1:%.0f]",
                             _Symbol, portofolio, structure, session_info, m1_shift, m15_shift, h1_shift);
      
      char posData[], result[];
      string headers = "Content-Type: text/plain\r\n";
      StringToCharArray(reportStruct, posData, 0, StringLen(reportStruct));
      
      ResetLastError();
      int res = WebRequest("POST", InpServerUrl, headers, InpAITimeoutMs, posData, result, headers);
      
      if(res == 200)
        {
         string answer = CharArrayToString(result);
         Print("📡 [RAW AI OUTPUT] ", answer); // CCTV Transparansi Data Mentah
         string stringArray[];
         int partsCount = StringSplit(answer, '|', stringArray);
         
         if(partsCount >= 5)
           {
            // FORMAT WAJIB: ACTION | ENTRY_PRICE | SL | TP | REASON
            string action    = stringArray[0];
            double entry_ai  = StringToDouble(stringArray[1]);
            double sl_ai     = StringToDouble(stringArray[2]); 
            double tp_ai     = StringToDouble(stringArray[3]); 
            string reason    = stringArray[4];
            
            StringTrimLeft(action); StringTrimRight(action);
            Print("🧠 [Deep Thinker]: ", reason);
            
            if(action == "CUT_LOSS_ALL" || action == "CUT_LOSS")
              {
               Print("⚠️ A.I MENGINSTRUKSIKAN SIKAP DEFENTIF: MANUVER CUT LOSS DIJALANKAN!");
               CloseAllPositions();
              }
            else if(action == "HOLD") 
              {
                // Do nothing
              }
            else if(action == "BUY") 
               trade.Buy(InpInitialLot, _Symbol, ask, sl_ai, tp_ai, "A.I MARKET");
            else if(action == "SELL") 
               trade.Sell(InpInitialLot, _Symbol, bid, sl_ai, tp_ai, "A.I MARKET");
            else if(action == "BUY_LIMIT")
               {
                if(HasPendingOrder())
                  {
                   Print("🔄 [Oracle] Pending order lama terdeteksi. Refresh dengan instruksi terbaru...");
                   CancelAllPendingOrders();
                  }
                trade.BuyLimit(InpInitialLot, entry_ai, _Symbol, sl_ai, tp_ai, ORDER_TIME_GTC, 0, "A.I LIMIT");
                Print("✅ [Oracle] BUY_LIMIT dipasang di ", DoubleToString(entry_ai, 5));
               }
            else if(action == "SELL_LIMIT")
               {
                if(HasPendingOrder())
                  {
                   Print("🔄 [Oracle] Pending order lama terdeteksi. Refresh dengan instruksi terbaru...");
                   CancelAllPendingOrders();
                  }
                trade.SellLimit(InpInitialLot, entry_ai, _Symbol, sl_ai, tp_ai, ORDER_TIME_GTC, 0, "A.I LIMIT");
                Print("✅ [Oracle] SELL_LIMIT dipasang di ", DoubleToString(entry_ai, 5));
               }
            else if(StringFind(action, "AVERAGING") != -1 && action == "AVERAGING_BUY") 
               trade.Buy(NormalizeLot(InpInitialLot*2), _Symbol, ask, sl_ai, tp_ai, "A.I AVG UP");
           }
         else
           {
            Print("⚠️ Sinyal Tak Terbaca/Hold: ", answer);
           }
        }
       else
         {
          int err = GetLastError();
          string errDesc = "";
          if(err == 4014)        errDesc = "URL tidak di-whitelist di MT5 Options!";
          else if(res == -1)     errDesc = "Timeout! Server AI terlalu lambat (naikkan InpAITimeoutMs).";
          else if(res == 404)    errDesc = "404: Endpoint tidak ditemukan di server.";
          else if(res == 500)    errDesc = "500: Server AI error internal.";
          else                   errDesc = "Error tidak diketahui.";
          
          Print("❌ [Oracle] GAGAL! HTTP:", res, " | SysErr:", err, " → ", errDesc);
         }
     }
  }
//+------------------------------------------------------------------+
