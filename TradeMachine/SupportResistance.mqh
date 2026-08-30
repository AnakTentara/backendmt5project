//+------------------------------------------------------------------+
//|                                         SupportResistance.mqh    |
//|                                                        TradeMachine |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "TradeMachine"
#property link      "https://haikaldev.my.id"
#property version   "3.00"
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
    Print("SupportResistance: Initialized");
}

double CalculateLevelStrength(SRLevel &level) {
    double score = level.touches * 2.0;
    if(level.type == SR_MAJOR) score += 3.0;
    else if(level.type == SR_MINOR) score += 1.5;
    return score;
}

void AddSwingLevel(SwingPoint &sp, SR_LEVEL_TYPE type) {
    if(sp.price == 0 || !sp.is_confirmed) return;
    
    for(int i = 0; i < g_sr_count; i++) {
        if(MathAbs(g_sr_levels[i].price - sp.price) <= 20.0) {
            g_sr_levels[i].touches++;
            g_sr_levels[i].last_touch_time = sp.time;
            g_sr_levels[i].strength = CalculateLevelStrength(g_sr_levels[i]);
            return;
        }
    }
    
    if(g_sr_count < MAX_SR_LEVELS) {
        SRLevel level;
        level.price = sp.price;
        level.type = type;
        level.touches = 1;
        level.volume_at_level = sp.volume;
        level.last_touch_time = sp.time;
        level.timeframe = sp.timeframe;
        level.is_active = true;
        level.strength = CalculateLevelStrength(level);
        level.bounce_height = 0;
        level.retest_depth = 0;
        level.vol80_1to1_confirmed = false;
        
        g_sr_levels[g_sr_count] = level;
        g_sr_count++;
    }
}

void UpdateSwingLevels() {
    SwingPoint sp_h4_h = GetLastSwingHigh(4);
    SwingPoint sp_h4_l = GetLastSwingLow(4);
    SwingPoint sp_h1_h = GetLastSwingHigh(3);
    SwingPoint sp_h1_l = GetLastSwingLow(3);
    SwingPoint sp_m15_h = GetLastSwingHigh(1);
    SwingPoint sp_m15_l = GetLastSwingLow(1);
    SwingPoint sp_m5_h = GetLastSwingHigh(0);
    SwingPoint sp_m5_l = GetLastSwingLow(0);
    
    AddSwingLevel(sp_h4_h, SR_MAJOR);
    AddSwingLevel(sp_h4_l, SR_MAJOR);
    AddSwingLevel(sp_h1_h, SR_MAJOR);
    AddSwingLevel(sp_h1_l, SR_MAJOR);
    AddSwingLevel(sp_m15_h, SR_MINOR);
    AddSwingLevel(sp_m15_l, SR_MINOR);
    AddSwingLevel(sp_m5_h, SR_MICRO);
    AddSwingLevel(sp_m5_l, SR_MICRO);
}

void UpdateSupplyDemandZones() {
    g_zone_count = 0;
    
    // Scan recent swings to build zones
    for(int i = 0; i < g_sr_count && g_zone_count < MAX_ZONES; i++) {
        if(!g_sr_levels[i].is_active) continue;
        
        SupplyDemandZone zone;
        double p = g_sr_levels[i].price;
        double buffer = 100.0; // Zone thickness for VOL_80
        
        zone.top = p + buffer;
        zone.bottom = p - buffer;
        zone.center = p;
        zone.bars_count = 10;
        zone.touches = g_sr_levels[i].touches;
        zone.volume_profile = g_sr_levels[i].volume_at_level;
        zone.strength = g_sr_levels[i].strength;
        zone.is_major = (g_sr_levels[i].type == SR_MAJOR);
        zone.created_time = g_sr_levels[i].last_touch_time;
        zone.last_test_time = TimeCurrent();
        zone.is_fresh = (zone.touches <= 1);
        zone.is_broken = false;
        
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(bid > zone.top) {
            zone.type = ZONE_DEMAND;
        } else {
            zone.type = ZONE_SUPPLY;
        }
        
        g_zones[g_zone_count] = zone;
        g_zone_count++;
    }
}

void UpdateSupportResistance() {
    UpdateSwingLevels();
    UpdateSupplyDemandZones();
}

bool PriceAtMajorSupply() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    for(int i = 0; i < g_zone_count; i++) {
        if(g_zones[i].type == ZONE_SUPPLY && g_zones[i].is_major) {
            if(ask >= g_zones[i].bottom && ask <= g_zones[i].top + 50) return true;
        }
    }
    return false;
}

bool PriceAtMajorDemand() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    for(int i = 0; i < g_zone_count; i++) {
        if(g_zones[i].type == ZONE_DEMAND && g_zones[i].is_major) {
            if(bid <= g_zones[i].top && bid >= g_zones[i].bottom - 50) return true;
        }
    }
    return false;
}

double GetMinorResistance() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double nearest = DBL_MAX;
    for(int i = 0; i < g_sr_count; i++) {
        if(g_sr_levels[i].price > bid && g_sr_levels[i].price < nearest) {
            nearest = g_sr_levels[i].price;
        }
    }
    return (nearest == DBL_MAX) ? bid + 200 : nearest;
}

double GetMinorSupport() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double nearest = 0;
    for(int i = 0; i < g_sr_count; i++) {
        if(g_sr_levels[i].price < bid && g_sr_levels[i].price > nearest) {
            nearest = g_sr_levels[i].price;
        }
    }
    return (nearest == 0) ? bid - 200 : nearest;
}

void PrintSupportResistance() {
    Print("--- S/R Levels Count: ", g_sr_count, " | Zones Count: ", g_zone_count, " ---");
}
