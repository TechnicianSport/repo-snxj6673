# repo-snxj6673 — DCA Pro Expert Advisor (MT4)

Advanced two-direction, multi-cycle **DCA Expert Advisor** for MetaTrader 4,
built for cent accounts and 5-digit brokers, with precise volume-weighted
break-even / take-profit math, high-spread handling, full crash/disconnect
recovery, and an advanced on-chart UI.

## Layout
```
MQL4/Experts/DCA_Pro.mq4          - EA entry point
MQL4/Include/DCAPro/Defs.mqh      - enums, structs, constants
MQL4/Include/DCAPro/Utils.mqh     - pip/point, spread, ROC, swap, money/pip
MQL4/Include/DCAPro/Persistence.mqh - save/load cycles + spread map (recovery)
MQL4/Include/DCAPro/CycleManager.mqh - core cycle logic & scenarios
MQL4/Include/DCAPro/Panel.mqh     - advanced UI
docs/PLAN.md                      - full feature & math plan (FA)
docs/USAGE.md                     - install & usage (FA/EN)
```

See **docs/PLAN.md** for the complete specification and formulas, and
**docs/USAGE.md** for installation and panel usage.
