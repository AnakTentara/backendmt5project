//+------------------------------------------------------------------+
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
