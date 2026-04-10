//+------------------------------------------------------------------+
//|                                                   AutoTrade6.mq5 |
//|                             The Deep Thinking Agent (Tri-Radar)  |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "6.20"

#include <Trade\Trade.mqh>
CTrade trade;

input string   InpServerUrl        = "http://103.93.129.117:8880/"; // Gunakan Base URL agar tembus
input double   InpInitialLot       = 0.01;      // Ukuran Lot Kesatuan
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat Martingale
input int      InpBaseGridStep     = 1500;      // Poin Lapis Jaring AI
input double   InpTargetProfitUSD  = 3.0;       // Target Bersih Keranjang
input ulong    InpMagicNum         = 606606;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   
   // Polling 1 Detik, tetapi kita akan mengukur perpindahan Candle 1-Menit.
   EventSetTimer(1); 
   Print("AutoTrade6.2: Tri-Radar Intelligence Aktif! Menganalisa Paru-paru M1, M15, dan H1 secara Real-Time.");
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

//+------------------------------------------------------------------+
//| KESELAMATAN: MARTINGALE JARING OTOMATIS (Tanpa AI)               |
//+------------------------------------------------------------------+
void OnTick()
  {
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
   // Biarkan pasukan Martingale berperang. Jangan ajak bicara AI jika portofolio sedang bahaya/berjalan.
   if(PositionsTotal() > 0) return;

   static datetime last_m1_bar = 0;
   datetime current_m1_bar = iTime(_Symbol, PERIOD_M1, 0);

   // TRIGGER: Mengeksekusi Laporan HANYA saat lilin (candle) 1-Menit baru berlalu (Tepat 60 Detik Sinkron)
   if(current_m1_bar != last_m1_bar)
     {
      last_m1_bar = current_m1_bar;
      
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

      Print("⏳ [AutoTrade6]: Menghitung M1(", DoubleToString(m1_shift,0), "), M15(", DoubleToString(m15_shift,0), "), H1(", DoubleToString(h1_shift,0), ")... Menunggu Balasan AI.");

      // Membuat Surat Pengajuan ke Meja Warren Buffett
      string reportStruct = StringFormat("M1_PIPS:%.0f|M15_PIPS:%.0f|H1_PIPS:%.0f|HARGA:%.5f", m1_shift, m15_shift, h1_shift, ask);
      
      char posData[], result[];
      StringToCharArray(reportStruct, posData);
      string headers = "Content-Type: text/plain\r\n";
      
      ResetLastError();
      // Memberikan Kelonggaran Timeout karena proses "Deep Thinking" Gemini cukup lama (2 Detik Max di lokal MT5)
      int res = WebRequest("POST", InpServerUrl, headers, 2000, posData, result, headers);
      
      if(res == 200)
        {
         string answer = CharArrayToString(result);
         string stringArray[];
         int partsCount = StringSplit(answer, '|', stringArray);
         
         if(partsCount == 4)
           {
            // FORMAT WAJIB GOOGLE GEMINI TADI: ACTION | SL | TP | REASON
            string action = stringArray[0];
            double sl_ai  = StringToDouble(stringArray[1]); 
            double tp_ai  = StringToDouble(stringArray[2]); 
            string reason = stringArray[3];
            
            Print("🧠 [Deep Thinker]: ", reason);
            
            if(action == "BUY") trade.Buy(InpInitialLot, _Symbol, ask, sl_ai, tp_ai, "A.I: ["+DoubleToString(m1_shift,0)+"/"+DoubleToString(h1_shift,0)+"]");
            else if(action == "SELL") trade.Sell(InpInitialLot, _Symbol, bid, sl_ai, tp_ai, "A.I: ["+DoubleToString(m1_shift,0)+"/"+DoubleToString(h1_shift,0)+"]");
           }
         else
           {
            Print("⚠️ Sinyal Tak Terbaca/Hold: ", answer);
           }
        }
      else
        {
         Print("❌ GAGAL MENGHUBUNGI SERVER! Kode Balasan: ", res, " | Error System: ", GetLastError());
         Print("PASTIKAN Port Firewall Ubuntu terbuka ATAU URL MQL5 sudah di-Whitelist di Options!");
        }
     }
  }
//+------------------------------------------------------------------+
