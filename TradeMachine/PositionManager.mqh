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
    
    // --- PHASE 1: REACHED +200 PTS PROFIT -> LOCK RISK-FREE SL+ (+50 PTS) ---
    if(!mp.draft.sl_plus_active) {
        bool lock_reached = (mp.type == POSITION_TYPE_BUY) ? 
                            (bid >= mp.entry_price + Inp_LockProfit_Pts) : 
                            (ask <= mp.entry_price - Inp_LockProfit_Pts);
        if(lock_reached) {
            double slplus = (mp.type == POSITION_TYPE_BUY) ? 
                            (mp.entry_price + Inp_LockedProfit_Value) : 
                            (mp.entry_price - Inp_LockedProfit_Value);
            if(ModifyPositionSL(mp.ticket, slplus)) {
                mp.draft.sl_plus_active = true;
                mp.sl_price = slplus;
                Print("SL+ LOCKED: Ticket ", mp.ticket, " Risk is ZERO! Locked @ ", DoubleToString(slplus, 0));
            }
        }
    }
    
    // --- PHASE 2: WAVE RIDER TRAILING STOP (350 PTS) ---
    if(mp.draft.sl_plus_active) {
        double trail_dist = Inp_TrailingDist_Pts;
        if(mp.type == POSITION_TYPE_BUY) {
            double candidate_sl = bid - trail_dist;
            if(candidate_sl > mp.sl_price + 30.0) {
                if(ModifyPositionSL(mp.ticket, candidate_sl)) {
                    mp.sl_price = candidate_sl;
                }
            }
        } else {
            double candidate_sl = ask + trail_dist;
            if(candidate_sl < mp.sl_price - 30.0) {
                if(ModifyPositionSL(mp.ticket, candidate_sl)) {
                    mp.sl_price = candidate_sl;
                }
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
