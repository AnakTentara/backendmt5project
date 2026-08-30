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
    if(CopyRates(_Symbol, PERIOD_M5, 0, 20, rates) < 20) return;
    
    double hi = rates[2].high;
    double lo = rates[2].low;
    for(int i = 3; i <= 15; i++) {
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
    if(CopyRates(_Symbol, PERIOD_M5, 0, 20, rates) < 20) return;
    
    double rng1 = rates[1].high - rates[1].low;
    double body1 = MathAbs(rates[1].close - rates[1].open);
    if(rng1 <= 0 || (body1 / rng1) < 0.50) return; // Require strong conviction breakout bar (body >= 50%)
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // 1. Breakout Long Setup (Donchian breakout on previous closed bar + H1 alignment)
    if(rates[1].close > g_donchian_high && rates[1].close > rates[1].open && HigherTFsAlignedBullish()) {
        double swing_lo = GetLocalM5SwingLow(Inp_LocalSwingBars);
        if(swing_lo == 0) swing_lo = ask - 200.0;
        double sl_dist = (ask - swing_lo) + Inp_SL_Buffer_Pips;
        sl_dist = MathMax(Inp_MinSL_Points, MathMin(Inp_MaxSL_Points, sl_dist));
        
        g_last_pattern.type = PATTERN_BASE_BREAKOUT_UP;
        g_last_pattern.entry_price = ask;
        g_last_pattern.sl_price = NormalizeDouble(ask - sl_dist, 0);
        g_last_pattern.tp1_price = NormalizeDouble(ask + sl_dist * Inp_TP1_RR, 0);
        g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
        g_last_pattern.tp2_price = NormalizeDouble(ask + sl_dist * Inp_TP2_RR, 0);
        g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
        g_last_pattern.confidence = 85;
        g_last_pattern.is_valid = true;
        g_last_pattern.detected_time = TimeCurrent();
        return;
    }
    
    // 2. Breakout Short Setup (Donchian breakdown on previous closed bar + H1 alignment)
    if(rates[1].close < g_donchian_low && rates[1].close < rates[1].open && HigherTFsAlignedBearish()) {
        double swing_hi = GetLocalM5SwingHigh(Inp_LocalSwingBars);
        if(swing_hi == 0) swing_hi = bid + 200.0;
        double sl_dist = (swing_hi - bid) + Inp_SL_Buffer_Pips;
        sl_dist = MathMax(Inp_MinSL_Points, MathMin(Inp_MaxSL_Points, sl_dist));
        
        g_last_pattern.type = PATTERN_BASE_BREAKOUT_DOWN;
        g_last_pattern.entry_price = bid;
        g_last_pattern.sl_price = NormalizeDouble(bid + sl_dist, 0);
        g_last_pattern.tp1_price = NormalizeDouble(bid - sl_dist * Inp_TP1_RR, 0);
        g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
        g_last_pattern.tp2_price = NormalizeDouble(bid - sl_dist * Inp_TP2_RR, 0);
        g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
        g_last_pattern.confidence = 85;
        g_last_pattern.is_valid = true;
        g_last_pattern.detected_time = TimeCurrent();
        return;
    }
}

void PrintPatterns() {}
