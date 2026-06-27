# DCA Pro — MetaTrader 4 Expert Advisor (Comprehensive Plan)

This document is the full specification of the EA: features, scenarios and the
exact math. Goal: a two-direction, multi-cycle, fault-tolerant DCA EA with an
advanced UI and precise calculations on a **cent account** and a **5-digit
broker**.

> All example numbers in the original request were illustrative; the logic and
> formulas are implemented for mathematical correctness, not for the sample
> numbers.

---

## 1) Core concepts and unit conversion (cent account + 5-digit)

- 5-digit broker: `Point = 0.00001`, **1 pip = 10 points = 0.0001**.
  - For 3-digit JPY pairs the pip is `0.01` and the point is `0.001`; the code
    detects this automatically from `Digits`.
- Cent account:
  - `1 cent lot = 0.01 standard lot`
  - `0.01 cent lot = 0.0001 standard lot`
- For full precision the code reads the **money value of one pip directly from
  the terminal** (`MarketInfo(MODE_TICKVALUE)` and `MODE_TICKSIZE`) so it is
  correct on any account type and any symbol. User volumes are entered in cent
  lots and mapped to OrderSend lots via `InpLotInputFactor` (default 1.0).

## 2) Cycle structure

Each cycle is an independent unit with:
- `symbol`, `direction` (LONG/SHORT).
- Layers: an array of `(spacing_pips, lot)` entries. Spacing is interpreted by
  `spacingMode`: **step** (gap from the previous layer) or **absolute**
  (cumulative distance from the reference price).
- `baseTP` (pips), **`slPips` (mandatory per-cycle fixed stop-loss in pips)**,
  `defaultSpread`, `maxSpread`, `startMaxSpread`, `useStartSpreadFilter`,
  `useSpreadInTP`, `useSwapInTP`, swap parameters (`swapLong`/`swapShort`,
  `swapMode`, `tripleSwapDay`), ROC start-filter parameters.
- Each cycle owns a **unique magic number** (`MagicBase + id`); all tracking and
  recovery is keyed on magic + the order comment (`DCAP|cycleId|layer`).
- Multiple same-direction cycles on one symbol are allowed (e.g. 2 long + 3
  short on EURUSD); each is managed completely independently.

## 3) Cycle lifecycle

1. User picks symbol + direction, creates the cycle, configures and saves it,
   then **Activates** it.
2. Start filters are checked (section 7). If OK, the **layer-0 market order** is
   opened.
3. The real fill price of layer 0 becomes the reference for laying out the
   remaining DCA limit orders (limits are placed relative to the real fill
   price, not the price at submission time).
4. Every time a layer fills, the volume-weighted break-even and the single
   unified final TP of **all** open positions are recomputed and pushed to every
   ticket.
5. When price reaches the unified TP the whole cycle closes and the **next
   generation starts automatically with the same config** (unless a shutdown
   mode was applied).

## 4) The math core

Notation: for open position `i` with entry `e_i`, volume `v_i` (lots) and the
spread recorded at its fill `s_i` (pips), across `N` open positions.

- **Volume-weighted break-even:**
  ```
  BE = Σ(e_i · v_i) / Σ(v_i)
  ```
- **Spread cost — SIMPLE average (corrected):** the spread distance added to TP
  is the simple arithmetic mean of the registered spreads, NOT a
  volume-weighted average:
  ```
  spreadDist = Σ(s_i) / N        (pips)
  ```
  This matches the requirement: as more volume is added the per-unit spread
  cost is diluted, and the unified TP only needs to cover the average registered
  spread across the filled tickets.
- **Swap cost (only when negative):**
  ```
  swapMoney = Σ OrderSwap()_i                         (AUTO mode)
            = Σ [ v_i · moneyPerPipPerLot · rate · nightsHeld_i ]   (MANUAL)
  swapDist  = max(0, -swapMoney) / (Σv_i · moneyPerPipPerLot)       (pips)
  ```
  where `rate` is `swapLong` for a LONG cycle and `swapShort` for a SHORT cycle
  (pips per 1.0 lot per night), and `nightsHeld_i` includes triple-swap-day
  weighting (section 5). Positive swap is ignored (only negative swap is
  covered).
- **TP distance from BE:**
  ```
  tpDist = baseTP + (useSpreadInTP ? spreadDist : 0) + (useSwapInTP ? swapDist : 0)
  ```
- **Unified final TP price (identical for every position in the cycle):**
  ```
  LONG : TP = BE + tpDist · pip
  SHORT: TP = BE − tpDist · pip
  ```
- **Order-of-operations rule:** every time a layer transitions from pending to
  open — for ANY reason (normal grid fill OR the spread-spike market recovery
  fill) — the EA, in this exact order: (1) re-reads the real fill price and real
  spread for that ticket, (2) recomputes BE, (3) recomputes the simple-average
  spread cost, (4) recomputes swap cost, (5) recomputes the unified TP price,
  (6) pushes that TP to every open ticket AND refreshes the provisional TP on
  every still-pending limit of the cycle. There is exactly one TP-recalculation
  pipeline, always triggered the same way.

### Mandatory per-cycle stop-loss
Every order — market or limit — is submitted with a fixed stop-loss placed
`slPips` away from **its own entry price**, in the loss direction. The SL is
fixed for the life of the cycle and is preserved on every TP `OrderModify`.
`slPips` must be > 0; the config dialog rejects a zero/blank value and falls
back to the default (50 pips). A single basket-wide SL price is intentionally
NOT used, because grid layers fill at different prices and a shared SL price
would be geometrically invalid for the deeper layers.

### Not-yet-filled limits
Because the spread/slippage at fill time is unknown, a pending limit is given a
provisional TP using `defaultSpread` (MT4 requires a valid TP/SL on the order).
As soon as it fills, the real spread is registered and the unified TP of all
positions is recomputed. Provisional TP/SL on resting limits is also refreshed
on every recompute.

### Slippage
If the realized fill is adverse by up to `slipTolerance` pips, no correction is
needed; the unified TP recompute always anchors to the real fill price anyway,
so any larger deviation is absorbed automatically. Adverse slippage beyond the
tolerance is logged.

## 5) Swap calculation

```
SwapMoney_dollars = Lots × MoneyPerPipPerLot × SwapRate(pips/lot/night) × NightsHeld
```
- The Wed→Thu rollover is charged triple (configurable `tripleSwapDay`,
  0=Sun..6=Sat). `NightsHeld` accrues from the position open time to now and
  applies the triple weighting on the configured day.
- The user enters the signed swap rate (e.g. `-7`) for LONG and SHORT
  separately; only the side matching the cycle direction is used, but both are
  stored so the config is reusable if the cycle is cloned to the opposite side.
  `SWAP_AUTO` instead reads the broker's actual `OrderSwap()`. Negative swap is
  converted to pips and added to `tpDist`.
- On each broker day rollover the swap-driven TP is recomputed once even without
  a new fill.

## 6) Very-high-spread scenarios

- **Temporary parking of forward limits:** if the spread exceeds `maxSpread`,
  the forward (not-yet-filled) limit orders of the cycle are temporarily
  cancelled, but their full specs (price level, volume, TP, layer index) are
  kept in memory/file. When the spread returns to normal, the same orders are
  re-placed.
- **Reposition in the profit direction:** if, during the high-spread window,
  price crossed the nearest parked limit and is now deeper, that nearest skipped
  limit is filled at **market**; the real fill price is taken, BE and the
  unified TP are recomputed, and the remaining layers are shifted by the
  overshoot so their base spacing is preserved from the new market fill.
- Hence **market** orders happen in exactly two places: (a) the start of each
  cycle (layer 0), and (b) the high-spread nearest-skipped-layer recovery fill.

## 7) Start/continue filters

1. **Spread:** if `useStartSpreadFilter` is on and the spread is above
   `startMaxSpread` at start time, the cycle does not start (it stays Waiting)
   until the spread returns to range.
2. **ROC:** if `|ROC|` on the configured timeframe (default M15) exceeds the
   threshold (default 0.28), the cycle waits.
   - `ROC = (Close[0] − Close[period]) / Close[period] × 100`.

## 8) Cycle shutdown modes

1. **Close Now:** immediately close all positions of the cycle at market.
2. **Stop After TP:** the cycle runs until the current TP is hit, then
   deactivates; the next generation is not started. The state is shown clearly
   in the UI.
3. **Detach:** control is removed from the orders; positions/limits and their
   TPs are left untouched and the cycle is removed from the UI list.
- A cycle must first be deactivated by one of the three modes above, then
  **deleted** from the panel.

## 9) Recovery after MT4 restart / disconnect

- Before every event, the config + state of all cycles and the
  `ticket → spread` map are saved to file. On return, the code rebuilds and
  re-tracks cycles by scanning orders by magic, and continues under the normal
  rules.
- A periodic full reconciliation pass and a reconnect detector re-sync the
  in-memory state with the live order pool (self-healing against missed events).
- If a cycle's unified TP was hit server-side while the EA was off: the unused
  limits of that cycle are deleted and the cycle is **deactivated** for manual
  re-activation (clear message: "TP done; ready to restart").
- If TP was not hit: the cycle keeps and manages its positions/limits as usual
  until TP, then auto-starts the next generation.

## 10) Account-wide order cap

- The account allows at most 100 simultaneous orders+positions. The EA tracks
  this (`InpAccountMaxOrders`). A cycle that cannot place an order because the
  cap is full moves to the **BLOCKED** state and automatically re-arms once room
  frees.

## 11) Master kill-switch

- A global `TRADING: ON/OFF` switch on the panel. When OFF, the EA places no
  NEW orders (no new cycles, no new limits, no recovery market fills) but keeps
  all existing positions and their TP/SL management intact.

## 12) Advanced UI

- Main panel: create cycle (symbol + direction), Activate/Save/Delete,
  Close Now / Stop-After-TP / Detach buttons, master kill-switch,
  Minimize/Restore, account order counter, and an activity log feed.
- Each cycle row: symbol, direction, state, live aggregate P/L, open-position
  count, current BE and unified TP.
- Per-cycle config dialog: layer table (spacing pips + lot), baseTP,
  **Stop Loss (pips)**, defaultSpread, maxSpread, startMaxSpread, swap L/S,
  triple-swap day, ROC threshold/period/TF, slippage/deviation, and toggles for
  spread-in-TP, swap-in-TP, swap AUTO/MANUAL, start-spread filter, ROC filter,
  and spacing mode (step/absolute).

## 13) File layout

```
MQL4/Experts/DCA_Pro.mq4            — entry point (OnInit/OnTick/OnTimer/OnChartEvent)
MQL4/Include/DCAPro/Defs.mqh        — enums / struct / constants
MQL4/Include/DCAPro/Utils.mqh       — pip/point, spread, ROC, swap, money/pip, log
MQL4/Include/DCAPro/Persistence.mqh — save/load cycles & spread map
MQL4/Include/DCAPro/CycleManager.mqh— core cycle logic and scenarios
MQL4/Include/DCAPro/Panel.mqh       — UI
```

## 14) Notes / limitations

- This environment has no MetaTrader; the code is written carefully but the
  final compile must be done in your MetaEditor (F7). Send any compile errors
  and they will be fixed quickly.
