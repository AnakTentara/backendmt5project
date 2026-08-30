//+------------------------------------------------------------------+
//|                                           RiskManager.mqh        |
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

double g_total_exposure_risk = 0;
int g_open_positions_buy = 0;
int g_open_positions_sell = 0;
double g_daily_pnl = 0;
int g_daily_trades = 0;
int g_last_reset_day = 0;
double g_starting_balance = 0;

void RiskManager_Init() {
    g_total_exposure_risk = 0;
    g_open_positions_buy = 0;
    g_open_positions_sell = 0;
    g_daily_pnl = 0;
    g_daily_trades = 0;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    g_last_reset_day = dt.day;
    
    g_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    Print("RiskManager: Initialized | Balance: ", DoubleToString(g_starting_balance, 2));
}

void CheckDailyReset() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(dt.day != g_last_reset_day) {
        g_daily_pnl = 0;
        g_daily_trades = 0;
        g_last_reset_day = dt.day;
        Print("Daily reset: New trading day");
    }
}

void ResetDailyMetrics() {
    g_daily_pnl = 0;
    g_daily_trades = 0;
}

double GetDynamicRR() {
    if(!Inp_UseDynamicRR) return Inp_TP1_RR;
    
    if(g_current_flag.is_valid && g_current_flag.is_bear_flag) return Inp_RR_FlagTopSell;
    if(IsCHOCHBullishM5() || IsCHOCHBearishM5()) return Inp_RR_CHOCH;
    if(g_current_flag.is_valid) return Inp_RR_FlagBreakout;
    if(IsConsolidation()) return Inp_RR_Consolidation;
    if(HigherTFsAlignedBullish()) return Inp_RR_BullishTrend;
    if(HigherTFsAlignedBearish()) return Inp_RR_BearishTrend;
    
    return Inp_RR_CounterTrend;
}

double CalculateMargin(double lots) {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    if(leverage <= 0) leverage = 2000;
    if(contract_size <= 0) contract_size = 1.0;
    
    return (lots * contract_size * price) / (double)leverage;
}

bool CheckMarginSafety(double lots, double &required_margin) {
    if(!Inp_UseMarginSafety) return true;
    
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double used_margin = AccountInfoDouble(ACCOUNT_MARGIN);
    
    required_margin = CalculateMargin(lots);
    
    if(required_margin > free_margin * (Inp_MarginSafetyPct / 100.0)) {
        return false;
    }
    
    double projected_margin = used_margin + required_margin;
    if(projected_margin > 0) {
        double projected_level = (equity / projected_margin) * 100.0;
        if(projected_level < Inp_MarginAlertLevel) return false;
    }
    
    return true;
}

bool CheckMarginSafety(double lots, string &error_msg) {
    double req_margin;
    if(!CheckMarginSafety(lots, req_margin)) {
        error_msg = "Insufficient margin safety";
        return false;
    }
    return true;
}

LotSizeResult CalculateLotSize(double entry_price, double sl_price) {
    LotSizeResult result;
    result.valid = false;
    result.lots = 0;
    result.reason = "";
    
    CheckDailyReset();
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double vol_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(tick_value <= 0) tick_value = 1.0;
    if(point <= 0) point = 1.0;
    if(vol_min <= 0) vol_min = 0.01;
    if(vol_max <= 0) vol_max = 100.0;
    if(vol_step <= 0) vol_step = 0.01;
    
    double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    double risk_pct = Inp_MaxRiskPercent / 100.0;
    double risk_amount = balance * risk_pct;
    
    double sl_points = MathAbs(entry_price - sl_price) / point;
    if(sl_points < 20) sl_points = 20;
    
    double effective_sl = sl_points + spread;
    double risk_based_lots = risk_amount / (effective_sl * tick_value);
    
    double lots = risk_based_lots;
    if(Inp_UseSpreadAdjLots && spread > Inp_SpreadReduceThresh) {
        lots *= (Inp_SpreadReduceThresh / spread);
    }
    
    lots = MathMax(lots, vol_min);
    lots = MathMin(lots, vol_max);
    lots = MathFloor(lots / vol_step) * vol_step;
    
    double req_margin;
    if(!CheckMarginSafety(lots, req_margin)) {
        // Scale down lots to fit margin
        double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double max_margin_avail = free_margin * (Inp_MarginSafetyPct / 100.0);
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        long lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
        if(lev <= 0) lev = 2000;
        
        lots = (max_margin_avail * (double)lev) / (price * 1.0);
        lots = MathFloor(lots / vol_step) * vol_step;
    }
    
    if(lots < vol_min) {
        result.reason = "Lot size below broker minimum";
        return result;
    }
    
    result.lots = NormalizeDouble(lots, 2);
    result.risk_based_lots = risk_based_lots;
    result.spread_adjusted = lots;
    result.valid = true;
    return result;
}

bool CanAddPosition() {
    int total = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber) {
            total++;
        }
    }
    return (total == 0); // Strict 1-position max: No stacking/averaging
}

void RiskManager_Update() {
    CheckDailyReset();
}

void CheckRiskAlerts() {
    double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    if(margin_level > 0 && margin_level < Inp_MarginAlertLevel) {
        Print("WARNING: Margin Level Low: ", DoubleToString(margin_level, 1), "%");
    }
}

void PrintRiskStatus() {
    Print("--- Risk Status: Daily Trades: ", g_daily_trades, " | Daily PnL: ", DoubleToString(g_daily_pnl, 2), " ---");
}
