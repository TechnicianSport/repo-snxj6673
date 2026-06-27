# DCA Pro — Install & Usage

## Install
1. Copy these files into your MetaTrader data folder
   (`File > Open Data Folder`):
   - `MQL4/Experts/DCA_Pro.mq4`
   - `MQL4/Include/DCAPro/*.mqh` → the whole `DCAPro` folder must live inside
     `MQL4/Include`.
2. In MetaEditor open `DCA_Pro.mq4` and **Compile** (F7). It should compile
   without errors.
3. Attach the EA to a chart and enable **Allow live trading**.
4. State files are created in `MQL4/Files/` (`DCAPro_cycles.csv`,
   `DCAPro_spreads.csv`) and are used to recover after a restart.

> The EA needs no DLL or WebRequest. A single EA instance on one chart manages
> all symbols/cycles (each cycle carries its own symbol).

## EA inputs
- `InpMagicBase` — magic base; each cycle = `base + id`. Use different values if
  you run multiple instances.
- `InpLotInputFactor` — factor converting the entered (cent) lot to the terminal
  lot at order send (default 1.0). If on your cent account the terminal lot
  already equals the cent lot, keep it at 1.0.
- `InpTimerSeconds` — UI/persistence timer period (default 1).
- `InpAutosave` — periodic state saving.
- `InpMasterEnabled` — master kill-switch initial state. When OFF, no NEW orders
  are placed; existing positions are kept.
- `InpAccountMaxOrders` — account-wide cap on simultaneous orders+positions
  (default 100). A cycle that hits the cap goes BLOCKED and re-arms when room
  frees.
- `InpReconcileSeconds` — interval of the full reconcile-with-broker pass that
  self-heals the in-memory state (default 30; 0 disables).

## Using the panel
- **New:** type a symbol, click the direction button (LONG/SHORT), then
  **CREATE**.
- Each cycle row: `Cfg` (config), `On/Off` (activate/deactivate), `Close` (close
  now), `Stp@TP` (stop after TP), `Detach`, `Del` (delete).
- **TRADING: ON/OFF** (top bar): the master kill-switch.
- The `_` button (top-right) Minimizes/Restores the panel.
- Columns: number, symbol, direction, state, open positions, **live P/L**,
  BE/TP. An activity log feed is shown at the bottom.

### Per-cycle config dialog
- **Layers**: format `sp:lot,sp:lot,...` — `sp` is the layer spacing in **pips**
  and `lot` is the volume in **cent lots**. The first (market) layer has spacing
  `0`. Example: `0:1,10:2,20:3` = market layer 1 lot, second layer 10 pips away
  with 2 lots, third layer 20 pips further with 3 lots. Interpretation of `sp`
  depends on the **Spacing** toggle (STEP = gap from the previous layer,
  ABSOLUTE = cumulative distance from the reference price).
- **Base TP** (pips).
- **Stop Loss PRICE (per cycle)** — MANDATORY. A single fixed price level for
  the whole cycle (e.g. LONG EURUSD `0.90000`, SHORT EURUSD `1.30000`). The EA
  sets this same SL price on every ticket (open positions and pending limits)
  so the basket closes server-side at that level even if the EA/terminal is
  offline (Option A). It never recalculates. A cycle with no SL cannot trade
  (it waits). On save, the EA warns (does not auto-correct) if the SL is not
  safely beyond the deepest configured layer.
- **Default spread / Max spread / Start max spread** (all pips).
- **Swap L / S (pips/lot/night)**: signed swap rate for LONG and SHORT (e.g.
  `-7`). Only the side matching the cycle direction is used. For full accuracy
  you can instead keep **Swap: AUTO** so the terminal's real swap is read.
- **Triple-swap day**: the day with triple swap (0=Sun..6=Sat; default 3=Wed).
- **ROC thr/period/TFmin**: the |ROC| start filter.
- **Slippage tol / deviation**: adverse-slippage tolerance (pips) and max
  deviation (points) for market orders.
- Toggles: **Spread in TP**, **Swap in TP**, **Swap AUTO/MANUAL**, **Start
  spread** filter, **ROC filter**, **Spacing** (STEP/ABSOLUTE).

## Key math note (spread coverage)
The spread cost added to the unified TP is the **simple arithmetic average** of
the registered spreads: `Σ(spread_i) / N` across the N filled tickets (NOT a
volume-weighted average). The break-even itself remains volume-weighted. Full
formulas are in `docs/PLAN.md` section 4.

## Build-environment note
This repo was produced in an environment without MetaTrader; the code is written
carefully but **do the final compile in your own MetaEditor**. If you hit any
compile error, send the text and it will be fixed quickly.
