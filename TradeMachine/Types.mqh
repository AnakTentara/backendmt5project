//+------------------------------------------------------------------+
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
