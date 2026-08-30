//+------------------------------------------------------------------+
//|                                                    Include.mqh   |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
//+------------------------------------------------------------------+
//| Master Include - Core Modules Only                               |
//| DO NOT INCLUDE EXECUTION MODULES HERE                           |
//+------------------------------------------------------------------+

// Core Types & Config
#include "Types.mqh"
#include "Config.mqh"

// Analysis Modules
#include "MarketStructure.mqh"
#include "SupportResistance.mqh"
#include "PatternDetector.mqh"
#include "MultiTimeframe.mqh"

// Risk Management
#include "RiskManager.mqh"
#include "SpreadFilter.mqh"
#include "CapManager.mqh"

// Brute Mode
#include "BruteMode.mqh"
#include "HTTPReceiver.mqh"

// Execution (included in TradeMachine.mq5, not here)
// #include "OrderManager.mqh"
// #include "PositionManager.mqh"
// #include "TicketSplitter.mqh"

//+------------------------------------------------------------------+
//| Global Helper Functions                                          |
//+------------------------------------------------------------------+

// Quick logging (wrapper around Print)
void Log(string msg) {
    string ts = TimeToString(TimeCurrent(), TIME_DATE|TIME_TIME);
    Print(ts + " | " + msg);
}

// Quick alert
void Alert(string msg) {
    ::Alert(msg);
}

// Normalize to symbol digits
double NormalizePrice(double price) {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

// Check if trading hours (avoid rollover)
bool IsTradingHours() {
    int hour = TimeHour(TimeCurrent());
    int minute = TimeMinute(TimeCurrent());
    
    // Avoid rollover: 23:55 - 00:05
    if((hour == 23 && minute >= 55) || (hour == 0 && minute <= 5)) return false;
    return true;
}

// Get current spread
double GetCurrentSpread() {
    return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
}

// Check SL minimum distance
bool CanSetSL(double sl_distance_pts) {
    double min_stop = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_STOP_LEVEL);
    return sl_distance_pts >= min_stop;
}

//+------------------------------------------------------------------+