//+------------------------------------------------------------------+
//|                                                   AutoTrade6.mq5 |
//|                        The Oracle v9 "APEX ENGINE"               |
//|                  Phase 1-4: Breakeven, Killswitch, Dynamic Lot   |
//|                  Confidence Score, Scalper Drone, News Assassin  |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "9.01"

#include <Trade\Trade.mqh>
CTrade trade;

// ==========================================
// INPUT PARAMETERS
// ==========================================
input string   InpServerUrl        = "http://103.93.129.117:8880/"; // URL Server Oracle (Feedback Only)
input double   InpInitialLot       = 0.01;      // Lot Awal
input double   InpLotMultiplier    = 1.5;       // Faktor Darurat Martingale
input int      InpBaseGridStep     = 1500;      // Poin Lapis Jaring
input double   InpTargetProfitUSD  = 3.0;       // Target Profit Keranjang (USD)
input ulong    InpMagicNum         = 606606;    // Magic Number EA
input bool     InpSessionFilter    = true;      // Filter Sesi London+NY?
input int      InpSessionStartUTC  = 7;         // Mulai Sesi (UTC)
input int      InpSessionEndUTC    = 21;        // Akhir Sesi (UTC)
input int      InpAITimeoutMs      = 12000;     // Timeout Server (ms)
input double   InpDailyKillPct     = 5.0;       // Daily Killswitch: Maks Loss % per hari
input double   InpBreakevenPip     = 10.0;      // Titik Breakeven (pip float profit)
input double   InpTrailingPip      = 20.0;      // Mulai Trailing Stop (pip)
input int      InpScalperIntervalMin = 5;       // Interval Scalper Drone (menit)
input int      InpRsiPeriod        = 14;        // Periode RSI (M15)
input int      InpRsiOverbought    = 70;        // Threshold Jual
input int      InpRsiOversold      = 30;        // Threshold Beli

// ==========================================
// STATE VARIABLES
// ==========================================
static double  daily_start_balance = 0;
static bool    daily_killed        = false;
static int     win_streak          = 0;
static int     loss_streak         = 0;
static int     scalper_tick_count  = 0;
static int     handle_rsi;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   EventSetTimer(1);
   daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   handle_rsi = iRSI(_Symbol, PERIOD_M15, InpRsiPeriod, PRICE_CLOSE);
   if(handle_rsi == INVALID_HANDLE)
     {
      Print("❌ Gagal inisialisasi RSI!");
      return(INIT_FAILED);
     }
   
   Print("⚡ AutoTrade6 [AUTONOMOUS ENGINE]: Sistem Aktif Tanpa AI!");
   Print("   Session Filter  : ", InpSessionFilter ? "AKTIF (London+NY)" : "NONAKTIF (24 jam)");
   Print("   Daily Killswitch: ", InpDailyKillPct, "% max daily drawdown");
   Print("   Entry Logic     : Constant RSI (", InpRsiOversold, "/", InpRsiOverbought, ")");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   IndicatorRelease(handle_rsi);
  }

// ==========================================
// CEK HARI WEEKEND
// ==========================================
bool IsWeekend()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
  }

// ==========================================
// CEK SESI TRADING
// ==========================================
bool IsActiveSession()
  {
   if(IsWeekend()) return false;
   if(!InpSessionFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;
   
   // Aktif mulai jam 06:00 UTC (Pre-London / Frankfurt) hingga 21:00 UTC
   bool pre_london = (hour >= 6 && hour < 16);
   bool newyork    = (hour >= 13 && hour < InpSessionEndUTC); 
   
   return (pre_london || newyork);
  }

// ==========================================
// PHASE 1A: DAILY KILLSWITCH
// ==========================================
bool CheckDailyKillswitch()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   static int last_day = -1;
   if(dt.day != last_day)
     {
      last_day            = dt.day;
      daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      daily_killed        = false;
      Print("🌅 [Killswitch] Hari baru. Balance awal hari: $", DoubleToString(daily_start_balance, 2));
     }

   if(daily_killed) return true;

   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double floating        = AccountInfoDouble(ACCOUNT_PROFIT);
   double equity          = current_balance + floating;
   double daily_loss_pct  = (daily_start_balance - equity) / daily_start_balance * 100.0;

   if(daily_loss_pct >= InpDailyKillPct)
     {
      Print("💀 [KILLSWITCH] Daily loss mencapai ", DoubleToString(daily_loss_pct, 2), "%. SEMUA POSISI DITUTUP.");
      CloseAllPositions();
      CancelAllPendingOrders();
      daily_killed = true;
      return true;
     }
   return false;
  }

// ==========================================
// UTILITY: CLOSE & CANCEL
// ==========================================
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
         trade.PositionClose(ticket);
     }
  }

double NormalizeLot(double lot)
  {
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double safe = MathRound(lot / step) * step;
   return MathMax(mn, MathMin(safe, mx));
  }

void CancelAllPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNum)
         trade.OrderDelete(ticket);
     }
  }

int GetEAPositionsTotal()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
         count++;
     }
   return count;
  }

// ==========================================
// PHASE 2A: DYNAMIC LOT SIZING
// ==========================================
double GetDynamicLot()
  {
   double lot = InpInitialLot;
   if(win_streak >= 6)
      lot = InpInitialLot;
   else if(win_streak >= 3)
      lot = NormalizeLot(InpInitialLot * 2.0);
   else
      lot = InpInitialLot;

   if(loss_streak >= 2)
      lot = InpInitialLot;
   return NormalizeLot(lot);
  }

// ==========================================
// PHASE 1B: BREAKEVEN & TRAILING STOP
// ==========================================
void ManageBreakevenTrailing()
  {
   double pip = _Point * 10;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNum)
         continue;

      ENUM_POSITION_TYPE ptype  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price         = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl         = PositionGetDouble(POSITION_SL);
      double current_tp         = PositionGetDouble(POSITION_TP);
      double ask                = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid                = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double float_pip          = (ptype == POSITION_TYPE_BUY) ? (bid - open_price) / pip : (open_price - ask) / pip;

      if(float_pip >= InpTrailingPip)
        {
         double new_sl = (ptype == POSITION_TYPE_BUY) ? bid - (InpTrailingPip * 0.5 * pip) : ask + (InpTrailingPip * 0.5 * pip);
         if((ptype == POSITION_TYPE_BUY && new_sl > current_sl + pip) || (ptype == POSITION_TYPE_SELL && (new_sl < current_sl - pip || current_sl == 0)))
           {
            trade.PositionModify(ticket, new_sl, current_tp);
           }
        }
      else if(float_pip >= InpBreakevenPip && current_sl != 0)
        {
         double be_sl = (ptype == POSITION_TYPE_BUY) ? open_price + pip : open_price - pip;
         if((ptype == POSITION_TYPE_BUY && be_sl > current_sl + pip) || (ptype == POSITION_TYPE_SELL && (be_sl < current_sl - pip || current_sl == 0)))
           {
            trade.PositionModify(ticket, be_sl, current_tp);
           }
        }
     }
  }

// ==========================================
// FEEDBACK LOOP: Monitoring Dashboard
// ==========================================
void SendFeedback(string result, double profit, double balance)
  {
   HistorySelect(TimeCurrent()-3600, TimeCurrent());
   int total = HistoryDealsTotal();
   ulong ticket = 0; string type = "N/A"; double vol = 0, px_out = 0;

   for(int i = total - 1; i >= 0; i--)
     {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC) == InpMagicNum && HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol)
        {
         ticket = t; vol = HistoryDealGetDouble(t, DEAL_VOLUME); px_out = HistoryDealGetDouble(t, DEAL_PRICE);
         type = (HistoryDealGetInteger(t, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
         break; 
        }
     }

   string payload = StringFormat("%s|%s|%.2f|%.2f|%I64u|%s|%.2f|%.5f|%.5f", 
                                 _Symbol, result, profit, balance, ticket, type, vol, px_out, px_out);
   char data[], res[];
   StringToCharArray(payload, data, 0, StringLen(payload));
   string headers = "Content-Type: text/plain\r\n";
   string url = InpServerUrl + "feedback";
   WebRequest("POST", url, headers, 4000, data, res, headers);
  }

// ==========================================
// PHASE 3: LOCAL SCALPER DRONE
// ==========================================
void RunScalperDrone()
  {
   if(GetEAPositionsTotal() > 0) return;
   if(!IsActiveSession())        return;

   double m1_open  = iOpen(_Symbol, PERIOD_M1, 1);
   double m1_close = iClose(_Symbol, PERIOD_M1, 1);
   double m5_open  = iOpen(_Symbol, PERIOD_M5, 1);
   double m5_close = iClose(_Symbol, PERIOD_M5, 1);
   double m1_delta = (m1_close - m1_open) / _Point;
   double m5_delta = (m5_close - m5_open) / _Point;
   long   spread   = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   string action = "HOLD";
   double sl = 0, tp = 0;
   double pip = _Point * 10;

   if(m1_delta > 50 && m5_delta > 50 && spread < 20)
     {
      action = "SCALP_BUY";
      sl = ask - (10 * pip); tp = ask + (12 * pip);
     }
   else if(m1_delta < -50 && m5_delta < -50 && spread < 20)
     {
      action = "SCALP_SELL";
      sl = bid + (10 * pip); tp = bid - (12 * pip);
     }

   if(action != "HOLD")
     {
      double scalp_lot = GetDynamicLot();
      if(action == "SCALP_BUY") trade.Buy(scalp_lot, _Symbol, ask, sl, tp, "LOCAL SCALP");
      else trade.Sell(scalp_lot, _Symbol, bid, sl, tp, "LOCAL SCALP");
      Print("🐝 [Scalper] ", action, " ", DoubleToString(scalp_lot, 2), " lot");
     }
  }

void OnTick()
  {
   if(IsWeekend() || CheckDailyKillswitch()) return;
   ManageBreakevenTrailing();

   int total_pos = 0; double total_profit = 0; long grid_type = -1; double extreme_price = 0, highest_lot = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         total_pos++; total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         grid_type = PositionGetInteger(POSITION_TYPE); double op = PositionGetDouble(POSITION_PRICE_OPEN);
         double vol = PositionGetDouble(POSITION_VOLUME); if(highest_lot < vol) highest_lot = vol;
         if(grid_type == POSITION_TYPE_BUY) extreme_price = (extreme_price == 0 || op < extreme_price) ? op : extreme_price;
         else extreme_price = (extreme_price == 0 || op > extreme_price) ? op : extreme_price;
        }
     }

   if(total_pos > 0 && total_profit >= InpTargetProfitUSD) { CloseAllPositions(); return; }

   if(total_pos > 0)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distance = InpBaseGridStep * _Point;
      if(grid_type == POSITION_TYPE_BUY && (extreme_price - ask >= distance))
         trade.Buy(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, ask, 0, 0, "Grid Layer");
      else if(grid_type == POSITION_TYPE_SELL && (bid - extreme_price >= distance))
         trade.Sell(NormalizeLot(highest_lot * InpLotMultiplier), _Symbol, bid, 0, 0, "Grid Layer");
     }
  }

void OnTimer()
  {
   static datetime last_m1_bar = 0;
   datetime current_m1_bar = iTime(_Symbol, PERIOD_M1, 0);

   scalper_tick_count++;
   if(scalper_tick_count >= InpScalperIntervalMin * 60) { scalper_tick_count = 0; RunScalperDrone(); }

   if(current_m1_bar == last_m1_bar) return;
   last_m1_bar = current_m1_bar;

   int current_pos = GetEAPositionsTotal();
   static int last_pos = 0; static double last_balance = 0;
   if(last_pos == 0 && current_pos > 0) last_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   else if(last_pos > 0 && current_pos == 0)
     {
      double profit = AccountInfoDouble(ACCOUNT_BALANCE) - last_balance;
      string outcome = (profit > 0) ? "WIN" : (profit == 0 ? "CUT" : "LOSS");
      if(outcome == "WIN") { win_streak++; loss_streak = 0; } else { loss_streak++; win_streak = 0; }
      SendFeedback(outcome, profit, AccountInfoDouble(ACCOUNT_BALANCE));
     }
   last_pos = current_pos;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double floating = AccountInfoDouble(ACCOUNT_PROFIT);
   double free_marg = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // Heartbeat Dashboard
   string hbPayload = StringFormat("SYMBOL:%s|FLOAT:%.2f|BAL:%.2f|F_MARG:%.2f|POS:%d", _Symbol, floating, balance, free_marg, current_pos);
   char data_hb[], res_hb[];
   StringToCharArray(hbPayload, data_hb, 0, StringLen(hbPayload));
   string headers_hb = "Content-Type: text/plain\r\n";
   WebRequest("POST", InpServerUrl + "heartbeat", headers_hb, 3000, data_hb, res_hb, headers_hb);

   if(!IsActiveSession() || current_pos > 0) return;

   // LOCAL RSI ENTRY LOGIC
   double rsi_buf[]; ArraySetAsSeries(rsi_buf, true);
   if(CopyBuffer(handle_rsi, 0, 1, 1, rsi_buf) > 0)
     {
      double rsi_val = rsi_buf[0];
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), pip = _Point * 10;
      double exec_lot = GetDynamicLot();
      if(rsi_val < InpRsiOversold) trade.Buy(exec_lot, _Symbol, ask, ask-(30*pip), ask+(45*pip), "RSI ENTRY");
      else if(rsi_val > InpRsiOverbought) trade.Sell(exec_lot, _Symbol, bid, bid+(30*pip), bid-(45*pip), "RSI ENTRY");
     }
  }
