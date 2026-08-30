//+------------------------------------------------------------------+
//|                                         SpreadFilter.mqh         |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"

double g_spread_history[100];
int g_spread_idx = 0;
int g_spread_count = 0;

void SpreadFilter_Init() {
    g_spread_state.current_spread = 0;
    g_spread_state.average_spread = 0;
    g_spread_state.max_spread_today = 0;
    g_spread_state.spread_warnings = 0;
    g_spread_state.is_wide = false;
    g_spread_state.state = SPREAD_NORMAL;
    
    ArrayInitialize(g_spread_history, 0);
    g_spread_idx = 0;
    g_spread_count = 0;
    Print("SpreadFilter: Initialized");
}

void UpdateSpreadState() {
    double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    g_spread_state.current_spread = current_spread;
    g_spread_state.last_spread_update = TimeCurrent();
    
    g_spread_history[g_spread_idx] = current_spread;
    g_spread_idx = (g_spread_idx + 1) % 100;
    if(g_spread_count < 100) g_spread_count++;
    
    double sum = 0;
    for(int i = 0; i < g_spread_count; i++) sum += g_spread_history[i];
    g_spread_state.average_spread = sum / g_spread_count;
    
    if(current_spread > g_spread_state.max_spread_today) {
        g_spread_state.max_spread_today = current_spread;
    }
    
    if(current_spread > Inp_SpreadCloseThresh) {
        g_spread_state.state = SPREAD_CRITICAL;
    } else if(current_spread > Inp_SpreadFilterMax * 1.5) {
        g_spread_state.state = SPREAD_VERY_WIDE;
    } else if(current_spread > Inp_SpreadFilterMax) {
        g_spread_state.state = SPREAD_WIDE;
    } else if(current_spread > Inp_SpreadReduceThresh) {
        g_spread_state.state = SPREAD_ELEVATED;
    } else {
        g_spread_state.state = SPREAD_NORMAL;
    }
    
    g_spread_state.is_wide = (g_spread_state.state >= SPREAD_WIDE);
}

bool SpreadFilter_Check() {
    if(!Inp_UseSpreadFilter) return true;
    
    if(Inp_AvoidRollover) {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if((dt.hour == 23 && dt.min >= 55) || (dt.hour == 0 && dt.min <= 5)) {
            return false;
        }
    }
    
    return (g_spread_state.current_spread <= Inp_SpreadFilterMax);
}

bool ShouldSkipTrade() {
    return !SpreadFilter_Check();
}

void PrintSpreadStatus() {
    Print("--- Spread: ", DoubleToString(g_spread_state.current_spread, 0),
          " pts | Avg: ", DoubleToString(g_spread_state.average_spread, 1),
          " pts | State: ", EnumToString(g_spread_state.state), " ---");
}
