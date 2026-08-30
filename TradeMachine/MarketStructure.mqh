//+------------------------------------------------------------------+
//|                                             MarketStructure.mqh  |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "MultiTimeframe.mqh"

//--- Global Market Structure Data (per TF)
MarketStructure g_market_structure[5];  // M5, M15, M30, H1, H4

//--- Swing Point Storage
SwingPoint g_swing_highs[5][MAX_SWING_POINTS];
SwingPoint g_swing_lows[5][MAX_SWING_POINTS];
int g_swing_high_count[5] = {0,0,0,0,0};
int g_swing_low_count[5] = {0,0,0,0,0};
int g_swing_high_idx[5] = {0,0,0,0,0};
int g_swing_low_idx[5] = {0,0,0,0,0};

//+------------------------------------------------------------------+
//| Initialize Market Structure Module                               |
//+------------------------------------------------------------------+
void MarketStructure_Init() {
    ZeroMemory(g_swing_highs);
    ZeroMemory(g_swing_lows);
    
    for(int i = 0; i < 5; i++) {
        g_market_structure[i].timeframe = (TIMEFRAME_ID)g_timeframes[i];
        g_market_structure[i].trend = TREND_NEUTRAL;
        g_market_structure[i].prev_trend = TREND_NEUTRAL;
        g_market_structure[i].choch_bullish = false;
        g_market_structure[i].choch_bearish = false;
        g_market_structure[i].structure_valid = false;
        
        g_swing_high_count[i] = 0;
        g_swing_low_count[i] = 0;
        g_swing_high_idx[i] = 0;
        g_swing_low_idx[i] = 0;
    }
    Print("MarketStructure: Initialized for 5 timeframes");
}

//+------------------------------------------------------------------+
//| Helper to get rates reference                                    |
//+------------------------------------------------------------------+
int GetTFRates(int tf_idx, MqlRates &out_rates[]) {
    switch(tf_idx) {
        case 0: return CopyRates(_Symbol, PERIOD_M5, 0, 100, out_rates);
        case 1: return CopyRates(_Symbol, PERIOD_M15, 0, 100, out_rates);
        case 2: return CopyRates(_Symbol, PERIOD_M30, 0, 100, out_rates);
        case 3: return CopyRates(_Symbol, PERIOD_H1, 0, 100, out_rates);
        case 4: return CopyRates(_Symbol, PERIOD_H4, 0, 100, out_rates);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Detect Swing Points (5-Bar Fractal on Series Array)              |
//+------------------------------------------------------------------+
void DetectSwingPoints(int tf_idx) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = GetTFRates(tf_idx, rates);
    if(copied < 25) return;
    
    int lookback = Inp_SwingLookback;
    int max_scan = MathMin(copied - lookback, 50);
    
    // 1. Scan Swing Highs
    for(int i = lookback; i < max_scan; i++) {
        bool is_high = true;
        for(int j = 1; j <= lookback; j++) {
            if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high) {
                is_high = false;
                break;
            }
        }
        
        if(is_high) {
            double price = rates[i].high;
            datetime time = rates[i].time;
            
            bool exists = false;
            for(int k = 0; k < g_swing_high_count[tf_idx]; k++) {
                if(g_swing_highs[tf_idx][k].time == time) {
                    exists = true;
                    break;
                }
            }
            
            if(!exists) {
                SwingPoint sp;
                sp.price = price;
                sp.time = time;
                sp.is_high = true;
                sp.timeframe = tf_idx;
                sp.index = i;
                sp.volume = (double)rates[i].tick_volume;
                sp.is_confirmed = true;
                sp.choch_broken = false;
                sp.choch_time = 0;
                
                g_swing_highs[tf_idx][g_swing_high_idx[tf_idx]] = sp;
                g_swing_high_idx[tf_idx] = (g_swing_high_idx[tf_idx] + 1) % MAX_SWING_POINTS;
                if(g_swing_high_count[tf_idx] < MAX_SWING_POINTS) g_swing_high_count[tf_idx]++;
                
                g_market_structure[tf_idx].prev_high = g_market_structure[tf_idx].last_high;
                g_market_structure[tf_idx].last_high = sp;
            }
        }
    }
    
    // 2. Scan Swing Lows
    for(int i = lookback; i < max_scan; i++) {
        bool is_low = true;
        for(int j = 1; j <= lookback; j++) {
            if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low) {
                is_low = false;
                break;
            }
        }
        
        if(is_low) {
            double price = rates[i].low;
            datetime time = rates[i].time;
            
            bool exists = false;
            for(int k = 0; k < g_swing_low_count[tf_idx]; k++) {
                if(g_swing_lows[tf_idx][k].time == time) {
                    exists = true;
                    break;
                }
            }
            
            if(!exists) {
                SwingPoint sp;
                sp.price = price;
                sp.time = time;
                sp.is_high = false;
                sp.timeframe = tf_idx;
                sp.index = i;
                sp.volume = (double)rates[i].tick_volume;
                sp.is_confirmed = true;
                sp.choch_broken = false;
                sp.choch_time = 0;
                
                g_swing_lows[tf_idx][g_swing_low_idx[tf_idx]] = sp;
                g_swing_low_idx[tf_idx] = (g_swing_low_idx[tf_idx] + 1) % MAX_SWING_POINTS;
                if(g_swing_low_count[tf_idx] < MAX_SWING_POINTS) g_swing_low_count[tf_idx]++;
                
                g_market_structure[tf_idx].prev_low = g_market_structure[tf_idx].last_low;
                g_market_structure[tf_idx].last_low = sp;
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Check CHOCH on M5 (Per Tick)                                    |
//+------------------------------------------------------------------+
void CheckCHOCH_M5() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_price = (bid + ask) / 2.0;
    
    // Bullish CHOCH: Break above previous lower high
    if(g_market_structure[0].prev_high.price > 0 && 
       !g_market_structure[0].prev_high.choch_broken &&
       current_price > g_market_structure[0].prev_high.price) {
        
        g_market_structure[0].choch_bullish = true;
        g_market_structure[0].choch_price = current_price;
        g_market_structure[0].choch_time = TimeCurrent();
        g_market_structure[0].prev_high.choch_broken = true;
        Print("Bullish CHOCH detected on M5 @ ", current_price);
    }
    
    // Bearish CHOCH: Break below previous higher low
    if(g_market_structure[0].prev_low.price > 0 && 
       !g_market_structure[0].prev_low.choch_broken &&
       current_price < g_market_structure[0].prev_low.price) {
        
        g_market_structure[0].choch_bearish = true;
        g_market_structure[0].choch_price = current_price;
        g_market_structure[0].choch_time = TimeCurrent();
        g_market_structure[0].prev_low.choch_broken = true;
        Print("Bearish CHOCH detected on M5 @ ", current_price);
    }
}

//+------------------------------------------------------------------+
//| Update Trend State per TF                                        |
//+------------------------------------------------------------------+
void UpdateTFTrend(int tf_idx) {
    double ema20 = GetEMA(tf_idx, 20, 0);
    double ema50 = GetEMA(tf_idx, 50, 0);
    double ema200 = GetEMA(tf_idx, 200, 0);
    
    if(ema20 == 0 || ema50 == 0 || ema200 == 0) return;
    
    TREND_STATE state = TREND_NEUTRAL;
    if(ema20 > ema50 && ema50 > ema200) {
        state = TREND_BULLISH_STRONG;
    } else if(ema20 > ema50) {
        state = TREND_BULLISH_WEAK;
    } else if(ema20 < ema50 && ema50 < ema200) {
        state = TREND_BEARISH_STRONG;
    } else if(ema20 < ema50) {
        state = TREND_BEARISH_WEAK;
    }
    
    g_market_structure[tf_idx].prev_trend = g_market_structure[tf_idx].trend;
    g_market_structure[tf_idx].trend = state;
    g_market_structure[tf_idx].structure_valid = true;
}

//+------------------------------------------------------------------+
//| Update All Market Structure                                      |
//+------------------------------------------------------------------+
void UpdateMarketStructure() {
    for(int i = 0; i < 5; i++) {
        DetectSwingPoints(i);
        UpdateTFTrend(i);
    }
    CheckCHOCH_M5();
}

//+------------------------------------------------------------------+
//| Trend Query Helpers                                              |
//+------------------------------------------------------------------+
bool HigherTFsAlignedBullish() {
    return (g_market_structure[4].trend >= TREND_BULLISH_WEAK && // H4
            g_market_structure[3].trend >= TREND_BULLISH_WEAK && // H1
            g_market_structure[1].trend >= TREND_BULLISH_WEAK);  // M15
}

bool HigherTFsAlignedBearish() {
    return (g_market_structure[4].trend <= TREND_BEARISH_WEAK && // H4
            g_market_structure[3].trend <= TREND_BEARISH_WEAK && // H1
            g_market_structure[1].trend <= TREND_BEARISH_WEAK);  // M15
}

bool IsCHOCHBullishM5() { return g_market_structure[0].choch_bullish; }
bool IsCHOCHBearishM5() { return g_market_structure[0].choch_bearish; }

SwingPoint GetLastSwingHigh(int tf_idx) { return g_market_structure[tf_idx].last_high; }
SwingPoint GetLastSwingLow(int tf_idx)  { return g_market_structure[tf_idx].last_low; }

bool IsConsolidation() {
    return (g_market_structure[0].trend == TREND_NEUTRAL &&
            g_market_structure[1].trend == TREND_NEUTRAL);
}

void PrintMarketStructure() {
    for(int i=0; i<5; i++) {
        Print(g_tf_names[i], " Trend: ", EnumToString(g_market_structure[i].trend));
    }
}
