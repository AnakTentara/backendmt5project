//+------------------------------------------------------------------+
//|                                     BruteTest_EA.mq5            |
//|                                                        TradeMachine |
//|                          Standalone Brute Mode Tester            |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"

#include "../Include.mqh"
// For testing, include just the core components
#include "Types.mqh"
#include "BruteMode.mqh"

//+------------------------------------------------------------------+
//| Test Parameters                                                  |
//+------------------------------------------------------------------+
#define TEST_SYMBOL    "VOL_80"
#define TEST_TIMEFRAME PERIOD_M5
#define MAX_LOTS       100
#define SL_TIGHT       0.05
#define TP_MULTIPLIER  2.0

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("========================================");
    Print("BRUTE MODE STANDALONE TESTER");
    Print("Symbol: ", TEST_SYMBOL);
    Print("Timeframe: ", EnumToString(TEST_TIMEFRAME));
    Print("========================================");
    
    // Initialize brute mode with test params
    Inp_Brute_FixedLots = 0.01;
    Inp_Brute_UltraTightSL = SL_TIGHT;
    Inp_Brute_MaxOrdersPerMin = 60;
    Inp_Brute_ReentryDelay = 2;
    Inp_Brute_TP_RR = TP_MULTIPLIER;
    Inp_EnableLogging = true;
    
    BruteMode_Init();
    
    // Activate brute mode immediately for testing
    BruteMode_SetActive(true);
    
    Print("🔥 BRUTE MODE TESTER STARTED");
    
    EventSetTimer(1);  // Update every second
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("\n=== TEST COMPLETE ===");
    Print("Reason: ", IntegerToString(reason));
    BruteMode_PrintStatus();
    
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Run Brute Mode logic
    BruteMode_OnTick();
    
    // Check emergency stop file (if WebBridge sends command)
    // This would be integrated when full system is ready
}

//+------------------------------------------------------------------+
//| Timer Function (for periodic updates)                            |
//+------------------------------------------------------------------+
void OnTimer() {
    static int update_counter = 0;
    update_counter++;
    
    if(update_counter % 60 == 0) {
        // Log stats every minute
        Print("--- BRUTE TEST STATS ---");
        BruteMode_PrintStatus();
        
        // Check total orders this session
        int total = g_brute_state.total_brute_orders;
        double pnl = g_brute_state.session_pnl;
        Print("Total Orders: ", total);
        Print("Session PnL: ", DoubleToString(pnl, 2));
    }
    
    if(update_counter >= 3600) {
        // After 1 hour (60 min), stop automatically
        Print("⚠️ Test reached 1 hour limit. Stopping.");
        BruteMode_CloseAll();
        Deinit(INIT_REINITIALIZED);
    }
}

//+------------------------------------------------------------------+