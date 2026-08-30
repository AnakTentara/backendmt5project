//+------------------------------------------------------------------+
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
