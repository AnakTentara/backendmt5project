//+------------------------------------------------------------------+
//|                                          TradeMachine.mq5        |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#property strict

#include "Types.mqh"
#include "Config.mqh"
#include "MultiTimeframe.mqh"
#include "MarketStructure.mqh"
#include "SupportResistance.mqh"
#include "PatternDetector.mqh"
#include "RiskManager.mqh"
#include "SpreadFilter.mqh"
#include "CapManager.mqh"
#include "TicketSplitter.mqh"
#include "OrderManager.mqh"
#include "PositionManager.mqh"
#include "PerformanceMonitor.mqh"
#include "ErrorHandling.mqh"
#include "HTTPReceiver.mqh"

// Forward declarations
void EvaluateEntries();
bool ValidateEntry(ENUM_POSITION_TYPE type, double entry, double sl);
TPDraft CalculateTP_Draft(double entry, double sl, double rr_config);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=================================================");
    Print("TradeMachine v3.0 - VOL_80 Synthetic Index EA");
    Print("=================================================");
    
    MathSrand(GetTickCount());
    
    InitRuntimeConfig();
    MultiTimeframe_Init();
    MarketStructure_Init();
    SupportResistance_Init();
    PatternDetector_Init();
    RiskManager_Init();
    SpreadFilter_Init();
    CapManager_Init();
    TicketSplitter_Init();
    OrderManager_Init();
    PositionManager_Init();
    HTTPReceiver_Init();
    PerfMonitor_Init();
    ErrorHandler_Init();
    
    if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT)) {
        SymbolSelect(_Symbol, true);
    }
    
    long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    if(leverage <= 0) leverage = 2000;
    double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    Print("TradeMachine initialized for ", _Symbol);
    Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN), " | Balance: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
    Print("Leverage: 1:", leverage, " | Initial Spread: ", spread, " pts");
    
    EventSetTimer(60);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    MultiTimeframe_Cleanup();
    ErrorHandler_Cleanup();
    ResetDailyMetrics();
    
    Print("=== TRADEMACHINE DEINITIALIZATION ===");
    Print("Final Daily Trades: ", g_daily_trades, " | Daily PnL: ", DoubleToString(g_daily_pnl, 2));
    PerfPrintStats();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    PerfMonitor_StartTick();
    
    // 0. Data updates
    UpdateMultiTimeframeData();
    UpdateSpreadState();
    UpdateMarketStructure();
    UpdateSupportResistance();
    ScanPatterns_M5();
    CapManager_Update();
    RiskManager_Update();
    HTTPReceiver_OnTick();
    
    // 1. Spread Check
    if(!SpreadFilter_Check()) {
        ManagePositions();
        ManagePendingOrders();
        PerfMonitor_EndTick();
        return;
    }
    
    // 2. Risk Alerts
    CheckRiskAlerts();
    
    // 3. Entry Evaluation
    EvaluateEntries();
    
    // 4. Position & Order Management
    ManagePositions();
    ManagePendingOrders();
    
    PerfMonitor_EndTick();
}

//+------------------------------------------------------------------+
//| Timer Function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    if(Inp_LogLevel >= 2) {
        Print("--- TIMER STATUS CHECK ---");
        PrintMarketStructure();
        PrintSpreadStatus();
        PrintRiskStatus();
        PrintCapStatus();
        PrintSupportResistance();
        PrintPatterns();
        PrintManagedPositions();
        PrintActiveSplits();
    }
    
    static int timer_count = 0;
    timer_count++;
    if(timer_count >= 5) {
        SyncAllTimeframes();
        timer_count = 0;
    }
}

//+------------------------------------------------------------------+
//| Evaluate Entries                                                 |
//+------------------------------------------------------------------+
datetime g_last_trade_bar = 0;

void EvaluateEntries() {
    datetime current_bar = iTime(_Symbol, PERIOD_M5, 0);
    if(current_bar == g_last_trade_bar) return; // Bar-lock: 1 trade per M5 bar max
    
    if(!CanAddPosition()) return;
    if(ShouldSkipTrade()) return;
    if(!g_last_pattern.is_valid) return;
    
    double entry_price = g_last_pattern.entry_price;
    double sl_price = g_last_pattern.sl_price;
    
    ENUM_POSITION_TYPE trade_type = (g_last_pattern.tp1_price > g_last_pattern.entry_price) ? 
                                    POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    
    if(!ValidateEntry(trade_type, entry_price, sl_price)) return;
    
    LotSizeResult lot_res = CalculateLotSize(entry_price, sl_price);
    if(!lot_res.valid) {
        Log("ENTRY REJECTED: " + lot_res.reason);
        return;
    }
    double lots = lot_res.lots;
    
    double req_margin;
    if(!CheckMarginSafety(lots, req_margin)) {
        Log("ENTRY REJECTED: Margin safety check failed");
        return;
    }
    
    double rr = GetDynamicRR();
    TPDraft draft = CalculateTP_Draft(entry_price, sl_price, rr);
    
    lots = GetCapAwareLotSize(lots);
    
    if(IsPositionCapReached(lots)) {
        TicketSplit split = CalculateSplit(lots, entry_price, sl_price);
        split.draft = draft;
        int created = SplitAndExecute(split);
        if(created > 0) {
            Log("MULTI-TICKET ENTRY: " + IntegerToString(created) + " tickets for " + DoubleToString(lots, 2) + " lots");
            g_daily_trades += created;
            g_last_trade_bar = current_bar;
        }
    } else {
        ulong ticket = OpenPositionDraftMode(entry_price, lots, draft);
        if(ticket > 0) {
            RegisterPosition(ticket, draft, -1, 0, 1, (g_last_pattern.type == PATTERN_FLAG_TOP_SELL));
            g_daily_trades++;
            g_last_trade_bar = current_bar;
        }
    }
    
    // Invalidate pattern after processing to avoid duplicate entries on same bar
    g_last_pattern.is_valid = false;
}

//+------------------------------------------------------------------+
//| Validate Entry                                                   |
//+------------------------------------------------------------------+
bool ValidateEntry(ENUM_POSITION_TYPE type, double entry, double sl) {
    double sl_points = MathAbs(entry - sl) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(sl_points < 20) {
        Log("ENTRY REJECTED: SL too tight (" + DoubleToString(sl_points, 0) + " pts)");
        return false;
    }
    
    if(type == POSITION_TYPE_BUY && PriceAtMajorSupply()) {
        Log("ENTRY REJECTED: At major supply zone");
        return false;
    }
    if(type == POSITION_TYPE_SELL && PriceAtMajorDemand()) {
        Log("ENTRY REJECTED: At major demand zone");
        return false;
    }
    
    if(type == POSITION_TYPE_SELL && HigherTFsAlignedBullish()) {
        if(!Inp_AllowCounterTrend) {
            Log("ENTRY REJECTED: Counter-trend sell not allowed");
            return false;
        }
        if(g_last_pattern.type != PATTERN_FLAG_TOP_SELL && g_last_pattern.type != PATTERN_BASE_BREAKOUT_DOWN) {
            Log("ENTRY REJECTED: Counter-trend sell only allowed at flag top or breakdown");
            return false;
        }
    }
    
    if(type == POSITION_TYPE_BUY && HigherTFsAlignedBearish()) {
        if(!Inp_AllowCounterTrend) {
            Log("ENTRY REJECTED: Counter-trend buy not allowed");
            return false;
        }
    }
    
    if(!SpreadFilter_Check()) {
        Log("ENTRY REJECTED: Spread filter failed");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate TP Draft with Dynamic R:R                              |
//+------------------------------------------------------------------+
TPDraft CalculateTP_Draft(double entry, double sl, double rr_config) {
    TPDraft draft;
    ZeroMemory(draft);
    
    draft.spread_at_entry = g_spread_state.current_spread;
    double gross_risk = MathAbs(entry - sl) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(gross_risk <= 0) gross_risk = 200.0;
    
    double gross_tp1_dist = gross_risk * rr_config;
    double net_tp1_dist = gross_tp1_dist - draft.spread_at_entry;
    
    if(net_tp1_dist < gross_risk * 0.3) {
        gross_tp1_dist = gross_risk * 0.3 + draft.spread_at_entry + gross_risk * 0.5;
    }
    
    if(entry > sl) { // Buy
        draft.tp1_price = entry + gross_tp1_dist * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        draft.tp2_price = entry + (gross_risk * Inp_TP2_RR) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    } else { // Sell
        draft.tp1_price = entry - gross_tp1_dist * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        draft.tp2_price = entry - (gross_risk * Inp_TP2_RR) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    }
    
    draft.tp1_rr = rr_config;
    draft.tp2_rr = Inp_TP2_RR;
    draft.net_rr = net_tp1_dist / gross_risk;
    draft.tp1_triggered = false;
    draft.tp1_been_been = false;
    
    // SL+ is midpoint between Entry and TP1
    draft.sl_plus_price = (entry + draft.tp1_price) / 2.0;
    draft.sl_plus_active = false;
    
    draft.tp2_active = false;
    draft.tp2_triggered = false;
    
    draft.tp3_start_price = draft.tp2_price;
    draft.tp3_trailing_dist = gross_risk * Inp_TP3_TrailingMult;
    draft.tp3_active = false;
    draft.state = TP_STATE_DRAFT;
    draft.created_time = TimeCurrent();
    
    return draft;
}
