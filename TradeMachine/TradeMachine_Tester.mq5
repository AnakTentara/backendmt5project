//+------------------------------------------------------------------+
//|                                      TradeMachine_Tester.mq5     |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#property tester_everytick_calculate

#include "TradeMachine.mq5"

//+------------------------------------------------------------------+
//| Tester initialization                                            |
//+------------------------------------------------------------------+
int OnTesterInit() {
    Print("=== STRATEGY TESTER MODE ===");
    Print("Testing on: ", _Symbol, " | Period: ", EnumToString((ENUM_TIMEFRAMES)Period()));
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Tester deinitialization                                          |
//+------------------------------------------------------------------+
void OnTesterDeinit() {
    Print("=== TESTER COMPLETE ===");
    Print("Trades: ", g_daily_trades);
    Print("Final Balance: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
    Print("Net Profit: ", DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2));
}

//+------------------------------------------------------------------+
//| Tester pass (Optimization)                                       |
//+------------------------------------------------------------------+
double OnTester() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double profit = AccountInfoDouble(ACCOUNT_PROFIT);
    int trades = g_daily_trades;
    
    if(trades == 0) return -1000; // Penalize no trades
    
    // Custom fitness: Profit factor weighted by trade count
    double profit_factor = 1.0;
    // Would need to calculate from history
    
    // Simple fitness: profit per trade * sqrt(trades)
    double fitness = (profit / trades) * MathSqrt(trades);
    
    return fitness;
}

//+------------------------------------------------------------------+
//| Tester pass (Walk-forward)                                       |
//+------------------------------------------------------------------+
void OnTesterPass() {
    // Called after each optimization pass
}

//+------------------------------------------------------------------+