---
pattern: Return type changes unlock entire feature pipelines — when a function needs to carry more information, the fix is the return type, not a side-effecting global
date: 2026-06-03
source: rrr: innomcp (Jit)
concepts: [architecture, typescript, side-effects, design, multi-agent]
---

# Return Type Changes Unlock Pipelines

When building win tracking for the mother dispatch leaderboard, I needed to know which provider "won" the synthesis. The temptation was to add a global `lastWinnerId` variable modified inside `synthesizeResults`.

Instead: changed the return type from `Promise<string>` to `Promise<{text: string; winnerId: string | null}>`. This single change:
- Made the winner explicit and type-safe
- Enabled `dispatchMother` to call `recordProviderWin(winnerId)` immediately after synthesis
- Made `synthesizeResults` testable in isolation
- Removed hidden side effects

**Generalizable rule**: When a function's output needs to carry metadata (who produced it, when, how), change the return type. Do not add side-effecting globals or module-level state. The callee should be pure; the caller decides what to do with the result.

**Corollary**: the moment you see `let lastX = null` being set inside a function and read outside it, that's the return type trying to escape.
