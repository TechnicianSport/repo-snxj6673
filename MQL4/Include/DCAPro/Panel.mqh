//+------------------------------------------------------------------+
//|                                                        Panel.mqh |
//|     DCA Pro - advanced on-chart UI (panel, rows, config dialog)    |
//+------------------------------------------------------------------+
#property strict

#ifndef __DCAPRO_PANEL_MQH__
#define __DCAPRO_PANEL_MQH__

#include "Defs.mqh"
#include "Utils.mqh"
#include "CycleManager.mqh"
#include "Persistence.mqh"

//--- UI state --------------------------------------------------------
bool     g_uiMinimized   = false;
int      g_uiConfigCid   = -1;     // cycle id whose config dialog is open (-1 none)
string   g_uiNewSymbol   = "";
CycleDir g_uiNewDir      = DIR_LONG;

//--- layout constants ------------------------------------------------
#define UI_X        12
#define UI_Y        20
#define UI_W        790
#define UI_TITLEH   32
#define UI_STATUSH  24
#define UI_BLOCKH   70        // height of one cycle block (info + reason + buttons)
#define UI_ABTN_W   112       // action button width
#define UI_ABTN_H   28        // action button height

//--- font sizes (clear hierarchy: title > section > row > log) --------
#define FS_TITLE    14
#define FS_SEC      12
#define FS_HDR      11
#define FS_ROW      11
#define FS_BTN      10
#define FS_LOG      10

//--- colors ----------------------------------------------------------
#define C_BG        (color)C'28,30,38'
#define C_BAR       (color)C'40,44,58'
#define C_SEC       (color)C'37,40,52'
#define C_BTN       (color)C'55,60,78'
#define C_BTN2      (color)C'70,90,120'
#define C_GREEN     (color)C'40,120,70'
#define C_RED       (color)C'150,55,55'
#define C_TXT       clrWhite
#define C_SUB       (color)C'180,186,200'
#define C_AMBER     (color)C'212,158,48'
#define C_TEAL      (color)C'55,150,162'
#define C_GRAY      (color)C'120,126,140'
#define C_BLUE      (color)C'78,120,200'
#define C_LONG      (color)C'58,120,205'
#define C_SHORT     (color)C'208,98,60'
#define C_KILLON    (color)C'34,150,74'
#define C_KILLOFF   (color)C'185,52,42'

//=================================================================== //
//  Low-level object helpers                                           //
//=================================================================== //
void UiRect(string name, int x, int y, int w, int h, color bg, color border)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void UiLabel(string name, int x, int y, string text, color clr, int fs = FS_ROW, string font = "Tahoma")
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void UiButton(string name, int x, int y, int w, int h, string text, color bg, int fs = FS_BTN)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C_TXT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_SUB);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

void UiEdit(string name, int x, int y, int w, int h, string text, int fs = FS_ROW)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void UiDeleteAll()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string nm = ObjectName(0, i);
      if(StringFind(nm, DCA_OBJ) == 0)
         ObjectDelete(0, nm);
     }
  }

//=================================================================== //
//  State / direction -> text + color                                  //
//=================================================================== //
string StateText(CycleState s)
  {
   switch(s)
     {
      case ST_IDLE:          return("DEACTIVATED");
      case ST_WAITING:       return("WAITING");
      case ST_RUNNING:       return("RUNNING");
      case ST_STOP_AFTER_TP: return("STOP AFTER TP");
      case ST_DONE:          return("DONE (TP HIT)");
      case ST_DETACHED:      return("DETACHED");
      case ST_BLOCKED:       return("BLOCKED");
     }
   return("-");
  }

color StateColor(CycleState s)
  {
   switch(s)
     {
      case ST_RUNNING:       return((color)C'90,200,120');
      case ST_WAITING:       return(C_AMBER);
      case ST_BLOCKED:       return((color)C'235,110,90');
      case ST_STOP_AFTER_TP: return(C_TEAL);
      case ST_DONE:          return(C_BLUE);
      case ST_DETACHED:      return(C_GRAY);
      case ST_IDLE:          return(C_GRAY);
     }
   return(C_SUB);
  }

string DirText(CycleDir d)  { return(d == DIR_LONG ? "LONG" : "SHORT"); }
color  DirColor(CycleDir d) { return(d == DIR_LONG ? C_LONG : C_SHORT); }

//--- the activate/deactivate button reflects the current state
bool   CycleIsActive(CycleState s)
  { return(s == ST_WAITING || s == ST_RUNNING || s == ST_STOP_AFTER_TP || s == ST_BLOCKED); }
string ActText(CycleState s) { return(CycleIsActive(s) ? "Deactivate" : "Activate"); }

//=================================================================== //
//  Config dialog (grouped, readable sections)                         //
//=================================================================== //
#define CFG_W   560

//--- draw a tinted section box with a header; returns the y just below header
int CfgSection(string id, int x, int y, int w, int rows, string title)
  {
   int h = 22 + rows * 28 + 8;
   UiRect(DCA_OBJ + "sec_" + id, x + 8, y, w - 16, h, C_SEC, C_SUB);
   UiLabel(DCA_OBJ + "sh_" + id, x + 16, y + 4, title, C_TXT, FS_SEC);
   return(y + 24);
  }

void BuildConfigDialog(int cid)
  {
   int idx = FindCycleIndexById(cid);
   if(idx < 0) return;
   Cycle c = g_cycles[idx];

   int x = UI_X, y = UI_Y, w = CFG_W;
   int lx = x + 18, ex = x + 250, rh = 28;

   // overall background sized to fit all sections
   int H = 40 + (22+2*28+8) + (22+1*28+8) + (22+2*28+8) + (22+3*28+8)
             + (22+2*28+8) + (22+1*28+8) + 44 + 60;
   UiRect(DCA_OBJ + "cfgbg", x, y, w, H, C_BG, C_SUB);
   UiLabel(DCA_OBJ + "cfgtitle", x + 14, y + 8,
           StringFormat("Configure cycle #%d   %s %s", c.id, c.symbol, DirText(c.direction)),
           C_TXT, FS_TITLE);

   int ry = y + 40;

   //--- Section: Layers & Take Profit (2 rows) -----------------------
   int sy = CfgSection("lay", x, ry, w, 2, "Layers & Take Profit");
   UiLabel(DCA_OBJ + "l_layers", lx, sy + 4, "Layers (sp:lot, ...):", C_SUB);
   UiEdit (DCA_OBJ + "e_layers", ex, sy, 290, 22, SerializeLayers(c)); sy += rh;
   UiLabel(DCA_OBJ + "l_btp", lx, sy + 4, "Base Take Profit (pips):", C_SUB);
   UiEdit (DCA_OBJ + "e_btp", ex, sy, 120, 22, DoubleToString(c.baseTP, 2));
   ry += 22 + 2*28 + 8 + 6;

   //--- Section: Stop Loss (1 row) -----------------------------------
   sy = CfgSection("sl", x, ry, w, 1, "Stop Loss (mandatory)");
   UiLabel(DCA_OBJ + "l_sl", lx, sy + 4, "Stop Loss PRICE (per cycle):", C_SUB);
   UiEdit (DCA_OBJ + "e_sl", ex, sy, 120, 22,
           (c.slPrice > 0 ? DoubleToString(c.slPrice, SymDigits(c.symbol)) : ""));
   ry += 22 + 1*28 + 8 + 6;

   //--- Section: TP Cost Inclusion (2 rows) --------------------------
   sy = CfgSection("cost", x, ry, w, 2, "TP & Cost Inclusion");
   UiLabel(DCA_OBJ + "l_dspr", lx, sy + 4, "Default spread (pips):", C_SUB);
   UiEdit (DCA_OBJ + "e_dspr", ex, sy, 120, 22, DoubleToString(c.defaultSpread, 2)); sy += rh;
   UiButton(DCA_OBJ + "t_uspr", lx, sy, 150, 24,
            "Spread in TP: " + (c.useSpreadInTP ? "ON" : "OFF"), c.useSpreadInTP ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_uswp", lx + 160, sy, 150, 24,
            "Swap in TP: " + (c.useSwapInTP ? "ON" : "OFF"), c.useSwapInTP ? C_GREEN : C_BTN);
   ry += 22 + 2*28 + 8 + 6;

   //--- Section: Spread & ROC Filters (3 rows) -----------------------
   sy = CfgSection("filt", x, ry, w, 3, "Spread & ROC Filters");
   UiLabel(DCA_OBJ + "l_mspr", lx, sy + 4, "Max / Start-max spread (pips):", C_SUB);
   UiEdit (DCA_OBJ + "e_mspr", ex, sy, 120, 22, DoubleToString(c.maxSpread, 2));
   UiEdit (DCA_OBJ + "e_sspr", ex + 130, sy, 120, 22, DoubleToString(c.startMaxSpread, 2)); sy += rh;
   UiLabel(DCA_OBJ + "l_roc", lx, sy + 4, "ROC thr / period / TF(min):", C_SUB);
   UiEdit (DCA_OBJ + "e_rocth", ex, sy, 80, 22, DoubleToString(c.rocThreshold, 3));
   UiEdit (DCA_OBJ + "e_rocp", ex + 90, sy, 80, 22, IntegerToString(c.rocPeriod));
   UiEdit (DCA_OBJ + "e_roctf", ex + 180, sy, 80, 22, IntegerToString(c.rocTF)); sy += rh;
   UiButton(DCA_OBJ + "t_ussp", lx, sy, 150, 24,
            "Start spread: " + (c.useStartSpreadFilter ? "ON" : "OFF"), c.useStartSpreadFilter ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_uroc", lx + 160, sy, 150, 24,
            "ROC filter: " + (c.useROCFilter ? "ON" : "OFF"), c.useROCFilter ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_spm", lx + 320, sy, 170, 24,
            "Spacing: " + (c.spacingMode == 1 ? "ABSOLUTE" : "STEP"), C_BTN2);
   ry += 22 + 3*28 + 8 + 6;

   //--- Section: Swap (2 rows) ---------------------------------------
   sy = CfgSection("swap", x, ry, w, 2, "Swap");
   UiLabel(DCA_OBJ + "l_swap", lx, sy + 4, "Swap Long / Short (pips/lot/night):", C_SUB);
   UiEdit (DCA_OBJ + "e_swapl", ex, sy, 120, 22, DoubleToString(c.swapLong, 2));
   UiEdit (DCA_OBJ + "e_swaps", ex + 130, sy, 120, 22, DoubleToString(c.swapShort, 2)); sy += rh;
   UiLabel(DCA_OBJ + "l_tday", lx, sy + 4, "Triple-swap day (0=Sun..6=Sat):", C_SUB);
   UiEdit (DCA_OBJ + "e_tday", ex, sy, 80, 22, IntegerToString(c.tripleSwapDay));
   UiButton(DCA_OBJ + "t_smode", ex + 130, sy, 150, 24,
            "Swap: " + (c.swapMode == SWAP_AUTO ? "AUTO" : "MANUAL"), C_BTN2);
   ry += 22 + 2*28 + 8 + 6;

   //--- Section: Execution (1 row) -----------------------------------
   sy = CfgSection("exec", x, ry, w, 1, "Execution");
   UiLabel(DCA_OBJ + "l_slip", lx, sy + 4, "Slippage tol / Max deviation:", C_SUB);
   UiEdit (DCA_OBJ + "e_slip", ex, sy, 120, 22, DoubleToString(c.slipTolerance, 2));
   UiEdit (DCA_OBJ + "e_dev", ex + 130, sy, 120, 22, IntegerToString(c.maxDeviation));
   ry += 22 + 1*28 + 8 + 10;

   //--- Save / Cancel -----------------------------------------------
   UiButton(DCA_OBJ + "b_save", lx, ry, 150, 30, "SAVE", C_GREEN, FS_SEC);
   UiButton(DCA_OBJ + "b_cancel", lx + 165, ry, 150, 30, "CANCEL", C_RED, FS_SEC);
  }

//=================================================================== //
//  Main panel                                                         //
//=================================================================== //
//--- column x-offsets (relative to panel x) for the cycle table
#define COL_ID   10
#define COL_SYM  44
#define COL_DIR  150
#define COL_ST   235
#define COL_POS  370
#define COL_PNL  450
#define COL_BE   560
#define COL_TP   680

void PanelRebuild()
  {
   UiDeleteAll();

   int x = UI_X, y = UI_Y, w = UI_W;

   //--- title bar (always visible) ----------------------------------
   UiRect(DCA_OBJ + "bar", x, y, w, UI_TITLEH, C_BAR, C_SUB);
   UiLabel(DCA_OBJ + "title", x + 12, y + 7, "DCA Pro  -  Multi-Cycle Manager", C_TXT, FS_TITLE);
   // master kill-switch: the single most prominent control
   UiButton(DCA_OBJ + "kill", x + w - 232, y + 3, 196, UI_TITLEH - 6,
            g_masterEnabled ? "TRADING: ON" : "TRADING: OFF  (PAUSED)",
            g_masterEnabled ? C_KILLON : C_KILLOFF, FS_SEC);
   UiButton(DCA_OBJ + "min", x + w - 30, y + 7, 22, 18, g_uiMinimized ? "+" : "_", C_BTN);

   if(g_uiMinimized)
      return;

   if(g_uiConfigCid >= 0)
     {
      BuildConfigDialog(g_uiConfigCid);
      return;
     }

   //--- global status bar (connection + market liveness + order count)
   int statY = y + UI_TITLEH;
   UiRect(DCA_OBJ + "statbar", x, statY, w, UI_STATUSH, C_SEC, C_SUB);
   UiLabel(DCA_OBJ + "conn", x + 12, statY + 5, "Connection: ...", C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "mkt",  x + 250, statY + 5, "Market: ...", C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "acc",  x + w - 160, statY + 5,
           StringFormat("Orders: %d / %d", TotalLiveOrders(), g_accountMaxOrders), C_SUB, FS_HDR);

   //--- body background ---------------------------------------------
   int rows  = g_cycleCount;
   int bodyTop = statY + UI_STATUSH;
   int bodyH = 44 + 30 + rows * UI_BLOCKH + 8 + 100;
   UiRect(DCA_OBJ + "body", x, bodyTop, w, bodyH, C_BG, C_SUB);

   //--- new-cycle controls ------------------------------------------
   int ny = bodyTop + 10;
   UiLabel(DCA_OBJ + "nl", x + 12, ny + 5, "Symbol:", C_SUB, FS_HDR);
   if(g_uiNewSymbol == "") g_uiNewSymbol = Symbol();
   UiEdit  (DCA_OBJ + "nsym", x + 80, ny, 140, 26, g_uiNewSymbol);
   UiButton(DCA_OBJ + "ndir", x + 234, ny, 110, 26, DirText(g_uiNewDir), DirColor(g_uiNewDir));
   UiButton(DCA_OBJ + "ncreate", x + 354, ny, 120, 26, "Create Cycle", C_BTN2);

   //--- table header (full words) -----------------------------------
   int hy = ny + 36;
   UiLabel(DCA_OBJ + "h_id",  x + COL_ID,  hy, "#",            C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_sym", x + COL_SYM, hy, "Symbol",       C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_dir", x + COL_DIR, hy, "Direction",    C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_st",  x + COL_ST,  hy, "Status",       C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_pos", x + COL_POS, hy, "Open Pos",     C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_pnl", x + COL_PNL, hy, "Live P/L",     C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_be",  x + COL_BE,  hy, "Breakeven",    C_SUB, FS_HDR);
   UiLabel(DCA_OBJ + "h_tp",  x + COL_TP,  hy, "Take Profit",  C_SUB, FS_HDR);

   //--- cycle blocks ------------------------------------------------
   int ry0 = hy + 22;
   for(int i = 0; i < g_cycleCount; i++)
     {
      Cycle c = g_cycles[i];
      string sfx = IntegerToString(c.id);
      int ry = ry0 + i * UI_BLOCKH;

      // status colour badge
      UiRect (DCA_OBJ + "rbadge" + sfx, x + 4, ry + 2, 4, 16, StateColor(c.state), StateColor(c.state));
      // info columns (each its own label for per-column colour + alignment)
      UiLabel(DCA_OBJ + "rid"  + sfx, x + COL_ID,  ry + 2, sfx, C_TXT, FS_ROW);
      UiLabel(DCA_OBJ + "rsym" + sfx, x + COL_SYM, ry + 2, c.symbol, C_TXT, FS_ROW);
      UiLabel(DCA_OBJ + "rdir" + sfx, x + COL_DIR, ry + 2, DirText(c.direction), DirColor(c.direction), FS_ROW);
      UiLabel(DCA_OBJ + "rst"  + sfx, x + COL_ST,  ry + 2, StateText(c.state), StateColor(c.state), FS_ROW);
      UiLabel(DCA_OBJ + "rpos" + sfx, x + COL_POS, ry + 2, IntegerToString(c.openPositions), C_TXT, FS_ROW);
      UiLabel(DCA_OBJ + "rpnl" + sfx, x + COL_PNL, ry + 2, "0.00", C_TXT, FS_ROW);
      UiLabel(DCA_OBJ + "rbe"  + sfx, x + COL_BE,  ry + 2, "-", C_TXT, FS_ROW);
      UiLabel(DCA_OBJ + "rtp"  + sfx, x + COL_TP,  ry + 2, "-", C_TXT, FS_ROW);

      // blocked/waiting reason line
      UiLabel(DCA_OBJ + "rrsn" + sfx, x + COL_SYM, ry + 22, "", C_AMBER, FS_LOG);

      // action buttons (full words)
      int by = ry + 38, bx = x + 18, bw = UI_ABTN_W, bh = UI_ABTN_H, gap = 6;
      UiButton(DCA_OBJ + "cfg" + sfx, bx, by, bw, bh, "Configure", C_BTN); bx += bw + gap;
      UiButton(DCA_OBJ + "act" + sfx, bx, by, bw, bh, ActText(c.state),
               CycleIsActive(c.state) ? C_BTN : C_GREEN); bx += bw + gap;
      UiButton(DCA_OBJ + "cls" + sfx, bx, by, bw, bh, "Close Now", C_RED); bx += bw + gap;
      UiButton(DCA_OBJ + "stp" + sfx, bx, by, bw, bh, "Stop After TP", C_BTN); bx += bw + gap;
      UiButton(DCA_OBJ + "det" + sfx, bx, by, bw, bh, "Detach", C_BTN); bx += bw + gap;
      UiButton(DCA_OBJ + "del" + sfx, bx, by, bw, bh, "Delete", C_BTN);
     }

   //--- activity log feed -------------------------------------------
   int ly = ry0 + rows * UI_BLOCKH + 6;
   UiLabel(DCA_OBJ + "logh", x + 12, ly, "Activity log", C_SUB, FS_HDR); ly += 20;
   for(int k = 0; k < 4; k++)
     {
      UiLabel(DCA_OBJ + "log" + IntegerToString(k), x + 18, ly, DcaLogLine(k), C_SUB, FS_LOG);
      ly += 18;
     }
  }

//--- update only the dynamic text (no rebuild -> no flicker / focus loss)
void PanelRefresh()
  {
   if(g_uiMinimized || g_uiConfigCid >= 0) return;

   // kill-switch reflects current state
   ObjectSetString (0, DCA_OBJ + "kill", OBJPROP_TEXT,
                    g_masterEnabled ? "TRADING: ON" : "TRADING: OFF  (PAUSED)");
   ObjectSetInteger(0, DCA_OBJ + "kill", OBJPROP_BGCOLOR, g_masterEnabled ? C_KILLON : C_KILLOFF);

   // global connection + market-liveness indicators
   bool conn = IsConnected();
   ObjectSetString (0, DCA_OBJ + "conn", OBJPROP_TEXT,
                    conn ? "Connection: CONNECTED" : "Connection: DISCONNECTED");
   ObjectSetInteger(0, DCA_OBJ + "conn", OBJPROP_COLOR,
                    conn ? (color)C'120,210,140' : (color)C'235,140,140');
   MktLive ls = MarketLiveness(Symbol());
   ObjectSetString (0, DCA_OBJ + "mkt", OBJPROP_TEXT,
                    StringFormat("Market(%s): %s", Symbol(), MktLiveText(ls)));
   ObjectSetInteger(0, DCA_OBJ + "mkt", OBJPROP_COLOR,
                    ls == MKT_LIVE ? (color)C'120,210,140'
                                   : (ls == MKT_CLOSED ? (color)C'235,140,140' : C_AMBER));

   ObjectSetString(0, DCA_OBJ + "acc", OBJPROP_TEXT,
                   StringFormat("Orders: %d / %d", TotalLiveOrders(), g_accountMaxOrders));
   for(int k = 0; k < 4; k++)
      ObjectSetString(0, DCA_OBJ + "log" + IntegerToString(k), OBJPROP_TEXT, DcaLogLine(k));

   for(int i = 0; i < g_cycleCount; i++)
     {
      Cycle c = g_cycles[i];
      string sfx = IntegerToString(c.id);
      double pnl = ComputeLivePnL(c);

      ObjectSetInteger(0, DCA_OBJ + "rbadge" + sfx, OBJPROP_BGCOLOR, StateColor(c.state));
      ObjectSetString (0, DCA_OBJ + "rst"  + sfx, OBJPROP_TEXT, StateText(c.state));
      ObjectSetInteger(0, DCA_OBJ + "rst"  + sfx, OBJPROP_COLOR, StateColor(c.state));
      ObjectSetString (0, DCA_OBJ + "rpos" + sfx, OBJPROP_TEXT, IntegerToString(c.openPositions));
      ObjectSetString (0, DCA_OBJ + "rpnl" + sfx, OBJPROP_TEXT,
                       StringFormat("%s%.2f", (pnl >= 0 ? "+" : ""), pnl));
      ObjectSetInteger(0, DCA_OBJ + "rpnl" + sfx, OBJPROP_COLOR,
                       pnl >= 0 ? (color)C'120,210,140' : (color)C'235,140,140');
      ObjectSetString (0, DCA_OBJ + "rbe" + sfx, OBJPROP_TEXT,
                       (c.currentBE > 0 ? DoubleToString(c.currentBE, SymDigits(c.symbol)) : "-"));
      ObjectSetString (0, DCA_OBJ + "rtp" + sfx, OBJPROP_TEXT,
                       (c.currentTP > 0 ? DoubleToString(c.currentTP, SymDigits(c.symbol)) : "-"));

      // show the specific blocked/waiting reason (addendum C.4)
      string rsn = "";
      if(c.state == ST_WAITING || c.state == ST_BLOCKED) rsn = c.blockReason;
      ObjectSetString(0, DCA_OBJ + "rrsn" + sfx, OBJPROP_TEXT, rsn);

      // keep the activate/deactivate button label in sync with state
      ObjectSetString (0, DCA_OBJ + "act" + sfx, OBJPROP_TEXT, ActText(c.state));
      ObjectSetInteger(0, DCA_OBJ + "act" + sfx, OBJPROP_BGCOLOR,
                       CycleIsActive(c.state) ? C_BTN : C_GREEN);
     }
   ChartRedraw(0);
  }

//=================================================================== //
//  Read config dialog edits back into the cycle                       //
//=================================================================== //
double EditD(string name) { return(StringToDouble(ObjectGetString(0, DCA_OBJ + name, OBJPROP_TEXT))); }
int    EditI(string name) { return((int)StringToInteger(ObjectGetString(0, DCA_OBJ + name, OBJPROP_TEXT))); }
string EditS(string name) { return(ObjectGetString(0, DCA_OBJ + name, OBJPROP_TEXT)); }

void SaveConfigFromDialog(int cid)
  {
   int idx = FindCycleIndexById(cid);
   if(idx < 0) return;
   DeserializeLayers(g_cycles[idx], EditS("e_layers"));
   if(g_cycles[idx].layerCount < 1) g_cycles[idx].layerCount = 1;
   g_cycles[idx].baseTP         = EditD("e_btp");
   g_cycles[idx].slPrice        = EditD("e_sl");
   g_cycles[idx].defaultSpread  = EditD("e_dspr");
   g_cycles[idx].maxSpread      = EditD("e_mspr");
   g_cycles[idx].startMaxSpread = EditD("e_sspr");
   g_cycles[idx].swapLong       = EditD("e_swapl");
   g_cycles[idx].swapShort      = EditD("e_swaps");
   g_cycles[idx].tripleSwapDay  = EditI("e_tday");
   g_cycles[idx].rocThreshold   = EditD("e_rocth");
   g_cycles[idx].rocPeriod      = EditI("e_rocp");
   g_cycles[idx].rocTF          = EditI("e_roctf");
   g_cycles[idx].slipTolerance  = EditD("e_slip");
   g_cycles[idx].maxDeviation   = EditI("e_dev");
   // Stop-Loss is mandatory and is a single fixed PRICE for the whole cycle.
   // Validate placement but only WARN (no silent auto-correction).
   string slWarn;
   if(!ValidateSLPlacement(g_cycles[idx], slWarn))
      DcaLog(StringFormat("cid=%d SL warning: %s", cid, slWarn));
  }

//=================================================================== //
//  Click handling                                                     //
//=================================================================== //
bool HandleSuffixButton(string name, string prefix, int &cidOut)
  {
   string full = DCA_OBJ + prefix;
   if(StringFind(name, full) != 0) return(false);
   string s = StringSubstr(name, StringLen(full));
   cidOut = (int)StringToInteger(s);
   return(true);
  }

void PanelOnClick(string name)
  {
   int cid;

   if(name == DCA_OBJ + "min")
     {
      g_uiMinimized = !g_uiMinimized;
      PanelRebuild(); return;
     }

   if(name == DCA_OBJ + "kill")
     {
      g_masterEnabled = !g_masterEnabled;
      DcaLog(g_masterEnabled ? "Master switch ON: new orders allowed."
                             : "Master switch OFF: no NEW orders (open positions kept).");
      PanelRebuild(); return;
     }

   // config dialog buttons
   if(g_uiConfigCid >= 0)
     {
      if(name == DCA_OBJ + "b_save")
        { SaveConfigFromDialog(g_uiConfigCid); SaveCycles(); g_uiConfigCid = -1; PanelRebuild(); return; }
      if(name == DCA_OBJ + "b_cancel")
        { g_uiConfigCid = -1; PanelRebuild(); return; }
      if(name == DCA_OBJ + "t_uspr")
        { int i=FindCycleIndexById(g_uiConfigCid); if(i>=0){g_cycles[i].useSpreadInTP=!g_cycles[i].useSpreadInTP;} PanelRebuild(); return; }
      if(name == DCA_OBJ + "t_uswp")
        { int i=FindCycleIndexById(g_uiConfigCid); if(i>=0){g_cycles[i].useSwapInTP=!g_cycles[i].useSwapInTP;} PanelRebuild(); return; }
      if(name == DCA_OBJ + "t_smode")
        { int i=FindCycleIndexById(g_uiConfigCid); if(i>=0){g_cycles[i].swapMode=(g_cycles[i].swapMode==SWAP_AUTO?SWAP_MANUAL:SWAP_AUTO);} PanelRebuild(); return; }
      if(name == DCA_OBJ + "t_uroc")
        { int i=FindCycleIndexById(g_uiConfigCid); if(i>=0){g_cycles[i].useROCFilter=!g_cycles[i].useROCFilter;} PanelRebuild(); return; }
      if(name == DCA_OBJ + "t_ussp")
        { int i=FindCycleIndexById(g_uiConfigCid); if(i>=0){g_cycles[i].useStartSpreadFilter=!g_cycles[i].useStartSpreadFilter;} PanelRebuild(); return; }
      if(name == DCA_OBJ + "t_spm")
        { int i=FindCycleIndexById(g_uiConfigCid); if(i>=0){g_cycles[i].spacingMode=(g_cycles[i].spacingMode==1?0:1);} PanelRebuild(); return; }
      return;
     }

   // new-cycle controls
   if(name == DCA_OBJ + "ndir")
     {
      g_uiNewDir = (g_uiNewDir == DIR_LONG ? DIR_SHORT : DIR_LONG);
      PanelRebuild(); return;
     }
   if(name == DCA_OBJ + "ncreate")
     {
      string sym = ObjectGetString(0, DCA_OBJ + "nsym", OBJPROP_TEXT);
      if(sym == "") sym = Symbol();
      if(MarketInfo(sym, MODE_BID) <= 0)
        { DcaLog("Create: unknown symbol " + sym); return; }
      int idx = CreateCycle(sym, g_uiNewDir);
      if(idx >= 0) { SaveCycles(); PanelRebuild(); }
      return;
     }

   // per-cycle row buttons
   if(HandleSuffixButton(name, "cfg", cid)) { g_uiConfigCid = cid; PanelRebuild(); return; }
   if(HandleSuffixButton(name, "act", cid))
     {
      int i = FindCycleIndexById(cid);
      if(i >= 0)
        {
         if(g_cycles[i].state == ST_IDLE || g_cycles[i].state == ST_DONE) ActionActivate(g_cycles[i]);
         else ActionDeactivate(g_cycles[i]);
         SaveCycles();
        }
      PanelRebuild(); return;
     }
   if(HandleSuffixButton(name, "cls", cid))
     { int i=FindCycleIndexById(cid); if(i>=0){ShutdownCloseNow(g_cycles[i]); SaveCycles();} PanelRebuild(); return; }
   if(HandleSuffixButton(name, "stp", cid))
     { int i=FindCycleIndexById(cid); if(i>=0){ShutdownStopAfterTP(g_cycles[i]); SaveCycles();} PanelRebuild(); return; }
   if(HandleSuffixButton(name, "det", cid))
     { int i=FindCycleIndexById(cid); if(i>=0){ShutdownDetach(g_cycles[i]);} RemoveCycle(FindCycleIndexById(cid)); SaveCycles(); PanelRebuild(); return; }
   if(HandleSuffixButton(name, "del", cid))
     {
      int i = FindCycleIndexById(cid);
      if(i >= 0)
        {
         // only allow delete when not actively running
         if(g_cycles[i].state == ST_RUNNING || g_cycles[i].state == ST_WAITING || g_cycles[i].state == ST_STOP_AFTER_TP)
            DcaLog("Delete blocked: deactivate the cycle first (Close/Stop After TP/Detach).");
         else
           { RemoveCycle(i); SaveCycles(); }
        }
      PanelRebuild(); return;
     }
  }

//--- reset the toggle visual state of a clicked button
void PanelResetButton(string name)
  {
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

#endif // __DCAPRO_PANEL_MQH__
//+------------------------------------------------------------------+
