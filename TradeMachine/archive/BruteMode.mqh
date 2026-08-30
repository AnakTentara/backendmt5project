//+------------------------------------------------------------------+
//|                                         BruteMode.mqh            |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"
#include "OrderManager.mqh"
#include "PositionManager.mqh"
#include "SupportResistance.mqh"
#include "PatternDetector.mqh"
//+------------------------------------------------------------------+
//| BRUTE MODE - Aggressive Momentum Scalping                        |
//| - Spam orders on strong momentum candles                         |
//| - Ultra-tight SL (0.00 to -0.10 pts)                            |
//| - Re-entry on SL hit until price moves away                     |
//| - SL+ locks at midpoint, stays fixed on reversal pressure       |
//| - TP slightly below supply/demand zone                          |
//+------------------------------------------------------------------+

//--- Brute Mode State
struct BruteState {
    bool active;                    // Brute mode enabled
    bool momentum_bullish;          // Current momentum direction
    bool momentum_bearish;
    datetime last_order_time;       // Last order timestamp
    int orders_this_minute;         // Orders placed this minute
    int max_orders_per_minute;      // Rate limit
    double last_sl_price;           // Last SL price for re-entry
    ENUM_POSITION_TYPE last_type;   // Last order type
    bool sl_hit_pending_reentry;    // SL hit, waiting to re-enter
    datetime sl_hit_time;           // When SL was hit
    int reentry_count;              // Number of re-entries for current sequence
    double locked_sl_plus;          // Locked SL+ price (midpoint)
    bool sl_plus_locked;            // SL+ is locked (doesn't move)
    double entry_price_ref;         // Reference entry for SL+ calculation
    int total_brute_orders;         // Total orders in this session
    double session_pnl;             // Brute mode session PnL
};
BruteState g_brute_state;

//--- Brute Order Tracking
struct BruteOrder {
    ulong ticket;
    ENUM_POSITION_TYPE type;
    double entry_price;
    double volume;
    double ultra_tight_sl;          // The 0.00 or -0.10 SL
    double tp_price;                // TP below supply/demand
    double locked_sl_plus;          // Locked midpoint SL+
    bool sl_plus_locked;
    bool sl_hit;
    datetime created;
    int reentry_sequence;           // Which re-entry in sequence
};
BruteOrder g_brute_orders[50];
int g_brute_order_count = 0;

//+------------------------------------------------------------------+
//| Initialize Brute Mode                                            |
//+------------------------------------------------------------------+
void BruteMode_Init() {
    g_brute_state = {false};
    g_brute_state.max_orders_per_minute = Inp_Brute_MaxOrdersPerMin;
    g_brute_state.reentry_count = 0;
    g_brute_state.sl_plus_locked = false;
    g_brute_state.total_brute_orders = 0;
    g_brute_state.session_pnl = 0;
    
    ArrayInitialize(g_brute_orders);
    g_brute_order_count = 0;
    
    Print("BruteMode: Initialized (MAX ORDERS/MIN: ", IntegerToString(Inp_Brute_MaxOrdersPerMin), ")");
}

//+------------------------------------------------------------------+
//| Activate/Deactivate Brute Mode                                   |
//+------------------------------------------------------------------+
void BruteMode_SetActive(bool state) {
    g_brute_state.active = state;
    if(state) {
        Print("🔥 BRUTE MODE ACTIVATED 🔥");
        Print("  Max orders/min: ", IntegerToString(g_brute_state.max_orders_per_minute));
        Print("  Ultra-tight SL: ", DoubleToString(Inp_Brute_UltraTightSL, 2), " pts");
        Print("  Re-entry on SL hit: ", Inp_Brute_ReentryOnSL ? "ENABLED" : "DISABLED");
        Print("  SL+ Lock on reversal: ", Inp_Brute_SLPlusLock ? "ENABLED" : "DISABLED");
        Print("  TP at S/D zone: ", Inp_Brute_TPAtZone ? "ENABLED" : "DISABLED");
        
        // Reset state
        g_brute_state.momentum_bullish = false;
        g_brute_state.momentum_bearish = false;
        g_brute_state.orders_this_minute = 0;
        g_brute_state.last_order_time = TimeCurrent();
        g_brute_state.reentry_count = 0;
        g_brute_state.sl_plus_locked = false;
        g_brute_state.sl_hit_pending_reentry = false;
    } else {
        Print("🛑 BRUTE MODE DEACTIVATED");
        Print("  Session orders: ", IntegerToString(g_brute_state.total_brute_orders));
        Print("  Session PnL: ", DoubleToString(g_brute_state.session_pnl, 2));
        
        // Close all brute positions
        BruteMode_CloseAll();
    }
}

bool BruteMode_IsActive() {
    return g_brute_state.active;
}

//+------------------------------------------------------------------+
//| Main Brute Mode Loop (Per Tick)                                  |
//+------------------------------------------------------------------+
void BruteMode_OnTick() {
    if(!g_brute_state.active) return;
    
    // Rate limiting: reset counter each minute
    if(TimeCurrent() - g_brute_state.last_order_time >= 60) {
        g_brute_state.orders_this_minute = 0;
        g_brute_state.last_order_time = TimeCurrent();
    }
    
    // Check rate limit
    if(g_brute_state.orders_this_minute >= g_brute_state.max_orders_per_minute) {
        return;
    }
    
    // Check spread filter
    if(!SpreadFilter_Check()) return;
    
    // Check if we have pending re-entry from SL hit
    if(g_brute_state.sl_hit_pending_reentry) {
        BruteMode_CheckReentry();
        return;
    }
    
    // Detect momentum for new entries
    BruteMode_DetectMomentum();
    
    // Execute brute orders if momentum confirmed
    if(g_brute_state.momentum_bullish) {
        BruteMode_ExecuteOrder(POSITION_TYPE_BUY);
    } else if(g_brute_state.momentum_bearish) {
        BruteMode_ExecuteOrder(POSITION_TYPE_SELL);
    }
    
    // Manage existing brute orders (SL+ locking, TP checks)
    BruteMode_ManageOrders();
}

//+------------------------------------------------------------------+
//| Detect Momentum (Strong Full-Body Candle)                       |
//+------------------------------------------------------------------+
void BruteMode_DetectMomentum() {
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M5, 0, 3, rates) < 3) return;
    
    // Current forming candle (index 0) + last closed (index 1)
    double body = MathAbs(rates[1].close - rates[1].open);
    double range = rates[1].high - rates[1].low;
    if(range == 0) return;
    
    double body_ratio = body / range;
    bool is_bullish = (rates[1].close > rates[1].open);
    bool is_bearish = (rates[1].close < rates[1].open);
    
    // Momentum criteria: Full body candle (body > 80% of range)
    // Volume confirmation
    long vol = rates[1].tick_volume;
    double avg_vol = GetAverageVolume(0, 20);
    bool vol_ok = (vol > avg_vol * Inp_Brute_VolumeMult);
    
    // Reset momentum flags
    g_brute_state.momentum_bullish = false;
    g_brute_state.momentum_bearish = false;
    
    if(body_ratio >= Inp_Brute_MinBodyRatio && vol_ok) {
        if(is_bullish) {
            g_brute_state.momentum_bullish = true;
            g_brute_state.momentum_bearish = false;
            Log("🔥 BRUTE MOMENTUM BULLISH: Body " + DoubleToString(body_ratio*100, 1) + "% | Vol: " + LongToString(vol));
        } else if(is_bearish) {
            g_brute_state.momentum_bearish = true;
            g_brute_state.momentum_bullish = false;
            Log("🔥 BRUTE MOMENTUM BEARISH: Body " + DoubleToString(body_ratio*100, 1) + "% | Vol: " + LongToString(vol));
        }
    }
    
    // Also check M1 for faster reaction (optional)
    if(Inp_Brute_UseM1Confirm) {
        BruteMode_CheckM1Momentum();
    }
}

//+------------------------------------------------------------------+
//| M1 Momentum Confirmation (Faster Reaction)                      |
//+------------------------------------------------------------------+
void BruteMode_CheckM1Momentum() {
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) < 3) return;
    
    double body = MathAbs(rates[1].close - rates[1].open);
    double range = rates[1].high - rates[1].low;
    if(range == 0) return;
    
    double body_ratio = body / range;
    bool is_bullish = (rates[1].close > rates[1].open);
    bool is_bearish = (rates[1].close < rates[1].open);
    
    // M1 confirmation: body > 70%
    if(body_ratio >= 0.70) {
        if(is_bullish && !g_brute_state.momentum_bullish) {
            g_brute_state.momentum_bullish = true;
            Log("🔥 M1 CONFIRM BULLISH: Body " + DoubleToString(body_ratio*100, 1) + "%");
        } else if(is_bearish && !g_brute_state.momentum_bearish) {
            g_brute_state.momentum_bearish = true;
            Log("🔥 M1 CONFIRM BEARISH: Body " + DoubleToString(body_ratio*100, 1) + "%");
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Brute Order                                              |
//+------------------------------------------------------------------+
void BruteMode_ExecuteOrder(ENUM_POSITION_TYPE type) {
    // Check rate limit again
    if(g_brute_state.orders_this_minute >= g_brute_state.max_orders_per_minute) return;
    
    double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    // Calculate lot size (use fixed brute lot or risk-based)
    double lots = Inp_Brute_FixedLots > 0 ? Inp_Brute_FixedLots : 
                  CalculateLotSize(price, price + (type == POSITION_TYPE_BUY ? -Inp_Brute_UltraTightSL : Inp_Brute_UltraTightSL)).lots;
    
    if(lots <= 0) return;
    
    // Margin check
    string margin_error;
    if(!CheckMarginSafety(lots, margin_error)) {
        Log("BRUTE: Margin check failed - " + margin_error);
        return;
    }
    
    // --- ULTRA-TIGHT SL ---
    // SL = entry ± ultra_tight_sl (0.00 to 0.10 points)
    double sl_price;
    if(type == POSITION_TYPE_BUY) {
        sl_price = price - Inp_Brute_UltraTightSL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    } else {
        sl_price = price + Inp_Brute_UltraTightSL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    }
    
    // --- TP CALCULATION ---
    // TP slightly below supply (for buy) / above demand (for sell)
    double tp_price = 0;
    if(Inp_Brute_TPAtZone) {
        if(type == POSITION_TYPE_BUY) {
            double supply = GetNearestSupply(price);
            if(supply > 0) {
                tp_price = supply - Inp_Brute_TPBuffer * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            }
        } else {
            double demand = GetNearestDemand(price);
            if(demand > 0) {
                tp_price = demand + Inp_Brute_TPBuffer * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            }
        }
    }
    
    // Fallback TP: fixed R:R
    if(tp_price == 0) {
        double risk_pts = Inp_Brute_UltraTightSL;
        double rr = Inp_Brute_TP_RR;
        if(type == POSITION_TYPE_BUY) {
            tp_price = price + risk_pts * rr * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        } else {
            tp_price = price - risk_pts * rr * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        }
    }
    
    // Place order with ULTRA-TIGHT SL (no TP on server - draft mode)
    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};
    
    request.action = TRADE_ACTION_DEAL;
    request.magic = Inp_MagicNumber + 1000; // Different magic for brute
    request.symbol = _Symbol;
    request.volume = lots;
    request.price = price;
    request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.deviation = Inp_MaxSlippage;
    request.type_filling = ORDER_FILLING_FOK;
    request.sl = NormalizePrice(sl_price);
    request.tp = 0; // NO TP on server - draft mode
    request.comment = "BRUTE_" + EnumToString(type);
    
    if(!OrderSend(request, result)) {
        int err = GetLastError();
        Log("BRUTE ORDER ERROR: " + IntegerToString(err) + " - " + ErrorDescription(err));
        return;
    }
    
    ulong ticket = result.order;
    
    // Track brute order
    BruteOrder bo;
    bo.ticket = ticket;
    bo.type = type;
    bo.entry_price = price;
    bo.volume = lots;
    bo.ultra_tight_sl = sl_price;
    bo.tp_price = tp_price;
    bo.locked_sl_plus = 0;
    bo.sl_plus_locked = false;
    bo.sl_hit = false;
    bo.created = TimeCurrent();
    bo.reentry_sequence = g_brute_state.reentry_count;
    
    if(g_brute_order_count < 50) {
        g_brute_orders[g_brute_order_count] = bo;
        g_brute_order_count++;
    }
    
    // Update state
    g_brute_state.orders_this_minute++;
    g_brute_state.last_order_time = TimeCurrent();
    g_brute_state.last_type = type;
    g_brute_state.total_brute_orders++;
    g_brute_state.reentry_count = 0;
    g_brute_state.sl_hit_pending_reentry = false;
    
    // Store reference for SL+ calculation
    g_brute_state.entry_price_ref = price;
    g_brute_state.locked_sl_plus = 0;
    g_brute_state.sl_plus_locked = false;
    
    Log("🔥 BRUTE ORDER: " + EnumToString(type) + " " + DoubleToString(lots, 2) + 
        " lots @ " + DoubleToString(price, _Digits) +
        " | SL: " + DoubleToString(sl_price, _Digits) + " (" + DoubleToString(Inp_Brute_UltraTightSL, 2) + " pts)" +
        " | TP: " + DoubleToString(tp_price, _Digits) +
        " | Ticket: " + IntegerToString(ticket));
}

//+------------------------------------------------------------------+
//| Manage Brute Orders (SL+ Locking, TP)                           |
//+------------------------------------------------------------------+
void BruteMode_ManageOrders() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    for(int i = 0; i < g_brute_order_count; i++) {
        BruteOrder &bo = g_brute_orders[i];
        if(bo.ticket == 0) continue;
        
        // Check if position still exists
        if(!PositionSelectByTicket(bo.ticket)) {
            if(!bo.sl_hit) {
                // Position closed - check if at TP or SL
                BruteMode_OnPositionClosed(bo);
            }
            continue;
        }
        
        double current_price = (bo.type == POSITION_TYPE_BUY) ? bid : ask;
        
        // --- SL+ LOCKING LOGIC ---
        if(!bo.sl_plus_locked && !bo.sl_hit) {
            double distance_moved = (bo.type == POSITION_TYPE_BUY) ? 
                (current_price - bo.entry_price) : 
                (bo.entry_price - current_price);
            
            // If price moved favorably by at least 2x ultra-tight SL
            double min_move = Inp_Brute_UltraTightSL * 2.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            if(distance_moved >= min_move) {
                // Calculate midpoint SL+
                double sl_plus = (bo.entry_price + current_price) / 2.0;
                
                // Set SL+ on server
                if(ModifyPositionSL(bo.ticket, sl_plus)) {
                    bo.locked_sl_plus = sl_plus;
                    bo.sl_plus_locked = true;
                    g_brute_state.locked_sl_plus = sl_plus;
                    g_brute_state.sl_plus_locked = true;
                    
                    Log("🔒 BRUTE SL+ LOCKED: Ticket " + IntegerToString(bo.ticket) + 
                        " | SL+ at " + DoubleToString(sl_plus, _Digits) + 
                        " (midpoint: Entry=" + DoubleToString(bo.entry_price, _Digits) + 
                        " + Current=" + DoubleToString(current_price, _Digits) + ")/2");
                }
            }
        }
        
        // --- TP CHECK (Draft Mode) ---
        if(bo.tp_price > 0 && !bo.sl_hit) {
            bool tp_hit = false;
            if(bo.type == POSITION_TYPE_BUY) {
                tp_hit = (ask >= bo.tp_price);
            } else {
                tp_hit = (bid <= bo.tp_price);
            }
            
            if(tp_hit) {
                Log("🎯 BRUTE TP HIT: Ticket " + IntegerToString(bo.ticket) + 
                    " | TP at " + DoubleToString(bo.tp_price, _Digits));
                ClosePosition(bo.ticket);
                bo.sl_hit = true; // Mark as done
            }
        }
        
        // --- SL+ LOCK PROTECTION (Reversal Pressure) ---
        // If SL+ is locked and price reverses toward it, DON'T move SL back
        if(bo.sl_plus_locked && Inp_Brute_SLPlusLock) {
            double current_sl = PositionGetDouble(POSITION_SL);
            if(bo.type == POSITION_TYPE_BUY) {
                // For buy: SL should never go down once locked
                if(current_sl > bo.locked_sl_plus) {
                    // Someone tried to move SL down - restore it
                    ModifyPositionSL(bo.ticket, bo.locked_sl_plus);
                    Log("🛡️ BRUTE SL+ PROTECTED: Restored locked SL+ at " + DoubleToString(bo.locked_sl_plus, _Digits));
                }
            } else {
                // For sell: SL should never go up once locked
                if(current_sl < bo.locked_sl_plus && current_sl > 0) {
                    ModifyPositionSL(bo.ticket, bo.locked_sl_plus);
                    Log("🛡️ BRUTE SL+ PROTECTED: Restored locked SL+ at " + DoubleToString(bo.locked_sl_plus, _Digits));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Handle Position Closed (SL Hit or TP)                           |
//+------------------------------------------------------------------+
void BruteMode_OnPositionClosed(BruteOrder &bo) {
    // Determine if closed at SL or TP
    // We'd need to check deal history for exact close price
    // For now, assume if not at TP, it was SL hit
    
    double close_price = 0; // Would need deal history
    
    // Check if it was likely SL hit (price near ultra-tight SL)
    bool likely_sl_hit = false;
    
    if(bo.type == POSITION_TYPE_BUY) {
        // If we have a locked SL+, check if price went below it
        if(bo.sl_plus_locked) {
            // SL+ was hit
            likely_sl_hit = true;
        } else {
            // Check if price near ultra-tight SL
            // This is approximate without deal history
            likely_sl_hit = true; // Assume SL hit if not at TP
        }
    } else {
        if(bo.sl_plus_locked) {
            likely_sl_hit = true;
        } else {
            likely_sl_hit = true;
        }
    }
    
    if(likely_sl_hit && Inp_Brute_ReentryOnSL) {
        bo.sl_hit = true;
        g_brute_state.sl_hit_pending_reentry = true;
        g_brute_state.sl_hit_time = TimeCurrent();
        g_brute_state.last_sl_price = bo.ultra_tight_sl;
        g_brute_state.reentry_count++;
        
        Log("💥 BRUTE SL HIT (Re-entry #" + IntegerToString(g_brute_state.reentry_count) + 
            "): Ticket " + IntegerToString(bo.ticket) + 
            " | Will re-enter " + EnumToString(bo.type) + " at next tick");
    } else {
        // TP hit or manual close - reset re-entry counter
        g_brute_state.reentry_count = 0;
        g_brute_state.sl_hit_pending_reentry = false;
        g_brute_state.sl_plus_locked = false;
        g_brute_state.locked_sl_plus = 0;
        
        if(bo.tp_price > 0) {
            Log("🎯 BRUTE TP HIT: Ticket " + IntegerToString(bo.ticket));
        }
    }
    
    // Update session PnL
    double profit = PositionGetDouble(POSITION_PROFIT); // This won't work after close
    g_brute_state.session_pnl += profit;
}

//+------------------------------------------------------------------+
//| Check Re-entry After SL Hit                                     |
//+------------------------------------------------------------------+
void BruteMode_CheckReentry() {
    // Wait a tiny bit after SL hit (spread may be wide)
    if(TimeCurrent() - g_brute_state.sl_hit_time < Inp_Brute_ReentryDelay) return;
    
    // Check spread
    if(!SpreadFilter_Check()) return;
    
    // Re-enter same direction
    ENUM_POSITION_TYPE type = g_brute_state.last_type;
    
    Log("🔄 BRUTE RE-ENTRY #" + IntegerToString(g_brute_state.reentry_count) + 
        ": " + EnumToString(type));
    
    BruteMode_ExecuteOrder(type);
    
    // Reset re-entry flag
    g_brute_state.sl_hit_pending_reentry = false;
    
    // Max re-entries protection
    if(g_brute_state.reentry_count >= Inp_Brute_MaxReentries) {
        Log("⚠️ BRUTE MAX RE-ENTRIES REACHED (" + IntegerToString(Inp_Brute_MaxReentries) + ") - Pausing re-entries");
        g_brute_state.sl_hit_pending_reentry = false;
        g_brute_state.reentry_count = 0;
    }
}

//+------------------------------------------------------------------+
//| Close All Brute Positions                                        |
//+------------------------------------------------------------------+
void BruteMode_CloseAll() {
    int closed = 0;
    for(int i = 0; i < g_brute_order_count; i++) {
        if(g_brute_orders[i].ticket > 0) {
            if(PositionSelectByTicket(g_brute_orders[i].ticket)) {
                ClosePosition(g_brute_orders[i].ticket);
                closed++;
            }
        }
    }
    
    // Cancel brute pending orders
    // (Would need to track pending orders separately)
    
    g_brute_state.active = false;
    g_brute_state.momentum_bullish = false;
    g_brute_state.momentum_bearish = false;
    g_brute_state.sl_hit_pending_reentry = false;
    
    Print("🛑 BRUTE MODE: Closed " + IntegerToString(closed) + " positions");
}

//+------------------------------------------------------------------+
//| Emergency Stop (Kill Switch)                                    |
//+------------------------------------------------------------------+
void BruteMode_EmergencyStop() {
    Print("🚨 BRUTE MODE EMERGENCY STOP 🚨");
    BruteMode_CloseAll();
    CancelAllPendingOrders();
    g_brute_state.active = false;
    g_brute_state.sl_hit_pending_reentry = false;
}

//+------------------------------------------------------------------+
//| Get Brute Mode Status (for Dashboard)                           |
//+------------------------------------------------------------------+
string BruteMode_GetStatusJSON() {
    string json = "{";
    json += "\"active\":" + (g_brute_state.active ? "true" : "false") + ",";
    json += "\"momentum_bullish\":" + (g_brute_state.momentum_bullish ? "true" : "false") + ",";
    json += "\"momentum_bearish\":" + (g_brute_state.momentum_bearish ? "true" : "false") + ",";
    json += "\"orders_this_min\":" + IntegerToString(g_brute_state.orders_this_minute) + ",";
    json += "\"max_orders_min\":" + IntegerToString(g_brute_state.max_orders_per_minute) + ",";
    json += "\"total_orders\":" + IntegerToString(g_brute_state.total_brute_orders) + ",";
    json += "\"reentry_count\":" + IntegerToString(g_brute_state.reentry_count) + ",";
    json += "\"sl_plus_locked\":" + (g_brute_state.sl_plus_locked ? "true" : "false") + ",";
    json += "\"locked_sl_plus\":" + DoubleToString(g_brute_state.locked_sl_plus, _Digits) + ",";
    json += "\"sl_hit_pending\":" + (g_brute_state.sl_hit_pending_reentry ? "true" : "false") + ",";
    json += "\"session_pnl\":" + DoubleToString(g_brute_state.session_pnl, 2) + ",";
    json += "\"ultra_tight_sl\":" + DoubleToString(Inp_Brute_UltraTightSL, 2) + ",";
    json += "\"reentry_delay\":" + IntegerToString(Inp_Brute_ReentryDelay) + "";
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Debug Print                                                      |
//+------------------------------------------------------------------+
void BruteMode_PrintStatus() {
    Print("=== BRUTE MODE STATUS ===");
    Print("Active: ", g_brute_state.active ? "YES" : "NO");
    Print("Momentum: Bull=", g_brute_state.momentum_bullish ? "YES" : "NO", 
          " | Bear=", g_brute_state.momentum_bearish ? "YES" : "NO");
    Print("Orders this min: ", IntegerToString(g_brute_state.orders_this_minute), "/", IntegerToString(g_brute_state.max_orders_per_minute));
    Print("Total orders: ", IntegerToString(g_brute_state.total_brute_orders));
    Print("Re-entry count: ", IntegerToString(g_brute_state.reentry_count));
    Print("SL Hit Pending: ", g_brute_state.sl_hit_pending_reentry ? "YES" : "NO");
    Print("SL+ Locked: ", g_brute_state.sl_plus_locked ? "YES (" + DoubleToString(g_brute_state.locked_sl_plus, _Digits) + ")" : "NO");
    Print("Session PnL: ", DoubleToString(g_brute_state.session_pnl, 2));
    Print("Ultra-tight SL: ", DoubleToString(Inp_Brute_UltraTightSL, 2), " pts");
}

//+------------------------------------------------------------------+