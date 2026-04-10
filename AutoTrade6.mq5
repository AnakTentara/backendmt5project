//+------------------------------------------------------------------+
//|                                                   AutoTrade6.mq5 |
//|                                    The Field Agent (Post Output) |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "6.10"

#include <Trade\Trade.mqh>
CTrade trade;

input string   InpServerUrl        = "http://103.93.129.117:8880/consult"; // Endpoint KONSULTASI (POST)
input double   InpInitialLot       = 0.01;      // Ukuran Lot Tembakan
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat Martingale
input int      InpBaseGridStep     = 1500;      // Jarak Poin Jaring Darurat
input double   InpTargetProfitUSD  = 3.0;       // Target Penutupan Sapu Bersih
input ulong    InpMagicNum         = 606606;    // Magic Number The Executioner

int handle_rsi;
double rsi[];
datetime last_consult_time = 0;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   handle_rsi = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
   ArraySetAsSeries(rsi, true);
   
   // Polling 1 detik hanya untuk jaring. Konsultasi AI hanya dipicu anomali.
   EventSetTimer(1); 
   Print("AutoTrade6.1: Menjadi Agen Lapangan. Menunggu Pemicu (Trigger) Anomali...");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   IndicatorRelease(handle_rsi);
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
   Print("🤖🔥 AI SYSTEM BINGO! Seluruh keranjang berhasil dicetak menjadi Uang!");
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
//| JARING MARTINGALE KESELAMATAN (Berjalan Tiap Tick Tanpa Otak)    |
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
      double distance_in_price = InpBaseGridStep * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(grid_type == POSITION_TYPE_BUY && (extreme_price - ask >= distance_in_price))
         trade.Buy(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, ask, 0, 0, "Drone Layer [Buy]");
      else if(grid_type == POSITION_TYPE_SELL && (bid - extreme_price >= distance_in_price))
         trade.Sell(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, bid, 0, 0, "Drone Layer [Sell]");
     }
  }

//+------------------------------------------------------------------+
//| EVENT-DRIVEN TRIGGER: AGEN LAPANGAN MENGHANTAR DATA KE AI       |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Jika robot sedang bertempur (ada posisi), jangan tanya AI baru. 
   // Fokus perang pakai Martingale. Biarkan AI istirahat.
   if(PositionsTotal() > 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime current = TimeCurrent();

   // MENCEGAH SPAM: Hanya hubungi AI jika sudah lewat 5 Menit sejak pertanyaan terakhir
   if(current - last_consult_time < 300) return;

   // 1. ANOMALI RADAR (Scanner Data)
   if(CopyBuffer(handle_rsi, 0, 1, 1, rsi) > 0)
     {
      // TRIGGER BAHAYA: Tanyakan ke AI HANYA JIKA RSI menyentuh Area Sangat Murah / Sangat Mahal
      // Inilah alasan kita tidak nge-spam WebRequest API tiap detik!
      if(rsi[0] >= 70 || rsi[0] <= 30)
        {
         // 2. PEMBENTUKAN LAPORAN INTELEJEN
         string reportStruct = StringFormat("RSI:%.2f|HARGA:%.5f", rsi[0], ask);
         
         // 3. KIRIM LAPORAN (POST Request) KE WARREN BUFFETT
         char posData[], result[];
         StringToCharArray(reportStruct, posData);
         string headers = "Content-Type: text/plain\r\n";
         
         ResetLastError();
         int res = WebRequest("POST", InpServerUrl, headers, 1000, posData, result, headers);
         
         if(res == 200)
           {
            last_consult_time = current;
            
            // 4. MEMBONGKAR (PARSING) ARAHAN AI
            string answer = CharArrayToString(result);
            string stringArray[];
            int partsCount = StringSplit(answer, '|', stringArray);
            
            // Format yang ditunggu: ACTION|SL|TP|REASON
            if(partsCount == 4)
              {
               string action = stringArray[0];
               double sl_ai  = StringToDouble(stringArray[1]); // SL dinamis usulan AI, 0 berarti mati.
               double tp_ai  = StringToDouble(stringArray[2]); // TP dinamis usulan AI
               string reason = stringArray[3];
               
               Print("🗣️ [AI Berbicara]: ", reason);
               
               // Jika AI melarang, ia hanya komentar Hold.
               if(action == "BUY")
                 {
                  trade.Buy(InpInitialLot, _Symbol, ask, sl_ai, tp_ai, "A.I: " + reason);
                 }
               else if(action == "SELL")
                 {
                  trade.Sell(InpInitialLot, _Symbol, bid, sl_ai, tp_ai, "A.I: " + reason);
                 }
              }
            else
              {
               Print("Pesan Mesin Acak (Bukan Format). Pesan: ", answer);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
