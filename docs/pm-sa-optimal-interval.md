# PM-SA Loop — Optimal Interval via Calculus

## Problem

Find T* = optimal loop interval (minutes) that maximises **value/token** ratio.

## Cost Model

Each dispatcher run costs:
- 7 × haiku agents: ~2,000 tokens each = 14,000 tokens
- 1 × sonnet coordinator: ~3,000 tokens  
- Main bash loop: ~0 tokens
- **Total C = 17,000 tokens/run**

Token cost rate (tokens per minute): `f(T) = C / T`

## Value Model

New tickets discovered per run:
- Run 1–3: N ≈ 15–20 (fresh discovery)
- Run 4–10: N ≈ 8–12 (diminishing returns, new areas)
- Run 11+: N ≈ 3–5 (maintenance, fine-grained gaps)

Value rate: `g(T) = N(run) × V_ticket / T`

Where `V_ticket` = development-hours saved (treated as constant unit).

## Overlap Penalty (key constraint)

Sub-agent completion time: `T_run ≈ 2–3 minutes` (haiku parallel, file I/O included)

For `T < T_run`: new batch launches before old one finishes.  
Wasted fraction = `1 - T/T_run`  
Effective cost: `f_eff(T) = C/T × (T_run/T) = C·T_run / T²`  ← **quadratic blowup**

For `T ≥ T_run`: no overlap, `f_eff(T) = C/T`

## Optimisation

**Net value rate**: `V_net(T) = g(T) - f_eff(T)`

Taking derivative and setting to zero in each region:

**Region 1: T < T_run**
```
dV_net/dT = -N·V/T² + 2C·T_run/T³ = 0
→ T* = 2·C·T_run / (N·V)
```
This gives T* < T_run only if `N·V > 2C` — i.e. ticket value >> token cost.
Since tokens are cheap and tickets are high value, T* in this region → small, but bounded below by T_run.

**Region 2: T ≥ T_run (practical region)**
```
dV_net/dT = -N·V/T² + C/T² = 0
→ N·V = C  ← tickets stop being worth running when N → C/V
```
Below this crossover, run as often as possible (T = T_run).
Above this crossover (N < C/V), stop the loop.

## Result

```
T* = max(T_run, T_diminishing_returns)
   = max(3 min, onset of N < C/V)

Early iterations (N > 10):  T* = T_run ≈ 3 min → use 5 min (2× safety)
Middle iterations (N ≈ 5):  T* = 5–10 min
Late iterations (N < 2):    T* → stop or switch to daily cadence
```

**Recommended schedule**:
```
Iter  1–5:   every 5 min   (active discovery)
Iter  6–15:  every 15 min  (refinement)
Iter 16–30:  every 60 min  (maintenance)
Iter 31+:    daily         (or on-demand)
```

## Adaptive Rule (implemented in skill)

```bash
TICKET_COUNT=$(ls tickets/open/ | wc -l)
if   [ $TICKET_COUNT -lt  30 ]; then INTERVAL=5m   # active discovery
elif [ $TICKET_COUNT -lt  60 ]; then INTERVAL=15m  # refinement
elif [ $TICKET_COUNT -lt 100 ]; then INTERVAL=60m  # maintenance
else                                  INTERVAL=daily # saturated
fi
```

## Token Savings vs 1-minute loop

| Mode | Runs/hour | Tokens/hour | Useful runs |
|------|-----------|-------------|-------------|
| 1m (old) | 60 | 1,020,000 | ~12 (rest overlap) |
| 5m (T*) | 12 | 204,000 | 12 (all complete) |
| 15m | 4 | 68,000 | 4 |

**5m saves 80% tokens vs 1m with identical output.**

Generated: 2026-06-07 · PM+SA Optimal Interval Analysis
