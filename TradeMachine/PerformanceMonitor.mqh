//+------------------------------------------------------------------+
//|                                       PerformanceMonitor.mqh     |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"

uint g_last_tick_time = 0;
uint g_execution_time_ms = 0;

void PerfMonitor_Init() {
    g_last_tick_time = 0;
    g_execution_time_ms = 0;
    Print("PerformanceMonitor: Initialized");
}

void PerfMonitor_StartTick() {
    g_last_tick_time = GetTickCount();
}

void PerfMonitor_EndTick() {
    if(g_last_tick_time > 0) {
        g_execution_time_ms = GetTickCount() - g_last_tick_time;
    }
}

void PerfPrintStats() {
    Print("--- Performance: Last Execution Time = ", g_execution_time_ms, " ms ---");
}
