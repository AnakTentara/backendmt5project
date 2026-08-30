//+------------------------------------------------------------------+
//|                                             Custom Indicator.mq5 |
//|                                                        HaikalDev |
//|                                          https://haikaldev.my.id |
//+------------------------------------------------------------------+
#property copyright "HaikalDev"
#property link      "https://haikaldev.my.id"
#property version   "1.00"
#property indicator_separate_window
#property indicator_minimum 1
#property indicator_maximum 10
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const int32_t begin,
                const double &price[])
  {
//---
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
