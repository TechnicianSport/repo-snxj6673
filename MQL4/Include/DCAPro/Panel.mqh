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
#define UI_Y        22
#define UI_W        470
#define UI_ROWH     24
#define UI_TITLEH   22

//--- colors ----------------------------------------------------------
#define C_BG        (color)C'28,30,38'
#define C_BAR       (color)C'40,44,58'
#define C_BTN       (color)C'55,60,78'
#define C_BTN2      (color)C'70,90,120'
#define C_GREEN     (color)C'40,120,70'
#define C_RED       (color)C'150,55,55'
#define C_TXT       clrWhite
#define C_SUB       (color)C'170,176,190'

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

void UiLabel(string name, int x, int y, string text, color clr, int fs = 9)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void UiButton(string name, int x, int y, int w, int h, string text, color bg)
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
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_SUB);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

void UiEdit(string name, int x, int y, int w, int h, string text)
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
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void UiDeleteAll()
  {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
     {
      string nm = ObjectName(0, i);
      if(StringFind(nm, DCA_OBJ) == 0)
         ObjectDelete(0, nm);
     }
  }

//=================================================================== //
//  State -> text helpers                                              //
//=================================================================== //
string StateText(CycleState s)
  {
   switch(s)
     {
      case ST_IDLE:          return("IDLE");
      case ST_WAITING:       return("WAIT");
      case ST_RUNNING:       return("RUN");
      case ST_STOP_AFTER_TP: return("STOP@TP");
      case ST_DONE:          return("DONE");
      case ST_DETACHED:      return("DETACHED");
      case ST_BLOCKED:       return("BLOCKED");
     }
   return("-");
  }

string DirText(CycleDir d) { return(d == DIR_LONG ? "LONG" : "SHORT"); }

//=================================================================== //
//  Config dialog                                                      //
//=================================================================== //
void BuildConfigDialog(int cid)
  {
   int idx = FindCycleIndexById(cid);
   if(idx < 0) return;
   Cycle c = g_cycles[idx];

   int x = UI_X, y = UI_Y, w = UI_W;
   int H = 432;
   UiRect(DCA_OBJ + "cfgbg", x, y, w, H, C_BG, C_SUB);
   UiLabel(DCA_OBJ + "cfgtitle", x + 10, y + 6,
           StringFormat("Config cycle #%d  %s %s", c.id, c.symbol, DirText(c.direction)), C_TXT, 10);

   int lx = x + 12, ex = x + 200, ew = 240, rh = 24;
   int ry = y + 34;

   UiLabel(DCA_OBJ + "l_layers", lx, ry + 4, "Layers (sp:lot,sp:lot,..):", C_SUB);
   UiEdit(DCA_OBJ + "e_layers", ex, ry, ew, 20, SerializeLayers(c)); ry += rh;

   UiLabel(DCA_OBJ + "l_btp", lx, ry + 4, "Base TP (pips):", C_SUB);
   UiEdit(DCA_OBJ + "e_btp", ex, ry, 90, 20, DoubleToString(c.baseTP, 2)); ry += rh;

   UiLabel(DCA_OBJ + "l_sl", lx, ry + 4, "Stop Loss (pips, per order):", C_SUB);
   UiEdit(DCA_OBJ + "e_sl", ex, ry, 90, 20, DoubleToString(c.slPips, 2)); ry += rh;

   UiLabel(DCA_OBJ + "l_dspr", lx, ry + 4, "Default spread (pips):", C_SUB);
   UiEdit(DCA_OBJ + "e_dspr", ex, ry, 90, 20, DoubleToString(c.defaultSpread, 2)); ry += rh;

   UiLabel(DCA_OBJ + "l_mspr", lx, ry + 4, "Max spread / park (pips):", C_SUB);
   UiEdit(DCA_OBJ + "e_mspr", ex, ry, 90, 20, DoubleToString(c.maxSpread, 2)); ry += rh;

   UiLabel(DCA_OBJ + "l_sspr", lx, ry + 4, "Start max spread (pips):", C_SUB);
   UiEdit(DCA_OBJ + "e_sspr", ex, ry, 90, 20, DoubleToString(c.startMaxSpread, 2)); ry += rh;

   UiLabel(DCA_OBJ + "l_swap", lx, ry + 4, "Swap L / S (pips/lot/night):", C_SUB);
   UiEdit(DCA_OBJ + "e_swapl", ex, ry, 90, 20, DoubleToString(c.swapLong, 2));
   UiEdit(DCA_OBJ + "e_swaps", ex + 100, ry, 90, 20, DoubleToString(c.swapShort, 2)); ry += rh;

   UiLabel(DCA_OBJ + "l_tday", lx, ry + 4, "Triple-swap day (0Sun..6Sat):", C_SUB);
   UiEdit(DCA_OBJ + "e_tday", ex, ry, 90, 20, IntegerToString(c.tripleSwapDay)); ry += rh;

   UiLabel(DCA_OBJ + "l_roc", lx, ry + 4, "ROC thr / period / TFmin:", C_SUB);
   UiEdit(DCA_OBJ + "e_rocth", ex, ry, 70, 20, DoubleToString(c.rocThreshold, 3));
   UiEdit(DCA_OBJ + "e_rocp", ex + 80, ry, 70, 20, IntegerToString(c.rocPeriod));
   UiEdit(DCA_OBJ + "e_roctf", ex + 160, ry, 70, 20, IntegerToString(c.rocTF)); ry += rh;

   UiLabel(DCA_OBJ + "l_slip", lx, ry + 4, "Slippage tol / deviation:", C_SUB);
   UiEdit(DCA_OBJ + "e_slip", ex, ry, 90, 20, DoubleToString(c.slipTolerance, 2));
   UiEdit(DCA_OBJ + "e_dev", ex + 100, ry, 90, 20, IntegerToString(c.maxDeviation)); ry += rh;

   // toggles
   UiButton(DCA_OBJ + "t_uspr", lx, ry, 130, 20,
            "Spread in TP: " + (c.useSpreadInTP ? "ON" : "OFF"), c.useSpreadInTP ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_uswp", lx + 140, ry, 130, 20,
            "Swap in TP: " + (c.useSwapInTP ? "ON" : "OFF"), c.useSwapInTP ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_smode", lx + 280, ry, 150, 20,
            "Swap: " + (c.swapMode == SWAP_AUTO ? "AUTO" : "MANUAL"), C_BTN2);
   ry += rh;
   UiButton(DCA_OBJ + "t_uroc", lx, ry, 130, 20,
            "ROC filter: " + (c.useROCFilter ? "ON" : "OFF"), c.useROCFilter ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_ussp", lx + 140, ry, 130, 20,
            "Start spread: " + (c.useStartSpreadFilter ? "ON" : "OFF"), c.useStartSpreadFilter ? C_GREEN : C_BTN);
   UiButton(DCA_OBJ + "t_spm", lx + 280, ry, 150, 20,
            "Spacing: " + (c.spacingMode == 1 ? "ABSOLUTE" : "STEP"), C_BTN2);
   ry += rh + 4;

   UiButton(DCA_OBJ + "b_save", lx, ry, 120, 24, "SAVE", C_GREEN);
   UiButton(DCA_OBJ + "b_cancel", lx + 130, ry, 120, 24, "CANCEL", C_RED);
  }

//=================================================================== //
//  Main panel                                                         //
//=================================================================== //
void PanelRebuild()
  {
   UiDeleteAll();

   int x = UI_X, y = UI_Y, w = UI_W;

   // title bar (always visible)
   UiRect(DCA_OBJ + "bar", x, y, w, UI_TITLEH, C_BAR, C_SUB);
   UiLabel(DCA_OBJ + "title", x + 8, y + 4, "DCA Pro  -  Multi-Cycle Manager", C_TXT, 10);
   UiButton(DCA_OBJ + "kill", x + w - 150, y + 2, 120, 18,
            g_masterEnabled ? "TRADING: ON" : "TRADING: OFF",
            g_masterEnabled ? C_GREEN : C_RED);
   UiButton(DCA_OBJ + "min", x + w - 26, y + 2, 22, 18, g_uiMinimized ? "+" : "_", C_BTN);

   if(g_uiMinimized)
      return;

   if(g_uiConfigCid >= 0)
     {
      BuildConfigDialog(g_uiConfigCid);
      return;
     }

   // body background
   int rows = g_cycleCount;
   int bodyH = 40 + (rows + 1) * UI_ROWH + 30;
   UiRect(DCA_OBJ + "body", x, y + UI_TITLEH, w, bodyH, C_BG, C_SUB);

   // new-cycle controls
   int ny = y + UI_TITLEH + 8;
   UiLabel(DCA_OBJ + "nl", x + 8, ny + 4, "New:", C_SUB);
   if(g_uiNewSymbol == "") g_uiNewSymbol = Symbol();
   UiEdit(DCA_OBJ + "nsym", x + 44, ny, 110, 20, g_uiNewSymbol);
   UiButton(DCA_OBJ + "ndir", x + 162, ny, 80, 20, DirText(g_uiNewDir),
            g_uiNewDir == DIR_LONG ? C_GREEN : C_RED);
   UiButton(DCA_OBJ + "ncreate", x + 250, ny, 90, 20, "CREATE", C_BTN2);
   UiLabel(DCA_OBJ + "acc", x + 350, ny + 4,
           StringFormat("Orders %d/%d", TotalLiveOrders(), g_accountMaxOrders), C_SUB);

   // header row
   int hy = ny + UI_ROWH + 2;
   UiLabel(DCA_OBJ + "hdr", x + 8, hy, "#  SYMBOL  DIR  STATE   POS   PnL        BE / TP", C_SUB, 8);

   // cycle rows
   int ry = hy + 18;
   for(int i = 0; i < g_cycleCount; i++)
     {
      Cycle c = g_cycles[i];
      string sfx = IntegerToString(c.id);
      UiLabel(DCA_OBJ + "row" + sfx, x + 8, ry + 4, "...", C_TXT, 8);
      int bx = x + 250;
      UiButton(DCA_OBJ + "cfg" + sfx, bx, ry, 34, 20, "Cfg", C_BTN);          bx += 36;
      UiButton(DCA_OBJ + "act" + sfx, bx, ry, 34, 20,
               (c.state == ST_WAITING || c.state == ST_RUNNING || c.state == ST_STOP_AFTER_TP) ? "Off" : "On",
               (c.state == ST_IDLE || c.state == ST_DONE) ? C_GREEN : C_BTN);  bx += 36;
      UiButton(DCA_OBJ + "cls" + sfx, bx, ry, 40, 20, "Close", C_RED);         bx += 42;
      UiButton(DCA_OBJ + "stp" + sfx, bx, ry, 44, 20, "Stp@TP", C_BTN);        bx += 46;
      UiButton(DCA_OBJ + "det" + sfx, bx, ry, 40, 20, "Detach", C_BTN);        bx += 42;
      UiButton(DCA_OBJ + "del" + sfx, bx, ry, 30, 20, "Del", C_BTN);
      ry += UI_ROWH;
     }

   // status / log feed (most recent first)
   int ly = ry + 6;
   UiLabel(DCA_OBJ + "logh", x + 8, ly, "Activity log:", C_SUB, 8); ly += 16;
   for(int k = 0; k < 4; k++)
     {
      UiLabel(DCA_OBJ + "log" + IntegerToString(k), x + 14, ly, DcaLogLine(k), C_SUB, 8);
      ly += 14;
     }
  }

//--- update only the dynamic text (no rebuild -> no flicker / focus loss)
void PanelRefresh()
  {
   if(g_uiMinimized || g_uiConfigCid >= 0) return;
   ObjectSetString(0, DCA_OBJ + "acc", OBJPROP_TEXT,
                   StringFormat("Orders %d/%d", TotalLiveOrders(), g_accountMaxOrders));
   for(int k = 0; k < 4; k++)
      ObjectSetString(0, DCA_OBJ + "log" + IntegerToString(k), OBJPROP_TEXT, DcaLogLine(k));
   for(int i = 0; i < g_cycleCount; i++)
     {
      Cycle c = g_cycles[i];
      double pnl = ComputeLivePnL(c);
      string row = StringFormat("%d  %-8s %-5s %-7s %2d   %s%.2f   %s/%s",
                     c.id, c.symbol, DirText(c.direction), StateText(c.state),
                     c.openPositions, (pnl >= 0 ? "+" : ""), pnl,
                     (c.currentBE > 0 ? DoubleToString(c.currentBE, SymDigits(c.symbol)) : "-"),
                     (c.currentTP > 0 ? DoubleToString(c.currentTP, SymDigits(c.symbol)) : "-"));
      ObjectSetString(0, DCA_OBJ + "row" + IntegerToString(c.id), OBJPROP_TEXT, row);
      ObjectSetInteger(0, DCA_OBJ + "row" + IntegerToString(c.id), OBJPROP_COLOR,
                       pnl >= 0 ? (color)C'120,210,140' : (color)C'235,140,140');
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
   g_cycles[idx].slPips         = EditD("e_sl");
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
   // Stop-Loss is mandatory: every order must carry one to be accepted.
   if(g_cycles[idx].slPips <= 0.0)
     {
      g_cycles[idx].slPips = 50.0;
      DcaLog(StringFormat("cid=%d Stop Loss must be > 0; reset to default 50 pips.", cid));
     }
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
            DcaLog("Delete blocked: deactivate the cycle first (Close/Stp@TP/Detach).");
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
