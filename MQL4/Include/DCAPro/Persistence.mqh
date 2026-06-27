//+------------------------------------------------------------------+
//|                                                  Persistence.mqh |
//|     DCA Pro - save/load cycles & ticket->spread map to files       |
//+------------------------------------------------------------------+
#property strict

#ifndef __DCAPRO_PERSIST_MQH__
#define __DCAPRO_PERSIST_MQH__

#include "Defs.mqh"
#include "Utils.mqh"
#include "CycleManager.mqh"

//--- serialize the layer table as "sp:lot,sp:lot,..."
string SerializeLayers(const Cycle &c)
  {
   string s = "";
   for(int i = 0; i < c.layerCount; i++)
     {
      if(i > 0) s += ",";
      s += StringFormat("%.5f:%.2f", c.spacing[i], c.lots[i]);
     }
   return(s);
  }

void DeserializeLayers(Cycle &c, const string s)
  {
   string items[];
   int n = StringSplit(s, ',', items);
   c.layerCount = 0;
   for(int i = 0; i < n && i < DCA_MAX_LAYERS; i++)
     {
      string kv[];
      if(StringSplit(items[i], ':', kv) == 2)
        {
         c.spacing[i] = StringToDouble(kv[0]);
         c.lots[i]    = StringToDouble(kv[1]);
         c.layerCount++;
        }
     }
  }

//+------------------------------------------------------------------+
//| Save all cycles                                                  |
//+------------------------------------------------------------------+
void SaveCycles()
  {
   int h = FileOpen(DCA_FILE_CYC, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) { DcaLog("SaveCycles: open failed " + IntegerToString(GetLastError())); return; }
   FileWriteString(h, "DCAPRO_V2\n");
   FileWriteString(h, IntegerToString(g_nextId) + "\n");
   for(int i = 0; i < g_cycleCount; i++)
     {
      Cycle c = g_cycles[i];
      if(c.state == ST_DETACHED) continue; // not managed anymore
      string line = StringFormat(
         "%d\t%d\t%s\t%d\t%d\t%.5f\t%.5f\t%.5f\t%.5f\t%.5f\t%d\t%d\t%d\t%d\t%.5f\t%.5f\t%d\t%d\t%.5f\t%d\t%d\t%.5f\t%d\t%d\t%.5f\t%.5f\t%d\t%s",
         c.id, c.magic, c.symbol, (int)c.direction, (int)c.state,
         c.baseTP, c.slPrice, c.defaultSpread, c.maxSpread, c.startMaxSpread,
         (c.useStartSpreadFilter ? 1 : 0), (c.useSpreadInTP ? 1 : 0), (c.useSwapInTP ? 1 : 0), (int)c.swapMode,
         c.swapLong, c.swapShort, c.tripleSwapDay, (c.useROCFilter ? 1 : 0),
         c.rocThreshold, c.rocPeriod, c.rocTF, c.slipTolerance, c.maxDeviation,
         c.spacingMode, c.referencePrice, c.pushOffsetPips, (c.limitsParked ? 1 : 0), SerializeLayers(c));
      FileWriteString(h, line + "\n");
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Load all cycles (config + identity + state)                      |
//+------------------------------------------------------------------+
bool LoadCycles()
  {
   if(!FileIsExist(DCA_FILE_CYC)) return(false);
   int h = FileOpen(DCA_FILE_CYC, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return(false);

   string magicHdr = FileReadString(h);
   bool isV2 = (StringFind(magicHdr, "DCAPRO_V2") >= 0);
   bool isV1 = (StringFind(magicHdr, "DCAPRO_V1") >= 0);
   if(!isV2 && !isV1) { FileClose(h); return(false); }
   g_nextId = (int)StringToInteger(FileReadString(h));

   g_cycleCount = 0;
   ArrayResize(g_cycles, 0);

   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(StringLen(line) < 5) continue;
      string f[];
      int n = StringSplit(line, '\t', f);
      int idx = g_cycleCount;
      ArrayResize(g_cycles, idx + 1);
      InitCycleDefaults(g_cycles[idx]);
      if(isV2)
        {
         if(n < 28) { ArrayResize(g_cycles, idx); continue; }
         g_cycles[idx].id            = (int)StringToInteger(f[0]);
         g_cycles[idx].magic         = (int)StringToInteger(f[1]);
         g_cycles[idx].symbol        = f[2];
         g_cycles[idx].direction     = (CycleDir)(int)StringToInteger(f[3]);
         g_cycles[idx].state         = (CycleState)(int)StringToInteger(f[4]);
         g_cycles[idx].baseTP        = StringToDouble(f[5]);
         g_cycles[idx].slPrice       = StringToDouble(f[6]);
         g_cycles[idx].defaultSpread = StringToDouble(f[7]);
         g_cycles[idx].maxSpread     = StringToDouble(f[8]);
         g_cycles[idx].startMaxSpread= StringToDouble(f[9]);
         g_cycles[idx].useStartSpreadFilter = (StringToInteger(f[10]) != 0);
         g_cycles[idx].useSpreadInTP = (StringToInteger(f[11]) != 0);
         g_cycles[idx].useSwapInTP   = (StringToInteger(f[12]) != 0);
         g_cycles[idx].swapMode      = (SwapMode)(int)StringToInteger(f[13]);
         g_cycles[idx].swapLong      = StringToDouble(f[14]);
         g_cycles[idx].swapShort     = StringToDouble(f[15]);
         g_cycles[idx].tripleSwapDay = (int)StringToInteger(f[16]);
         g_cycles[idx].useROCFilter  = (StringToInteger(f[17]) != 0);
         g_cycles[idx].rocThreshold  = StringToDouble(f[18]);
         g_cycles[idx].rocPeriod     = (int)StringToInteger(f[19]);
         g_cycles[idx].rocTF         = (int)StringToInteger(f[20]);
         g_cycles[idx].slipTolerance = StringToDouble(f[21]);
         g_cycles[idx].maxDeviation  = (int)StringToInteger(f[22]);
         g_cycles[idx].spacingMode   = (int)StringToInteger(f[23]);
         g_cycles[idx].referencePrice= StringToDouble(f[24]);
         g_cycles[idx].pushOffsetPips= StringToDouble(f[25]);
         g_cycles[idx].limitsParked  = (StringToInteger(f[26]) != 0);
         DeserializeLayers(g_cycles[idx], f[27]);
        }
      else // legacy V1 (no SL / swap-long-short / spacing-mode): use defaults
        {
         if(n < 23) { ArrayResize(g_cycles, idx); continue; }
         g_cycles[idx].id            = (int)StringToInteger(f[0]);
         g_cycles[idx].magic         = (int)StringToInteger(f[1]);
         g_cycles[idx].symbol        = f[2];
         g_cycles[idx].direction     = (CycleDir)(int)StringToInteger(f[3]);
         g_cycles[idx].state         = (CycleState)(int)StringToInteger(f[4]);
         g_cycles[idx].baseTP        = StringToDouble(f[5]);
         g_cycles[idx].defaultSpread = StringToDouble(f[6]);
         g_cycles[idx].maxSpread     = StringToDouble(f[7]);
         g_cycles[idx].startMaxSpread= StringToDouble(f[8]);
         g_cycles[idx].useSpreadInTP = (StringToInteger(f[9]) != 0);
         g_cycles[idx].useSwapInTP   = (StringToInteger(f[10]) != 0);
         g_cycles[idx].swapMode      = (SwapMode)(int)StringToInteger(f[11]);
         g_cycles[idx].swapLong      = StringToDouble(f[12]);
         g_cycles[idx].swapShort     = StringToDouble(f[12]);
         g_cycles[idx].tripleSwapDay = (int)StringToInteger(f[13]);
         g_cycles[idx].useROCFilter  = (StringToInteger(f[14]) != 0);
         g_cycles[idx].rocThreshold  = StringToDouble(f[15]);
         g_cycles[idx].rocPeriod     = (int)StringToInteger(f[16]);
         g_cycles[idx].rocTF         = (int)StringToInteger(f[17]);
         g_cycles[idx].slipTolerance = StringToDouble(f[18]);
         g_cycles[idx].maxDeviation  = (int)StringToInteger(f[19]);
         g_cycles[idx].referencePrice= StringToDouble(f[20]);
         g_cycles[idx].pushOffsetPips= StringToDouble(f[21]);
         DeserializeLayers(g_cycles[idx], f[22]);
        }
      g_cycleCount++;
     }
   FileClose(h);
   return(true);
  }

//+------------------------------------------------------------------+
//| Save / load ticket -> spread map                                 |
//+------------------------------------------------------------------+
void SaveSpreadMap()
  {
   int h = FileOpen(DCA_FILE_SPR, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   for(int i = 0; i < ArraySize(g_sprTicket); i++)
      FileWriteString(h, StringFormat("%d\t%.5f\n", g_sprTicket[i], g_sprValue[i]));
   FileClose(h);
  }

void LoadSpreadMap()
  {
   ArrayResize(g_sprTicket, 0);
   ArrayResize(g_sprValue, 0);
   if(!FileIsExist(DCA_FILE_SPR)) return;
   int h = FileOpen(DCA_FILE_SPR, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(StringLen(line) < 3) continue;
      string f[];
      if(StringSplit(line, '\t', f) == 2)
        {
         int n = ArraySize(g_sprTicket);
         ArrayResize(g_sprTicket, n + 1);
         ArrayResize(g_sprValue, n + 1);
         g_sprTicket[n] = (int)StringToInteger(f[0]);
         g_sprValue[n]  = StringToDouble(f[1]);
        }
     }
   FileClose(h);
  }

#endif // __DCAPRO_PERSIST_MQH__
//+------------------------------------------------------------------+
