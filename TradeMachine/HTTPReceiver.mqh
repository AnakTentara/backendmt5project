//+------------------------------------------------------------------+
//|                                          HTTPReceiver.mqh        |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"
#include "Config.mqh"

void HTTPReceiver_Init() {
    Print("HTTPReceiver: Initialized");
}

void HTTPReceiver_OnTick() {
    // Pure algorithmic execution - no external HTTP blocks
}
