# TradeMachine v3.0 — Trading Plan for VOL_80 (Deriv MT5 Synthetic Index)

## Overview
Fully programmatic, high-frequency EA for Deriv/MT5 synthetic index **VOL_80 (Volatility 80 Index)**.
No AI/ML — pure algorithmic logic for maximum speed and determinism.

**Live VOL_80 Specs (from MT5):**
- Price: ~245,000 | Contract Size: 1.0 | Point: 1.0 | Digits: 0
- **Spread: dynamic (56-82 pts live)** ~72 pts avg ($72/lot) — MASSIVE cost ⚠️
- **Tick Value: $1.00** per point per lot
- Volume Min: 0.01 | Volume Max: 100.0 | Volume Step: 0.01
- Max lots per ticket capped at **100.0**

---

## 1. Market Structure Analysis (Multi-Timeframe)

### Timeframe Hierarchy
| TF | Purpose | Weight |
|----|---------|--------|
| H4 | Major Trend Direction | 30% |
| H1 | Intermediate Trend | 25% |
| M30 | Swing Structure | 20% |
| M15 | Entry Trend Confirmation | 15% |
| M5 | Pattern Detection & Execution | 10% |

### Trend Classification (Per TF)
```cpp
enum TREND_STATE {
    TREND_BULLISH_STRONG,
    TREND_BULLISH_WEAK,
    TREND_NEUTRAL,
    TREND_BEARISH_WEAK,
    TREND_BEARISH_STRONG
};
```

### CHOCH (Change of Character) Detection — Per Tick
- **Bullish CHOCH**: Price breaks prior Lower High (LH) with volume confirmation
- **Bearish CHOCH**: Price breaks prior Higher Low (HL) with volume confirmation
- Track swing points using **ZigZag logic** (min 5-bar fractal confirmation)
- Store last 50 swing points per TF for context

---

## 2. Pattern Detection (M5 — Execution TF)

### 2.1 Flag Pattern
```cpp
struct FlagPattern {
    bool isBullFlag;
    bool isBearFlag;
    double poleHigh;
    double poleLow;
    double flagTop;
    double flagBottom;
    int flagBars;
    double breakoutLevel;
};
```
- **Pole**: Min 3 consecutive strong candles (body > 60% range)
- **Flag**: 3-15 bars, parallel channels, volume decreasing
- **Entry**: Breakout + retest of flag boundary
- **Flag Top Sell**: When price at flagTop in bearish trend context

### 2.2 Base/Consolidation (Accumulation/Distribution)
```cpp
struct ConsolidationZone {
    double top;
    double bottom;
    int bars;
    bool isAccumulation;
    bool isDistribution;
    double volumeProfile;
};
```
- Detect using **Donchian Channel** (20-period) + **ATR contraction** (< 0.5x avg ATR)

### 2.3 Structure Labels
- **Bullish**: HH/HL sequence + M5 breakout above recent LH
- **Bearish**: LL/LH sequence + M5 breakout below recent HL

---

## 3. Support/Resistance Engine (Minor + Major)

### Levels Hierarchy
| Level Type | Lookback | Strength Calculation | Min Touches |
|------------|----------|---------------------|-------------|
| **Major S/R** | H4/H1 swing points | Volume × Touches × Time | 3+ |
| **Minor S/R** | M15/M5 swing points | Volume × Touches | 2+ |
| **Micro S/R** | M5 fractals | Immediate reaction | 1 (reactive) |

### Dynamic S/R (Per Tick Update)
- **VWAP Bands** (Session + Daily) — Major
- **EMA 20/50/200** (M15/H1) — Dynamic minor
- **Pivot Points** (Daily/Weekly) — Major
- **Order Blocks** (Last 3 swing reversals) — Minor/Major
- **Fair Value Gaps (FVG)** — Unfilled gaps = magnetic levels

### Level Scoring
```cpp
double CalculateLevelStrength(level) {
    return (touches * 2.0) + 
           (volumeAtLevel / avgVolume * 1.5) + 
           (timeSinceTouch < 24h ? 1.0 : 0.5) +
           (isMajorTF ? 2.0 : 1.0);
}
```

---

## 4. Entry Logic

### 4.1 Primary Entry: Trend-Following (Buy in Bullish, Sell in Bearish)
```cpp
bool CanEnterLong() {
    return (H4_Trend >= TREND_BULLISH_WEAK) &&
           (H1_Trend >= TREND_BULLISH_WEAK) &&
           (M15_Trend != TREND_BEARISH_STRONG) &&
           (M5_Pattern == BULL_FLAG_BREAK || 
            M5_Pattern == BASE_BREAKOUT_UP ||
            M5_CHOCH_BULLISH) &&
           PriceAtDemandZone() &&
           !PriceAtMajorSupply();
}
```

### 4.2 Counter-Trend Entry (Consolidation Only)
- **Allowed**: M5/M15 consolidation + H1/H4 trend still intact
- **Type**: Limit orders at consolidation extremes
- **Size**: 50% of normal position size
- **SL**: Beyond consolidation boundary + 1 ATR

### 4.3 Order Types
| Scenario | Order Type | Price |
|----------|------------|-------|
| Breakout confirmation | STOP | Breakout level + 0.5 pt |
| Retest of broken level | LIMIT | Broken level (now S/R flipped) |
| Flag top (bearish) | LIMIT | Flag top - 0.5 pt |
| Base bottom (bullish) | LIMIT | Base bottom + 0.5 pt |

---

## 5. Risk Management — Core Framework

### 5.1 Risk Per Trade Rules
- **Max 3% per trade** (single position)
- **Max 5% total exposure** (all open positions combined)
- **Max 2 concurrent positions** same direction
- **Max 1 counter-trend position** at any time
- **Spread-adjusted**: Effective risk includes spread cost (72 pts on VOL_80)

---

## 6. 💰 R:R (Risk-to-Reward) Management System

### 6.1 Dynamic R:R Based on Market Structure

```cpp
struct RiskRewardConfig {
    double rr_bullish_trend;      // R:R when all TFs bullish (default 1:2.5)
    double rr_bearish_trend;      // R:R when all TFs bearish (default 1:2.5)
    double rr_consolidation;      // R:R during consolidation (default 1:1.5)
    double rr_choch;              // R:R on CHOCH entry (default 1:3.0)
    double rr_flag_breakout;      // R:R on flag breakout (default 1:2.0)
    double rr_flag_top_sell;      // R:R on flag top sell (default 1:1.5)
    double rr_counter_trend;      // R:R counter-trend (default 1:1.0)
};
```

### 6.2 R:R Selection Logic

```cpp
double GetDynamicRR() {
    if (M5_Pattern == FLAG_TOP_SELL) 
        return rr_flag_top_sell;
    if (M5_CHOCH_DETECTED) 
        return rr_choch;
    if (M5_Pattern == FLAG_BREAKOUT) 
        return rr_flag_breakout;
    if (IsConsolidation()) 
        return rr_consolidation;
    if (IsBullishTrendAllTFs()) 
        return rr_bullish_trend;
    if (IsBearishTrendAllTFs()) 
        return rr_bearish_trend;
    return rr_counter_trend;
}
```

### 6.3 R:R Caps Based on Spread (VOL_80 = 72 pts)

```cpp
double CalculateRR_targets(double entry, double sl, double rr_ratio) {
    double risk_points = MathAbs(entry - sl);  // In points
    double gross_rr = risk_points * rr_ratio;  // Gross TP distance
    
    // TP must beat spread: net movement = gross_rr - spread
    double net_points = gross_rr - 72.0;  // Subtract VOL_80 spread
    
    // Minimum net target: 50% of risk (after spread)
    if (net_points < risk_points * 0.5) {
        // Adjust R:R upward to compensate for spread
        double min_gross = (risk_points * 0.5 + 72.0);
        rr_ratio = min_gross / risk_points;
        gross_rr = min_gross;
    }
    
    double tp1_price = (entry > sl) ? entry + gross_rr : entry - gross_rr;  // Buy/Sell
    
    return rr_ratio;
}
```

### 6.4 Multi-Level R:R Pipeline

| Level | R:R (Bullish Trend) | R:R (Consolidation) | Notes |
|-------|---------------------|---------------------|-------|
| **TP1** | 1:1.5 | 1:1.0 | First target (draft only) |
| **TP2** | 1:3.0 | 1:1.5 | Activated after TP1 hit |
| **TP3 (Trailing)** | 1:5.0+ | 1:2.0 | Activate after TP2 hit |
| **Flag Top Sell** | 1:1.0 | N/A | Fixed SL at minor resistance |
| **CHOCH Entry** | 1:3.0 | 1:2.0 | High conviction entry |

### 6.5 Structure-Based R:R Override
- If nearest Minor S/R is closer than calculated TP1 → use S/R as TP1
- If nearest Major S/R is closer than calculated TP2 → use S/R as TP2
- **Never set TP closer than spread + 10 points** (avoid spread-eat-all-profit scenarios)

### 6.6 R:R Decay Check (Per Tick)
```cpp
bool CheckRRDecay(double entry, double current_sl, double current_tp) {
    double current_rr = MathAbs(current_tp - entry) / MathAbs(current_sl - entry);
    double min_rr = GetDynamicRR() * 0.7;  // Allow 30% decay before adjustment
    return (current_rr < min_rr);
}
```

---

## 7. 💰 Margin Calculation System

### 7.1 Real-Time Margin Formula
```cpp
double CalculateMargin(double lots) {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    
    return (lots * contract_size * price) / leverage;
}
```

### 7.2 Margin Safety Checks (Per Order)
```cpp
bool CanOpenPosition(double lots, double &required_margin) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin_free = AccountInfoDouble(ACCOUNT_FREE_MARGIN);
    
    required_margin = CalculateMargin(lots);
    
    // Check 1: Margin must not exceed 50% of free margin (safety buffer)
    if (required_margin > margin_free * 0.50) 
        return false;
    
    // Check 2: Equity must remain above 110% of used margin (margin call safety)
    double used_margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double projected_margin = used_margin + required_margin;
    double projected_margin_level = (equity / projected_margin) * 100.0;
    
    if (projected_margin_level < 200.0)  // Alert threshold
        return false;
    
    // Check 3: After spread cost, equity must stay positive
    double spread_cost = 72.0 * lots;  // VOL_80 spread = 72 pts
    if ((equity - spread_cost) <= 0)
        return false;
    
    return true;
}
```

### 7.3 Margin Monitoring (Per Tick)
```cpp
void MonitorMargin() {
    double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    double margin_free = AccountInfoDouble(ACCOUNT_FREE_MARGIN);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Alert levels
    if (margin_level < 500.0) 
        Alert("⚠️ MARGIN WARNING: " + DoubleToString(margin_level, 1) + "%");
    if (margin_level < 300.0) 
        CloseAllPositions();  // Emergency close
    
    // Track worst margin level today
    UpdateDailyMarginStatistics(margin_level);
}
```

### 7.4 Leverage Impact Table (VOL_80 at 245,000)

| Leverage | 0.01 Lot Margin | 0.08 Lot Margin | 100 Lot Margin | Can Trade on $10? |
|----------|----------------|-----------------|----------------|-------------------|
| **1:50** | $49.00 | $392.00 | $490,000 | ❌ **IMPOSSIBLE** |
| **1:200** | $12.25 | $98.00 | $122,500 | ❌ Impossible |
| **1:245** | $10.00 | $80.00 | $100,000 | ⚠️ Barely |
| **1:500** | $4.90 | $39.20 | $49,000 | ✅ Possible |
| **1:1000** | $2.45 | $19.60 | $24,500 | ✅ Comfortable |
| **1:2000** | $1.23 | $9.80 | $12,250 | ✅ **RECOMMENDED** |

---

## 8. 💰 Lot Sizing System

### 8.1 Multi-Factor Lot Calculation
```cpp
double CalculateLotSize(double entry, double sl, double risk_override = -1) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_percent = (risk_override > 0) ? risk_override : MaxRiskPercent / 100.0;
    
    // Factor 1: Risk-based sizing (3% rule)
    double risk_amount = balance * risk_percent;
    double sl_points = MathAbs(entry - sl) / _Point;
    double risk_based_lots = risk_amount / (sl_points * 1.0);  // $1/point/lot
    
    // Factor 2: Spread-adjusted sizing (VOL_80 = 72 pt spread)
    // Effective risk = SL distance + spread (you pay spread on entry)
    double effective_sl = sl_points + 72.0;  // Add spread to effective SL
    double spread_adjusted_lots = risk_amount / (effective_sl * 1.0);
    
    // Use the SMALLER of the two (more conservative)
    double lots = MathMin(risk_based_lots, spread_adjusted_lots);
    
    // Factor 3: Margin availability check
    double required_margin = CalculateMargin(lots);
    double margin_free = AccountInfoDouble(ACCOUNT_FREE_MARGIN);
    double margin_cap_lots = (margin_free * 0.50) / (245000.0 / AccountInfoInteger(ACCOUNT_LEVERAGE));
    lots = MathMin(lots, margin_cap_lots);
    
    // Factor 4: Position cap (100 lots max per ticket)
    lots = MathMin(lots, 100.0);
    
    // Factor 5: Broker constraints
    double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);   // 0.01
    double vol_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);   // 100.0
    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); // 0.01
    
    if (lots < vol_min) return 0;  // Cannot open minimum lot
    
    // Round down to volume step
    lots = MathFloor(lots / vol_step) * vol_step;
    
    // Factor 6: Total exposure cap (5% max)
    double total_exposure = GetTotalOpenRisk();
    if ((total_exposure + risk_amount) > balance * 0.05)
        lots = MathMin(lots, (balance * 0.05 - total_exposure) / (effective_sl * 1.0));
    
    if (lots < vol_min) return 0;
    
    return NormalizeDouble(lots, 2);
}
```

### 8.2 Lot Size Reference Table (Balance $10, 1:2000 Lev)

| SL Distance | Risk-Based Lots | Spread-Adj Lots | Final Lots | Margin Used |
|-------------|----------------|-----------------|------------|-------------|
| 50 pts | 0.03 | 0.02 | **0.02** | $1.23 |
| 78 pts (net) | 0.02 | 0.01 | **0.01** | $1.23 |
| 100 pts | 0.02 | 0.01 | **0.01** | $1.23 |
| 200 pts | 0.01 | 0.01 | **0.01** | $1.23 |

### 8.3 Compounding Lot Growth
```cpp
double GetCompoundedLotSize() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lots = balance / 500.0;  // 1 lot per $500 (customize)
    
    // Cap at 100 lots
    if (lots > 100.0) {
        // Trigger multi-ticket splitting
        return 100.0;
    }
    
    double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if (lots < vol_min) lots = vol_min;
    
    return NormalizeDouble(lots, 2);
}
```

### 8.4 Risk Scaling by Phase
| Balance Range | Lot Mode | Notes |
|---------------|----------|-------|
| $10 – $500 | Fixed 0.01 | Minimum, spread-adjusted |
| $500 – $5,000 | Linear growth | 1 lot per $500 |
| $5,000 – $50,000 | Linear growth | 1 lot per $500, cap approaching |
| $50,000+ | Capped + multi-ticket | 100 lots max, split remaining |

---

## 9. 💰 TP Draft System

### 9.1 TP Draft Architecture
```cpp
struct TPDraft {
    // TP1 — First Target
    double tp1_price;
    double tp1_rr;             // R:R ratio used for TP1
    bool tp1_triggered;        // Internal flag (NOT on server)
    bool tp1_been_been;        // Price touched tp1_price (tick-level)
    
    // TP2 — Second Target (activated after TP1)
    double tp2_price;
    double tp2_rr;             // R:R ratio used for TP2
    bool tp2_active;           // TP2 order placed on server
    bool tp2_triggered;
    
    // TP3 — Trailing Target (activated after TP2)
    double tp3_start_price;
    double tp3_trailing_dist;
    bool tp3_active;
    
    // SL+ — Stop Loss Positive
    double sl_plus_price;      // Between Entry and TP1
    bool sl_plus_active;       // SL+ set on server
    
    // Spread tracking
    double spread_at_entry;
    double net_rr;             // R:R after spread cost
};
```

### 9.2 TP Draft Calculation (Full Pipeline)

```cpp
TPDraft CalculateTP_Draft(double entry, double sl, double rr_config) {
    TPDraft draft;
    draft.spread_at_entry = 72.0;  // VOL_80 current spread
    
    // --- TP1 Calculation ---
    double gross_risk = MathAbs(entry - sl);  // Points
    double gross_tp1_dist = gross_risk * rr_config.rr_tp1;  // Gross TP distance
    double net_tp1_dist = gross_tp1_dist - draft.spread_at_entry;  // After spread
    
    // Ensure net profit after spread
    if (net_tp1_dist < gross_risk * 0.3) {
        // Recalculate with higher R:R to beat spread
        gross_tp1_dist = (gross_risk * 0.3 + draft.spread_at_entry) / rr_config.rr_tp1;
    }
    
    draft.tp1_price = (entry > sl) ? entry + gross_tp1_dist : entry - gross_tp1_dist;
    draft.tp1_rr = gross_tp1_dist / gross_risk;
    draft.net_rr = net_tp1_dist / gross_risk;
    draft.tp1_triggered = false;
    draft.tp1_been_been = false;
    
    // --- SL+ Calculation (between Entry and TP1) ---
    draft.sl_plus_price = (entry + draft.tp1_price) / 2.0;
    draft.sl_plus_active = false;
    
    // --- TP2 Calculation ---
    double gross_tp2_dist = gross_risk * rr_config.rr_tp2;
    draft.tp2_price = (entry > sl) ? entry + gross_tp2_dist : entry - gross_tp2_dist;
    draft.tp2_rr = gross_tp2_dist / gross_risk;
    draft.tp2_active = false;
    draft.tp2_triggered = false;
    
    // --- TP3 Calculation (Trailing) ---
    draft.tp3_start_price = draft.tp2_price;
    draft.tp3_trailing_dist = gross_risk * 1.5;  // 1.5x risk
    draft.tp3_active = false;
    
    return draft;
}
```

### 9.3 TP Draft → Real Conversion Pipeline

```cpp
void ProcessTP_Draft(Position &pos, TPDraft &draft) {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // --- PHASE 0: OPEN POSITION (no TP/SL on server) ---
    // Position opened with DRAFT TP/SL only tracked internally
    
    // --- PHASE 1: TP1 APPROACH (monitoring) ---
    if (!draft.tp1_been_been && bid >= draft.tp1_price) {
        draft.tp1_been_been = true;
        Log("TP1 price reached: " + DoubleToString(draft.tp1_price, _Digits));
    }
    
    // --- PHASE 2: TP1 HIT → SL+ + TP2 ---
    if (draft.tp1_been_been && !draft.tp1_triggered && bid >= draft.tp1_price) {
        draft.tp1_triggered = true;
        
        // Step 1: Set SL+ on server (midpoint between entry and TP1)
        ModifyPositionSL(pos.ticket, draft.sl_plus_price);
        draft.sl_plus_active = true;
        
        // Step 2: Place TP2 as real LIMIT order
        double tp2_lot = pos.volume;  // Same volume
        PlaceLimitOrder(pos.type == ORDER_TYPE_BUY ? ORDER_TYPE_SELL_LIMIT 
                                                       : ORDER_TYPE_BUY_LIMIT,
                        draft.tp2_price, tp2_lot, 0, 0, "TP2");
        draft.tp2_active = true;
        
        Log("TP1 HIT → SL+ at " + DoubleToString(draft.sl_plus_price, _Digits) + 
            ", TP2 placed at " + DoubleToString(draft.tp2_price, _Digits));
    }
    
    // --- PHASE 3: TP2 HIT → Trailing ---
    if (draft.tp2_active && draft.tp2_triggered && !draft.tp3_active) {
        draft.tp3_active = true;
        // Activate trailing SL (move by 1 ATR or structure)
        ActivateTrailingSL(pos, draft.tp3_trailing_dist);
        Log("TP2 HIT → Trailing SL activated at " + DoubleToString(draft.tp3_trailing_dist, _Digits));
    }
    
    // --- PHASE 4: TRAILING (TP3) ---
    if (draft.tp3_active) {
        UpdateTrailingSL(pos, draft.tp3_trailing_dist);
    }
}
```

### 9.4 SL+ Logic (Detailed)
```
ENTRY → No SL/TP on server (draft only)
  ↓
Price reaches TP1 (draft) → 
  ↓
Server: SL modified to SL+ = (Entry + TP1) / 2
Server: TP2 LIMIT order placed
  ↓
Price reaches TP2 (server LIMIT) → 
  ↓
Server: Trailing SL activated (1.5x risk distance)
  ↓
Position closed at trailing SL or TP3 (if extended)
```

### 9.5 Flag Top Sell — Special TP/SL
```cpp
TPDraft CalculateFlagTopSell_Draft(double entry, double sl) {
    TPDraft draft;
    
    // SL = Minor Resistance + buffer OR 3-5% account risk (whichever tighter)
    double minor_resistance = GetMinorResistance();
    double sl_from_resistance = minor_resistance + 5.0;  // 5 pt buffer
    double sl_from_risk = entry * (1.0 + FlagTop_SL_Percent / 100.0);
    draft.sl_price = MathMin(sl_from_resistance, sl_from_risk);
    
    // TP = 1:1 R:R (fixed for flag top sells — quick exit)
    double risk = MathAbs(entry - draft.sl_price);
    draft.tp1_price = entry - risk;  // Sell: TP below entry
    
    // SL+ = midpoint
    draft.sl_plus_price = (entry + draft.tp1_price) / 2.0;
    
    // TP2 = 1:2 R:R (if momentum continues bearish)
    draft.tp2_price = entry - (risk * 2.0);
    
    return draft;
}
```

---

## 10. 💰 Spread Filter System

### 10.1 Real-Time Spread Monitoring
```cpp
struct SpreadState {
    double current_spread;      // Current spread in points
    double average_spread;      // Rolling average (100 ticks)
    double max_spread_today;    // Today's max spread
    double spread_at_entry;     // Spread when position opened
    int spread_warnings;        // Warning count today
    datetime last_spread_update;
    bool is_wide;               // Current spread too wide
};
```

### 10.2 Spread Filter Logic

```cpp
bool SpreadFilter_Check() {
    double current_spread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD);
    double spread_threshold = SpreadFilter_Max;  // 80 points (VOL_80 default)
    
    // Update rolling average
    UpdateSpreadAverage(current_spread);
    
    // Check 1: Current spread must be below threshold
    if (current_spread > spread_threshold) {
        spread_state.is_wide = true;
        spread_state.spread_warnings++;
        return false;  // Skip trade
    }
    
    // Check 2: Average spread must be acceptable
    if (spread_state.average_spread > spread_threshold * 1.2) {
        // Market condition degraded — reduce position size
        ReducePositionSize(0.5);
        return false;
    }
    
    // Check 3: Spread must be < 50% of minimum target
    if (current_spread > MinTargetPoints * 0.5) {
        // Spread eats too much of potential profit
        return false;
    }
    
    spread_state.is_wide = false;
    return true;  // OK to trade
}
```

### 10.3 Spread-Based Position Sizing Adjustment
```cpp
double SpreadAdjustedLotSize(double base_lots) {
    double current_spread = spread_state.current_spread;
    double base_spread = 72.0;  // VOL_80 baseline spread
    
    // Scale down proportionally if spread widens
    if (current_spread > base_spread) {
        double ratio = base_spread / current_spread;
        return base_lots * MathMax(ratio, 0.25);  // Minimum 25% of base
    }
    
    return base_lots;
}
```

### 10.4 Spread Alert Levels
| Spread (pts) | Action |
|-------------|--------|
| < 60 | ✅ Normal — trade freely |
| 60-80 | ⚠️ Elevated — reduce lot size 25% |
| 80-100 | ⚠️ Wide — skip new trades |
| 100-150 | 🔴 Very Wide — close existing, no new |
| > 150 | 🔴 Critical — emergency close all |

### 10.5 Session-Based Spread Behavior (VOL_80)
```
| Time (Server)  | Typical Spread | Action |
|----------------|---------------|--------|
| 00:00-00:05    | 80-120 pts    | 🔴 Skip — rollover |
| 00:05-08:00    | 60-80 pts     | ⚠️ Reduced lots |
| 08:00-20:00    | 50-75 pts     | ✅ Normal |
| 20:00-23:55    | 60-90 pts     | ⚠️ Reduced lots |
| 23:55-23:59    | 80-150 pts    | 🔴 Skip |
```

---

## 11. 💰 Position Cap Handling System

### 11.1 Cap Detection
```cpp
bool IsPositionCapReached(double desired_lots) {
    double vol_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);  // 100.0
    return (desired_lots >= vol_max);
}

double GetPositionCap() {
    return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);  // 100.0
}
```

### 11.2 Cap-Aware Lot Calculation
```cpp
double GetCapAwareLotSize(double balance, double risk_sl_points) {
    // Standard lot sizing
    double lots = CalculateLotSize(0, risk_sl_points);
    double cap = GetPositionCap();
    
    if (lots >= cap) {
        // Cap is reached — enable multi-ticket mode
        Log("⚠️ Position cap reached at " + DoubleToString(lots, 2) + 
            " lots → activating multi-ticket splitting");
        return cap;  // Return max per ticket
    }
    
    return lots;
}
```

### 11.3 Balance-to-Cap Threshold Table (1:2000 Leverage)

| Balance | Max Theoretical Lots | Capped Lots | Action |
|---------|---------------------|-------------|--------|
| $10 | 0.08 | 0.08 | Normal |
| $500 | 4.0 | 4.0 | Normal |
| $5,000 | 40.9 | 40.9 | Normal |
| **$12,250** | **100.0** | **100.0** | ⚠️ **CAP REACHED** |
| $50,000 | 100.0 (cap) | 100.0 | Multi-ticket mode |
| $100,000 | 100.0 (cap) | 100.0 | Multi-ticket mode |
| $1,000,000 | 100.0 (cap) | 100.0 | Multi-ticket mode |

### 11.4 Graceful Degradation on Cap
```cpp
void HandlePositionCap(double lots, double entry, double sl) {
    if (IsPositionCapReached(lots)) {
        // Step 1: Log warning
        Log("Position cap reached. Activating multi-ticket splitting.");
        
        // Step 2: Split across multiple tickets
        SplitPosition(lots, entry, sl);
        
        // Step 3: Adjust compounding strategy
        // After cap, growth becomes LINEAR (fixed $ profit per trade)
        // instead of exponential (fixed % profit per trade)
        
        SetCompoundingMode(COMPOUND_LINEAR);
    }
}
```

---

## 12. 💰 Multi-Ticket Splitting System

### 12.1 Split Logic
```cpp
struct TicketSplit {
    int ticket_count;           // Number of tickets to split into
    double lots_per_ticket;     // Lots per ticket (max 100)
    double total_lots;          // Total lots (sum of all tickets)
    double entry_price;         // Common entry price
    double sl_price;            // Common SL
    TPDraft draft;              // Common TP Draft
    int tickets[];              // Array of ticket numbers
    bool all_closed;            // All tickets closed
    bool tp2_activated;         // TP2 placed on all tickets
};
```

### 12.2 Split Calculation
```cpp
TicketSplit CalculateSplit(double total_lots, double entry, double sl) {
    TicketSplit split;
    split.total_lots = total_lots;
    split.entry_price = entry;
    split.sl_price = sl;
    split.draft = CalculateTP_Draft(entry, sl, GetDynamicRR());
    
    double cap = GetPositionCap();  // 100.0
    
    if (total_lots <= cap) {
        // No split needed
        split.ticket_count = 1;
        split.lots_per_ticket = total_lots;
        return split;
    }
    
    // Split into multiple tickets
    split.ticket_count = (int)MathCeil(total_lots / cap);
    split.lots_per_ticket = cap;
    
    // Last ticket gets remainder
    double remainder = total_lots - (cap * (split.ticket_count - 1));
    // Actually: all tickets get cap except last which gets remainder
    // But for simplicity, split evenly if possible, or cap + remainder
    
    return split;
}
```

### 12.3 Split Execution
```cpp
int[] SplitAndExecute(TicketSplit &split) {
    int[] tickets;
    
    for (int i = 0; i < split.ticket_count; i++) {
        double lots = (i == split.ticket_count - 1) 
            ? (split.total_lots - split.lots_per_ticket * (split.ticket_count - 1))
            : split.lots_per_ticket;
        
        if (lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) 
            continue;  // Skip if below minimum
        
        // Open ticket with DRAFT TP/SL (no server TP/SL)
        int ticket = OpenPosition(
            split.entry_price, 
            lots, 
            SPLIT_TICKET_MODE  // Flag: multi-ticket split
        );
        
        if (ticket > 0) {
            ArrayResize(tickets, ArraySize(tickets) + 1);
            tickets[ArraySize(tickets) - 1] = ticket;
            
            // Store split metadata for each ticket
            StoreSplitMetadata(ticket, split, i);
        }
    }
    
    Log("Split into " + IntegerToString(split.ticket_count) + 
        " tickets, " + DoubleToString(split.lots_per_ticket, 2) + " lots each");
    
    return tickets;
}
```

### 12.4 Multi-Ticket Management

```cpp
void ManageMultiTicket(int[] tickets, TicketSplit &split) {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Count still-open tickets
    int open_count = 0;
    for (int i = 0; i < ArraySize(tickets); i++) {
        if (PositionSelectByTicket(tickets[i])) open_count++;
    }
    
    // --- TP1 Trigger (all tickets) ---
    if (!split.tp1_triggered && bid >= split.draft.tp1_price) {
        split.tp1_triggered = true;
        
        // Set SL+ on ALL tickets
        for (int i = 0; i < ArraySize(tickets); i++) {
            ModifyPositionSL(tickets[i], split.draft.sl_plus_price);
        }
        split.sl_plus_active = true;
        
        // Place TP2 on ALL tickets
        for (int i = 0; i < ArraySize(tickets); i++) {
            PlaceLimitOrder(/* ... */, split.draft.tp2_price, 
                           split.lots_per_ticket, 0, 0, "TP2_Multi");
        }
        split.tp2_activated = true;
    }
    
    // --- TP2 Trigger ---
    if (split.tp2_activated && bid >= split.draft.tp2_price) {
        split.tp2_triggered = true;
        // Activate trailing on all remaining tickets
        for (int i = 0; i < ArraySize(tickets); i++) {
            if (PositionSelectByTicket(tickets[i])) {
                ActivateTrailingSL(tickets[i], split.draft.tp3_trailing_dist);
            }
        }
    }
    
    // --- Aggregate P&L tracking ---
    double total_pnl = 0;
    for (int i = 0; i < ArraySize(tickets); i++) {
        if (PositionSelectByTicket(tickets[i])) {
            total_pnl += PositionGetDouble(PRICE_PROFIT);
        }
    }
    UpdateSplitPnL(split.ticket_id, total_pnl);
}
```

### 12.5 Multi-Ticket Split Example

```
Balance: $50,000 | 1:2000 leverage | Required lots: 400

Split into 4 tickets:
  Ticket 1: 100 lots @ 245,000 → SL+ at midpoint, TP2 LIMIT
  Ticket 2: 100 lots @ 245,001 → SL+ at midpoint, TP2 LIMIT
  Ticket 3: 100 lots @ 245,002 → SL+ at midpoint, TP2 LIMIT
  Ticket 4: 100 lots @ 245,003 → SL+ at midpoint, TP2 LIMIT
  
  (Slight price offset to avoid slippage clustering)

All tickets share:
  - Same SL+ price
  - Same TP2 price
  - Same trailing SL distance
  - Same TP Draft metadata
```

### 12.6 Multi-Ticket Edge Cases
```cpp
// Partial fill: some tickets filled, others rejected
void HandlePartialFill(int[] tickets, TicketSplit &split) {
    int filled = CountFilledTickets(tickets);
    int expected = split.ticket_count;
    
    if (filled < expected) {
        // Re-attempt remaining with reduced lots
        double remaining_lots = split.total_lots - (filled * split.lots_per_ticket);
        if (remaining_lots >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
            // Retry with smaller lots per ticket
            double new_lots_per_ticket = MathMin(remaining_lots / 3, 100.0);
            RetrySplit(remaining_lots, new_lots_per_ticket, split);
        }
    }
}

// One ticket hits TP2 but others haven't
void HandleMixedTP2(int[] tickets, TicketSplit &split) {
    // Continue trailing on remaining tickets
    // TP2 hit on partial tickets: keep those profits, trail the rest
    Log("Partial TP2 hit: " + IntegerToString(CountTP2Hits(tickets)) + 
        " of " + ArraySize(tickets) + " tickets");
}
```

---

## 13. Execution Engine (Per Tick — Updated)

### 13.1 Main Loop (OnTick) — Full Pipeline
```cpp
void OnTick() {
    // === PHASE 0: DATA UPDATE ===
    UpdateMultiTimeframeData();
    UpdateSpreadState();                    // NEW: Spread monitoring
    UpdateMarginTracking();                 // NEW: Margin tracking
    DetectCHOCH_M5();
    UpdateSupportResistance();
    ScanPatterns_M5();
    
    // === PHASE 1: SPREAD FILTER ===
    if (!SpreadFilter_Check()) {
        // Spread too wide — skip new entries
        // But still manage existing positions
        ManagePositions();
        ManagePendingOrders();
        return;
    }
    
    // === PHASE 2: ENTRY EVALUATION ===
    if (NoOpenPositions() || CanAddPosition()) {
        double entry_price, sl_price;
        TREND_TYPE trend = DetermineEntryDirection(entry_price, sl_price);
        
        if (CanEnter(trend, entry_price, sl_price)) {
            // --- LOT SIZING ---
            double lots = CalculateLotSize(entry_price, sl_price);
            
            // --- MARGIN CHECK ---
            double required_margin;
            if (!CanOpenPosition(lots, required_margin)) {
                Log("Insufficient margin. Required: " + DoubleToString(required_margin, 2));
                return;
            }
            
            // --- R:R CALCULATION ---
            RiskRewardConfig rr = GetDynamicRR();
            
            // --- TP DRAFT CALCULATION ---
            TPDraft draft = CalculateTP_Draft(entry_price, sl_price, rr);
            
            // --- POSITION CAP CHECK ---
            if (IsPositionCapReached(lots)) {
                // Multi-ticket split
                TicketSplit split = CalculateSplit(lots, entry_price, sl_price);
                int[] tickets = SplitAndExecute(split);
                StoreActiveSplit(split);
            } else {
                // Single ticket — DRAFT TP/SL mode
                OpenPositionDraftMode(entry_price, lots, draft);
            }
            
            Log("Position opened: " + DoubleToString(lots, 2) + 
                " lots @ " + DoubleToString(entry_price, _Digits) +
                " | TP1: " + DoubleToString(draft.tp1_price, _Digits) +
                " | SL+: " + DoubleToString(draft.sl_plus_price, _Digits) +
                " | TP2: " + DoubleToString(draft.tp2_price, _Digits));
        }
    }
    
    // === PHASE 3: POSITION MANAGEMENT ===
    ManagePositions();          // TP Draft → SL+ → TP2 → Trailing
    ManagePendingOrders();      // TP2 LIMIT orders
    ManageMultiTicket();        // Multi-ticket synchronization
    
    // === PHASE 4: MARGIN & RISK MONITORING ===
    MonitorMargin();
    CheckTotalExposure();
    CheckRiskLimits();
}
```

### 13.2 System Interdependency Map

```
SPREAD FILTER
    │
    ├──► LOT SIZING ──► MARGIN CHECK ──► POSITION CAP CHECK
    │         │                │                  │
    │         │                │                  ├──► Single Ticket
    │         │                │                  └──► MULTI-TICKET SPLIT
    │         │                │
    │         │                └──► R:R CALCULATION
    │         │                       │
    │         │                       └──► TP DRAFT CALCULATION
    │         │                               │
    │         └───────────────────────────────┘
    │                                         │
    └─────────────────────────────────────────┘
                                                  │
                                          OPEN POSITION
                                          (Draft TP/SL)
                                                  │
                                                  ▼
                                    TP1 APPROACH → TP1 HIT
                                                  │
                                                  ▼
                                    SL+ SET + TP2 PLACED
                                                  │
                                                  ▼
                                    TP2 HIT → TRAILING SL
```

---

## 14. File Architecture (Proposed — Updated)

```
TradeMachine/
├── Core/
│   ├── TradeMachine.mqh              # Main EA class
│   ├── Config.mqh                    # All parameters (inputs)
│   └── Types.mqh                     # Structs, enums, constants
│
├── Analysis/
│   ├── MarketStructure.mqh           # Trend, CHOCH, Swing Points
│   ├── PatternDetector.mqh           # Flag, Base, Consolidation
│   ├── SupportResistance.mqh         # S/R Engine (Minor/Major)
│   └── MultiTimeframe.mqh            # TF Sync & Data Management
│
├── Execution/
│   ├── OrderManager.mqh              # Order placement, modification
│   ├── PositionManager.mqh           # TP Draft → SL+ → TP2 → Trailing
│   ├── RiskManager.mqh               # 3% sizing, exposure limits
│   ├── PendingOrderManager.mqh       # Limit/Stop order lifecycle
│   ├── RRMANAGER.mqh                 # [NEW] R:R Management
│   ├── MarginManager.mqh             # [NEW] Margin Calculation & Safety
│   ├── LotManager.mqh                # [NEW] Multi-Factor Lot Sizing
│   ├── SpreadFilter.mqh              # [NEW] Spread Monitoring & Filter
│   ├── CapManager.mqh                # [NEW] Position Cap Handling
│   └── TicketSplitter.mqh            # [NEW] Multi-Ticket Splitting
│
├── Utilities/
│   ├── MathUtils.mqh                 # Fast math, statistics
│   ├── TimeUtils.mqh                 # Session, TF conversions
│   └── DebugUtils.mqh                # Logging, visualization
│
├── TradeMachine.mq5                  # Main EA entry point
├── TradeMachine_Tester.mq5           # Strategy Tester version
├── FINANCIAL_REVIEW.md               # Leverage & target analysis
└── Include.mqh                       # Common includes
```

---

## 15. Input Parameters (Config.mqh — Updated)

```cpp
// ============================================================
// R:R MANAGEMENT
// ============================================================
input double RR_BullishTrend = 2.5;       // R:R in bullish trend
input double RR_BearishTrend = 2.5;       // R:R in bearish trend
input double RR_Consolidation = 1.5;      // R:R in consolidation
input double RR_CHOCH = 3.0;              // R:R on CHOCH entry
input double RR_FlagBreakout = 2.0;       // R:R on flag breakout
input double RR_FlagTopSell = 1.5;        // R:R on flag top sell
input double RR_CounterTrend = 1.0;       // R:R counter-trend
input bool UseDynamicRR = true;           // Enable dynamic R:R

// ============================================================
// MARGIN CALCULATION
// ============================================================
input double MarginSafetyPercent = 50.0;  // Max % of free margin used
input double MarginAlertLevel = 200.0;    // Margin level alert threshold
input double MarginCloseLevel = 300.0;    // Emergency close level
input bool UseMarginSafety = true;        // Enable margin safety checks

// ============================================================
// LOT SIZING
// ============================================================
input double MaxRiskPercent = 3.0;        // Max % per trade (risk-based)
input double MaxTotalExposure = 5.0;      // Max % total open risk
input double LotPerDollar = 0.002;        // Lots per $1 balance (1 lot / $500)
input bool UseSpreadAdjustedLots = true;  // Adjust lots for spread cost
input int MaxPositionsPerDirection = 2;   // Max concurrent same-dir
input bool AllowCounterTrend = true;      // Enable consolidation sells

// ============================================================
// TP DRAFT SYSTEM
// ============================================================
input double TP1_RR = 1.5;                // TP1 Risk:Reward
input double TP2_RR = 3.0;                // TP2 Risk:Reward
input double TP3_TrailingMult = 1.5;      // TP3 trailing distance (x risk)
input bool UseStructureTP = true;         // Use S/R for TP override
input double SL_Buffer_Pips = 5;          // SL buffer beyond structure
input double FlagTop_SL_Percent = 3.0;    // Flag sell SL % (3-5%)
input bool UseTPDraft = true;             // Enable draft TP mode (no server TP)

// ============================================================
// SPREAD FILTER (VOL_80 = 72 pts)
// ============================================================
input double SpreadFilter_Max = 80;       // Max spread (points) — skip if > 80
input double Spread_Reduce_Threshold = 60; // Reduce lots above this
input double Spread_Close_Threshold = 150; // Emergency close above this
input double MinTargetPoints = 100;       // Min gross move target (beat spread)
input bool UseSpreadFilter = true;        // Enable spread filtering
input bool UseSessionSpreadFilter = true; // Session-based spread adjustments

// ============================================================
// POSITION CAP HANDLING (100 lots max)
// ============================================================
input bool UsePositionCap = true;         // Enable cap handling
input double CapAlertBalance = 12250;     // Balance at which cap becomes relevant
input bool UseMultiTicketSplitting = true;// Enable multi-ticket splitting
input double SplitPriceOffset = 1.0;      // Price offset between split tickets

// ============================================================
// MULTI-TICKET SPLITTING
// ============================================================
input double MaxLotsPerTicket = 100.0;    // Maximum lots per ticket
input double MinLotsPerTicket = 0.01;     // Minimum lots per ticket
input bool SplitOnCapOnly = true;         // Only split when cap reached
input double TicketRetryDelay = 500;      // Retry delay ms on partial fill

// ============================================================
// CHOCH
// ============================================================
input int SwingLookback = 5;              // Fractal lookback
input double CHOCH_VolumeMult = 1.2;      // Volume confirmation

// ============================================================
// S/R
// ============================================================
input int MajorSwingLookback = 50;        // Bars for major swings
input int MinorSwingLookback = 20;        // Bars for minor swings
input double LevelStrengthThreshold = 3.0;// Min strength to respect

// ============================================================
// PATTERN DETECTION
// ============================================================
input int FlagMinBars = 3;
input int FlagMaxBars = 15;
input double FlagPoleStrength = 0.6;
input int ConsolidationMinBars = 10;
input double ATRContractionMultiplier = 0.5;

// ============================================================
// EXECUTION
// ============================================================
input int MagicNumber = 20260829;         // Magic number for orders
input int MaxSlippage = 50;               // Max slippage (points)
input int OrderTimeout = 5000;            // Order timeout (ms)
```

---

## 16. Development Phases (Updated)

### Phase 1: Foundation (Week 1)
- [ ] Core architecture + Multi-timeframe data sync
- [ ] Swing point detection (ZigZag) per TF
- [ ] Basic trend classification (HH/HL/LL/LH)
- [ ] CHOCH detection per tick (M5)
- [ ] **Spread monitoring module** (real-time spread tracking)
- [ ] **Margin calculation module** (real-time margin tracking)
- [ ] **Types.mqh** — All structs, enums, constants (TPDraft, SpreadState, TicketSplit, etc.)

### Phase 2: Risk & Money Management (Week 2)
- [ ] **R:R Manager** — Dynamic R:R calculation and selection
- [ ] **Margin Manager** — Safety checks, monitoring, alerts
- [ ] **Lot Manager** — Multi-factor lot sizing (risk + spread + margin + cap)
- [ ] **Spread Filter** — Real-time spread filter with session awareness

### Phase 3: Execution & TP Pipeline (Week 3)
- [ ] **TP Draft System** — Full draft → SL+ → TP2 → Trailing pipeline
- [ ] **Order Manager** — Limit/Stop/Market order placement
- [ ] **Position Manager** — Draft TP/SL management
- [ ] **PendingOrderManager** — TP2 LIMIT order lifecycle
- [ ] **Risk Manager** — 3% sizing, exposure limits

### Phase 4: Position Cap & Multi-Ticket (Week 4)
- [ ] **Cap Manager** — Position cap detection and graceful degradation
- [ ] **Ticket Splitter** — Multi-ticket splitting logic
- [ ] **Multi-Ticket Manager** — Synchronized SL/TP/trailing across tickets
- [ ] Partial fill handling and retry logic
- [ ] Aggregate P&L tracking

### Phase 5: Integration & Testing (Week 5-6)
- [ ] Full EA integration
- [ ] Strategy Tester optimization (VOL_80, 72-pt spread adjusted)
- [ ] Forward test on demo (min 2 weeks)
- [ ] Parameter optimization walk-forward
- [ ] **Spread impact testing** (spread widening scenarios)
- [ ] **Multi-ticket stress testing** (partial fills, slippage)
- [ ] **Margin call simulation** (extreme scenarios)

### Phase 6: Production Hardening (Week 7-8)
- [ ] Error handling & recovery
- [ ] Logging & dashboard
- [ ] VPS deployment setup
- [ ] Monitoring alerts

---

## 17. Key Algorithms (Updated)

### Complete Order Pipeline Pseudocode
```
1. OnTick() triggered
2. Update all TF data (M5, M15, M30, H1, H4)
3. Detect CHOCH on M5 (per tick)
4. Update S/R levels (dynamic)
5. Scan patterns on M5
6. Update spread state
7. SPREAD FILTER: if spread > 80 pts → skip entry, manage existing only
8. Evaluate entry conditions
9. If entry signal found:
   a. Calculate lot size (risk-based + spread-adjusted + margin-capped)
   b. Check margin availability
   c. Calculate dynamic R:R
   d. Calculate TP Draft (TP1, TP2, TP3, SL+)
   e. Check position cap:
      - If lots < 100: single ticket, open with DRAFT TP/SL
      - If lots >= 100: split into N tickets, each ≤ 100 lots
10. Manage all open positions:
    a. Monitor TP1 draft (price tick level)
    b. TP1 hit → set SL+ on server + place TP2 LIMIT
    c. TP2 hit → activate trailing SL
    d. Multi-ticket sync: all tickets move together
11. Monitor margin level → alert if < 200%, close if < 300%
12. Check total exposure → ensure < 5% of balance
```

### TP Draft State Machine
```cpp
enum TP_STATE {
    TP_STATE_DRAFT,         // Position open, TP/SL tracked internally only
    TP_STATE_TP1_APPROACH,  // Price approaching TP1
    TP_STATE_TP1_HIT,       // TP1 reached, SL+ set, TP2 placed
    TP_STATE_TP2_HIT,       // TP2 reached, trailing activated
    TP_STATE_TRAILING,      // Trailing SL active
    TP_STATE_CLOSED         // Position closed
};
```

### Multi-Ticket Synchronization
```cpp
void SyncMultiTicketState(int[] tickets, TP_STATE state) {
    for (int i = 0; i < ArraySize(tickets); i++) {
        if (PositionSelectByTicket(tickets[i])) {
            switch (state) {
                case TP_STATE_TP1_HIT:
                    ModifyPositionSL(tickets[i], sl_plus_price);
                    // TP2 already placed as LIMIT order
                    break;
                case TP_STATE_TP2_HIT:
                    ActivateTrailingSL(tickets[i], trailing_dist);
                    break;
                case TP_STATE_TRAILING:
                    UpdateTrailingSL(tickets[i], trailing_dist);
                    break;
            }
        }
    }
}
```

### Spread Filter State Machine
```cpp
enum SPREAD_STATE {
    SPREAD_NORMAL,          // < 60 pts — trade freely
    SPREAD_ELEVATED,        // 60-80 pts — reduce lot size 25%
    SPREAD_WIDE,            // 80-100 pts — skip new trades
    SPREAD_VERY_WIDE,       // 100-150 pts — close existing, no new
    SPREAD_CRITICAL         // > 150 pts — emergency close all
};
```

---

## 18. Testing & Validation Checklist (Updated)

### Backtest Requirements
- [ ] Minimum 2 years VOL_80 data (M5 + higher TFs)
- [ ] Walk-forward: 70% train / 30% test, rolling 6-month windows
- [ ] Metrics: PF > 1.5, DD < 15%, Win Rate > 45%, Expectancy > 0.5R
- [ ] Monte Carlo: 1000 runs, 95% confidence profitable
- [ ] **Spread stress test**: Test with 72pt, 100pt, 150pt spread scenarios
- [ ] **Margin stress test**: Test with 1:50, 1:100, 1:500, 1:2000 leverage
- [ ] **Position cap test**: Verify multi-ticket splitting at 100+ lots
- [ ] **Partial fill test**: Simulate some tickets being rejected

### Forward Test (Demo)
- [ ] 4 weeks minimum
- [ ] Track: Slippage, Spread impact, Execution latency
- [ ] Track: Spread behavior per session
- [ ] Track: Margin level fluctuations
- [ ] Track: Multi-ticket P&L synchronization
- [ ] Compare: Backtest vs Forward (degradation < 20%)

### Stress Tests
- [ ] Spread widening to 150+ pts (emergency close)
- [ ] Position cap triggered (100 lots) → multi-ticket behavior
- [ ] Margin call scenarios (leverage, balance drops)
- [ ] Partial fills (some tickets rejected)
- [ ] Connection loss recovery (all ticket state preservation)
- [ ] High volatility spikes (VOL_80 expansion)

---

## 19. Monitoring & Alerts (Updated)

### Real-time Dashboard (Chart Objects)
- Current Trend (All TFs)
- Active Patterns
- S/R Levels (visual)
- Open Positions + Virtual TP/SL
- Daily P&L / Risk Used
- **Spread: current / average / status**
- **Margin Level / Free Margin / Used Margin**
- **Lot Size: current / cap status**
- **Position Cap: active / tickets split**
- **Multi-Ticket: ticket count / sync status**

### Alerts (Push/Email)
- CHOCH detected
- Pattern completed (Flag/Base)
- TP1 hit → SL+ activated
- TP2 hit
- SL hit
- Risk limit approached (> 2.5%)
- Spread > threshold (elevated/wide/critical)
- Margin level < 200% / < 300% (emergency)
- Position cap reached → multi-ticket activated
- Ticket split executed / partial fill detected

---

## 20. Notes for VOL_80 Specifics

- **No news impact** — Pure technical, 24/7 market
- **Mean-reverting tendencies** — Use for counter-trend in consolidation
- **Volatility cycles** — ATR-based filters essential
- **Tick volume** — Use as proxy (real volume unavailable)
- **Spread** = dynamic (56-82 pts live), baseline ~72 pts ($72/lot) — MASSIVE, requires 100+ pt targets ⚠️
- **Contract Size** = 1.0, **Point Value** = $1.00/point/lot
- **Max lots per ticket** = 100.0 → position cap at ~$12,250 balance (1:2000 lev)
- **Digits** = 0 (integer pricing)
- **Current price** ≈ 245,000
- **Leverage requirement**: 1:2000 RECOMMENDED (1:50 CANNOT open any position)
- **Spread filter**: Must skip trades when spread > 80 points
- **Margin**: Must check before every order — 1:2000 lev, $10 balance = $1.23 margin per 0.01 lot

---

## 21. Next Steps

### IMMEDIATE (Before Coding):
1. **Set leverage to 1:2000** — 1:50 is IMPOSSIBLE (cannot open minimum 0.01 lot on $10 balance)
2. **Review FINANCIAL_REVIEW.md** for full leverage analysis and target realism
3. **Code `Types.mqh`** first — all structs (TPDraft, SpreadState, TicketSplit, etc.)
4. **Code `Config.mqh`** — all input parameters

### Phase 1: Foundation (Week 1)
- [ ] Core architecture + Multi-timeframe data sync
- [ ] Swing point detection (ZigZag) per TF
- [ ] Basic trend classification (HH/HL/LL/LH)
- [ ] CHOCH detection per tick (M5)
- [ ] **Spread monitoring module** (real-time spread tracking)
- [ ] **Margin tracking module**
- [ ] **Types.mqh** + **Config.mqh**

### Phase 2: Risk & Money Management (Week 2)
- [ ] **R:R Manager** (dynamic R:R calculation)
- [ ] **Margin Manager** (safety checks, alerts)
- [ ] **Lot Manager** (multi-factor lot sizing)
- [ ] **Spread Filter** (real-time filter + session awareness)

### Phase 3: Execution & TP Pipeline (Week 3)
- [ ] **TP Draft System** (full draft → SL+ → TP2 → Trailing pipeline)
- [ ] Order Manager (Limit/Stop/Market)
- [ ] Position Manager
- [ ] PendingOrderManager

### Phase 4: Position Cap & Multi-Ticket (Week 4)
- [ ] **Cap Manager** (position cap detection)
- [ ] **Ticket Splitter** (multi-ticket splitting)
- [ ] **Multi-Ticket Manager** (synchronized management)
- [ ] Partial fill handling

### Phase 5: Integration & Testing (Week 5-6)
- [ ] Full EA integration
- [ ] Strategy Tester optimization (VOL_80, 72-pt spread adjusted)
- [ ] Forward test on demo (min 2 weeks)
- [ ] Parameter optimization walk-forward
- [ ] Spread impact testing, margin stress tests, multi-ticket stress tests

### Phase 6: Production Hardening (Week 7-8)
- [ ] Error handling & recovery
- [ ] Logging & dashboard
- [ ] VPS deployment setup
- [ ] Monitoring alerts

### Target Revision:
- **Original**: $40M in 2 days
- **Revised realistic target**: $100K–$1M in 2 days with 1:2000 leverage
- **$40M timeline**: 3-5 days (position cap limits exponential growth after ~$12K)
- **Key constraint**: 72-pt spread + 100-lot position cap + margin requirements

---

*Document Version: 3.0 | Author: TradeMachine Planning | Date: 2026*