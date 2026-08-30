//+------------------------------------------------------------------+
//|                                           PatternDetector.mqh    |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "MarketStructure.mqh"
#include "SupportResistance.mqh"

FlagPattern g_current_flag;
ConsolidationZone g_current_consolidation;
PatternResult g_last_pattern;

double g_donchian_high = 0;
double g_donchian_low = 0;
double g_atr_m5 = 0;
double g_atr_avg_m5 = 0;

void PatternDetector_Init() {
    ZeroMemory(g_current_flag);
    ZeroMemory(g_current_consolidation);
    ZeroMemory(g_last_pattern);
    Print("PatternDetector: Initialized");
}

void UpdateDonchian_M5() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, 20, rates) < 20) return;
    
    double hi = rates[0].high;
    double lo = rates[0].low;
    for(int i = 1; i < 20; i++) {
        if(rates[i].high > hi) hi = rates[i].high;
        if(rates[i].low < lo)  lo = rates[i].low;
    }
    g_donchian_high = hi;
    g_donchian_low = lo;
}

void UpdateATR_M5() {
    g_atr_m5 = GetATR(0, 0); // M5 ATR
    if(g_atr_m5 == 0) g_atr_m5 = 1200.0;
    g_atr_avg_m5 = g_atr_m5;
}

void DetectFlagPattern() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, 30, rates) < 30) return;
    
    ZeroMemory(g_current_flag);
    
    // Check for 3-bar pole
    int pole_bars = 0;
    bool bull_pole = false;
    bool bear_pole = false;
    
    for(int i = 5; i < 15; i++) {
        double body = MathAbs(rates[i].close - rates[i].open);
        double range = rates[i].high - rates[i].low;
        if(range <= 0) continue;
        
        if(body / range >= Inp_FlagPoleStrength) {
            if(rates[i].close > rates[i].open) {
                bull_pole = true;
                pole_bars++;
            } else {
                bear_pole = true;
                pole_bars++;
            }
        } else {
            break;
        }
    }
    
    if(pole_bars >= Inp_FlagMinBars) {
        g_current_flag.is_valid = true;
        g_current_flag.is_bull_flag = bull_pole;
        g_current_flag.is_bear_flag = bear_pole;
        g_current_flag.flag_top = rates[0].high;
        g_current_flag.flag_bottom = rates[0].low;
        g_current_flag.flag_bars = 5;
        
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Flag top sell logic
        if(bear_pole && bid >= g_current_flag.flag_top - 50) {
            g_last_pattern.type = PATTERN_FLAG_TOP_SELL;
            g_last_pattern.entry_price = bid;
            g_last_pattern.sl_price = GetMinorResistance() + Inp_SL_Buffer_Pips;
            g_last_pattern.tp1_price = bid - MathAbs(bid - g_last_pattern.sl_price) * Inp_RR_FlagTopSell;
            g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
            g_last_pattern.tp2_price = bid - MathAbs(bid - g_last_pattern.sl_price) * Inp_TP2_RR;
            g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
            g_last_pattern.confidence = 80;
            g_last_pattern.is_valid = true;
            g_last_pattern.detected_time = TimeCurrent();
            g_last_pattern.bars_duration = 5;
        }
    }
}

void DetectConsolidation() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, 25, rates) < 25) return;
    
    ZeroMemory(g_current_consolidation);
    double width = g_donchian_high - g_donchian_low;
    
    if(width < g_atr_avg_m5 * Inp_ATRContractionMult && width > 0) {
        g_current_consolidation.is_valid = true;
        g_current_consolidation.top = g_donchian_high;
        g_current_consolidation.bottom = g_donchian_low;
        g_current_consolidation.bars = 10;
        g_current_consolidation.atr_ratio = width / g_atr_avg_m5;
        g_current_consolidation.start_time = rates[10].time;
    }
}

void DetectStructureBreakouts() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current = (bid + ask) / 2.0;
    
    if(g_current_consolidation.is_valid) {
        if(current > g_current_consolidation.top + 20) {
            g_last_pattern.type = PATTERN_BASE_BREAKOUT_UP;
            g_last_pattern.entry_price = ask;
            g_last_pattern.sl_price = g_current_consolidation.bottom - Inp_SL_Buffer_Pips;
            g_last_pattern.tp1_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_RR_FlagBreakout;
            g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
            g_last_pattern.tp2_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_TP2_RR;
            g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
            g_last_pattern.confidence = 75;
            g_last_pattern.is_valid = true;
            g_last_pattern.detected_time = TimeCurrent();
            g_last_pattern.bars_duration = g_current_consolidation.bars;
        } else if(current < g_current_consolidation.bottom - 20) {
            g_last_pattern.type = PATTERN_BASE_BREAKOUT_DOWN;
            g_last_pattern.entry_price = bid;
            g_last_pattern.sl_price = g_current_consolidation.top + Inp_SL_Buffer_Pips;
            g_last_pattern.tp1_price = bid - MathAbs(g_last_pattern.sl_price - bid) * Inp_RR_FlagBreakout;
            g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
            g_last_pattern.tp2_price = bid - MathAbs(g_last_pattern.sl_price - bid) * Inp_TP2_RR;
            g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
            g_last_pattern.confidence = 75;
            g_last_pattern.is_valid = true;
            g_last_pattern.detected_time = TimeCurrent();
            g_last_pattern.bars_duration = g_current_consolidation.bars;
        }
    }
}

void DetectSDRetestConfirmation() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Retest of broken supply zone (now demand) + green bullish confirmation -> BEST BUY
    for(int i = 0; i < g_zone_count; i++) {
        if(g_zones[i].type == ZONE_DEMAND) {
            if(bid >= g_zones[i].bottom && bid <= g_zones[i].top + 50) {
                MqlRates rates[];
                ArraySetAsSeries(rates, true);
                if(CopyRates(_Symbol, PERIOD_M5, 0, 2, rates) >= 2) {
                    if(rates[0].close > rates[0].open) { // Green confirmation bar
                        g_last_pattern.type = PATTERN_SD_RETEST_BUY;
                        g_last_pattern.entry_price = ask;
                        g_last_pattern.sl_price = g_zones[i].bottom - Inp_SL_Buffer_Pips;
                        g_last_pattern.tp1_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_RR_BullishTrend;
                        g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
                        g_last_pattern.tp2_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_TP2_RR;
                        g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
                        g_last_pattern.confidence = 90;
                        g_last_pattern.is_valid = true;
                        g_last_pattern.detected_time = TimeCurrent();
                        g_last_pattern.bars_duration = 2;
                        return;
                    }
                }
            }
        }
    }
}

void ScanPatterns_M5() {
    UpdateDonchian_M5();
    UpdateATR_M5();
    
    DetectFlagPattern();
    DetectConsolidation();
    DetectStructureBreakouts();
    DetectSDRetestConfirmation();
}

void PrintPatterns() {
    Print("--- Last Pattern: ", EnumToString(g_last_pattern.type),
          " | Valid: ", g_last_pattern.is_valid,
          " | Confidence: ", g_last_pattern.confidence, "% ---");
}
