//+------------------------------------------------------------------+
//|                                                         Defs.mqh |
//|        DCA Pro - shared definitions, enums, structs, inputs       |
//+------------------------------------------------------------------+
#property strict

#ifndef __DCAPRO_DEFS_MQH__
#define __DCAPRO_DEFS_MQH__

//--- hard limits -----------------------------------------------------
#define DCA_MAX_CYCLES   50      // max cycles managed at once
#define DCA_MAX_LAYERS   60      // max DCA layers per cycle
#define DCA_ACCOUNT_MAX_ORDERS 100 // broker/account cap (pending+market)

//--- object/name prefixes -------------------------------------------
#define DCA_OBJ        "DCAP_"   // every chart object name starts with this
#define DCA_COMMENT    "DCAP"    // order comment prefix
#define DCA_FILE_CYC   "DCAPro_cycles.csv"
#define DCA_FILE_SPR   "DCAPro_spreads.csv"

//--- direction -------------------------------------------------------
enum CycleDir
  {
   DIR_LONG = 0,
   DIR_SHORT = 1
  };

//--- cycle high-level state -----------------------------------------
enum CycleState
  {
   ST_EMPTY        = 0, // slot unused
   ST_IDLE         = 1, // configured, not activated
   ST_WAITING      = 2, // activated, waiting for start filters (spread/ROC)
   ST_RUNNING      = 3, // has the market layer / live orders
   ST_STOP_AFTER_TP= 4, // will deactivate after next TP
   ST_DONE         = 5, // TP hit while we were off; waiting for manual re-activate
   ST_DETACHED     = 6, // control removed, orders left untouched (slot will be freed)
   ST_BLOCKED      = 7  // cannot place orders: account-wide order cap reached
  };

//--- per-layer runtime state ----------------------------------------
enum LayerState
  {
   LS_NONE      = 0, // not placed yet
   LS_PENDING   = 1, // limit order live on server
   LS_FILLED    = 2, // converted to an open position
   LS_CLOSED    = 3, // position closed (TP/manual)
   LS_CANCELLED = 4  // temporarily cancelled due to high spread (kept virtually)
  };

enum SwapMode
  {
   SWAP_AUTO   = 0, // read OrderSwap() actually charged
   SWAP_MANUAL = 1  // project using configured per-lot-per-night value
  };

//--- market-liveness (one shared condition: weekend close, restart, disconnect)
enum MktLive
  {
   MKT_UNKNOWN = 0, // not enough info yet (startup / never seen a tick)
   MKT_LIVE    = 1, // trading allowed and ticks are fresh
   MKT_CLOSED  = 2  // trade-disallowed by broker OR ticks are stale
  };

//+------------------------------------------------------------------+
//| Cycle structure                                                  |
//+------------------------------------------------------------------+
struct Cycle
  {
   //--- identity
   int      id;          // logical id (slot index based, stable)
   int      magic;       // unique magic = MagicBase + id
   string   symbol;
   CycleDir direction;
   CycleState state;

   //--- configuration (per layer)
   int      layerCount;
   int      spacingMode;              // 0 = step (from previous layer), 1 = absolute (cumulative from reference)
   double   spacing[DCA_MAX_LAYERS];  // pips: step from previous layer, or cumulative from reference (per spacingMode); index 0 = 0
   double   lots[DCA_MAX_LAYERS];     // input volume per layer (terminal lots after factor)

   //--- configuration (cycle level)
   double   baseTP;          // base take-profit in pips
   double   slPrice;         // per-cycle fixed stop-loss PRICE level; identical on EVERY ticket, never recalculated (0 = unset)
   double   defaultSpread;   // assumed spread (pips) for not-yet-filled limits
   double   maxSpread;       // pause/cancel limits above this spread (pips)
   double   startMaxSpread;  // do not OPEN a new cycle above this spread (pips)
   bool     useStartSpreadFilter; // gate 1 on/off (start spread)
   bool     useSpreadInTP;   // include simple-average spread cost in final TP
   bool     useSwapInTP;     // include negative swap cost in final TP
   SwapMode swapMode;
   double   swapLong;        // signed swap (e.g. -7) per 1.0 std lot per night, LONG side
   double   swapShort;       // signed swap per 1.0 std lot per night, SHORT side
   int      tripleSwapDay;   // day-of-week with triple swap (0=Sun..6=Sat), default 3=Wed
   bool     useROCFilter;
   double   rocThreshold;    // e.g. 0.28
   int      rocPeriod;       // bars
   int      rocTF;           // timeframe in minutes (e.g. 15)
   double   slipTolerance;   // pips of adverse slippage tolerated before re-TP (def 1.0)
   int      maxDeviation;    // max deviation (points) for market orders

   //--- runtime (per layer)
   int        layerStateArr[DCA_MAX_LAYERS];
   int        layerTicket[DCA_MAX_LAYERS];
   double     layerOpenPrice[DCA_MAX_LAYERS];
   double     layerOpenSpread[DCA_MAX_LAYERS]; // recorded spread (pips) at fill
   double     layerPlanPrice[DCA_MAX_LAYERS];  // planned price level (for cancel/restore)
   double     layerPlanTP[DCA_MAX_LAYERS];     // planned temp TP (for cancel/restore)

   //--- runtime (cycle level)
   double   referencePrice;  // actual open price of the first (market) layer
   double   currentBE;       // weighted break-even of open positions
   double   currentTP;       // unified final TP price
   double   pushOffsetPips;  // accumulated reposition push (high-spread scenario)
   bool     limitsParked;    // limits temporarily cancelled due to spread
   double   livePnL;         // last computed floating P/L (account currency)
   int      openPositions;   // count of open positions
   datetime lastActionTime;
   datetime lastSwapDay;     // last broker calendar day the rollover TP recompute ran
   string   blockReason;     // why this cycle is currently not opening new orders (for the UI)
   int      prevLive;        // last observed market-liveness (-1 unknown, 0 not-live, 1 live)
  };

#endif // __DCAPRO_DEFS_MQH__
//+------------------------------------------------------------------+
