//+------------------------------------------------------------------+
//|                                         OrderManager.mqh         |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "4.00"
#include <Trade\Trade.mqh>
#include "Types.mqh"
#include "Config.mqh"
#include "RiskManager.mqh"

CTrade g_trade;

void OrderManager_Init() {
    g_trade.SetExpertMagicNumber(Inp_MagicNumber);
    g_trade.SetDeviationInPoints(Inp_MaxSlippage);
    long fm = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((fm & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    else if((fm & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) g_trade.SetTypeFilling(ORDER_FILLING_IOC);
    else g_trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

ulong ResolvePositionTicket(ulong order_ticket) {
    if(PositionSelectByTicket(order_ticket)) {
        if(PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber) return order_ticket;
    }
    if(HistorySelect(TimeCurrent() - 300, TimeCurrent() + 60)) {
        int n = HistoryDealsTotal();
        for(int i = n - 1; i >= 0; i--) {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0) continue;
            if((ulong)HistoryDealGetInteger(d, DEAL_ORDER) != order_ticket) continue;
            ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
            if(pid != 0 && PositionSelectByTicket(pid)) return pid;
        }
    }
    return 0;
}

ulong OpenPositionDraftMode(double price, double lots, TPDraft &draft,
                            int split_id = -1, int split_index = 0, int total_splits = 1) {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    ENUM_ORDER_TYPE order_type = (draft.tp1_price > price) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double exec_price = (order_type == ORDER_TYPE_BUY) ? ask : bid;
    double sl_norm = NormalizeDouble(draft.sl_plus_price, 0);
    
    // In Market Execution brokers, initial order MUST have sl=0, tp=0 to prevent error 10016
    bool ok = false;
    if(order_type == ORDER_TYPE_BUY) {
        ok = g_trade.Buy(lots, _Symbol, exec_price, 0.0, 0.0, "TM_Buy");
    } else {
        ok = g_trade.Sell(lots, _Symbol, exec_price, 0.0, 0.0, "TM_Sell");
    }
    
    if(!ok) {
        Print("ORDER SEND ERROR: ", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
        return 0;
    }
    
    ulong ticket = ResolvePositionTicket(g_trade.ResultOrder());
    if(ticket == 0) ticket = g_trade.ResultDeal();
    if(ticket == 0) {
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong pt = PositionGetTicket(i);
            if(pt > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber) {
                ticket = pt;
                break;
            }
        }
    }
    
    // Attach Hard Server Stop Loss via PositionModify
    if(ticket > 0 && sl_norm > 0) {
        if(g_trade.PositionModify(ticket, sl_norm, 0.0)) {
            Print("ORDER EXECUTED & SL ATTACHED: Ticket ", ticket, " | Lots: ", DoubleToString(lots, 2), " @ ", DoubleToString(exec_price, 0), " SL=", DoubleToString(sl_norm, 0));
        } else {
            Print("ORDER EXECUTED: Ticket ", ticket, " (SL modify note: ", g_trade.ResultRetcode(), ")");
        }
    }
    
    return ticket;
}

bool ModifyPositionSL(ulong ticket, double new_sl) {
    return g_trade.PositionModify(ticket, NormalizeDouble(new_sl, 0), 0.0);
}

bool ClosePositionDirect(ulong ticket) {
    return g_trade.PositionClose(ticket);
}

void ManagePendingOrders() {}
