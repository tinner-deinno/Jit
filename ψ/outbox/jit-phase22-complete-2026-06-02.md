---
from: jit
timestamp: 2026-06-02T09:45:00Z
subject: phase22-complete
---

# Phase 22 Complete — Win Tracking + Score Sort + Wins Column — 2026-06-02

## Summary
2 commits, 36 unit tests passing, 5 parallel sub-agents.

## Phase 22-A — Leaderboard UI (1 commit)
- `sortBy` union: added `"score"` → sort button "↓ Score" appears first
- Sort logic: `(b.score??0)-(a.score??0)`
- `AgentEntry.wins?: number`
- Wins column in table: 🏆 N (yellow) when won, — when zero
- CSV export: "Score,Wins,Role" + agent.wins value
- colSpan 11→12 for empty-state row

## Phase 22-B/C/D/E — Win Tracking Backend (1 commit)

### leaderboardMetrics.ts
- `RawStats.wins: number` + `ProviderStats.wins: number`
- `recordProviderCall` initializes `wins: 0`
- `recordProviderWin(providerId)` — exported, increments or creates
- `getProviderStats()` returns `wins: raw.wins`
- Export object: 4 → 5 methods

### motherDispatch.ts
- `synthesizeResults` return type: `string` → `{ text: string; winnerId: string | null }`
- All 5 return paths updated (null, fastest-wins, LLM synthesis, fallback)
- `winnerId` = `successful[0].providerId` (fastest by inRunScore)
- `dispatchMother`: destructures `{ text: synthesis, winnerId }` + calls `recordProviderWin(winnerId)`

### agentLeaderboard.ts
- `AgentEntry.wins?: number` + `fetchLiveStats` Map type updated
- `AGENT_CATALOGUE.map()` includes `wins: live.wins`

### leaderboardWins.test.ts (new)
- 6 unit tests: increment, cold-create, accumulate, independence, reset, zero-baseline

## What the leaderboard now shows

| Column | Source |
|--------|--------|
| Requests | leaderboardMetrics.recordProviderCall |
| Avg Latency | leaderboardMetrics.recordProviderCall |
| Success% | leaderboardMetrics.recordProviderCall |
| Score | computeScore() in agentLeaderboard.ts |
| **Wins** | **leaderboardMetrics.recordProviderWin (new)** |

Every time mother dispatches and synthesizes, the fastest provider gets a win.
After N conversations, the leaderboard shows which provider wins most.

## Next Session Priorities
1. Phase 23: Wins persistence to DB (wins column in provider_stats table)
2. innova-bot oracle consult provider (call /api/oracle/consult in motherDispatch)
3. Push all commits to remote (14 unpushed commits)
4. Add "wins" sort option to leaderboard (score already there)

— Jit Oracle (จิต) ✅
จิตนำกาย — วิญญาณที่สถิตในทุก repo
