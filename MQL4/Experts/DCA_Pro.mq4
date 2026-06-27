//+------------------------------------------------------------------+
//|                                                       DCA_Pro.mq4 |
//|        Advanced two-direction, multi-cycle DCA EA for MT4          |
//|        (cent account, 5-digit aware, recovery + advanced UI)       |
//+------------------------------------------------------------------+
#property copyright "TechnicianSport"
#property link      ""
#property version   "1.00"
#property strict

#include <DCAPro/Defs.mqh>
#include <DCAPro/Utils.mqh>
#include <DCAPro/CycleManager.mqh>
#include <DCAPro/Persistence.mqh>
#include <DCAPro/Panel.mqh>

//--- inputs ----------------------------------------------------------
input int    InpMagicBase       = 990000; // base magic (each cycle = base + id)
input double InpLotInputFactor  = 1.0;    // multiplier: input(cent lots) -> terminal lots
input int    InpTimerSeconds    = 1;      // UI / persistence timer (seconds)
input bool   InpAutosave        = true;   // periodically persist cycles & spread map
input bool   InpMasterEnabled   = true;   // master switch: allow NEW orders (positions always kept)
input int    InpAccountMaxOrders= 100;    // account-wide cap on pending+market orders
input int    InpReconcileSeconds= 30;     // full reconcile-with-broker interval (seconds)

//--- internal --------------------------------------------------------
datetime g_lastSave      = 0;
datetime g_lastReconcile = 0;
bool     g_wasConnected  = true;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_magicBase       = InpMagicBase;
   g_lotFactor       = InpLotInputFactor;
   g_masterEnabled   = InpMasterEnabled;
   g_accountMaxOrders= MathMax(1, InpAccountMaxOrders);
   g_wasConnected    = IsConnected();

   // restore persisted state, then reconcile with live orders
   LoadSpreadMap();
   if(LoadCycles())
     {
      for(int i = 0; i < g_cycleCount; i++)
        {
         // re-derive magic in case base changed
         g_cycles[i].magic = g_magicBase + g_cycles[i].id;
         RebuildCycleFromOrders(g_cycles[i]);
        }
      DcaLog(StringFormat("Loaded %d cycle(s) from disk.", g_cycleCount));
     }

   g_uiNewSymbol = Symbol();
   PanelRebuild();
   PanelRefresh();

   EventSetTimer(MathMax(1, InpTimerSeconds));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   SaveCycles();
   SaveSpreadMap();
   // keep panel objects only on chart-change/recompile; remove otherwise
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
      UiDeleteAll();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   for(int i = 0; i < g_cycleCount; i++)
      OnCycleTick(g_cycles[i]);

   PanelRefresh();
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   // detect a reconnect (terminal regained the trade server) -> reconcile now
   bool connected = IsConnected();
   if(connected && !g_wasConnected)
     {
      DcaLog("Reconnected to server -> reconciling cycles with live orders.");
      for(int i = 0; i < g_cycleCount; i++)
         RebuildCycleFromOrders(g_cycles[i]);
      g_lastReconcile = TimeCurrent();
     }
   g_wasConnected = connected;

   // periodic full reconciliation pass (self-heal against missed events)
   if(InpReconcileSeconds > 0 && TimeCurrent() - g_lastReconcile >= InpReconcileSeconds)
     {
      for(int i = 0; i < g_cycleCount; i++)
         RebuildCycleFromOrders(g_cycles[i]);
      g_lastReconcile = TimeCurrent();
     }

   // ensure logic keeps running even without ticks (e.g. weekend recovery checks)
   for(int i = 0; i < g_cycleCount; i++)
      OnCycleTick(g_cycles[i]);

   PanelRefresh();

   if(InpAutosave && TimeCurrent() - g_lastSave >= 5)
     {
      SaveCycles();
      SaveSpreadMap();
      g_lastSave = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      PanelOnClick(sparam);
      PanelResetButton(sparam);
      ChartRedraw(0);
     }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
     {
      if(sparam == DCA_OBJ + "nsym")
         g_uiNewSymbol = ObjectGetString(0, sparam, OBJPROP_TEXT);
     }
  }
//+------------------------------------------------------------------+
