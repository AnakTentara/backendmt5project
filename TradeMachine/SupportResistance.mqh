//+------------------------------------------------------------------+
//|                                         SupportResistance.mqh    |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "4.00"
#include "Types.mqh"
#include "Config.mqh"
#include "MarketStructure.mqh"

SRLevel g_sr_levels[MAX_SR_LEVELS];
int g_sr_count = 0;
SupplyDemandZone g_zones[MAX_ZONES];
int g_zone_count = 0;

void SupportResistance_Init() {
    ZeroMemory(g_sr_levels);
    ZeroMemory(g_zones);
    g_sr_count = 0;
    g_zone_count = 0;
}

double GetLocalM5SwingLow(int bars=5) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, bars + 2, rates) < bars + 2) return 0.0;
    double lo = rates[1].low;
    for(int i = 2; i <= bars; i++) {
        if(rates[i].low < lo) lo = rates[i].low;
    }
    return lo;
}

double GetLocalM5SwingHigh(int bars=5) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M5, 0, bars + 2, rates) < bars + 2) return 0.0;
    double hi = rates[1].high;
    for(int i = 2; i <= bars; i++) {
        if(rates[i].high > hi) hi = rates[i].high;
    }
    return hi;
}

void UpdateSupportResistance() {}
bool PriceAtMajorSupply() { return false; }
bool PriceAtMajorDemand() { return false; }
void PrintSupportResistance() {}
