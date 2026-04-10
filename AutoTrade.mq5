//+------------------------------------------------------------------+
//|                                                    AutoTrade.mq5 |
//|                                                      Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "4.00"

#include <Trade\Trade.mqh>
CTrade trade;

//--- INPUT PARAMETERS (THE SMART GRID MARTINGALE)
input double   InpInitialLot       = 0.01;      // Ukuran Lot Pancingan Pertama
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat (Martingale Multiplier)
input int      InpBaseGridStep     = 1500;      // Jarak Minimal Grid Lantai (Points)
input double   InpAtrMultiplier    = 1.5;       // Faktor Pengali Jarak Dinamis ATR
input double   InpTargetProfitUSD  = 3.0;       // Target Bersih Tutup Buku ($/Cent)
input int      InpRsiPeriod        = 14;        // Periode RSI (M15)
input int      InpAtrPeriod        = 14;        // Periode ATR (M15)
input ulong    InpMagicNum         = 404404;    // Magic Number EA Smart Grid (v4)

//--- GLOBAL VARIABLES
int handle_rsi;
int handle_atr;
double rsi[];
double atr[];
MqlRates rates[];
datetime last_layer_time = 0; // Mencegah tembak ganda di Bar yang sama

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   
   // Indikator Titik Masuk Pertama
   handle_rsi = iRSI(_Symbol, PERIOD_M15, InpRsiPeriod, PRICE_CLOSE);
   
   // Indikator Volatilitas / Pendeteksi Badai
   handle_atr = iATR(_Symbol, PERIOD_M15, InpAtrPeriod);
   
   if(handle_rsi == INVALID_HANDLE || handle_atr == INVALID_HANDLE)
     {
      Print("Error: Gagal menyalakan Radar AI.");
      return(INIT_FAILED);
     }
     
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(rates, true);

   Print("AutoTrade v4.0 SMART GRID MARTINGALE Siap Bekerja di ", _Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handle_rsi);
   IndicatorRelease(handle_atr);
  }

//+------------------------------------------------------------------+
//| Fungsi Target Keuntungan Total (All In)                          |
//+------------------------------------------------------------------+
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
   Print("💥💥 TAKTIK BERHASIL! Rombongan Layer Ditutup dengan PROFIT! 💥💥");
  }

//+------------------------------------------------------------------+
//| Normalisasi Lot                                                  |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double safe_lot = MathRound(lot / step_lot) * step_lot;
   if(safe_lot < min_lot) safe_lot = min_lot;
   if(safe_lot > max_lot) safe_lot = max_lot;
   return safe_lot;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int total_positions = 0;
   double total_profit = 0.0;
   long grid_type = -1; 
   double extreme_price = 0.0; 
   double highest_lot = 0.0;

   // 1. Memindai Keranjang Posisi
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         total_positions++;
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

   // 2. TRIGGER TARGET (TAKE PROFIT BERJAMAAH)
   if(total_positions > 0 && total_profit >= InpTargetProfitUSD)
     {
      CloseAllPositions();
      return; 
     }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // 3. PANCINGAN AWAL (Jika Kosong)
   if(total_positions == 0)
     {
      if(CopyBuffer(handle_rsi, 0, 1, 1, rsi) > 0)
        {
         if(rsi[0] > 70) 
            trade.Sell(InpInitialLot, _Symbol, bid, 0, 0, "First [Sell]");
         else if(rsi[0] < 30)
            trade.Buy(InpInitialLot, _Symbol, ask, 0, 0, "First [Buy]");
        }
      return;
     }

   // 4. THE SMART GRID PROTOCOL: Perhitungan Jarak yang Mengembang
   double next_lot = NormalizeLot(highest_lot * InpLotMultiplier);
   
   // Jarak dasar statis (Misal 1500 points = 150 pips)
   double dynamic_distance = InpBaseGridStep * point;
   
   // Kita ukur volatilitas dari indikator ATR M15. Jika lebih besar, rekam!
   if(CopyBuffer(handle_atr, 0, 1, 1, atr) > 0)
     {
      double volatile_dist = atr[0] * InpAtrMultiplier;
      if(volatile_dist > dynamic_distance) 
        {
         dynamic_distance = volatile_dist; // Jika pasar gila, jarak renggang gila
        }
     }

   // 5. FITUR ANTI-PISAU JATUH (Candlestick Reversal Confirmation)
   bool is_reversing = false;
   if(CopyRates(_Symbol, PERIOD_M15, 0, 2, rates) > 1)
     {
      // Kita memakai rates[1] yaitu Bar/Candle terakhir yang sudah Valid Menutup (Bukan yg berkedip)
      if(grid_type == POSITION_TYPE_BUY)
        {
         // Cari tanda pembalikan arah naik (Candle Hijau)
         if(rates[1].close > rates[1].open) is_reversing = true;
        }
      else if(grid_type == POSITION_TYPE_SELL)
        {
         // Cari tanda pembalikan arah turun (Candle Merah)
         if(rates[1].close < rates[1].open) is_reversing = true;
        }
     }

   // 6. PENEMBAKAN LAYER BANTUAN MARTINGALE (Dengan izin ganda)
   datetime current_time = iTime(_Symbol, PERIOD_M15, 0);
   if(current_time == last_layer_time) return; // Maksimal 1 bantuan per 15 Menit

   if(grid_type == POSITION_TYPE_BUY)
     {
      if((extreme_price - ask) >= dynamic_distance) // Syarat 1: Sudah jauh
        {
         if(is_reversing) // Syarat 2: Menunggu mantul candle hijau
           {
            if(trade.Buy(next_lot, _Symbol, ask, 0, 0, "Taktis Layer [Buy]"))
              {
               Print("⚠️ Smart Buy Terbuka! Jarak yg dihajar: ", dynamic_distance / point);
               last_layer_time = current_time;
              }
           }
        }
     }
   else if(grid_type == POSITION_TYPE_SELL)
     {
      if((bid - extreme_price) >= dynamic_distance) // Syarat 1: Sudah jauh
        {
         if(is_reversing) // Syarat 2: Menunggu merah
           {
            if(trade.Sell(next_lot, _Symbol, bid, 0, 0, "Taktis Layer [Sell]"))
              {
               Print("⚠️ Smart Sell Terbuka! Jarak yg dihajar: ", dynamic_distance / point);
               last_layer_time = current_time;
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
