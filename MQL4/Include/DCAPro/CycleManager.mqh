//+------------------------------------------------------------------+
//|                                                 CycleManager.mqh |
//|      DCA Pro - core cycle logic: open, fill, TP, spread, recover  |
//+------------------------------------------------------------------+
#property strict

#ifndef __DCAPRO_CYCLEMGR_MQH__
#define __DCAPRO_CYCLEMGR_MQH__

#include "Defs.mqh"
#include "Utils.mqh"

//--- global state ----------------------------------------------------
Cycle  g_cycles[];
int    g_cycleCount = 0;
int    g_magicBase  = 990000;    // overwritten from input in OnInit
int    g_nextId     = 1;         // monotonic, never reused (persisted) -> no id collisions
double g_lotFactor  = 1.0;       // input(cent lots) -> terminal lots multiplier
bool   g_masterEnabled = true;   // master kill-switch: when false, no NEW orders are placed
int    g_accountMaxOrders = DCA_ACCOUNT_MAX_ORDERS; // configurable account-wide cap

//--- ticket -> recorded fill spread (pips), persisted for recovery ---
int    g_sprTicket[];
double g_sprValue[];

//=================================================================== //
//  Spread map helpers                                                 //
//=================================================================== //
void SprMapSet(int ticket, double spreadPips)
  {
   int n = ArraySize(g_sprTicket);
   for(int i = 0; i < n; i++)
      if(g_sprTicket[i] == ticket) { g_sprValue[i] = spreadPips; return; }
   ArrayResize(g_sprTicket, n + 1);
   ArrayResize(g_sprValue,  n + 1);
   g_sprTicket[n] = ticket;
   g_sprValue[n]  = spreadPips;
  }

double SprMapGet(int ticket, double def)
  {
   for(int i = 0; i < ArraySize(g_sprTicket); i++)
      if(g_sprTicket[i] == ticket) return(g_sprValue[i]);
   return(def);
  }

//=================================================================== //
//  Combined new-order gate (addendum A.5 hierarchy)                    //
//  Order: terminal permission -> market liveness -> (callers add the   //
//  spread / ROC gates). TP/SL execution is NEVER routed through here.   //
//=================================================================== //
bool TerminalReady(string &reason)
  {
   if(!IsConnected())    { reason = "Waiting: terminal disconnected"; return(false); }
   if(!IsTradeAllowed()) { reason = "Waiting: AutoTrading disabled";  return(false); }
   return(true);
  }

//--- terminal permission AND market liveness (no spread/ROC here)
bool MarketActionable(const string sym, string &reason)
  {
   if(!TerminalReady(reason)) return(false);
   MktLive ls = MarketLiveness(sym);
   if(ls != MKT_LIVE)
     {
      reason = (ls == MKT_CLOSED) ? "Waiting: market closed" : "Waiting: market status unknown";
      return(false);
     }
   return(true);
  }

//=================================================================== //
//  Cycle slot management                                              //
//=================================================================== //
int FindCycleIndexById(int id)
  {
   for(int i = 0; i < g_cycleCount; i++)
      if(g_cycles[i].id == id) return(i);
   return(-1);
  }

void InitCycleDefaults(Cycle &c)
  {
   c.layerCount      = 0;
   c.spacingMode     = 0;     // step mode (distance from previous layer)
   c.baseTP          = 5.0;
   c.slPrice         = 0.0;   // fixed stop-loss PRICE (0 = unset; must be set before the cycle can trade)
   c.defaultSpread   = 1.5;
   c.maxSpread       = 5.0;
   c.startMaxSpread  = 5.0;
   c.useStartSpreadFilter = true;
   c.useSpreadInTP   = true;
   c.useSwapInTP     = true;
   c.swapMode        = SWAP_AUTO;
   c.swapLong        = 0.0;
   c.swapShort       = 0.0;
   c.tripleSwapDay   = 3;     // Wednesday
   c.useROCFilter    = true;
   c.rocThreshold    = 0.28;
   c.rocPeriod       = 1;
   c.rocTF           = 15;
   c.slipTolerance   = 1.0;
   c.maxDeviation    = 30;
   c.referencePrice  = 0.0;
   c.currentBE       = 0.0;
   c.currentTP       = 0.0;
   c.pushOffsetPips  = 0.0;
   c.limitsParked    = false;
   c.livePnL         = 0.0;
   c.openPositions   = 0;
   c.lastActionTime  = 0;
   c.lastSwapDay     = 0;
   c.blockReason     = "";
   c.prevLive        = -1;
   for(int i = 0; i < DCA_MAX_LAYERS; i++)
     {
      c.spacing[i]        = 0.0;
      c.lots[i]           = 0.0;
      c.layerStateArr[i]  = LS_NONE;
      c.layerTicket[i]    = 0;
      c.layerOpenPrice[i] = 0.0;
      c.layerOpenSpread[i]= 0.0;
      c.layerPlanPrice[i] = 0.0;
      c.layerPlanTP[i]    = 0.0;
     }
  }

//--- create a new empty cycle slot, returns index or -1
int CreateCycle(const string sym, CycleDir dir)
  {
   if(g_cycleCount >= DCA_MAX_CYCLES) return(-1);
   int idx = g_cycleCount;
   ArrayResize(g_cycles, g_cycleCount + 1);
   InitCycleDefaults(g_cycles[idx]);
   g_cycles[idx].id        = g_nextId++;
   g_cycles[idx].magic     = g_magicBase + g_cycles[idx].id;
   g_cycles[idx].symbol    = sym;
   g_cycles[idx].direction = dir;
   g_cycles[idx].state     = ST_IDLE;
   // sensible default single layer (the market layer) so it is usable immediately
   g_cycles[idx].layerCount = 1;
   g_cycles[idx].lots[0]    = NormalizeLotsSym(sym, 1.0);
   g_cycleCount++;
   return(idx);
  }

//--- remove a cycle slot (only allowed when not running)
void RemoveCycle(int idx)
  {
   if(idx < 0 || idx >= g_cycleCount) return;
   for(int i = idx; i < g_cycleCount - 1; i++)
      g_cycles[i] = g_cycles[i + 1];
   g_cycleCount--;
   ArrayResize(g_cycles, g_cycleCount);
  }

//=================================================================== //
//  Trade helpers                                                      //
//=================================================================== //
double NormalizeLotsSym(const string sym, double lots)
  {
   double step = MarketInfo(sym, MODE_LOTSTEP);
   double mn   = MarketInfo(sym, MODE_MINLOT);
   double mx   = MarketInfo(sym, MODE_MAXLOT);
   if(step <= 0) step = 0.01;
   if(mn   <= 0) mn   = 0.01;
   if(mx   <= 0) mx   = 100000.0;
   double v = MathRound(lots / step) * step;
   if(v < mn) v = mn;
   if(v > mx) v = mx;
   return(NormalizeDouble(v, 2));
  }

double AddSign(const Cycle &c)
  {
   // direction the basket grows in price as we add layers
   return(c.direction == DIR_LONG ? -1.0 : +1.0);
  }

double ProfitSign(const Cycle &c)
  {
   return(-AddSign(c)); // profit direction is opposite to the averaging direction
  }

//--- effective signed swap rate (pips / 1.0 lot / night) for this cycle's side
double EffectiveSwapRate(const Cycle &c)
  {
   return(c.direction == DIR_LONG ? c.swapLong : c.swapShort);
  }

//--- cumulative distance (pips) of a layer from the reference price.
//    step mode    : spacing[i] is the gap from layer i-1, so we sum them.
//    absolute mode: spacing[layer] is already the cumulative distance.
double CumDist(const Cycle &c, int layer)
  {
   if(layer <= 0) return(0.0);
   if(c.spacingMode == 1)
      return(c.spacing[layer]);
   double d = 0.0;
   for(int i = 1; i <= layer && i < c.layerCount; i++)
      d += c.spacing[i];
   return(d);
  }

//--- the cycle's single fixed stop-loss PRICE, identical on every ticket
//    (Option A: broker-native per-ticket SL all pointing at the same price, so
//    the whole basket closes server-side at that level even if the EA is down).
//    The SL price is configured once and NEVER recalculated as layers fill.
//    Returns 0 when unset (slPrice <= 0) -> the cycle must not trade.
bool SLConfigured(const Cycle &c) { return(c.slPrice > 0.0); }

double SLPriceFor(const Cycle &c)
  {
   if(c.slPrice <= 0.0) return(0.0);
   return(NormPrice(c.symbol, c.slPrice));
  }

//--- config-time validity check (warning, NOT auto-correction). Ensures the
//    fixed SL is on the safe/protective side of the deepest configured DCA
//    layer, so it cannot trigger before the grid has finished laying out.
//    Uses the real reference once known, otherwise the current market as proxy.
bool ValidateSLPlacement(const Cycle &c, string &warn)
  {
   warn = "";
   if(!SLConfigured(c)) { warn = "Stop Loss price is not set (must be > 0)."; return(false); }
   string sym = c.symbol;
   double pip = SymPip(sym);
   double ref = (c.referencePrice > 0.0) ? c.referencePrice
              : ((c.direction == DIR_LONG) ? MarketInfo(sym, MODE_ASK)
                                           : MarketInfo(sym, MODE_BID));
   if(ref <= 0.0) return(true); // cannot evaluate yet
   int deepest = c.layerCount - 1;
   double deepestPrice = NormPrice(sym, ref + AddSign(c) * CumDist(c, deepest) * pip);
   double buffer = MathMax(c.maxSpread, 1.0) * pip; // small safety buffer
   if(c.direction == DIR_LONG)
     {
      if(c.slPrice >= deepestPrice - buffer)
        { warn = StringFormat("SL %.5f is not safely below the deepest BuyLimit %.5f (buffer %.1f pips).",
                              c.slPrice, deepestPrice, buffer / pip); return(false); }
     }
   else
     {
      if(c.slPrice <= deepestPrice + buffer)
        { warn = StringFormat("SL %.5f is not safely above the deepest SellLimit %.5f (buffer %.1f pips).",
                              c.slPrice, deepestPrice, buffer / pip); return(false); }
     }
   return(true);
  }

//--- planned price level for a layer (includes reposition push)
double PlannedLayerPrice(const Cycle &c, int layer)
  {
   double pip = SymPip(c.symbol);
   double dist = CumDist(c, layer) + c.pushOffsetPips;
   return(NormPrice(c.symbol, c.referencePrice + AddSign(c) * dist * pip));
  }

//--- open a market order for a layer; returns ticket or -1.
//    Used in exactly two places: (1) layer-0 cycle start, (2) spread-spike
//    nearest-skipped-layer recovery fill (Section 6.4). Asserted in OnCycleTick.
int OpenMarketLayer(Cycle &c, int layer)
  {
   if(!g_masterEnabled) { c.blockReason = "Paused: master switch OFF"; return(-1); }
   if(!SLConfigured(c))
     {
      c.blockReason = "Waiting: Stop Loss price not set";
      DcaLog(StringFormat("cid=%d cannot place order: Stop Loss price not set.", c.id));
      return(-1);
     }
   // market-liveness gate also covers the spread-spike recovery market order (addendum A.3)
   string gateReason;
   if(!MarketActionable(c.symbol, gateReason)) { c.blockReason = gateReason; return(-1); }
   string sym = c.symbol;
   double lots = NormalizeLotsSym(sym, c.lots[layer] * g_lotFactor);
   int    cmd  = (c.direction == DIR_LONG) ? OP_BUY : OP_SELL;
   double reqPrice = (cmd == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   double spr  = SpreadPips(sym);
   // temporary TP, recomputed right after as part of the unified TP pass
   double tpDist = (c.baseTP + (c.useSpreadInTP ? spr : 0)) ;
   double tp   = NormPrice(sym, reqPrice + ProfitSign(c) * PipsToPrice(sym, tpDist));
   double sl   = SLPriceFor(c); // single fixed cycle SL price, identical on every ticket
   int ticket = OrderSend(sym, cmd, lots, NormPrice(sym, reqPrice), c.maxDeviation,
                          sl, tp, MakeComment(c.id, layer), c.magic, 0, clrNONE);
   if(ticket < 0)
     {
      DcaLog(StringFormat("market order FAILED cid=%d layer=%d err=%d", c.id, layer, GetLastError()));
      return(-1);
     }
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      c.layerTicket[layer]    = ticket;
      c.layerStateArr[layer]  = LS_FILLED;
      c.layerOpenPrice[layer] = OrderOpenPrice();
      c.layerOpenSpread[layer]= spr;
      SprMapSet(ticket, spr);
      if(layer == 0)
         c.referencePrice = OrderOpenPrice();
      // adverse-slippage notice (TP already anchors to the real fill in RecomputeTP)
      double adverse = ProfitSign(c) * (reqPrice - OrderOpenPrice()) / SymPip(sym);
      if(adverse > c.slipTolerance)
         DcaLog(StringFormat("cid=%d layer=%d adverse slippage %.1f pips > tol %.1f -> TP re-pushed",
                             c.id, layer, adverse, c.slipTolerance));
     }
   c.lastActionTime = TimeCurrent();
   return(ticket);
  }

//--- place a pending limit order for a layer; returns ticket or -1.
//    Returns -2 specifically when the account-wide order cap blocks placement,
//    so the caller can flag BLOCKED_BY_ORDER_LIMIT and retry once room frees.
int PlaceLimitLayer(Cycle &c, int layer)
  {
   if(!g_masterEnabled) { c.blockReason = "Paused: master switch OFF"; return(-1); }
   if(!SLConfigured(c)) { c.blockReason = "Waiting: Stop Loss price not set"; return(-1); }
   string gateReason;
   if(!MarketActionable(c.symbol, gateReason)) { c.blockReason = gateReason; return(-1); }
   if(TotalLiveOrders() >= g_accountMaxOrders) return(-2);
   string sym = c.symbol;
   double lots = NormalizeLotsSym(sym, c.lots[layer] * g_lotFactor);
   int    cmd  = (c.direction == DIR_LONG) ? OP_BUYLIMIT : OP_SELLLIMIT;
   double price= PlannedLayerPrice(c, layer);
   // provisional formal TP using the default (assumed) spread (MT4 needs a TP)
   double tpDist = c.baseTP + (c.useSpreadInTP ? c.defaultSpread : 0);
   double tp   = NormPrice(sym, price + ProfitSign(c) * PipsToPrice(sym, tpDist));
   double sl   = SLPriceFor(c); // single fixed cycle SL price, identical on every ticket
   int ticket = OrderSend(sym, cmd, lots, price, c.maxDeviation, sl, tp,
                          MakeComment(c.id, layer), c.magic, 0, clrNONE);
   if(ticket < 0)
     {
      DcaLog(StringFormat("limit order FAILED cid=%d layer=%d price=%.5f err=%d",
                          c.id, layer, price, GetLastError()));
      return(-1);
     }
   c.layerTicket[layer]   = ticket;
   c.layerStateArr[layer] = LS_PENDING;
   c.layerPlanPrice[layer]= price;
   c.layerPlanTP[layer]   = tp;
   return(ticket);
  }

//--- (re)place every not-yet-filled limit layer from the reference.
//    Returns true if at least one layer could NOT be placed because the
//    account-wide order cap is full (caller flags BLOCKED_BY_ORDER_LIMIT).
bool PlaceAllPendingLimits(Cycle &c)
  {
   bool blocked = false;
   for(int layer = 1; layer < c.layerCount; layer++)
     {
      int st = c.layerStateArr[layer];
      if(st == LS_FILLED || st == LS_CLOSED) continue;
      if(st == LS_PENDING || st == LS_CANCELLED) continue; // already on server / parked
      int r = PlaceLimitLayer(c, layer);
      if(r == -2) blocked = true;
     }
   return(blocked);
  }

//=================================================================== //
//  Start filters                                                      //
//=================================================================== //
bool StartFiltersOK(Cycle &c, string &reason)
  {
   // gate hierarchy (addendum A.5):
   // 1) Stop Loss configured, 2) terminal permission + market liveness,
   // 3) spread gate, 4) ROC gate (fresh starts only)
   if(!SLConfigured(c))
     {
      reason = "Waiting: Stop Loss price not set";
      return(false);
     }
   if(!MarketActionable(c.symbol, reason))
      return(false);
   double spr = SpreadPips(c.symbol);
   if(c.useStartSpreadFilter && spr > c.startMaxSpread)
     {
      reason = StringFormat("Waiting: spread %.1fp > max %.1fp", spr, c.startMaxSpread);
      return(false);
     }
   if(c.useROCFilter)
     {
      double roc = CalcROC(c.symbol, c.rocTF, c.rocPeriod);
      if(roc > c.rocThreshold)
        {
         reason = StringFormat("Waiting: ROC %.3f > %.3f", roc, c.rocThreshold);
         return(false);
        }
     }
   reason = "ok";
   return(true);
  }

//=================================================================== //
//  Final TP recomputation (the math core)                             //
//=================================================================== //
//--- Signed accrued swap cost of the cycle's open positions, in account
//    currency (negative = the EA is paying swap).
//      AUTO   : sum of the broker's actual OrderSwap() across open tickets.
//      MANUAL : per-ticket projection using the user's signed swap rate
//               (pips / 1.0 lot / night), the dynamically-derived money-per-pip,
//               and the accrued nights-held (with triple-swap day weighting).
double SwapMoney(Cycle &c)
  {
   double money = 0.0;
   double rate  = EffectiveSwapRate(c);
   double mppl  = MoneyPerPipPerLot(c.symbol);
   for(int layer = 0; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_FILLED) continue;
      if(!OrderSelect(c.layerTicket[layer], SELECT_BY_TICKET)) continue;
      if(OrderCloseTime() != 0) continue;
      if(c.swapMode == SWAP_AUTO)
         money += OrderSwap();
      else // MANUAL: dollars = lots * ($/pip/lot) * (pips/night) * nights-held
         money += OrderLots() * mppl * rate * SwapNightsHeld(OrderOpenTime(), c.tripleSwapDay);
     }
   return(money);
  }

//--- projected volume-weighted breakeven if every layer up to & including
//    'upTo' were open: filled layers use their REAL open price/lots; not-yet-
//    filled layers use their planned price and configured lot (Section 5.5).
double ProjectedBE(Cycle &c, int upTo)
  {
   double sumVol = 0.0, sumPV = 0.0;
   for(int layer = 0; layer <= upTo && layer < c.layerCount; layer++)
     {
      int    st  = c.layerStateArr[layer];
      double vol, price;
      if(st == LS_FILLED && OrderSelect(c.layerTicket[layer], SELECT_BY_TICKET) && OrderCloseTime() == 0)
        { vol = OrderLots(); price = OrderOpenPrice(); }
      else
        { vol = NormalizeLotsSym(c.symbol, c.lots[layer] * g_lotFactor); price = PlannedLayerPrice(c, layer); }
      sumVol += vol;
      sumPV  += price * vol;
     }
   if(sumVol <= 0) return(0.0);
   return(sumPV / sumVol);
  }

//--- refresh the provisional TP (and fixed SL) carried by every resting pending
//    limit order, so they always show the best current estimate before filling.
void UpdatePendingProvisionalTPs(Cycle &c)
  {
   double pip = SymPip(c.symbol);
   for(int layer = 1; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_PENDING) continue;
      int ticket = c.layerTicket[layer];
      if(!OrderSelect(ticket, SELECT_BY_TICKET) || OrderCloseTime() != 0) continue;
      double projBE = ProjectedBE(c, layer);
      if(projBE <= 0) continue;
      double tpDist = c.baseTP + (c.useSpreadInTP ? c.defaultSpread : 0.0);
      double tp     = NormPrice(c.symbol, projBE + ProfitSign(c) * tpDist * pip);
      double sl     = SLPriceFor(c);
      if(MathAbs(OrderTakeProfit() - tp) < SymPoint(c.symbol) &&
         MathAbs(OrderStopLoss()   - sl) < SymPoint(c.symbol)) continue;
      if(!OrderModify(ticket, OrderOpenPrice(), sl, tp, 0, clrNONE))
         DcaLog(StringFormat("modify pending TP failed t=%d err=%d", ticket, GetLastError()));
      else
         c.layerPlanTP[layer] = tp;
     }
  }

void RecomputeTP(Cycle &c)
  {
   double sumVol = 0.0, sumEntryVol = 0.0, sumSpr = 0.0;
   int    nOpen  = 0;
   for(int layer = 0; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_FILLED) continue;
      if(!OrderSelect(c.layerTicket[layer], SELECT_BY_TICKET)) continue;
      if(OrderCloseTime() != 0) continue;
      double vol = OrderLots();
      sumVol      += vol;
      sumEntryVol += OrderOpenPrice() * vol;
      sumSpr      += c.layerOpenSpread[layer];   // SIMPLE sum -> simple average below
      nOpen++;
     }
   c.openPositions = nOpen;
   if(nOpen == 0 || sumVol <= 0) return;

   double sym_pip   = SymPip(c.symbol);
   double BE        = sumEntryVol / sumVol;                // volume-weighted breakeven
   double avgSpread = sumSpr / nOpen;                      // SIMPLE average registered spread (8.3/8.7)
   double swapM     = SwapMoney(c);
   double mppl      = MoneyPerPipPerLot(c.symbol);
   double swapDist  = 0.0;
   if(c.useSwapInTP && swapM < 0 && mppl > 0)
      swapDist = (-swapM) / (sumVol * mppl);               // pips to cover negative swap

   double tpDist = c.baseTP
                 + (c.useSpreadInTP ? avgSpread : 0.0)
                 + swapDist;

   double tpPrice = NormPrice(c.symbol, BE + ProfitSign(c) * tpDist * sym_pip);

   c.currentBE = BE;
   c.currentTP = tpPrice;

   // push all open positions to the single unified TP (keep their fixed SL)
   double minStop = MinStopDist(c.symbol);
   for(int layer = 0; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_FILLED) continue;
      if(!OrderSelect(c.layerTicket[layer], SELECT_BY_TICKET)) continue;
      if(OrderCloseTime() != 0) continue;
      // the cycle's single fixed SL price is identical on every ticket and never recalculated
      double sl = SLPriceFor(c);
      if(MathAbs(OrderTakeProfit() - tpPrice) < SymPoint(c.symbol) &&
         MathAbs(OrderStopLoss()   - sl)      < SymPoint(c.symbol)) continue;
      // validate against broker min stop distance from current market
      double ref = (OrderType() == OP_BUY) ? MarketInfo(c.symbol, MODE_BID)
                                           : MarketInfo(c.symbol, MODE_ASK);
      if(MathAbs(tpPrice - ref) < minStop) continue; // too close right now, retry next tick
      if(!OrderModify(OrderTicket(), OrderOpenPrice(), sl, tpPrice, 0, clrNONE))
         DcaLog(StringFormat("modify TP failed t=%d err=%d", OrderTicket(), GetLastError()));
     }

   // keep resting pending limits' provisional TP/SL up to date too (8.4)
   UpdatePendingProvisionalTPs(c);
  }

//=================================================================== //
//  Fill / close detection                                             //
//=================================================================== //
//--- returns true if any new fill happened (caller should recompute TP)
bool DetectFillsAndCloses(Cycle &c, bool &cycleTPDone)
  {
   bool newFill = false;
   int  filledNow = 0;
   cycleTPDone = false;

   for(int layer = 0; layer < c.layerCount; layer++)
     {
      int st = c.layerStateArr[layer];
      if(st == LS_NONE || st == LS_CANCELLED) continue;
      int ticket = c.layerTicket[layer];
      if(ticket <= 0) continue;
      if(!OrderSelect(ticket, SELECT_BY_TICKET))
        {
         // ticket vanished from open pool -> it is in history (closed/deleted)
         if(st == LS_FILLED) c.layerStateArr[layer] = LS_CLOSED;
         continue;
        }
      int type = OrderType();
      if(OrderCloseTime() != 0)
        {
         if(st == LS_FILLED) c.layerStateArr[layer] = LS_CLOSED;
         continue;
        }
      if(type == OP_BUY || type == OP_SELL)
        {
         if(st == LS_PENDING)
           {
            // a limit just became a position
            double spr = SpreadPips(c.symbol);
            c.layerStateArr[layer]  = LS_FILLED;
            c.layerOpenPrice[layer] = OrderOpenPrice();
            c.layerOpenSpread[layer]= spr;
            SprMapSet(ticket, spr);
            newFill = true;
           }
         filledNow++;
        }
     }

   c.openPositions = filledNow;

   // cycle TP completed: we had positions before but none are open now and
   // no pending limit is sitting that we still expect to use as part of THIS run
   bool everFilled = false;
   for(int l = 0; l < c.layerCount; l++)
      if(c.layerStateArr[l] == LS_CLOSED || c.layerStateArr[l] == LS_FILLED)
         { everFilled = true; break; }

   if(everFilled && filledNow == 0)
      cycleTPDone = true;

   return(newFill);
  }

//=================================================================== //
//  High-spread parking / restoring / reposition                       //
//=================================================================== //
void ParkLimits(Cycle &c)
  {
   for(int layer = 1; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_PENDING) continue;
      int ticket = c.layerTicket[layer];
      if(OrderSelect(ticket, SELECT_BY_TICKET) && OrderCloseTime() == 0)
        {
         // remember the plan so we can restore it exactly
         c.layerPlanPrice[layer] = OrderOpenPrice();
         c.layerPlanTP[layer]    = OrderTakeProfit();
         if(OrderDelete(ticket, clrNONE))
            c.layerStateArr[layer] = LS_CANCELLED;
         else
            DcaLog(StringFormat("ParkLimits delete failed t=%d err=%d", ticket, GetLastError()));
        }
     }
   c.limitsParked = true;
  }

//--- has the current price already crossed (overshot) a planned layer?
bool LayerCrossed(const Cycle &c, int layer)
  {
   double price = PlannedLayerPrice(c, layer);
   if(c.direction == DIR_SHORT)
      return(MarketInfo(c.symbol, MODE_BID) >= price); // sell limit overshot upward
   else
      return(MarketInfo(c.symbol, MODE_ASK) <= price); // buy limit overshot downward
  }

void RestoreLimits(Cycle &c)
  {
   if(!c.limitsParked) return;
   double pip = SymPip(c.symbol);

   // process layers from nearest to reference outward
   for(int layer = 1; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_CANCELLED) continue;

      if(LayerCrossed(c, layer))
        {
         // price overshot this layer while parked -> open it at market now and
         // push all remaining layers by the overshoot amount (reposition).
         double planned = PlannedLayerPrice(c, layer);
         int t = OpenMarketLayer(c, layer);
         if(t > 0)
           {
            double fill = c.layerOpenPrice[layer];
            double overshoot = MathAbs(fill - planned) / pip; // pips in adding dir
            c.pushOffsetPips += overshoot;
            DcaLog(StringFormat("Reposition cid=%d layer=%d push+=%.1f pips", c.id, layer, overshoot));
           }
        }
      else
        {
         // normal restore at the (possibly pushed) plan price
         PlaceLimitLayer(c, layer);
        }
     }
   c.limitsParked = false;
   RecomputeTP(c);
  }

//=================================================================== //
//  Shutdown modes                                                     //
//=================================================================== //
void DeletePendingOfCycle(Cycle &c)
  {
   for(int layer = 0; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_PENDING && c.layerStateArr[layer] != LS_CANCELLED)
         continue;
      int ticket = c.layerTicket[layer];
      if(ticket > 0 && OrderSelect(ticket, SELECT_BY_TICKET) && OrderCloseTime() == 0)
        {
         int tp = OrderType();
         if(tp == OP_BUYLIMIT || tp == OP_SELLLIMIT || tp == OP_BUYSTOP || tp == OP_SELLSTOP)
            if(!OrderDelete(ticket, clrNONE))
               DcaLog(StringFormat("OrderDelete failed t=%d err=%d", ticket, GetLastError()));
        }
      c.layerStateArr[layer] = LS_NONE;
      c.layerTicket[layer]   = 0;
     }
  }

void CloseAllPositionsOfCycle(Cycle &c)
  {
   for(int layer = 0; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_FILLED) continue;
      int ticket = c.layerTicket[layer];
      if(!OrderSelect(ticket, SELECT_BY_TICKET)) continue;
      if(OrderCloseTime() != 0) continue;
      double price = (OrderType() == OP_BUY) ? MarketInfo(c.symbol, MODE_BID)
                                             : MarketInfo(c.symbol, MODE_ASK);
      if(!OrderClose(ticket, OrderLots(), NormPrice(c.symbol, price), c.maxDeviation, clrNONE))
         DcaLog(StringFormat("OrderClose failed t=%d err=%d", ticket, GetLastError()));
      else
         c.layerStateArr[layer] = LS_CLOSED;
     }
  }

//--- 1) close now
void ShutdownCloseNow(Cycle &c)
  {
   DeletePendingOfCycle(c);
   CloseAllPositionsOfCycle(c);
   ResetCycleRuntime(c);
   c.state = ST_IDLE;
  }

//--- 2) stop after the next TP
void ShutdownStopAfterTP(Cycle &c)
  {
   if(c.state != ST_RUNNING) return; // only meaningful for a running cycle
   c.state = ST_STOP_AFTER_TP;
  }

//--- 3) detach: leave orders untouched, drop the cycle from management
void ShutdownDetach(Cycle &c)
  {
   c.state = ST_DETACHED;
  }

void ResetCycleRuntime(Cycle &c)
  {
   c.referencePrice = 0.0;
   c.currentBE = 0.0;
   c.currentTP = 0.0;
   c.pushOffsetPips = 0.0;
   c.limitsParked = false;
   c.openPositions = 0;
   c.lastSwapDay = 0;
   for(int i = 0; i < DCA_MAX_LAYERS; i++)
     {
      c.layerStateArr[i]  = LS_NONE;
      c.layerTicket[i]    = 0;
      c.layerOpenPrice[i] = 0.0;
      c.layerOpenSpread[i]= 0.0;
      c.layerPlanPrice[i] = 0.0;
      c.layerPlanTP[i]    = 0.0;
     }
  }

//=================================================================== //
//  Live P/L                                                           //
//=================================================================== //
double ComputeLivePnL(Cycle &c)
  {
   double pnl = 0.0;
   for(int layer = 0; layer < c.layerCount; layer++)
     {
      if(c.layerStateArr[layer] != LS_FILLED) continue;
      if(OrderSelect(c.layerTicket[layer], SELECT_BY_TICKET) && OrderCloseTime() == 0)
         pnl += OrderProfit() + OrderSwap() + OrderCommission();
     }
   c.livePnL = pnl;
   return(pnl);
  }

//=================================================================== //
//  Per-cycle tick                                                     //
//=================================================================== //
void OnCycleTick(Cycle &c)
  {
   if(c.state == ST_EMPTY || c.state == ST_IDLE || c.state == ST_DONE || c.state == ST_DETACHED)
     {
      ComputeLivePnL(c);
      return;
     }

   // market-liveness transition: the instant a symbol goes (not-live)->LIVE
   // (weekend reopen, reconnect, etc.) run the SAME full reconciliation pass
   // as restart/disconnect recovery, since TP/SL may have fired over the gap.
   int liveNow = (MarketLiveness(c.symbol) == MKT_LIVE) ? 1 : 0;
   if(liveNow == 1 && c.prevLive == 0)
     {
      DcaLog(StringFormat("cid=%d market reopened -> reconciling with live orders.", c.id));
      RebuildCycleFromOrders(c);
     }
   c.prevLive = liveNow;

   // 0) account-wide order cap recovery: a BLOCKED cycle re-arms once room frees
   if(c.state == ST_BLOCKED)
     {
      if(TotalLiveOrders() < g_accountMaxOrders)
        {
         c.state = ST_WAITING;
         DcaLog(StringFormat("cid=%d order cap cleared -> waiting.", c.id));
        }
      else
         return;
     }

   // 1) try to start when waiting
   if(c.state == ST_WAITING)
     {
      string reason;
      if(!g_masterEnabled)                          // master kill-switch: no new orders
        {
         c.blockReason = "Paused: master switch OFF";
         return;
        }
      if(TotalLiveOrders() >= g_accountMaxOrders)   // would breach the account cap
        {
         c.state = ST_BLOCKED;
         c.blockReason = StringFormat("Blocked: order cap %d/%d", TotalLiveOrders(), g_accountMaxOrders);
         DcaLog(StringFormat("cid=%d blocked: order cap %d reached.", c.id, g_accountMaxOrders));
         return;
        }
      if(StartFiltersOK(c, reason))
        {
         c.blockReason = "";
         if(OpenMarketLayer(c, 0) > 0 && c.referencePrice > 0)
           {
            PlaceAllPendingLimits(c);
            c.state = ST_RUNNING;
            RecomputeTP(c);
           }
        }
      else
         c.blockReason = reason;
      return;
     }

   if(c.state != ST_RUNNING && c.state != ST_STOP_AFTER_TP)
      return;

   // 2) detect fills & closes
   bool tpDone = false;
   bool newFill = DetectFillsAndCloses(c, tpDone);

   // 3) cycle finished (final TP reached, or the fixed SL closed every position)
   if(tpDone)
     {
      DeletePendingOfCycle(c);
      ResetCycleRuntime(c);
      if(c.state == ST_STOP_AFTER_TP)
        {
         c.state = ST_IDLE;
         DcaLog(StringFormat("cid=%d closed -> stopped (Stop-After-TP).", c.id));
        }
      else
        {
         c.state = ST_WAITING; // auto restart same config (new generation)
         DcaLog(StringFormat("cid=%d closed -> restarting next generation.", c.id));
        }
      return;
     }

   // 4) high-spread parking / restoring. NOTE (addendum B): this only cancels
   //    not-yet-filled NEW limit orders; it never touches the TP/SL of open
   //    positions, whose execution is broker-side and never spread/liveness gated.
   double spr = SpreadPips(c.symbol);
   if(!c.limitsParked && spr > c.maxSpread)
     {
      ParkLimits(c);
      DcaLog(StringFormat("cid=%d spread %.1f>%.1f -> limits parked.", c.id, spr, c.maxSpread));
     }
   else if(c.limitsParked && spr <= c.maxSpread)
     {
      RestoreLimits(c);
      DcaLog(StringFormat("cid=%d spread normal %.1f -> limits restored.", c.id, spr));
     }

   // 5) top-up any limits that could not be placed earlier (e.g. order cap)
   if(!c.limitsParked && c.referencePrice > 0 && g_masterEnabled)
      PlaceAllPendingLimits(c);

   // 6) recompute unified TP on new fills, OR once per broker rollover for swap (8.9)
   if(newFill)
      RecomputeTP(c);
   else if(c.useSwapInTP && c.openPositions > 0 && DayChanged(c.lastSwapDay))
     {
      c.lastSwapDay = TimeCurrent();
      RecomputeTP(c);
     }

   c.blockReason = ""; // running normally
   ComputeLivePnL(c);
  }

//=================================================================== //
//  Recovery after restart / reconnect                                 //
//=================================================================== //
void RebuildCycleFromOrders(Cycle &c)
  {
   // reset transient pointers then rescan
   for(int i = 0; i < DCA_MAX_LAYERS; i++)
     {
      if(c.layerStateArr[i] != LS_CLOSED)
         c.layerStateArr[i] = LS_NONE;
      c.layerTicket[i] = 0;
     }

   int nFilled = 0, nPending = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != c.magic) continue;
      int cid, layer;
      if(!ParseComment(OrderComment(), cid, layer)) continue;
      if(layer < 0 || layer >= DCA_MAX_LAYERS) continue;
      int type = OrderType();
      c.layerTicket[layer] = OrderTicket();
      if(type == OP_BUY || type == OP_SELL)
        {
         c.layerStateArr[layer]  = LS_FILLED;
         c.layerOpenPrice[layer] = OrderOpenPrice();
         c.layerOpenSpread[layer]= SprMapGet(OrderTicket(), c.defaultSpread);
         if(layer == 0) c.referencePrice = OrderOpenPrice();
         nFilled++;
        }
      else
        {
         c.layerStateArr[layer]  = LS_PENDING;
         c.layerPlanPrice[layer] = OrderOpenPrice();
         c.layerPlanTP[layer]    = OrderTakeProfit();
         nPending++;
        }
     }

   c.openPositions = nFilled;
   if(c.referencePrice <= 0 && nFilled > 0)
     {
      // fallback: use earliest filled layer's price as reference
      for(int l = 0; l < c.layerCount; l++)
         if(c.layerStateArr[l] == LS_FILLED) { c.referencePrice = c.layerOpenPrice[l]; break; }
     }

   if(nFilled > 0)
     {
      c.state = ST_RUNNING;
      RecomputeTP(c);
      DcaLog(StringFormat("cid=%d recovered RUNNING (%d pos, %d pending).", c.id, nFilled, nPending));
     }
   else
     {
      // no positions: if the cycle was supposed to be running, TP hit while off
      if(nPending > 0)
        {
         DeletePendingOfCycle(c);
         DcaLog(StringFormat("cid=%d recovered: TP done, leftover limits cleared.", c.id));
        }
      if(c.state == ST_RUNNING || c.state == ST_STOP_AFTER_TP)
        {
         ResetCycleRuntime(c);
         c.state = ST_DONE; // wait for manual re-activation
        }
     }
  }

//=================================================================== //
//  Public actions used by the panel                                   //
//=================================================================== //
void ActionActivate(Cycle &c)
  {
   if(c.state == ST_IDLE || c.state == ST_DONE)
      c.state = ST_WAITING;
  }

void ActionDeactivate(Cycle &c)
  {
   if(c.state == ST_WAITING)
      c.state = ST_IDLE;
  }

#endif // __DCAPRO_CYCLEMGR_MQH__
//+------------------------------------------------------------------+
