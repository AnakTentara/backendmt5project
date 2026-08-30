//+------------------------------------------------------------------+
//|                                         ErrorHandling.mqh        |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
#include "Types.mqh"

void ErrorHandler_Init() {
    Print("ErrorHandler: Initialized");
}

void ErrorHandler_Cleanup() {
}

void Log(string msg) {
    if(Inp_EnableLogging) {
        Print("[TradeMachine] ", msg);
    }
}

string ErrorDescription(int err) {
    return IntegerToString(err);
}
