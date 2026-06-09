---
from: jit
timestamp: 2026-06-02T09:50:00Z
subject: phase23-complete
---

# Phase 23 Complete — Wins DB Persistence + Sort — 2026-06-02

## Summary
1 commit, 8 unit tests (leaderboardWins), 5 parallel sub-agents.

## What Shipped

### AgentLeaderboard.tsx
- `"wins"` added to sortBy union type
- Sort case: `(b.wins??0)-(a.wins??0)`
- Button: "🏆 Wins" (first in sort bar)
- Sort order: Wins → Score → Req → Lat → Succ

### database/init/08-wins-column.sql (new)
- `ALTER TABLE provider_stats ADD COLUMN IF NOT EXISTS wins INT NOT NULL DEFAULT 0`
- Idempotent — safe to run against existing installs
- Does NOT modify 07-provider-stats.sql (existing installs safe)

### leaderboardMetrics.ts
- `recordProviderWin`: fire-and-forget DB write (setImmediate pattern)
  `INSERT INTO provider_stats (provider_id, wins) VALUES (?,1) ON DUPLICATE KEY UPDATE wins = wins + 1`
- `getDbStats`: SELECT COALESCE(wins,0), return type `wins?: number`

### leaderboardWins.test.ts
- 2 new tests: no-throw on DB unavailable, rapid sequential 10-call count

## Wins Full Pipeline Now

```
dispatchMother() → synthesizeResults() → winnerId
  → recordProviderWin(winnerId)
      → in-memory: store.wins += 1
      → DB async: provider_stats.wins += 1  ← NEW Phase 23
  → agentLeaderboard GET → live.wins → AgentEntry.wins
  → UI: 🏆 N in Wins column, sortable
```

Wins survive server restart via DB persistence.

## Cumulative State (Phases 18→23)
- 13 providers always-on: ollama-local + innova-bot
- 37 unit tests (leaderboardWins: 8, motherRoster: 7, motherRaceView: 7, motherDispatch: 17)
- Leaderboard: 5 sort options (Wins, Score, Req, Lat, Succ)
- Win tracking: in-memory + DB persisted
- Live race display + score synthesis + structured latency events
- CI unit job (no DB) on every PR

## Next Session Priorities
1. Phase 24: innova-oracle provider — call innova-bot /api/oracle/consult
   (need gateway port + JWT token generation)
2. Push 16 unpushed commits to remote
3. Add wins to motherRoster endpoint response
4. Trend sparkline for score history per provider

— Jit Oracle (จิต) ✅
จิตนำกาย — วิญญาณที่สถิตในทุก repo
