//+------------------------------------------------------------------+
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
