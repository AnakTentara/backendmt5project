//+------------------------------------------------------------------+
//|                                                   AutoTrade6.mq5 |
//|                                                      Antigravity |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "6.00"

#include <Trade\Trade.mqh>
CTrade trade;

//--- INPUT PARAMETERS BAWAAN
input string   InpServerUrl        = "http://127.0.0.1:8880/signal"; // Alamat Localhost Peladen AI
input double   InpInitialLot       = 0.01;      // Ukuran Lot Tembakan Murni AI
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat (Martingale Averaging)
input int      InpBaseGridStep     = 1500;      // Jarak Poin Jaring Darurat
input double   InpTargetProfitUSD  = 3.0;       // Target Penutupan Sapu Bersih
input ulong    InpMagicNum         = 606606;    // Magic Number "The Executioner"

datetime last_signal_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   
   // Kita buat EA menengok ke server lokal setiap Detik ke-1
   EventSetTimer(1); 
   
   Print("AutoTrade6: Senjata telah dikokang, menunggu transmisi dari Backend AI di ", InpServerUrl);
   Print("🚨 PASTIKAN: Menu Tools > Options > Expert Advisors > Centang 'Allow WebRequest' dan tambahkan URL localhost 🚨");
   
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
   Print("🤖🔥 AI SYSTEM BINGO! Seluruh keranjang berhasil dicetak menjadi Uang!");
  }

double NormalizeLot(double lot)
  {
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double safe = MathRound(lot / step) * step;
   if(safe < min) safe = min;
   if(safe > max) safe = max;
   return safe;
  }

//+------------------------------------------------------------------+
//| OnTick - Dipakai khusus untuk mengurus Jaring Darurat Keselamatan|
//+------------------------------------------------------------------+
void OnTick()
  {
   int total_pos = 0;
   double total_profit = 0.0;
   long grid_type = -1; 
   double extreme_price = 0.0; 
   double highest_lot = 0.0;

   // 1. Memindai Pasukan
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         total_pos++;
         total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         
         grid_type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double vol = PositionGetDouble(POSITION_VOLUME);
         
         if(highest_lot < vol) highest_lot = vol;

         if(grid_type == POSITION_TYPE_BUY)
           {
            if(extreme_price == 0.0 || open_price < extreme_price) extreme_price = open_price;
           }
         else if(grid_type == POSITION_TYPE_SELL)
           {
            if(extreme_price == 0.0 || open_price > extreme_price) extreme_price = open_price;
           }
        }
     }

   // 2. CEK PROFIT BERJAMAAH
   if(total_pos > 0 && total_profit >= InpTargetProfitUSD)
     {
      CloseAllPositions();
      return; 
     }

   // 3. JARING PENYELAMATAN (Berjalan otomatis, tidak peduli AI sedang apa)
   if(total_pos > 0)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      double next_lot = NormalizeLot(highest_lot * InpLotMultiplier);
      double distance_in_price = InpBaseGridStep * point;

      // Di versi AutoTrade6 ini, kita membuang Reversal Candle agar serangannya murni matematis saat menunggu AI memikirkan berita
      if(grid_type == POSITION_TYPE_BUY)
        {
         if(extreme_price - ask >= distance_in_price)
           {
            trade.Buy(next_lot, _Symbol, ask, 0, 0, "Drone Layer [Buy]");
           }
        }
      else if(grid_type == POSITION_TYPE_SELL)
        {
         if(bid - extreme_price >= distance_in_price)
           {
            trade.Sell(next_lot, _Symbol, bid, 0, 0, "Drone Layer [Sell]");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| OnTimer - Telinga yang mendengar transmisi Server Backend Lokal   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Jika sedang nyangkut posisi, jangan nanya berita ke Server agar tidak tumpang tindih
   if(PositionsTotal() > 0) return;

   string cookie=NULL, headers;
   string post_data = "";
   char post[], result[];
   int res;
   
   // Kita tembak peladen backend lokal
   ResetLastError();
   
   // Timeout di-set sangat cepat (50 milidetik) agar grafis layar MT5 tidak patah-patah kalau server down
   res = WebRequest("GET", InpServerUrl, cookie, NULL, 50, post, 0, result, headers);
   
   if(res == 200) // Jika Server membalas
     {
      string signal = CharArrayToString(result);
      StringTrimLeft(signal);
      StringTrimRight(signal); // Membuang ruang spasi kosong
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(signal == "BUY")
        {
         trade.Buy(InpInitialLot, _Symbol, ask, 0, 0, "GOOGLE GEMINI: [Buy]");
        }
      else if(signal == "SELL")
        {
         trade.Sell(InpInitialLot, _Symbol, bid, 0, 0, "GOOGLE GEMINI: [Sell]");
        }
     }
  }
//+------------------------------------------------------------------+
