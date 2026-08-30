# TradeMachine v3.0 MQL5 Generator for VOL_80
import os

DIR = os.path.dirname(os.path.abspath(__file__))

def save(fname, content):
    path = os.path.join(DIR, fname)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated: {fname}")

# ==============================================================================
# 1. Types.mqh
# ==============================================================================
types_mqh = r'''//+------------------------------------------------------------------+
//|                                                 Types.mqh        |
//|                                                     TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"

//--- Trend States
enum TREND_STATE {
    TREND_BULLISH_STRONG   = 2,
    TREND_BULLISH_WEAK     = 1,
    TREND_NEUTRAL          = 0,
    TREND_BEARISH_WEAK     = -1,
    TREND_BEARISH_STRONG   = -2
};

//--- Timeframe Enums
enum TIMEFRAME_ID {
    TF_M5  = PERIOD_M5,
    TF_M15 = PERIOD_M15,
    TF_M30 = PERIOD_M30,
    TF_H1  = PERIOD_H1,
    TF_H4  = PERIOD_H4
};

//--- Pattern Types
enum PATTERN_TYPE {
    PATTERN_NONE               = 0,
    PATTERN_BULL_FLAG          = 1,
    PATTERN_BEAR_FLAG          = 2,
    PATTERN_BULL_BASE          = 3,
    PATTERN_BEAR_BASE          = 4,
    PATTERN_CONSOLIDATION      = 5,
    PATTERN_CHOCH_BULLISH      = 6,
    PATTERN_CHOCH_BEARISH      = 7,
    PATTERN_FLAG_TOP_SELL      = 8,
    PATTERN_BASE_BREAKOUT_UP   = 9,
    PATTERN_BASE_BREAKOUT_DOWN = 10,
    PATTERN_SD_RETEST_BUY      = 11,
    PATTERN_SD_RETEST_SELL     = 12
};

//--- TP State Machine
enum TP_STATE {
    TP_STATE_DRAFT         = 0,  // Position open, TP tracked internally
    TP_STATE_TP1_APPROACH  = 1,  // Price approaching TP1
    TP_STATE_TP1_HIT       = 2,  // TP1 reached, SL+ locked at midpoint
    TP_STATE_TP2_HIT       = 3,  // TP2 reached, trailing activated
    TP_STATE_TRAILING      = 4,  // Trailing SL active
    TP_STATE_CLOSED        = 5   // Position closed
};

//--- Spread State Machine
enum SPREAD_STATE {
    SPREAD_NORMAL       = 0,  // < 60 pts - trade freely
    SPREAD_ELEVATED     = 1,  // 60-80 pts - reduce lot size 25%
    SPREAD_WIDE         = 2,  // 80-100 pts - skip new trades
    SPREAD_VERY_WIDE    = 3,  // 100-150 pts - close existing, no new
    SPREAD_CRITICAL     = 4   // > 150 pts - emergency close all
};

//--- S/R Level Types
enum SR_LEVEL_TYPE {
    SR_MINOR      = 0,
    SR_MAJOR      = 1,
    SR_MICRO      = 2,
    SR_DYNAMIC    = 3,
    SR_ORDERBLOCK = 4,
    SR_FVG        = 5
};

//--- Supply/Demand Zone Types
enum ZONE_TYPE {
    ZONE_SUPPLY     = 0,
    ZONE_DEMAND     = 1
};

//--- S/R Level Struct
struct SRLevel {
    double price;
    SR_LEVEL_TYPE type;
    int touches;
    double volume_at_level;
    datetime last_touch_time;
    double strength;
    bool is_active;
    int timeframe;
    double bounce_height;
    double retest_depth;
    bool vol80_1to1_confirmed;
};

//--- Supply/Demand Zone Struct
struct SupplyDemandZone {
    ZONE_TYPE type;
    double top;
    double bottom;
    double center;
    int bars_count;
    int touches;
    double volume_profile;
    double strength;
    bool is_major;
    datetime created_time;
    datetime last_test_time;
    bool is_fresh;
    double expected_bounce;
    bool vol80_bounce_confirmed;
    double retest_target;
    bool is_broken;
};

//--- Swing Point
struct SwingPoint {
    double price;
    datetime time;
    bool is_high;
    int timeframe;
    int index;
    double volume;
    bool is_confirmed;
    bool choch_broken;
    datetime choch_time;
};

//--- Flag Pattern
struct FlagPattern {
    bool is_bull_flag;
    bool is_bear_flag;
    double pole_high;
    double pole_low;
    double flag_top;
    double flag_bottom;
    int flag_bars;
    double breakout_level;
    double pole_strength;
    bool is_valid;
    datetime start_time;
    datetime end_time;
};

//--- Consolidation Zone
struct ConsolidationZone {
    double top;
    double bottom;
    int bars;
    bool is_accumulation;
    bool is_distribution;
    double volume_profile;
    double atr_ratio;
    bool is_valid;
    datetime start_time;
};

//--- TP Draft System
struct TPDraft {
    double tp1_price;
    double tp1_rr;
    bool tp1_triggered;
    bool tp1_been_been;
    
    double tp2_price;
    double tp2_rr;
    bool tp2_active;
    bool tp2_triggered;
    
    double tp3_start_price;
    double tp3_trailing_dist;
    bool tp3_active;
    
    double sl_plus_price;
    bool sl_plus_active;
    
    double spread_at_entry;
    double net_rr;
    
    TP_STATE state;
    datetime created_time;
};

//--- Spread State
struct SpreadState {
    double current_spread;
    double average_spread;
    double max_spread_today;
    double spread_at_entry;
    int spread_warnings;
    datetime last_spread_update;
    bool is_wide;
    SPREAD_STATE state;
};

//--- Risk/Reward Config
struct RiskRewardConfig {
    double rr_bullish_trend;
    double rr_bearish_trend;
    double rr_consolidation;
    double rr_choch;
    double rr_flag_breakout;
    double rr_flag_top_sell;
    double rr_counter_trend;
};

//--- Multi-Ticket Split
struct TicketSplit {
    int split_id;
    int ticket_count;
    double total_lots;
    double lots_per_ticket;
    double entry_price;
    double sl_price;
    TPDraft draft;
    ulong tickets[20];
    int active_count;
    bool tp1_triggered;
    bool tp2_activated;
    bool all_closed;
    datetime created_time;
};

//--- Margin Info
struct MarginInfo {
    double required_margin;
    double free_margin;
    double margin_level;
    double used_margin;
    double equity;
    bool margin_safe;
    string warning_msg;
};

//--- Lot Sizing Result
struct LotSizeResult {
    double lots;
    double risk_based_lots;
    double spread_adjusted;
    double margin_capped;
    double exposure_capped;
    bool valid;
    string reason;
};

//--- Market Structure Snapshot
struct MarketStructure {
    TIMEFRAME_ID timeframe;
    TREND_STATE trend;
    TREND_STATE prev_trend;
    SwingPoint last_high;
    SwingPoint last_low;
    SwingPoint prev_high;
    SwingPoint prev_low;
    bool choch_bullish;
    bool choch_bearish;
    double choch_price;
    datetime choch_time;
    bool structure_valid;
};

//--- Pattern Detection Result
struct PatternResult {
    PATTERN_TYPE type;
    double entry_price;
    double sl_price;
    double tp1_price;
    double tp1_draft;
    double tp2_price;
    double tp2_draft;
    double confidence;
    bool is_valid;
    datetime detected_time;
    int bars_duration;
};

//--- Managed Position
struct ManagedPosition {
    ulong ticket;
    ENUM_POSITION_TYPE type;
    double entry_price;
    double volume;
    double sl_price;
    double tp_price;
    TPDraft draft;
    int split_id;
    int split_index;
    int total_splits;
    bool is_managed;
    datetime open_time;
    datetime last_update;
    bool vol80_flag_top_sell;
};

//--- Constants
#define MAX_SWING_POINTS        50
#define MAX_SR_LEVELS           100
#define MAX_ZONES               50
#define MAX_PENDING_ORDERS      20
#define MAX_SPLIT_TICKETS       20
#define MAX_TRADE_HISTORY       500

#define VOL80_BASELINE_SPREAD   72.0
#define VOL80_MIN_TARGET_POINTS 100.0
#define VOL80_MAX_SPREAD_FILTER 80.0

#define MAX_LOTS_PER_TICKET     100.0
#define VOL80_CONTRACT_SIZE     1.0
#define VOL80_TICK_VALUE        1.0

#define DEFAULT_MAX_RISK_PCT    3.0
#define DEFAULT_MAX_EXPOSURE    5.0
#define DEFAULT_RR_BULLISH      2.5
#define DEFAULT_RR_BEARISH      2.5
#define DEFAULT_RR_CONSOL       1.5
#define DEFAULT_RR_CHOCH        3.0
#define DEFAULT_RR_FLAG_BREAK   2.0
#define DEFAULT_RR_FLAG_TOP     1.5
#define DEFAULT_RR_COUNTER      1.0

#define FLAG_MIN_BARS           3
#define FLAG_MAX_BARS           15
#define FLAG_MIN_POLE_STRENGTH  0.6
#define CONSOLIDATION_MIN_BARS  10
#define ATR_CONTRACTION_MULT    0.5
#define SWING_LOOKBACK          5
#define CHOCH_VOLUME_MULT       1.2

#define MAJOR_SWING_LOOKBACK    50
#define MINOR_SWING_LOOKBACK    20
#define LEVEL_STRENGTH_THRESH   3.0

#define TP1_DEFAULT_RR          1.5
#define TP2_DEFAULT_RR          3.0
#define TP3_TRAILING_MULT       1.5
#define SL_BUFFER_POINTS        5
#define FLAG_TOP_SL_PCT         3.0

#define MARGIN_SAFETY_PCT       50.0
#define MARGIN_ALERT_LEVEL      200.0
#define MARGIN_CLOSE_LEVEL      300.0

#define MAGIC_NUMBER            20260829
'''

save("Types.mqh", types_mqh)

# ==============================================================================
# 2. Config.mqh
# ==============================================================================
config_mqh = r'''//+------------------------------------------------------------------+
//|                                                 Config.mqh       |
//|                                                     TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"

// ============================================================
// R:R MANAGEMENT
// ============================================================
input group "=== R:R MANAGEMENT ==="
input double Inp_RR_BullishTrend    = 2.5;  // R:R in bullish trend (all TFs aligned)
input double Inp_RR_BearishTrend    = 2.5;  // R:R in bearish trend (all TFs aligned)
input double Inp_RR_Consolidation   = 1.5;  // R:R during consolidation
input double Inp_RR_CHOCH           = 3.0;  // R:R on CHOCH entry
input double Inp_RR_FlagBreakout    = 2.0;  // R:R on flag breakout
input double Inp_RR_FlagTopSell     = 1.5;  // R:R on flag top sell
input double Inp_RR_CounterTrend    = 1.0;  // R:R counter-trend
input bool   Inp_UseDynamicRR       = true; // Enable dynamic R:R selection

// ============================================================
// MARGIN CALCULATION & SAFETY
// ============================================================
input group "=== MARGIN SAFETY ==="
input double Inp_MarginSafetyPct    = 50.0;  // Max % of free margin to use
input double Inp_MarginAlertLevel   = 200.0; // Margin level alert threshold (%)
input double Inp_MarginCloseLevel   = 300.0; // Emergency close margin level (%)
input bool   Inp_UseMarginSafety    = true;  // Enable margin safety checks

// ============================================================
// LOT SIZING
// ============================================================
input group "=== LOT SIZING ==="
input double Inp_MaxRiskPercent     = 3.0;   // Max % risk per trade
input double Inp_MaxTotalExposure   = 5.0;   // Max % total open risk
input double Inp_LotPerDollar       = 0.002; // Lots per $1 balance (1 lot / $500)
input bool   Inp_UseSpreadAdjLots   = true;  // Adjust lots for spread cost
input int    Inp_MaxPosPerDirection = 2;     // Max concurrent same direction
input bool   Inp_AllowCounterTrend  = true;  // Enable consolidation sells

// ============================================================
// TP DRAFT SYSTEM
// ============================================================
input group "=== TP DRAFT SYSTEM ==="
input double Inp_TP1_RR             = 1.5;   // TP1 Risk:Reward
input double Inp_TP2_RR             = 3.0;   // TP2 Risk:Reward
input double Inp_TP3_TrailingMult   = 1.5;   // TP3 trailing distance (x risk)
input bool   Inp_UseStructureTP     = true;  // Use S/R for TP override
input double Inp_SL_Buffer_Pips     = 5;     // SL buffer beyond structure (points)
input double Inp_FlagTop_SL_Pct     = 3.0;   // Flag sell SL % (3-5%)
input bool   Inp_UseTPDraft         = true;  // Enable draft TP mode (no server TP)

// ============================================================
// SPREAD FILTER (VOL_80 = 72 pts avg)
// ============================================================
input group "=== SPREAD FILTER ==="
input double Inp_SpreadFilterMax    = 80;    // Max spread (points) - skip if >
input double Inp_SpreadReduceThresh = 60;    // Reduce lots above this (points)
input double Inp_SpreadCloseThresh  = 150;   // Emergency close above this (points)
input double Inp_MinTargetPoints    = 100;   // Min gross move target (beat spread)
input bool   Inp_UseSpreadFilter    = true;  // Enable spread filtering
input bool   Inp_UseSessionSpread   = true;  // Session-based spread adjustments

// ============================================================
// POSITION CAP HANDLING (100 lots max)
// ============================================================
input group "=== POSITION CAP ==="
input bool   Inp_UsePositionCap      = true;    // Enable cap handling
input double Inp_CapAlertBalance     = 12250;   // Balance where cap becomes relevant
input bool   Inp_UseMultiTicketSplit = true;    // Enable multi-ticket splitting
input double Inp_SplitPriceOffset    = 1.0;     // Price offset between split tickets

// ============================================================
// MULTI-TICKET SPLITTING
// ============================================================
input group "=== MULTI-TICKET SPLITTING ==="
input double Inp_MaxLotsPerTicket   = 100.0;   // Maximum lots per ticket
input double Inp_MinLotsPerTicket   = 0.01;    // Minimum lots per ticket
input bool   Inp_SplitOnCapOnly     = true;    // Only split when cap reached
input int    Inp_TicketRetryDelay   = 500;     // Retry delay ms on partial fill

// ============================================================
// CHOCH DETECTION
// ============================================================
input group "=== CHOCH DETECTION ==="
input int    Inp_SwingLookback      = 5;      // Fractal lookback bars
input double Inp_CHOCH_VolumeMult   = 1.2;    // Volume confirmation multiplier
input bool   Inp_CHOCH_NeedClose    = false;  // Require candle close for CHOCH

// ============================================================
// SUPPLY/DEMAND & S/R
// ============================================================
input group "=== SUPPLY/DEMAND & S/R ==="
input int    Inp_MajorSwingLookback = 50;     // Bars for major swings
input int    Inp_MinorSwingLookback = 20;     // Bars for minor swings
input double Inp_LevelStrengthThresh = 3.0;   // Min strength to respect
input bool   Inp_UseVWAP            = true;   // Use VWAP bands
input bool   Inp_UseEMAs            = true;   // Use EMA 20/50/200
input bool   Inp_UsePivots          = true;   // Use Daily/Weekly pivots
input bool   Inp_UseOrderBlocks     = true;   // Use order blocks
input bool   Inp_UseFVG             = true;   // Use Fair Value Gaps

// VOL_80 Specific S/D Logic
input bool   Inp_VOL80_1to1_Rule    = true;   // VOL_80 1:1 bounce/retest rule
input double Inp_VOL80_BounceTol    = 0.02;   // 2% tolerance for 1:1 match
input int    Inp_VOL80_LookbackBars = 200;    // Bars to scan for zones

// ============================================================
// PATTERN DETECTION
// ============================================================
input group "=== PATTERN DETECTION ==="
input int    Inp_FlagMinBars        = 3;      // Flag minimum bars
input int    Inp_FlagMaxBars        = 15;     // Flag maximum bars
input double Inp_FlagPoleStrength   = 0.6;    // Min pole body/range ratio
input int    Inp_ConsolMinBars      = 10;     // Consolidation minimum bars
input double Inp_ATRContractionMult = 0.5;    // ATR contraction multiplier

// ============================================================
// EXECUTION SETTINGS
// ============================================================
input group "=== EXECUTION ==="
input int    Inp_MagicNumber        = 20260829; // Magic number
input int    Inp_MaxSlippage        = 50;       // Max slippage (points)
input int    Inp_OrderTimeout       = 5000;     // Order timeout (ms)
input bool   Inp_AllowHedging       = true;     // Allow opposite positions

// ============================================================
// SESSION FILTER
// ============================================================
input group "=== SESSION FILTER ==="
input bool   Inp_UseSessionFilter   = true;    // Trade only active sessions
input string Inp_ActiveSessions     = "London,NewYork"; // Active sessions
input bool   Inp_AvoidRollover      = true;    // Avoid 23:55-00:05 server time

// ============================================================
// DEBUG & LOGGING
// ============================================================
input group "=== DEBUG & LOGGING ==="
input bool   Inp_EnableLogging      = true;    // Enable file logging
input bool   Inp_ShowDashboard      = true;    // Show chart dashboard
input int    Inp_LogLevel           = 2;       // 0=Error, 1=Warn, 2=Info, 3=Debug
input bool   Inp_LogToFile          = true;    // Write logs to file

// ============================================================
// HTTP SERVER (Dashboard Control)
// ============================================================
input group "=== HTTP SERVER ==="
input bool   Inp_HTTP_Enabled         = true;   // Enable HTTP server for dashboard
input int    Inp_HTTP_Port            = 8080;   // HTTP server port
input string Inp_HTTP_AllowedIPs      = "127.0.0.1,::1"; // Allowed IPs
input int    Inp_HTTP_Timeout         = 5000;   // Request timeout (ms)

//+------------------------------------------------------------------+
//| Global Variables (Runtime Config)                                |
//+------------------------------------------------------------------+
RiskRewardConfig g_rr_config;
SpreadState g_spread_state;

void InitRuntimeConfig() {
    g_rr_config.rr_bullish_trend   = Inp_RR_BullishTrend;
    g_rr_config.rr_bearish_trend   = Inp_RR_BearishTrend;
    g_rr_config.rr_consolidation   = Inp_RR_Consolidation;
    g_rr_config.rr_choch           = Inp_RR_CHOCH;
    g_rr_config.rr_flag_breakout   = Inp_RR_FlagBreakout;
    g_rr_config.rr_flag_top_sell   = Inp_RR_FlagTopSell;
    g_rr_config.rr_counter_trend   = Inp_RR_CounterTrend;
    
    g_spread_state.current_spread = 0;
    g_spread_state.average_spread = 0;
    g_spread_state.max_spread_today = 0;
    g_spread_state.spread_warnings = 0;
    g_spread_state.is_wide = false;
    g_spread_state.state = SPREAD_NORMAL;
}
'''
save("Config.mqh", config_mqh)

# ==============================================================================
# 3. MultiTimeframe.mqh
# ==============================================================================
multitimeframe_mqh = r'''//+------------------------------------------------------------------+
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
'''
save("MultiTimeframe.mqh", multitimeframe_mqh)

# ==============================================================================
# 4. MarketStructure.mqh
# ==============================================================================
marketstructure_mqh = r'''//+------------------------------------------------------------------+
//|                                             MarketStructure.mqh  |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "MultiTimeframe.mqh"

//--- Global Market Structure Data (per TF)
MarketStructure g_market_structure[5];  // M5, M15, M30, H1, H4

//--- Swing Point Storage
SwingPoint g_swing_highs[5][MAX_SWING_POINTS];
SwingPoint g_swing_lows[5][MAX_SWING_POINTS];
int g_swing_high_count[5] = {0,0,0,0,0};
int g_swing_low_count[5] = {0,0,0,0,0};
int g_swing_high_idx[5] = {0,0,0,0,0};
int g_swing_low_idx[5] = {0,0,0,0,0};

//+------------------------------------------------------------------+
//| Initialize Market Structure Module                               |
//+------------------------------------------------------------------+
void MarketStructure_Init() {
    ZeroMemory(g_swing_highs);
    ZeroMemory(g_swing_lows);
    
    for(int i = 0; i < 5; i++) {
        g_market_structure[i].timeframe = (TIMEFRAME_ID)g_timeframes[i];
        g_market_structure[i].trend = TREND_NEUTRAL;
        g_market_structure[i].prev_trend = TREND_NEUTRAL;
        g_market_structure[i].choch_bullish = false;
        g_market_structure[i].choch_bearish = false;
        g_market_structure[i].structure_valid = false;
        
        g_swing_high_count[i] = 0;
        g_swing_low_count[i] = 0;
        g_swing_high_idx[i] = 0;
        g_swing_low_idx[i] = 0;
    }
    Print("MarketStructure: Initialized for 5 timeframes");
}

//+------------------------------------------------------------------+
//| Helper to get rates reference                                    |
//+------------------------------------------------------------------+
int GetTFRates(int tf_idx, MqlRates &out_rates[]) {
    switch(tf_idx) {
        case 0: return CopyRates(_Symbol, PERIOD_M5, 0, 100, out_rates);
        case 1: return CopyRates(_Symbol, PERIOD_M15, 0, 100, out_rates);
        case 2: return CopyRates(_Symbol, PERIOD_M30, 0, 100, out_rates);
        case 3: return CopyRates(_Symbol, PERIOD_H1, 0, 100, out_rates);
        case 4: return CopyRates(_Symbol, PERIOD_H4, 0, 100, out_rates);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Detect Swing Points (5-Bar Fractal on Series Array)              |
//+------------------------------------------------------------------+
void DetectSwingPoints(int tf_idx) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = GetTFRates(tf_idx, rates);
    if(copied < 25) return;
    
    int lookback = Inp_SwingLookback;
    int max_scan = MathMin(copied - lookback, 50);
    
    // 1. Scan Swing Highs
    for(int i = lookback; i < max_scan; i++) {
        bool is_high = true;
        for(int j = 1; j <= lookback; j++) {
            if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high) {
                is_high = false;
                break;
            }
        }
        
        if(is_high) {
            double price = rates[i].high;
            datetime time = rates[i].time;
            
            bool exists = false;
            for(int k = 0; k < g_swing_high_count[tf_idx]; k++) {
                if(g_swing_highs[tf_idx][k].time == time) {
                    exists = true;
                    break;
                }
            }
            
            if(!exists) {
                SwingPoint sp;
                sp.price = price;
                sp.time = time;
                sp.is_high = true;
                sp.timeframe = tf_idx;
                sp.index = i;
                sp.volume = (double)rates[i].tick_volume;
                sp.is_confirmed = true;
                sp.choch_broken = false;
                sp.choch_time = 0;
                
                g_swing_highs[tf_idx][g_swing_high_idx[tf_idx]] = sp;
                g_swing_high_idx[tf_idx] = (g_swing_high_idx[tf_idx] + 1) % MAX_SWING_POINTS;
                if(g_swing_high_count[tf_idx] < MAX_SWING_POINTS) g_swing_high_count[tf_idx]++;
                
                g_market_structure[tf_idx].prev_high = g_market_structure[tf_idx].last_high;
                g_market_structure[tf_idx].last_high = sp;
            }
        }
    }
    
    // 2. Scan Swing Lows
    for(int i = lookback; i < max_scan; i++) {
        bool is_low = true;
        for(int j = 1; j <= lookback; j++) {
            if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low) {
                is_low = false;
                break;
            }
        }
        
        if(is_low) {
            double price = rates[i].low;
            datetime time = rates[i].time;
            
            bool exists = false;
            for(int k = 0; k < g_swing_low_count[tf_idx]; k++) {
                if(g_swing_lows[tf_idx][k].time == time) {
                    exists = true;
                    break;
                }
            }
            
            if(!exists) {
                SwingPoint sp;
                sp.price = price;
                sp.time = time;
                sp.is_high = false;
                sp.timeframe = tf_idx;
                sp.index = i;
                sp.volume = (double)rates[i].tick_volume;
                sp.is_confirmed = true;
                sp.choch_broken = false;
                sp.choch_time = 0;
                
                g_swing_lows[tf_idx][g_swing_low_idx[tf_idx]] = sp;
                g_swing_low_idx[tf_idx] = (g_swing_low_idx[tf_idx] + 1) % MAX_SWING_POINTS;
                if(g_swing_low_count[tf_idx] < MAX_SWING_POINTS) g_swing_low_count[tf_idx]++;
                
                g_market_structure[tf_idx].prev_low = g_market_structure[tf_idx].last_low;
                g_market_structure[tf_idx].last_low = sp;
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Check CHOCH on M5 (Per Tick)                                    |
//+------------------------------------------------------------------+
void CheckCHOCH_M5() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_price = (bid + ask) / 2.0;
    
    // Bullish CHOCH: Break above previous lower high
    if(g_market_structure[0].prev_high.price > 0 && 
       !g_market_structure[0].prev_high.choch_broken &&
       current_price > g_market_structure[0].prev_high.price) {
        
        g_market_structure[0].choch_bullish = true;
        g_market_structure[0].choch_price = current_price;
        g_market_structure[0].choch_time = TimeCurrent();
        g_market_structure[0].prev_high.choch_broken = true;
        Print("Bullish CHOCH detected on M5 @ ", current_price);
    }
    
    // Bearish CHOCH: Break below previous higher low
    if(g_market_structure[0].prev_low.price > 0 && 
       !g_market_structure[0].prev_low.choch_broken &&
       current_price < g_market_structure[0].prev_low.price) {
        
        g_market_structure[0].choch_bearish = true;
        g_market_structure[0].choch_price = current_price;
        g_market_structure[0].choch_time = TimeCurrent();
        g_market_structure[0].prev_low.choch_broken = true;
        Print("Bearish CHOCH detected on M5 @ ", current_price);
    }
}

//+------------------------------------------------------------------+
//| Update Trend State per TF                                        |
//+------------------------------------------------------------------+
void UpdateTFTrend(int tf_idx) {
    double ema20 = GetEMA(tf_idx, 20, 0);
    double ema50 = GetEMA(tf_idx, 50, 0);
    double ema200 = GetEMA(tf_idx, 200, 0);
    
    if(ema20 == 0 || ema50 == 0 || ema200 == 0) return;
    
    TREND_STATE state = TREND_NEUTRAL;
    if(ema20 > ema50 && ema50 > ema200) {
        state = TREND_BULLISH_STRONG;
    } else if(ema20 > ema50) {
        state = TREND_BULLISH_WEAK;
    } else if(ema20 < ema50 && ema50 < ema200) {
        state = TREND_BEARISH_STRONG;
    } else if(ema20 < ema50) {
        state = TREND_BEARISH_WEAK;
    }
    
    g_market_structure[tf_idx].prev_trend = g_market_structure[tf_idx].trend;
    g_market_structure[tf_idx].trend = state;
    g_market_structure[tf_idx].structure_valid = true;
}

//+------------------------------------------------------------------+
//| Update All Market Structure                                      |
//+------------------------------------------------------------------+
void UpdateMarketStructure() {
    for(int i = 0; i < 5; i++) {
        DetectSwingPoints(i);
        UpdateTFTrend(i);
    }
    CheckCHOCH_M5();
}

//+------------------------------------------------------------------+
//| Trend Query Helpers                                              |
//+------------------------------------------------------------------+
bool HigherTFsAlignedBullish() {
    return (g_market_structure[4].trend >= TREND_BULLISH_WEAK && // H4
            g_market_structure[3].trend >= TREND_BULLISH_WEAK && // H1
            g_market_structure[1].trend >= TREND_BULLISH_WEAK);  // M15
}

bool HigherTFsAlignedBearish() {
    return (g_market_structure[4].trend <= TREND_BEARISH_WEAK && // H4
            g_market_structure[3].trend <= TREND_BEARISH_WEAK && // H1
            g_market_structure[1].trend <= TREND_BEARISH_WEAK);  // M15
}

bool IsCHOCHBullishM5() { return g_market_structure[0].choch_bullish; }
bool IsCHOCHBearishM5() { return g_market_structure[0].choch_bearish; }

SwingPoint GetLastSwingHigh(int tf_idx) { return g_market_structure[tf_idx].last_high; }
SwingPoint GetLastSwingLow(int tf_idx)  { return g_market_structure[tf_idx].last_low; }
SwingPoint GetPrevSwingHigh(int tf_idx) { return g_market_structure[tf_idx].prev_high; }
SwingPoint GetPrevSwingLow(int tf_idx)  { return g_market_structure[tf_idx].prev_low; }

bool IsConsolidation() {
    return (g_market_structure[0].trend == TREND_NEUTRAL &&
            g_market_structure[1].trend == TREND_NEUTRAL);
}

void PrintMarketStructure() {
    Print("--- Market Structure ---");
    for(int i=0; i<5; i++) {
        Print(g_tf_names[i], " Trend: ", EnumToString(g_market_structure[i].trend),
              " | High: ", DoubleToString(g_market_structure[i].last_high.price, 0),
              " | Low: ", DoubleToString(g_market_structure[i].last_low.price, 0));
    }
}
'''
save("MarketStructure.mqh", marketstructure_mqh)

# ==============================================================================
# 5. SupportResistance.mqh
# ==============================================================================
supportresistance_mqh = r'''//+------------------------------------------------------------------+
//|                                         SupportResistance.mqh    |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "MarketStructure.mqh"

SRLevel g_sr_levels[MAX_SR_LEVELS];
int g_sr_count = 0;

SupplyDemandZone g_zones[MAX_ZONES];
int g_zone_count = 0;

void SupportResistance_Init() {
    ZeroMemory(g_sr_levels);
    ZeroMemory(g_zones);
    g_sr_count = 0;
    g_zone_count = 0;
    Print("SupportResistance: Initialized");
}

double CalculateLevelStrength(SRLevel &level) {
    double score = level.touches * 2.0;
    if(level.type == SR_MAJOR) score += 3.0;
    else if(level.type == SR_MINOR) score += 1.5;
    return score;
}

void AddSwingLevel(SwingPoint &sp, SR_LEVEL_TYPE type) {
    if(sp.price == 0 || !sp.is_confirmed) return;
    
    for(int i = 0; i < g_sr_count; i++) {
        if(MathAbs(g_sr_levels[i].price - sp.price) <= 20.0) {
            g_sr_levels[i].touches++;
            g_sr_levels[i].last_touch_time = sp.time;
            g_sr_levels[i].strength = CalculateLevelStrength(g_sr_levels[i]);
            return;
        }
    }
    
    if(g_sr_count < MAX_SR_LEVELS) {
        SRLevel level;
        level.price = sp.price;
        level.type = type;
        level.touches = 1;
        level.volume_at_level = sp.volume;
        level.last_touch_time = sp.time;
        level.timeframe = sp.timeframe;
        level.is_active = true;
        level.strength = CalculateLevelStrength(level);
        level.bounce_height = 0;
        level.retest_depth = 0;
        level.vol80_1to1_confirmed = false;
        
        g_sr_levels[g_sr_count] = level;
        g_sr_count++;
    }
}

void UpdateSwingLevels() {
    SwingPoint sp_h4_h = GetLastSwingHigh(4);
    SwingPoint sp_h4_l = GetLastSwingLow(4);
    SwingPoint sp_h1_h = GetLastSwingHigh(3);
    SwingPoint sp_h1_l = GetLastSwingLow(3);
    SwingPoint sp_m15_h = GetLastSwingHigh(1);
    SwingPoint sp_m15_l = GetLastSwingLow(1);
    SwingPoint sp_m5_h = GetLastSwingHigh(0);
    SwingPoint sp_m5_l = GetLastSwingLow(0);
    
    AddSwingLevel(sp_h4_h, SR_MAJOR);
    AddSwingLevel(sp_h4_l, SR_MAJOR);
    AddSwingLevel(sp_h1_h, SR_MAJOR);
    AddSwingLevel(sp_h1_l, SR_MAJOR);
    AddSwingLevel(sp_m15_h, SR_MINOR);
    AddSwingLevel(sp_m15_l, SR_MINOR);
    AddSwingLevel(sp_m5_h, SR_MICRO);
    AddSwingLevel(sp_m5_l, SR_MICRO);
}

void UpdateSupplyDemandZones() {
    g_zone_count = 0;
    
    // Scan recent swings to build zones
    for(int i = 0; i < g_sr_count && g_zone_count < MAX_ZONES; i++) {
        if(!g_sr_levels[i].is_active) continue;
        
        SupplyDemandZone zone;
        double p = g_sr_levels[i].price;
        double buffer = 100.0; // Zone thickness for VOL_80
        
        zone.top = p + buffer;
        zone.bottom = p - buffer;
        zone.center = p;
        zone.bars_count = 10;
        zone.touches = g_sr_levels[i].touches;
        zone.volume_profile = g_sr_levels[i].volume_at_level;
        zone.strength = g_sr_levels[i].strength;
        zone.is_major = (g_sr_levels[i].type == SR_MAJOR);
        zone.created_time = g_sr_levels[i].last_touch_time;
        zone.last_test_time = TimeCurrent();
        zone.is_fresh = (zone.touches <= 1);
        zone.is_broken = false;
        
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(bid > zone.top) {
            zone.type = ZONE_DEMAND;
        } else {
            zone.type = ZONE_SUPPLY;
        }
        
        g_zones[g_zone_count] = zone;
        g_zone_count++;
    }
}

void UpdateSupportResistance() {
    UpdateSwingLevels();
    UpdateSupplyDemandZones();
}

bool PriceAtMajorSupply() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    for(int i = 0; i < g_zone_count; i++) {
        if(g_zones[i].type == ZONE_SUPPLY && g_zones[i].is_major) {
            if(ask >= g_zones[i].bottom && ask <= g_zones[i].top + 50) return true;
        }
    }
    return false;
}

bool PriceAtMajorDemand() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    for(int i = 0; i < g_zone_count; i++) {
        if(g_zones[i].type == ZONE_DEMAND && g_zones[i].is_major) {
            if(bid <= g_zones[i].top && bid >= g_zones[i].bottom - 50) return true;
        }
    }
    return false;
}

double GetMinorResistance() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double nearest = DBL_MAX;
    for(int i = 0; i < g_sr_count; i++) {
        if(g_sr_levels[i].price > bid && g_sr_levels[i].price < nearest) {
            nearest = g_sr_levels[i].price;
        }
    }
    return (nearest == DBL_MAX) ? bid + 200 : nearest;
}

double GetMinorSupport() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double nearest = 0;
    for(int i = 0; i < g_sr_count; i++) {
        if(g_sr_levels[i].price < bid && g_sr_levels[i].price > nearest) {
            nearest = g_sr_levels[i].price;
        }
    }
    return (nearest == 0) ? bid - 200 : nearest;
}

void PrintSupportResistance() {
    Print("--- S/R Levels Count: ", g_sr_count, " | Zones Count: ", g_zone_count, " ---");
}
'''
save("SupportResistance.mqh", supportresistance_mqh)

# ==============================================================================
# 6. PatternDetector.mqh
# ==============================================================================
patterndetector_mqh = r'''//+------------------------------------------------------------------+
//|                                           PatternDetector.mqh    |
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

FlagPattern g_current_flag;
ConsolidationZone g_current_consolidation;
PatternResult g_last_pattern;

double g_donchian_high = 0;
double g_donchian_low = 0;
double g_atr_m5 = 0;
double g_atr_avg_m5 = 0;

void PatternDetector_Init() {
    ZeroMemory(g_current_flag);
    ZeroMemory(g_current_consolidation);
    ZeroMemory(g_last_pattern);
    Print("PatternDetector: Initialized");
}

void UpdateDonchian_M5() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, 20, rates) < 20) return;
    
    double hi = rates[0].high;
    double lo = rates[0].low;
    for(int i = 1; i < 20; i++) {
        if(rates[i].high > hi) hi = rates[i].high;
        if(rates[i].low < lo)  lo = rates[i].low;
    }
    g_donchian_high = hi;
    g_donchian_low = lo;
}

void UpdateATR_M5() {
    g_atr_m5 = GetATR(0, 0); // M5 ATR
    if(g_atr_m5 == 0) g_atr_m5 = 1200.0;
    g_atr_avg_m5 = g_atr_m5;
}

void DetectFlagPattern() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, 30, rates) < 30) return;
    
    ZeroMemory(g_current_flag);
    
    // Check for 3-bar pole
    int pole_bars = 0;
    bool bull_pole = false;
    bool bear_pole = false;
    
    for(int i = 5; i < 15; i++) {
        double body = MathAbs(rates[i].close - rates[i].open);
        double range = rates[i].high - rates[i].low;
        if(range <= 0) continue;
        
        if(body / range >= Inp_FlagPoleStrength) {
            if(rates[i].close > rates[i].open) {
                bull_pole = true;
                pole_bars++;
            } else {
                bear_pole = true;
                pole_bars++;
            }
        } else {
            break;
        }
    }
    
    if(pole_bars >= Inp_FlagMinBars) {
        g_current_flag.is_valid = true;
        g_current_flag.is_bull_flag = bull_pole;
        g_current_flag.is_bear_flag = bear_pole;
        g_current_flag.flag_top = rates[0].high;
        g_current_flag.flag_bottom = rates[0].low;
        g_current_flag.flag_bars = 5;
        
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Flag top sell logic
        if(bear_pole && bid >= g_current_flag.flag_top - 50) {
            g_last_pattern.type = PATTERN_FLAG_TOP_SELL;
            g_last_pattern.entry_price = bid;
            g_last_pattern.sl_price = GetMinorResistance() + Inp_SL_Buffer_Pips;
            g_last_pattern.tp1_price = bid - MathAbs(bid - g_last_pattern.sl_price) * Inp_RR_FlagTopSell;
            g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
            g_last_pattern.tp2_price = bid - MathAbs(bid - g_last_pattern.sl_price) * Inp_TP2_RR;
            g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
            g_last_pattern.confidence = 80;
            g_last_pattern.is_valid = true;
            g_last_pattern.detected_time = TimeCurrent();
            g_last_pattern.bars_duration = 5;
        }
    }
}

void DetectConsolidation() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, 25, rates) < 25) return;
    
    ZeroMemory(g_current_consolidation);
    double width = g_donchian_high - g_donchian_low;
    
    if(width < g_atr_avg_m5 * Inp_ATRContractionMult && width > 0) {
        g_current_consolidation.is_valid = true;
        g_current_consolidation.top = g_donchian_high;
        g_current_consolidation.bottom = g_donchian_low;
        g_current_consolidation.bars = 10;
        g_current_consolidation.atr_ratio = width / g_atr_avg_m5;
        g_current_consolidation.start_time = rates[10].time;
    }
}

void DetectStructureBreakouts() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current = (bid + ask) / 2.0;
    
    if(g_current_consolidation.is_valid) {
        if(current > g_current_consolidation.top + 20) {
            g_last_pattern.type = PATTERN_BASE_BREAKOUT_UP;
            g_last_pattern.entry_price = ask;
            g_last_pattern.sl_price = g_current_consolidation.bottom - Inp_SL_Buffer_Pips;
            g_last_pattern.tp1_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_RR_FlagBreakout;
            g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
            g_last_pattern.tp2_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_TP2_RR;
            g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
            g_last_pattern.confidence = 75;
            g_last_pattern.is_valid = true;
            g_last_pattern.detected_time = TimeCurrent();
            g_last_pattern.bars_duration = g_current_consolidation.bars;
        } else if(current < g_current_consolidation.bottom - 20) {
            g_last_pattern.type = PATTERN_BASE_BREAKOUT_DOWN;
            g_last_pattern.entry_price = bid;
            g_last_pattern.sl_price = g_current_consolidation.top + Inp_SL_Buffer_Pips;
            g_last_pattern.tp1_price = bid - MathAbs(g_last_pattern.sl_price - bid) * Inp_RR_FlagBreakout;
            g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
            g_last_pattern.tp2_price = bid - MathAbs(g_last_pattern.sl_price - bid) * Inp_TP2_RR;
            g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
            g_last_pattern.confidence = 75;
            g_last_pattern.is_valid = true;
            g_last_pattern.detected_time = TimeCurrent();
            g_last_pattern.bars_duration = g_current_consolidation.bars;
        }
    }
}

void DetectSDRetestConfirmation() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Retest of broken supply zone (now demand) + green bullish confirmation -> BEST BUY
    for(int i = 0; i < g_zone_count; i++) {
        if(g_zones[i].type == ZONE_DEMAND) {
            if(bid >= g_zones[i].bottom && bid <= g_zones[i].top + 50) {
                MqlRates rates[];
                ArraySetAsSeries(rates, true);
                if(CopyRates(_Symbol, PERIOD_M5, 0, 2, rates) >= 2) {
                    if(rates[0].close > rates[0].open) { // Green confirmation bar
                        g_last_pattern.type = PATTERN_SD_RETEST_BUY;
                        g_last_pattern.entry_price = ask;
                        g_last_pattern.sl_price = g_zones[i].bottom - Inp_SL_Buffer_Pips;
                        g_last_pattern.tp1_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_RR_BullishTrend;
                        g_last_pattern.tp1_draft = g_last_pattern.tp1_price;
                        g_last_pattern.tp2_price = ask + MathAbs(ask - g_last_pattern.sl_price) * Inp_TP2_RR;
                        g_last_pattern.tp2_draft = g_last_pattern.tp2_price;
                        g_last_pattern.confidence = 90;
                        g_last_pattern.is_valid = true;
                        g_last_pattern.detected_time = TimeCurrent();
                        g_last_pattern.bars_duration = 2;
                        return;
                    }
                }
            }
        }
    }
}

void ScanPatterns_M5() {
    UpdateDonchian_M5();
    UpdateATR_M5();
    
    DetectFlagPattern();
    DetectConsolidation();
    DetectStructureBreakouts();
    DetectSDRetestConfirmation();
}

void PrintPatterns() {
    Print("--- Last Pattern: ", EnumToString(g_last_pattern.type),
          " | Valid: ", g_last_pattern.is_valid,
          " | Confidence: ", g_last_pattern.confidence, "% ---");
}
'''
save("PatternDetector.mqh", patterndetector_mqh)

# ==============================================================================
# 7. RiskManager.mqh
# ==============================================================================
riskmanager_mqh = r'''//+------------------------------------------------------------------+
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
    int total_buy = 0, total_sell = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) total_buy++;
            else total_sell++;
        }
    }
    if(total_buy + total_sell >= Inp_MaxPosPerDirection * 2) return false;
    return true;
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
'''
save("RiskManager.mqh", riskmanager_mqh)

# ==============================================================================
# 8. SpreadFilter.mqh
# ==============================================================================
spreadfilter_mqh = r'''//+------------------------------------------------------------------+
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
'''
save("SpreadFilter.mqh", spreadfilter_mqh)

# ==============================================================================
# 9. CapManager.mqh
# ==============================================================================
capmanager_mqh = r'''//+------------------------------------------------------------------+
//|                                           CapManager.mqh         |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"

void CapManager_Init() {
    Print("CapManager: Initialized (Max Lot per ticket: ", Inp_MaxLotsPerTicket, ")");
}

void CapManager_Update() {
}

bool IsPositionCapReached(double lots) {
    return (lots >= Inp_MaxLotsPerTicket);
}

double GetCapAwareLotSize(double lots) {
    if(lots > Inp_MaxLotsPerTicket) return Inp_MaxLotsPerTicket;
    return lots;
}

void PrintCapStatus() {
    Print("--- Position Cap: ", Inp_MaxLotsPerTicket, " lots max ---");
}
'''
save("CapManager.mqh", capmanager_mqh)

# ==============================================================================
# 10. TicketSplitter.mqh
# ==============================================================================
ticketsplitter_mqh = r'''//+------------------------------------------------------------------+
//|                                         TicketSplitter.mqh       |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "CapManager.mqh"

TicketSplit g_active_splits[10];
int g_split_count = 0;
int g_next_split_id = 1;

void TicketSplitter_Init() {
    ZeroMemory(g_active_splits);
    g_split_count = 0;
    g_next_split_id = 1;
    Print("TicketSplitter: Initialized");
}

TicketSplit CalculateSplit(double total_lots, double entry_price, double sl_price) {
    TicketSplit split;
    ZeroMemory(split);
    split.split_id = g_next_split_id++;
    split.total_lots = total_lots;
    split.entry_price = entry_price;
    split.sl_price = sl_price;
    
    double cap = Inp_MaxLotsPerTicket;
    if(total_lots <= cap) {
        split.ticket_count = 1;
        split.lots_per_ticket = total_lots;
        return split;
    }
    
    split.ticket_count = (int)MathCeil(total_lots / cap);
    if(split.ticket_count > 20) split.ticket_count = 20;
    split.lots_per_ticket = NormalizeDouble(total_lots / split.ticket_count, 2);
    return split;
}

void ManageAllSplits() {
    // Sync multi-ticket positions
}

void PrintActiveSplits() {
    Print("--- Active Splits Count: ", g_split_count, " ---");
}
'''
save("TicketSplitter.mqh", ticketsplitter_mqh)

# ==============================================================================
# 11. OrderManager.mqh
# ==============================================================================
ordermanager_mqh = r'''//+------------------------------------------------------------------+
//|                                         OrderManager.mqh         |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "RiskManager.mqh"
#include "TicketSplitter.mqh"

void OrderManager_Init() {
    Print("OrderManager: Initialized");
}

ENUM_ORDER_TYPE_FILLING GetDynamicFillingMode() {
    uint fill = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((fill & 1) != 0) return ORDER_FILLING_FOK;
    if((fill & 2) != 0) return ORDER_FILLING_IOC;
    return ORDER_FILLING_RETURN;
}

ulong OpenPositionDraftMode(double price, double lots, TPDraft &draft,
                            int split_id = -1, int split_index = 0, int total_splits = 1) {
    double req_margin;
    if(!CheckMarginSafety(lots, req_margin)) {
        Print("ORDER REJECTED: Margin safety failure");
        return 0;
    }
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    ENUM_ORDER_TYPE order_type = (price >= ask) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double exec_price = (order_type == ORDER_TYPE_BUY) ? ask : bid;
    
    MqlTradeRequest request;
    ZeroMemory(request);
    MqlTradeResult result;
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.magic = Inp_MagicNumber;
    request.symbol = _Symbol;
    request.volume = lots;
    request.price = exec_price;
    request.type = order_type;
    request.deviation = Inp_MaxSlippage;
    request.type_filling = GetDynamicFillingMode();
    request.type_time = ORDER_TIME_GTC;
    request.comment = "TM_Draft";
    
    // Set initial SL on server for safety, but TP remains 0 (Drafted)
    if(order_type == ORDER_TYPE_BUY) {
        request.sl = g_last_pattern.sl_price;
    } else {
        request.sl = g_last_pattern.sl_price;
    }
    request.tp = 0;
    
    if(!OrderSend(request, result)) {
        int err = GetLastError();
        Print("ORDER ERROR: ", err, " - Result retcode: ", result.retcode);
        return 0;
    }
    
    ulong ticket = (result.deal > 0) ? result.deal : result.order;
    Print("ORDER EXECUTED: ", EnumToString(order_type), " ", DoubleToString(lots, 2),
          " @ ", DoubleToString(exec_price, _Digits), " | Ticket: ", ticket);
    return ticket;
}

bool ModifyPositionSL(ulong ticket, double new_sl) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request;
    ZeroMemory(request);
    MqlTradeResult result;
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = new_sl;
    request.tp = PositionGetDouble(POSITION_TP); // keep current TP (0)
    
    if(!OrderSend(request, result)) {
        Print("MODIFY SL ERROR: ", GetLastError());
        return false;
    }
    return (result.retcode == TRADE_RETCODE_DONE);
}

bool ClosePositionDirect(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double close_price = (pos_type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    MqlTradeRequest request;
    ZeroMemory(request);
    MqlTradeResult result;
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = volume;
    request.type = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = close_price;
    request.deviation = Inp_MaxSlippage;
    request.type_filling = GetDynamicFillingMode();
    request.comment = "TM_Close";
    
    if(!OrderSend(request, result)) {
        Print("CLOSE ERROR: ", GetLastError());
        return false;
    }
    return (result.retcode == TRADE_RETCODE_DONE);
}

int SplitAndExecute(TicketSplit &split) {
    int tickets_created = 0;
    for(int i = 0; i < split.ticket_count; i++) {
        ulong t = OpenPositionDraftMode(split.entry_price, split.lots_per_ticket, split.draft, split.split_id, i, split.ticket_count);
        if(t > 0) {
            split.tickets[tickets_created] = t;
            tickets_created++;
        }
    }
    return tickets_created;
}

void ManagePendingOrders() {
}
'''
save("OrderManager.mqh", ordermanager_mqh)

# ==============================================================================
# 12. PositionManager.mqh
# ==============================================================================
positionmanager_mqh = r'''//+------------------------------------------------------------------+
//|                                         PositionManager.mqh      |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "OrderManager.mqh"
#include "RiskManager.mqh"
#include "SupportResistance.mqh"
#include "TicketSplitter.mqh"

ManagedPosition g_managed_positions[20];
int g_managed_count = 0;

void PositionManager_Init() {
    ZeroMemory(g_managed_positions);
    g_managed_count = 0;
    Print("PositionManager: Initialized");
}

void RegisterPosition(ulong ticket, TPDraft &draft, int split_id = -1,
                      int split_index = 0, int total_splits = 1,
                      bool flag_top_sell = false) {
    if(!PositionSelectByTicket(ticket)) return;
    
    ManagedPosition mp;
    mp.ticket = ticket;
    mp.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    mp.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    mp.volume = PositionGetDouble(POSITION_VOLUME);
    mp.sl_price = PositionGetDouble(POSITION_SL);
    mp.tp_price = 0;
    mp.draft = draft;
    mp.split_id = split_id;
    mp.split_index = split_index;
    mp.total_splits = total_splits;
    mp.is_managed = true;
    mp.open_time = TimeCurrent();
    mp.last_update = TimeCurrent();
    mp.vol80_flag_top_sell = flag_top_sell;
    
    if(g_managed_count < 20) {
        g_managed_positions[g_managed_count] = mp;
        g_managed_count++;
    }
    
    Print("POSITION REGISTERED: Ticket ", ticket,
          " | Draft TP1: ", DoubleToString(draft.tp1_price, 0),
          " | Draft SL+: ", DoubleToString(draft.sl_plus_price, 0));
}

void ProcessTPDraftPipeline(ManagedPosition &mp) {
    if(!Inp_UseTPDraft) return;
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // --- PHASE 1: TP1 REACHED -> LOCK SL+ & ACTIVATE TP2 ---
    if(!mp.draft.tp1_triggered) {
        bool tp1_hit = (mp.type == POSITION_TYPE_BUY) ? (bid >= mp.draft.tp1_price) : (ask <= mp.draft.tp1_price);
        if(tp1_hit) {
            mp.draft.tp1_triggered = true;
            mp.draft.state = TP_STATE_TP1_HIT;
            
            // Lock SL+ at midpoint between entry and TP1
            if(!mp.draft.sl_plus_active) {
                if(ModifyPositionSL(mp.ticket, mp.draft.sl_plus_price)) {
                    mp.draft.sl_plus_active = true;
                    Print("SL+ LOCKED: Ticket ", mp.ticket, " SL moved to ", DoubleToString(mp.draft.sl_plus_price, 0));
                }
            }
            mp.draft.tp2_active = true;
        }
    }
    
    // --- PHASE 2: TP2 REACHED -> ACTIVATE TRAILING STOP ---
    if(mp.draft.tp2_active && !mp.draft.tp2_triggered) {
        bool tp2_hit = (mp.type == POSITION_TYPE_BUY) ? (bid >= mp.draft.tp2_price) : (ask <= mp.draft.tp2_price);
        if(tp2_hit) {
            mp.draft.tp2_triggered = true;
            mp.draft.tp3_active = true;
            mp.draft.state = TP_STATE_TRAILING;
            Print("TP2 HIT: Ticket ", mp.ticket, " Trailing Stop Activated!");
        }
    }
    
    // --- PHASE 3: TRAILING STOP MANAGEMENT ---
    if(mp.draft.tp3_active) {
        double trail_dist = mp.draft.tp3_trailing_dist;
        if(trail_dist <= 0) trail_dist = 300.0; // default points
        
        if(mp.type == POSITION_TYPE_BUY) {
            double candidate_sl = bid - trail_dist;
            double current_sl = PositionGetDouble(POSITION_SL);
            if(candidate_sl > current_sl + 20.0) {
                ModifyPositionSL(mp.ticket, candidate_sl);
            }
        } else {
            double candidate_sl = ask + trail_dist;
            double current_sl = PositionGetDouble(POSITION_SL);
            if(current_sl == 0 || candidate_sl < current_sl - 20.0) {
                ModifyPositionSL(mp.ticket, candidate_sl);
            }
        }
    }
}

void ManagePositions() {
    for(int i = 0; i < g_managed_count; i++) {
        if(!g_managed_positions[i].is_managed) continue;
        
        if(!PositionSelectByTicket(g_managed_positions[i].ticket)) {
            g_managed_positions[i].is_managed = false;
            continue;
        }
        
        ProcessTPDraftPipeline(g_managed_positions[i]);
    }
    
    // Compact array
    int active = 0;
    for(int i = 0; i < g_managed_count; i++) {
        if(g_managed_positions[i].is_managed) {
            if(active != i) g_managed_positions[active] = g_managed_positions[i];
            active++;
        }
    }
    g_managed_count = active;
}

void PrintManagedPositions() {
    Print("--- Active Managed Positions Count: ", g_managed_count, " ---");
}
'''
save("PositionManager.mqh", positionmanager_mqh)

# ==============================================================================
# 13. PerformanceMonitor.mqh
# ==============================================================================
performancemonitor_mqh = r'''//+------------------------------------------------------------------+
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
'''
save("PerformanceMonitor.mqh", performancemonitor_mqh)

# ==============================================================================
# 14. ErrorHandling.mqh
# ==============================================================================
errorhandling_mqh = r'''//+------------------------------------------------------------------+
//|                                         ErrorHandling.mqh        |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"

void ErrorHandler_Init() {
    Print("ErrorHandler: Initialized");
}

void ErrorHandler_Cleanup() {
}

void Log(string msg) {
    if(Inp_EnableLogging) {
        Print("[TradeMachine] ", msg);
    }
}

string ErrorDescription(int err) {
    return IntegerToString(err);
}
'''
save("ErrorHandling.mqh", errorhandling_mqh)

# ==============================================================================
# 15. HTTPReceiver.mqh
# ==============================================================================
httpreceiver_mqh = r'''//+------------------------------------------------------------------+
//|                                          HTTPReceiver.mqh        |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"

void HTTPReceiver_Init() {
    Print("HTTPReceiver: Initialized");
}

void HTTPReceiver_OnTick() {
    // Pure algorithmic execution - no external HTTP blocks
}
'''
save("HTTPReceiver.mqh", httpreceiver_mqh)

# ==============================================================================
# 16. TradeMachine.mq5
# ==============================================================================
trademachine_mq5 = r'''//+------------------------------------------------------------------+
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
        Alert("ERROR: Symbol not in Market Watch!");
        return INIT_FAILED;
    }
    
    long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
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
void EvaluateEntries() {
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
        }
    } else {
        ulong ticket = OpenPositionDraftMode(entry_price, lots, draft);
        if(ticket > 0) {
            RegisterPosition(ticket, draft, -1, 0, 1, (g_last_pattern.type == PATTERN_FLAG_TOP_SELL));
            g_daily_trades++;
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
'''
save("TradeMachine.mq5", trademachine_mq5)

print("\nAll 16 TradeMachine v3.0 modules generated successfully!")