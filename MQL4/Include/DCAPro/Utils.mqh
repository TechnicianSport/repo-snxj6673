//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|     DCA Pro - pip/point math, spread, ROC, swap, helpers          |
//+------------------------------------------------------------------+
#property strict

#ifndef __DCAPRO_UTILS_MQH__
#define __DCAPRO_UTILS_MQH__

#include "Defs.mqh"

//+------------------------------------------------------------------+
//| Logging  (terminal log + in-memory ring buffer for the UI feed)  |
//+------------------------------------------------------------------+
#define DCA_LOG_LINES 8        // how many recent events the UI feed keeps
string g_logRing[DCA_LOG_LINES];
int    g_logHead = 0;          // index of the most-recent line
bool   g_logInit = false;

void DcaLog(const string msg)
  {
   Print("[DCAPro] ", msg);
   if(!g_logInit)
     {
      for(int i = 0; i < DCA_LOG_LINES; i++) g_logRing[i] = "";
      g_logInit = true;
     }
   g_logHead = (g_logHead + 1) % DCA_LOG_LINES;
   g_logRing[g_logHead] = StringFormat("%s  %s", TimeToString(TimeCurrent(), TIME_MINUTES), msg);
  }

//--- return the i-th most-recent log line (0 = newest)
string DcaLogLine(int i)
  {
   if(i < 0 || i >= DCA_LOG_LINES) return("");
   int idx = ((g_logHead - i) % DCA_LOG_LINES + DCA_LOG_LINES) % DCA_LOG_LINES;
   return(g_logRing[idx]);
  }

//+------------------------------------------------------------------+
//| Point size for a symbol                                          |
//+------------------------------------------------------------------+
double SymPoint(const string sym)
  {
   double p = MarketInfo(sym, MODE_POINT);
   if(p <= 0) p = Point;
   return(p);
  }

//+------------------------------------------------------------------+
//| Digits for a symbol                                              |
//+------------------------------------------------------------------+
int SymDigits(const string sym)
  {
   int d = (int)MarketInfo(sym, MODE_DIGITS);
   if(d <= 0) d = Digits;
   return(d);
  }

//+------------------------------------------------------------------+
//| Pip size: 10 points on 3/5-digit quotes, 1 point on 2/4-digit    |
//+------------------------------------------------------------------+
double SymPip(const string sym)
  {
   int    d = SymDigits(sym);
   double p = SymPoint(sym);
   if(d == 3 || d == 5)
      return(p * 10.0);
   return(p);
  }

//--- how many points are in one pip (10 on 5-digit, 1 on 4-digit)
double PointsPerPip(const string sym)
  {
   return(SymPip(sym) / SymPoint(sym));
  }

//+------------------------------------------------------------------+
//| Convert pips <-> price distance                                  |
//+------------------------------------------------------------------+
double PipsToPrice(const string sym, double pips)
  {
   return(pips * SymPip(sym));
  }

double PriceToPips(const string sym, double priceDist)
  {
   double pip = SymPip(sym);
   if(pip <= 0) return(0);
   return(priceDist / pip);
  }

//+------------------------------------------------------------------+
//| Normalize a price to the symbol's digits                         |
//+------------------------------------------------------------------+
double NormPrice(const string sym, double price)
  {
   return(NormalizeDouble(price, SymDigits(sym)));
  }

//+------------------------------------------------------------------+
//| Live spread in pips                                              |
//+------------------------------------------------------------------+
double SpreadPips(const string sym)
  {
   double ask = MarketInfo(sym, MODE_ASK);
   double bid = MarketInfo(sym, MODE_BID);
   double pip = SymPip(sym);
   if(pip <= 0) return(0);
   if(ask > 0 && bid > 0)
      return((ask - bid) / pip);
   // fallback to broker reported spread (in points)
   return(MarketInfo(sym, MODE_SPREAD) / PointsPerPip(sym));
  }

//+------------------------------------------------------------------+
//| Money value of 1 pip for 1.0 lot, in account currency           |
//+------------------------------------------------------------------+
double MoneyPerPipPerLot(const string sym)
  {
   double tickVal  = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize = MarketInfo(sym, MODE_TICKSIZE);
   double pip      = SymPip(sym);
   if(tickSize <= 0 || tickVal <= 0)
     {
      // robust fallback: assume tickvalue is per point
      return(tickVal * PointsPerPip(sym));
     }
   return(tickVal * (pip / tickSize));
  }

//+------------------------------------------------------------------+
//| Broker minimum stop distance (in price)                          |
//+------------------------------------------------------------------+
double MinStopDist(const string sym)
  {
   double stops = MarketInfo(sym, MODE_STOPLEVEL); // in points
   double frz   = MarketInfo(sym, MODE_FREEZELEVEL);
   double lvl   = MathMax(stops, frz);
   return(lvl * SymPoint(sym));
  }

//+------------------------------------------------------------------+
//| Rate-of-change (%) on a timeframe, absolute value                |
//|   ROC = (Close[0]-Close[period]) / Close[period] * 100           |
//+------------------------------------------------------------------+
double CalcROC(const string sym, int tfMinutes, int period)
  {
   if(period < 1) period = 1;
   int tf = tfMinutes;
   double c0 = iClose(sym, tf, 0);
   double cn = iClose(sym, tf, period);
   if(cn == 0.0) return(0.0);
   return(MathAbs((c0 - cn) / cn * 100.0));
  }

//+------------------------------------------------------------------+
//| Build / parse order comment  "DCAP|<cid>|<layer>"                |
//+------------------------------------------------------------------+
string MakeComment(int cid, int layer)
  {
   return(StringFormat("%s|%d|%d", DCA_COMMENT, cid, layer));
  }

bool ParseComment(const string cmt, int &cid, int &layer)
  {
   cid = -1; layer = -1;
   if(StringFind(cmt, DCA_COMMENT) != 0) return(false);
   string parts[];
   int n = StringSplit(cmt, '|', parts);
   if(n < 3) return(false);
   cid   = (int)StringToInteger(parts[1]);
   layer = (int)StringToInteger(parts[2]);
   return(true);
  }

//+------------------------------------------------------------------+
//| Count total live orders (pending + market) on the account        |
//+------------------------------------------------------------------+
int TotalLiveOrders()
  {
   int cnt = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         cnt++;
     }
   return(cnt);
  }

//+------------------------------------------------------------------+
//| Day of week helper (0=Sun..6=Sat) for a server time              |
//+------------------------------------------------------------------+
int DowOf(datetime t)
  {
   return(TimeDayOfWeek(t));
  }

//+------------------------------------------------------------------+
//| How many swap-nights apply tonight given the triple-swap day      |
//+------------------------------------------------------------------+
int SwapNightsTonight(int tripleDay)
  {
   int dow = DowOf(TimeCurrent());
   return(dow == tripleDay ? 3 : 1);
  }

//+------------------------------------------------------------------+
//| Total swap-nights accrued for a position open since 'openTime',   |
//| applying triple-swap weighting on the configured day and skipping  |
//| the weekend rollovers (which the triple-swap day already covers).   |
//+------------------------------------------------------------------+
int SwapNightsHeld(datetime openTime, int tripleDay)
  {
   if(openTime <= 0) return(0);
   datetime cur  = TimeCurrent();
   if(cur <= openTime) return(0);
   datetime day0 = openTime - (openTime % 86400); // midnight of the open day
   int nights = 0;
   for(datetime d = day0 + 86400; d <= cur; d += 86400)
     {
      int dow = TimeDayOfWeek(d);
      if(dow == 0 || dow == 6) continue;          // Sat/Sun: no separate charge
      nights += (dow == tripleDay ? 3 : 1);
     }
   return(nights);
  }

//--- did the broker calendar day change since 'last'? (rollover detector)
bool DayChanged(datetime last)
  {
   if(last <= 0) return(true);
   datetime cur = TimeCurrent();
   return((cur / 86400) != (last / 86400));
  }

//=================================================================== //
//  Market-liveness detector (ONE shared condition for weekend close, //
//  terminal restart and internet disconnection - see addendum A).    //
//  Built from real MQL4 primitives:                                  //
//    - MarketInfo(MODE_TRADEALLOWED): hard "not live" when false.    //
//    - tick-staleness: measured against LOCAL clock so it still      //
//      advances when NO ticks arrive at all (server time freezes     //
//      without ticks, local time does not).                          //
//  Terminal permission (IsConnected/IsTradeAllowed) is kept distinct //
//  and checked separately by the caller, never folded in here.       //
//=================================================================== //
double g_tickStaleSeconds = 150.0;   // configurable staleness threshold (sec)

string   g_mktSym[];                 // per-symbol tracker
datetime g_mktQuote[];               // last broker quote time (MODE_TIME) seen
datetime g_mktLocalStamp[];          // LOCAL time when that quote last advanced

int MktIndex(const string sym)
  {
   for(int i = 0; i < ArraySize(g_mktSym); i++)
      if(g_mktSym[i] == sym) return(i);
   return(-1);
  }

//--- call once per tick/timer for every tracked symbol
void MktTouch(const string sym)
  {
   datetime qt = (datetime)MarketInfo(sym, MODE_TIME);
   int idx = MktIndex(sym);
   if(idx < 0)
     {
      int n = ArraySize(g_mktSym);
      ArrayResize(g_mktSym, n + 1);
      ArrayResize(g_mktQuote, n + 1);
      ArrayResize(g_mktLocalStamp, n + 1);
      g_mktSym[n]        = sym;
      g_mktQuote[n]      = qt;
      g_mktLocalStamp[n] = TimeLocal();
      return;
     }
   if(qt != g_mktQuote[idx])
     {
      g_mktQuote[idx]      = qt;
      g_mktLocalStamp[idx] = TimeLocal();
     }
  }

//--- current market-liveness for a symbol
MktLive MarketLiveness(const string sym)
  {
   if(MarketInfo(sym, MODE_TRADEALLOWED) == 0.0) return(MKT_CLOSED);
   int idx = MktIndex(sym);
   if(idx < 0 || g_mktLocalStamp[idx] == 0) return(MKT_UNKNOWN);
   double stale = (double)(TimeLocal() - g_mktLocalStamp[idx]);
   if(stale > g_tickStaleSeconds) return(MKT_CLOSED);
   return(MKT_LIVE);
  }

//--- non-authoritative weekend hint for the UI label ONLY (never gates trading)
bool WeekendHint()
  {
   int dow = DowOf(TimeCurrent());
   return(dow == 0 || dow == 6); // Sun / Sat
  }

string MktLiveText(MktLive s)
  {
   if(s == MKT_LIVE)   return("LIVE");
   if(s == MKT_CLOSED) return(WeekendHint() ? "CLOSED (weekend?)" : "CLOSED");
   return("UNKNOWN");
  }

#endif // __DCAPRO_UTILS_MQH__
//+------------------------------------------------------------------+
