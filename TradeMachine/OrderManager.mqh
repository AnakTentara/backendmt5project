//+------------------------------------------------------------------+
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
