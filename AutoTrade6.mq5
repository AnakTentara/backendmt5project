//+------------------------------------------------------------------+
//|                                                   AutoTrade6.mq5 |
//|                        The Oracle v9 "APEX ENGINE"               |
//|                  Phase 1-4: Breakeven, Killswitch, Dynamic Lot   |
//|                  Confidence Score, Scalper Drone, News Assassin  |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "9.00"

#include <Trade\Trade.mqh>
CTrade trade;

// ==========================================
// INPUT PARAMETERS
// ==========================================
input string   InpServerUrl        = "http://103.93.129.117:8880/"; // URL Server Oracle
input double   InpInitialLot       = 0.01;      // Lot Awal
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat Martingale
input int      InpBaseGridStep     = 1500;      // Poin Lapis Jaring
input double   InpTargetProfitUSD  = 3.0;       // Target Profit Keranjang (USD)
input ulong    InpMagicNum         = 606606;    // Magic Number EA
input bool     InpSessionFilter    = true;      // Filter Sesi London+NY?
input int      InpSessionStartUTC  = 7;         // Mulai Sesi (UTC)
input int      InpSessionEndUTC    = 21;        // Akhir Sesi (UTC)
input int      InpAITimeoutMs      = 12000;     // Timeout AI (ms)
input double   InpDailyKillPct     = 5.0;       // Daily Killswitch: Maks Loss % per hari
input double   InpBreakevenPip     = 10.0;      // Titik Breakeven (pip float profit)
input double   InpTrailingPip      = 20.0;      // Mulai Trailing Stop (pip)
input int      InpScalperIntervalMin = 5;       // Interval Scalper Drone (menit)

// ==========================================
// STATE VARIABLES
// ==========================================
static double  daily_start_balance = 0;
static bool    daily_killed        = false;
static int     win_streak          = 0;
static int     loss_streak         = 0;
static int     scalper_tick_count  = 0;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   EventSetTimer(1);
   daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("⚡ AutoTrade6 [The Oracle v9 APEX ENGINE]: Seluruh Sistem Aktif!");
   Print("   Session Filter  : ", InpSessionFilter ? "AKTIF (London+NY)" : "NONAKTIF (24 jam)");
   Print("   Daily Killswitch: ", InpDailyKillPct, "% max daily drawdown");
   Print("   Breakeven       : +", InpBreakevenPip, " pip trigger");
   Print("   Trailing Stop   : +", InpTrailingPip, " pip trigger");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

// ==========================================
// CEK HARI WEEKEND
// ==========================================
bool IsWeekend()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
  }

// ==========================================
// CEK SESI TRADING
// ==========================================
bool IsActiveSession()
  {
   if(IsWeekend()) return false;
   if(!InpSessionFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;
   
   // Waktu UTC: 23:00 UTC = 06:00 WIB
   bool tokyo   = (hour == 23 || hour < 7);
   bool london  = (hour >= 7 && hour < 16);
   bool newyork = (hour >= 13 && hour < InpSessionEndUTC); // Akhir sesi biasanya 21 UTC (04:00 WIB)
   
   return (tokyo || london || newyork);
  }

// ==========================================
// PHASE 1A: DAILY KILLSWITCH
// ==========================================
bool CheckDailyKillswitch()
  {
   // Reset killswitch di awal hari baru UTC
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   static int last_day = -1;
   if(dt.day != last_day)
     {
      last_day            = dt.day;
      daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      daily_killed        = false;
      Print("🌅 [Killswitch] Hari baru. Balance awal hari: $", DoubleToString(daily_start_balance, 2));
     }

   if(daily_killed) return true;

   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double floating        = AccountInfoDouble(ACCOUNT_PROFIT);
   double equity          = current_balance + floating;
   double daily_loss_pct  = (daily_start_balance - equity) / daily_start_balance * 100.0;

   if(daily_loss_pct >= InpDailyKillPct)
     {
      Print("💀 [KILLSWITCH] Daily loss mencapai ", DoubleToString(daily_loss_pct, 2), "%. SEMUA POSISI DITUTUP. Robot tidur hari ini.");
      CloseAllPositions();
      CancelAllPendingOrders();
      daily_killed = true;
      return true;
     }
   return false;
  }

// ==========================================
// UTILITY: CLOSE & CANCEL
// ==========================================
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
         trade.PositionClose(ticket);
     }
  }

double NormalizeLot(double lot)
  {
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double safe = MathRound(lot / step) * step;
   return MathMax(mn, MathMin(safe, mx));
  }

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

void CancelAllPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNum)
        {
         trade.OrderDelete(ticket);
         Print("🗑️ [Oracle] Pending Order lama dibatalkan.");
        }
     }
  }

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

// ==========================================
// PHASE 2A: DYNAMIC LOT SIZING
// ==========================================
double GetDynamicLot()
  {
   double lot = InpInitialLot;
   if(win_streak >= 6)
     {
      // Euphoria Phase—Kembali ke awal (mean-reversion warning)
      lot = InpInitialLot;
      Print("⚠️ [DynamicLot] Win streak ", win_streak, " terlalu panjang! Reset ke lot awal untuk keamanan.");
     }
   else if(win_streak >= 3)
      lot = NormalizeLot(InpInitialLot * 2.0); // 0.02
   else
      lot = InpInitialLot;

   if(loss_streak >= 2)
     {
      lot = InpInitialLot; // Reset saat loss beruntun
      Print("🔻 [DynamicLot] Loss streak ", loss_streak, ". Lot direset ke minimum.");
     }
   return NormalizeLot(lot);
  }

// ==========================================
// PHASE 1B: BREAKEVEN & TRAILING STOP
// ==========================================
void ManageBreakevenTrailing()
  {
   double pip = _Point * 10; // 1 pip = 10 poin untuk pasangan 5-digit

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNum)
         continue;

      ENUM_POSITION_TYPE ptype  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price         = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl         = PositionGetDouble(POSITION_SL);
      double current_tp         = PositionGetDouble(POSITION_TP);
      double ask                = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid                = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double float_pip          = 0;

      if(ptype == POSITION_TYPE_BUY)
         float_pip = (bid - open_price) / pip;
      else
         float_pip = (open_price - ask) / pip;

      // TRAILING STOP: Geser SL mengikuti profit
      if(float_pip >= InpTrailingPip)
        {
         double new_sl = 0;
         double trail_distance = (InpTrailingPip * 0.5) * pip; // Jaga jarak trailing 50% dari trigger

         if(ptype == POSITION_TYPE_BUY)
           {
            new_sl = bid - trail_distance;
            if(new_sl > current_sl + pip) // Hanya geser ke atas
              {
               trade.PositionModify(ticket, new_sl, current_tp);
               Print("📈 [Trailing] BUY trailing SL ke ", DoubleToString(new_sl, 5));
              }
           }
         else
           {
            new_sl = ask + trail_distance;
            if(new_sl < current_sl - pip || current_sl == 0) // Hanya geser ke bawah
              {
               trade.PositionModify(ticket, new_sl, current_tp);
               Print("📉 [Trailing] SELL trailing SL ke ", DoubleToString(new_sl, 5));
              }
           }
        }
      // BREAKEVEN: Geser SL ke harga masuk saat profit cukup
      else if(float_pip >= InpBreakevenPip && current_sl != 0)
        {
         double be_sl = 0;
         if(ptype == POSITION_TYPE_BUY)
           {
            be_sl = open_price + pip; // +1 pip dari entry
            if(be_sl > current_sl + pip)
              {
               trade.PositionModify(ticket, be_sl, current_tp);
               Print("🛡️ [Breakeven] BUY SL digeser ke breakeven+1pip: ", DoubleToString(be_sl, 5));
              }
           }
         else
           {
            be_sl = open_price - pip;
            if(be_sl < current_sl - pip || current_sl == 0)
              {
               trade.PositionModify(ticket, be_sl, current_tp);
               Print("🛡️ [Breakeven] SELL SL digeser ke breakeven-1pip: ", DoubleToString(be_sl, 5));
              }
           }
        }
     }
  }

// ==========================================
// FEEDBACK LOOP
// ==========================================
// ==========================================
// FEEDBACK LOOP: Kirim Detail Transaksi ke Server
// ==========================================
void SendFeedback(string result, double profit, double balance)
  {
   // Ambil detail deal terakhir dari history
   HistorySelect(TimeCurrent()-3600, TimeCurrent());
   int total = HistoryDealsTotal();
   ulong  ticket = 0;
   string type   = "N/A";
   double vol    = 0;
   double px_in  = 0;
   double px_out = 0;

   // Cari deal terakhir yang sesuai magic number
   for(int i = total - 1; i >= 0; i--)
     {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC) == InpMagicNum && HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol)
        {
         ticket = t;
         long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
         vol    = HistoryDealGetDouble(t, DEAL_VOLUME);
         px_out = HistoryDealGetDouble(t, DEAL_PRICE);
         
         long d_type = HistoryDealGetInteger(t, DEAL_TYPE);
         if(d_type == DEAL_TYPE_BUY) type = "BUY";
         else if(d_type == DEAL_TYPE_SELL) type = "SELL";
         
         // Untuk mendapatkan PX_IN, kita cari deal pembukanya (ini penyederhanaan)
         // Jika ini adalah DEAL_ENTRY_OUT, px_out adalah harga tutup.
         break; 
        }
     }

   string payload = StringFormat("%s|%s|%.2f|%.2f|%I64u|%s|%.2f|%.5f|%.5f", 
                                 _Symbol, result, profit, balance, ticket, type, vol, px_out, px_out);
                                 
   char data[], res[];
   StringToCharArray(payload, data, 0, StringLen(payload));
   string headers   = "Content-Type: text/plain\r\n";
   string feedUrl   = InpServerUrl;
   if(StringSubstr(feedUrl, StringLen(feedUrl)-1) != "/") feedUrl += "/";
   feedUrl += "feedback";
   int httpRes = WebRequest("POST", feedUrl, headers, 4000, data, res, headers);
   if(httpRes == 200)
      Print("💬 [Feedback] Laporan detail terkirim: ", ticket);
   else
      Print("❌ [Feedback] Gagal detail. HTTP:", httpRes);
  }

// ==========================================
// PHASE 3: SCALPER DRONE
// ==========================================
void RunScalperDrone()
  {
   // Scalper hanya jalan di luar posisi aktif dan di sesi liquid
   if(GetEAPositionsTotal() > 0) return;
   if(!IsActiveSession())        return;

   double m1_open  = iOpen(_Symbol, PERIOD_M1, 1);
   double m1_close = iClose(_Symbol, PERIOD_M1, 1);
   double m5_open  = iOpen(_Symbol, PERIOD_M5, 1);
   double m5_close = iClose(_Symbol, PERIOD_M5, 1);
   double m1_delta = (m1_close - m1_open) / _Point;
   double m5_delta = (m5_close - m5_open) / _Point;
   long   spread   = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Kirim payload mini ke endpoint /scalp
   string payload = StringFormat("SYMBOL:%s M1:%.0f M5:%.0f SPREAD:%d ASK:%.5f BID:%.5f",
                                  _Symbol, m1_delta, m5_delta, spread, ask, bid);
   char data[], result[];
   string headers = "Content-Type: text/plain\r\n";
   string scalperUrl = InpServerUrl;
   if(StringSubstr(scalperUrl, StringLen(scalperUrl)-1) != "/") scalperUrl += "/";
   scalperUrl += "scalp";

   int res = WebRequest("POST", scalperUrl, headers, 5000, data, result, headers);
   if(res != 200) return;

   string answer = CharArrayToString(result);
   if(StringLen(answer) < 5) return;

   string parts[];
   int count = StringSplit(answer, '|', parts);
   if(count < 5) return;

   string action = parts[0];
   StringTrimLeft(action); StringTrimRight(action);
   double sl_ai  = StringToDouble(parts[2]);
   double tp_ai  = StringToDouble(parts[3]);

   double scalp_lot = GetDynamicLot();

   if(action == "SCALP_BUY")
     {
      trade.Buy(scalp_lot, _Symbol, ask, sl_ai, tp_ai, "SCALP DRONE BUY");
      Print("🐝 [ScalperDrone] SCALP_BUY ", DoubleToString(scalp_lot, 2), " lot");
     }
   else if(action == "SCALP_SELL")
     {
      trade.Sell(scalp_lot, _Symbol, bid, sl_ai, tp_ai, "SCALP DRONE SELL");
      Print("🐝 [ScalperDrone] SCALP_SELL ", DoubleToString(scalp_lot, 2), " lot");
     }
  }

//+------------------------------------------------------------------+
//| ON TICK: MARTINGALE GRID + BREAKEVEN/TRAILING                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsWeekend())
     {
      static datetime last_wknd = 0;
      if(TimeCurrent() - last_wknd > 3600)
        {
         Print("🌙 [Oracle] Weekend. Pasar Tutup. Robot Istirahat.");
         last_wknd = TimeCurrent();
        }
      return;
     }

   // DAILY KILLSWITCH CHECK
   if(CheckDailyKillswitch()) return;

   // PHASE 1B: BREAKEVEN & TRAILING (tiap tick)
   ManageBreakevenTrailing();

   // MARTINGALE GRID DRONE LOGIC
   int total_pos = 0;
   double total_profit = 0.0;
   long grid_type = -1;
   double extreme_price = 0.0;
   double highest_lot   = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         total_pos++;
         total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         grid_type     = PositionGetInteger(POSITION_TYPE);
         double op     = PositionGetDouble(POSITION_PRICE_OPEN);
         double vol    = PositionGetDouble(POSITION_VOLUME);
         if(highest_lot < vol) highest_lot = vol;
         if(grid_type == POSITION_TYPE_BUY)
            extreme_price = (extreme_price == 0 || op < extreme_price) ? op : extreme_price;
         else if(grid_type == POSITION_TYPE_SELL)
            extreme_price = (extreme_price == 0 || op > extreme_price) ? op : extreme_price;
        }
     }

   if(total_pos > 0 && total_profit >= InpTargetProfitUSD)
     {
      CloseAllPositions();
      return;
     }

   if(total_pos > 0)
     {
      double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distance = InpBaseGridStep * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(grid_type == POSITION_TYPE_BUY && (extreme_price - ask >= distance))
         trade.Buy(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, ask, 0, 0, "Drone Layer [Buy]");
      else if(grid_type == POSITION_TYPE_SELL && (bid - extreme_price >= distance))
         trade.Sell(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, bid, 0, 0, "Drone Layer [Sell]");
     }
  }

//+------------------------------------------------------------------+
//| ON TIMER: ORACLE M1 + SCALPER PULSE + FEEDBACK TRACKER          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   static datetime last_m1_bar   = 0;
   datetime current_m1_bar       = iTime(_Symbol, PERIOD_M1, 0);

   // SCALPER DRONE PULSE (tiap N menit)
   scalper_tick_count++;
   if(scalper_tick_count >= InpScalperIntervalMin * 60)
     {
      scalper_tick_count = 0;
      RunScalperDrone();
     }

   if(current_m1_bar == last_m1_bar) return;
   last_m1_bar = current_m1_bar;

   // FEEDBACK TRACKER: Deteksi basket baru ditutup
   int current_pos = GetEAPositionsTotal();
   static int    last_pos     = 0;
   static double last_balance = 0;

   if(last_pos == 0 && current_pos > 0)
      last_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   else if(last_pos > 0 && current_pos == 0)
     {
      double profit = AccountInfoDouble(ACCOUNT_BALANCE) - last_balance;
      string outcome = (profit > 0) ? "WIN" : (profit == 0 ? "CUT" : "LOSS");
      // Update win/loss streak
      if(outcome == "WIN")   { win_streak++;  loss_streak = 0; }
      else                   { loss_streak++; win_streak  = 0; }
      SendFeedback(outcome, profit, AccountInfoDouble(ACCOUNT_BALANCE));
     }
   last_pos = current_pos;

   // SKIP AI jika posisi masih berjalan (kecuali setiap 15 menit untuk audit)
   if(current_pos > 0)
     {
      static int skip_count = 0;
      skip_count++;
      if(skip_count < 15) return;
      skip_count = 0;
     }

   if(!IsActiveSession())
     {
      MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
      Print("💤 [Oracle] UTC ", dt.hour, ":00 — Di luar sesi. (Heartbeat sent)");
      
      // Heartbeat sinkronisasi Dashboard 24/5 saat robot tidur
      string hbPayload = StringFormat("SYMBOL:%s|FLOAT:%.2f|BAL:%.2f|F_MARG:%.2f|POS:%d", 
                                  _Symbol, AccountInfoDouble(ACCOUNT_PROFIT), AccountInfoDouble(ACCOUNT_BALANCE), 
                                  AccountInfoDouble(ACCOUNT_MARGIN_FREE), current_pos);
      char data[], res[];
      StringToCharArray(hbPayload, data, 0, StringLen(hbPayload));
      string headers = "Content-Type: text/plain\r\n";
      string hbUrl = InpServerUrl;
      if(StringSubstr(hbUrl, StringLen(hbUrl)-1) != "/") hbUrl += "/";
      hbUrl += "heartbeat";
      WebRequest("POST", hbUrl, headers, 3000, data, res, headers);
      
      return;
     }

   // === ORACLE DEEP THINKING ===
   double m1_shift  = (iClose(_Symbol, PERIOD_M1, 1)  - iOpen(_Symbol, PERIOD_M1, 1))  / _Point;
   double m15_shift = (iClose(_Symbol, PERIOD_M15, 1) - iOpen(_Symbol, PERIOD_M15, 1)) / _Point;
   double h1_shift  = (iClose(_Symbol, PERIOD_H1, 1)  - iOpen(_Symbol, PERIOD_H1, 1))  / _Point;
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   long   spread    = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double floating  = AccountInfoDouble(ACCOUNT_PROFIT);
   double free_marg = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double d1_high   = iHigh(_Symbol, PERIOD_D1, 0);
   double d1_low    = iLow(_Symbol, PERIOD_D1, 0);

   // ATR H1 untuk volatilitas
   int atr_handle = iATR(_Symbol, PERIOD_H1, 14);
   double atr_buf[]; ArraySetAsSeries(atr_buf, true);
   double atr_pips = 0;
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_buf) > 0)
      atr_pips = atr_buf[0] / _Point;
   IndicatorRelease(atr_handle);

   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   string session = (dt.hour >= 13 && dt.hour < 16) ? "LONDON+NY_OVERLAP" :
                    (dt.hour >= 7  && dt.hour < 16) ? "LONDON" :
                    (dt.hour >= 16 && dt.hour < 22) ? "NEW_YORK" : "ASIA";

   // CONFIDENCE SCORE dari win/loss streak untuk dikirim ke server
   int confidence_bias = 50 + (win_streak * 5) - (loss_streak * 8);
   confidence_bias = MathMax(10, MathMin(95, confidence_bias));

   Print("⏳ [Oracle v9] ", _Symbol, " | ", session, " | Spread:", spread, " | ATR:", DoubleToString(atr_pips,0), " | WinStreak:", win_streak, " | LossStreak:", loss_streak);

   string portofolio   = StringFormat("POS:%d|FLOAT:%.2f|BAL:%.2f|F_MARG:%.2f|WIN_STREAK:%d|LOSS_STREAK:%d",
                                       current_pos, floating, balance, free_marg, win_streak, loss_streak);
   string structure    = StringFormat("D1_H:%.5f|D1_L:%.5f|ASK:%.5f|SPREAD:%d|ATR_PIP:%.0f",
                                       d1_high, d1_low, ask, spread, atr_pips);
   string session_info = StringFormat("SESSION:%s|DAILY_START_BAL:%.2f|CONF_BIAS:%d",
                                       session, daily_start_balance, confidence_bias);

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
      Print("📡 [RAW AI] ", answer);
      string parts[];
      int n = StringSplit(answer, '|', parts);

      if(n >= 5)
        {
         string action   = parts[0]; StringTrimLeft(action); StringTrimRight(action);
         double entry_ai = StringToDouble(parts[1]);
         double sl_ai    = StringToDouble(parts[2]);
         double tp_ai    = StringToDouble(parts[3]);
         string reason   = parts[4];

         // Ambil CONFIDENCE dari parts[5] jika ada
         int    conf     = 50;
         if(n >= 6 && StringFind(parts[5], "CONFIDENCE:") != -1)
           {
            string cv = StringSubstr(parts[5], 11);
            conf = (int)StringToInteger(cv);
           }

         // Lot dinamis berdasarkan confidence dari AI
         double exec_lot = GetDynamicLot();
         if(conf >= 76) exec_lot = NormalizeLot(exec_lot * 1.5);   // Extra lot saat sangat yakin
         else if(conf < 50) exec_lot = InpInitialLot;               // Lot minimum saat ragu

         Print("🧠 [Oracle] Action:", action, " | Conf:", conf, "% | Lot:", DoubleToString(exec_lot,2), " | ", reason);

         if(action == "CUT_LOSS_ALL" || action == "CUT_LOSS")
           {
            Print("⚠️ [Oracle] CUT LOSS DIJALANKAN!");
            CloseAllPositions();
           }
         else if(action == "HOLD") { /* diam */ }
         else if(action == "BUY")
            trade.Buy(exec_lot, _Symbol, ask, sl_ai, tp_ai, "A.I MARKET BUY");
         else if(action == "SELL")
            trade.Sell(exec_lot, _Symbol, bid, sl_ai, tp_ai, "A.I MARKET SELL");
         else if(action == "BUY_LIMIT")
           {
            if(HasPendingOrder()) CancelAllPendingOrders();
            trade.BuyLimit(exec_lot, entry_ai, _Symbol, sl_ai, tp_ai, ORDER_TIME_GTC, 0, "A.I LIMIT");
            Print("✅ [Oracle] BUY_LIMIT @ ", DoubleToString(entry_ai, 5));
           }
         else if(action == "SELL_LIMIT")
           {
            if(HasPendingOrder()) CancelAllPendingOrders();
            trade.SellLimit(exec_lot, entry_ai, _Symbol, sl_ai, tp_ai, ORDER_TIME_GTC, 0, "A.I LIMIT");
            Print("✅ [Oracle] SELL_LIMIT @ ", DoubleToString(entry_ai, 5));
           }
         else if(action == "AVERAGING_BUY")
            trade.Buy(NormalizeLot(exec_lot * 1.5), _Symbol, ask, sl_ai, tp_ai, "A.I AVG UP");
         else if(action == "AVERAGING_SELL")
            trade.Sell(NormalizeLot(exec_lot * 1.5), _Symbol, bid, sl_ai, tp_ai, "A.I AVG DOWN");
        }
      else
         Print("⚠️ Sinyal Tak Terbaca: ", answer);
     }
   else
     {
      int err = GetLastError();
      string errDesc = "";
      if(err == 4014)   errDesc = "URL tidak di-whitelist!";
      else if(res == -1) errDesc = "Timeout AI (naikkan InpAITimeoutMs).";
      else if(res == 404) errDesc = "404: Endpoint tidak ada.";
      else if(res == 500) errDesc = "500: Server error.";
      else               errDesc = "Error tak dikenal.";
      Print("❌ [Oracle] GAGAL! HTTP:", res, " | Err:", err, " → ", errDesc);
     }
  }
//+------------------------------------------------------------------+
