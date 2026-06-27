//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|     DCA Pro - pip/point math, spread, ROC, swap, helpers          |
//+------------------------------------------------------------------+
#property strict

#ifndef __DCAPRO_UTILS_MQH__
#define __DCAPRO_UTILS_MQH__

#include "Defs.mqh"

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void DcaLog(const string msg)
  {
   Print("[DCAPro] ", msg);
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

#endif // __DCAPRO_UTILS_MQH__
//+------------------------------------------------------------------+
