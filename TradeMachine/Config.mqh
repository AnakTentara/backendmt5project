//+------------------------------------------------------------------+
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
// TP DRAFT SYSTEM & STOP LOSS GATING
// ============================================================
input group "=== TP DRAFT SYSTEM ==="
input double Inp_TP1_RR             = 1.5;   // TP1 Risk:Reward
input double Inp_TP2_RR             = 3.0;   // TP2 Risk:Reward
input double Inp_TP3_TrailingMult   = 1.5;   // TP3 trailing distance (x risk)
input bool   Inp_UseStructureTP     = true;  // Use S/R for TP override
input double Inp_SL_Buffer_Pips     = 10.0;  // SL buffer beyond structure (points)
input double Inp_MinSL_Points       = 150.0; // Minimum SL distance in points (breathing room)
input double Inp_MaxSL_Points       = 400.0; // Maximum SL distance in points (prevents blowout)
input int    Inp_LocalSwingBars     = 5;     // Local M5 bars for swing SL calculation
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
