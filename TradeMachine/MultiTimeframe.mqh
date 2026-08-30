//+------------------------------------------------------------------+
//|                                          MultiTimeframe.mqh      |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"

//--- Timeframe Array
ENUM_TIMEFRAMES g_timeframes[5] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
string g_tf_names[5] = {"M5", "M15", "M30", "H1", "H4"};

//--- Rate Buffers (1D dynamic series buffers)
MqlRates g_rates_m5[];
MqlRates g_rates_m15[];
MqlRates g_rates_m30[];
MqlRates g_rates_h1[];
MqlRates g_rates_h4[];

int g_rates_count[5] = {0,0,0,0,0};
datetime g_last_update[5] = {0,0,0,0,0};
datetime g_last_bar_time_tf[5] = {0,0,0,0,0};

//--- Indicator handles
int g_ema20_handle[5] = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};
int g_ema50_handle[5] = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};
int g_ema200_handle[5] = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};
int g_atr_handle[5] = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};

//+------------------------------------------------------------------+
//| Initialize Multi-Timeframe Module                                |
//+------------------------------------------------------------------+
void MultiTimeframe_Init() {
    ArraySetAsSeries(g_rates_m5, true);
    ArraySetAsSeries(g_rates_m15, true);
    ArraySetAsSeries(g_rates_m30, true);
    ArraySetAsSeries(g_rates_h1, true);
    ArraySetAsSeries(g_rates_h4, true);

    for(int i = 0; i < 5; i++) {
        g_ema20_handle[i] = iMA(_Symbol, g_timeframes[i], 20, 0, MODE_EMA, PRICE_CLOSE);
        g_ema50_handle[i] = iMA(_Symbol, g_timeframes[i], 50, 0, MODE_EMA, PRICE_CLOSE);
        g_ema200_handle[i] = iMA(_Symbol, g_timeframes[i], 200, 0, MODE_EMA, PRICE_CLOSE);
        g_atr_handle[i] = iATR(_Symbol, g_timeframes[i], 14);
        
        UpdateTFData(i);
    }
    Print("MultiTimeframe: Initialized 5 timeframes with series buffers");
}

//+------------------------------------------------------------------+
//| Cleanup                                                          |
//+------------------------------------------------------------------+
void MultiTimeframe_Cleanup() {
    for(int i = 0; i < 5; i++) {
        if(g_ema20_handle[i] != INVALID_HANDLE) IndicatorRelease(g_ema20_handle[i]);
        if(g_ema50_handle[i] != INVALID_HANDLE) IndicatorRelease(g_ema50_handle[i]);
        if(g_ema200_handle[i] != INVALID_HANDLE) IndicatorRelease(g_ema200_handle[i]);
        if(g_atr_handle[i] != INVALID_HANDLE) IndicatorRelease(g_atr_handle[i]);
    }
}

//+------------------------------------------------------------------+
//| Update Single TF Data                                            |
//+------------------------------------------------------------------+
void UpdateTFData(int tf_idx) {
    int copied = 0;
    switch(tf_idx) {
        case 0: copied = CopyRates(_Symbol, PERIOD_M5, 0, 300, g_rates_m5); break;
        case 1: copied = CopyRates(_Symbol, PERIOD_M15, 0, 300, g_rates_m15); break;
        case 2: copied = CopyRates(_Symbol, PERIOD_M30, 0, 300, g_rates_m30); break;
        case 3: copied = CopyRates(_Symbol, PERIOD_H1, 0, 300, g_rates_h1); break;
        case 4: copied = CopyRates(_Symbol, PERIOD_H4, 0, 300, g_rates_h4); break;
    }
    if(copied > 0) {
        g_rates_count[tf_idx] = copied;
        g_last_update[tf_idx] = TimeCurrent();
        g_last_bar_time_tf[tf_idx] = iTime(_Symbol, g_timeframes[tf_idx], 0);
    }
}

//+------------------------------------------------------------------+
//| Check New Bar for Specific TF                                    |
//+------------------------------------------------------------------+
bool IsNewBarTF(int tf_idx) {
    datetime current_bar = iTime(_Symbol, g_timeframes[tf_idx], 0);
    if(current_bar != g_last_bar_time_tf[tf_idx]) {
        g_last_bar_time_tf[tf_idx] = current_bar;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Update All Timeframes                                            |
//+------------------------------------------------------------------+
void UpdateMultiTimeframeData() {
    for(int i = 0; i < 5; i++) {
        if(IsNewBarTF(i) || g_rates_count[i] == 0) {
            UpdateTFData(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Sync All Timeframes                                              |
//+------------------------------------------------------------------+
void SyncAllTimeframes() {
    for(int i = 0; i < 5; i++) {
        UpdateTFData(i);
    }
}

//+------------------------------------------------------------------+
//| Get Indicator Value (EMA, ATR)                                   |
//+------------------------------------------------------------------+
double GetEMA(int tf_idx, int period, int shift = 0) {
    int handle = INVALID_HANDLE;
    if(period == 20) handle = g_ema20_handle[tf_idx];
    else if(period == 50) handle = g_ema50_handle[tf_idx];
    else if(period == 200) handle = g_ema200_handle[tf_idx];
    else return 0;
    
    if(handle == INVALID_HANDLE) return 0;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0) return 0;
    return buffer[0];
}

double GetATR(int tf_idx, int shift = 0) {
    if(g_atr_handle[tf_idx] == INVALID_HANDLE) return 0;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    if(CopyBuffer(g_atr_handle[tf_idx], 0, shift, 1, buffer) <= 0) return 0;
    return buffer[0];
}
