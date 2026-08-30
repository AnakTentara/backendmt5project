//+------------------------------------------------------------------+
//|                                           PatternDetector.mqh    |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "4.00"
#include "Types.mqh"
#include "Config.mqh"
#include "MarketStructure.mqh"
#include "SupportResistance.mqh"

FlagPattern g_current_flag;
ConsolidationZone g_current_consolidation;
PatternResult g_last_pattern;

double g_donchian_high = 0;
double g_donchian_low = 0;

void PatternDetector_Init() {
    ZeroMemory(g_current_flag);
    ZeroMemory(g_current_consolidation);
    ZeroMemory(g_last_pattern);
}

void UpdateDonchian_M5() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, Inp_SD_LookbackBars + 5, rates) < Inp_SD_LookbackBars + 5) return;
    
    double hi = -DBL_MAX;
    double lo = DBL_MAX;
    for(int i = 2; i <= Inp_SD_LookbackBars; i++) {
        if(rates[i].high > hi) hi = rates[i].high;
        if(rates[i].low < lo)  lo = rates[i].low;
    }
    g_donchian_high = hi;
    g_donchian_low = lo;
}

void ScanPatterns_M5() {
    UpdateDonchian_M5();
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, Inp_SD_LookbackBars + 5, rates) < Inp_SD_LookbackBars + 5) return;
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double swing_hi = g_donchian_high;
    double swing_lo = g_donchian_low;
    if(swing_hi <= 0 || swing_lo <= 0) return;
    
    // 1. BUY: Supply Zone Breakout in past 5 bars + Retest of broken supply zone + Bullish Confirmation
    bool broken_up = false;
    for(int b = 1; b <= 5; b++) {
        if(rates[b].close > swing_hi) { broken_up = true; break; }
    }
    if(broken_up && rates[1].low <= swing_hi + Inp_SD_RetestZone_Pts && rates[1].close >= swing_hi && rates[1].close > rates[1].open) {
        double sl_dist = Inp_MinSL_Points;
        g_last_pattern.type = PATTERN_SD_RETEST_BUY;
        g_last_pattern.entry_price = ask;
        g_last_pattern.sl_price = NormalizeDouble(ask - sl_dist, 0);
        g_last_pattern.tp1_price = NormalizeDouble(ask + Inp_LockProfit_Pts, 0);
        g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
        g_last_pattern.tp2_price = NormalizeDouble(ask + 3000.0, 0); // Big wave runner
        g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
        g_last_pattern.confidence = 90;
        g_last_pattern.is_valid = true;
        g_last_pattern.detected_time = TimeCurrent();
        return;
    }
    
    // 2. SELL: Demand Zone Breakdown in past 5 bars + Retest of broken demand zone + Bearish Confirmation
    bool broken_dn = false;
    for(int b = 1; b <= 5; b++) {
        if(rates[b].close < swing_lo) { broken_dn = true; break; }
    }
    if(broken_dn && rates[1].high >= swing_lo - Inp_SD_RetestZone_Pts && rates[1].close <= swing_lo && rates[1].close < rates[1].open) {
        double sl_dist = Inp_MinSL_Points;
        g_last_pattern.type = PATTERN_SD_RETEST_SELL;
        g_last_pattern.entry_price = bid;
        g_last_pattern.sl_price = NormalizeDouble(bid + sl_dist, 0);
        g_last_pattern.tp1_price = NormalizeDouble(bid - Inp_LockProfit_Pts, 0);
        g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
        g_last_pattern.tp2_price = NormalizeDouble(bid - 3000.0, 0); // Big wave runner
        g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
        g_last_pattern.confidence = 90;
        g_last_pattern.is_valid = true;
        g_last_pattern.detected_time = TimeCurrent();
        return;
    }
}

void PrintPatterns() {}
