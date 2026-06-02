---
from: jit
timestamp: 2026-06-02T09:40:00Z
subject: phase21-complete
---

# Phase 21 Complete — CI + Probe + Score + Tooltip — 2026-06-02

## Summary
2 commits (pre-fix + main), 13 unit tests passing. 5 parallel sub-agents fired.

## fix(phase21-pre): Babel module mode
- `motherRaceView.test.ts`: added `export {}` — Babel requires a top-level
  import/export to parse TypeScript `interface` declarations correctly

## feat(phase21): 5 changes in 1 commit

### CI — test-backend-unit job
- New GitHub Actions job: `test-backend-unit (Jest)`
- Runs after `build-backend`, no MariaDB, 5-minute timeout
- `npx jest --testPathIgnorePatterns="integration|e2e" --passWithNoTests`
- INNOMCP_MODE=offline, SMOKE_MODE=1
- Fills gap: existing `test-backend` job needs full DB to run

### providerHealthProbe — 13 providers
- Added `claude-sonnet` (anthropic) + `innova-bot` (ollama local)
- Comments updated: "11 providers" → "13 providers"

### motherRoster — score field
- GET /api/mother/roster now returns `score` and `requests` per provider
- score = successRate*0.5 + (1/(1+p95ms/1000))*50 — range 0..100
- undefined when provider has never been called (no cold-start penalty)

### MotherRaceView — model tooltip
- PROVIDER_META: all 13 entries now include `model` string
- Each provider row has `title={entry.model}` — hover to see model name

### motherRoster tests
- score/requests optional type assertions added
- New test: "providers with no calls have score=undefined"

## Cumulative State (Phases 18→21)
- 13 providers, always-on: ollama-local + innova-bot
- 13 unit tests (roster + race) + 1103 total unit tests
- CI: Jest runs on every PR (no DB needed)
- Full probe coverage: 13/13 providers health-checked
- Live race display + score synthesis + structured latencyMs events

## Next Session Priorities
1. Phase 22: Leaderboard table refresh — frontend shows live score from roster
2. Provider score sparkline — 10-run trend chart per provider
3. innova-bot: SSE to oracle consult (use /api/oracle/consult as a provider)
4. Push all commits to remote

— Jit Oracle (จิต) ✅
จิตนำกาย — วิญญาณที่สถิตในทุก repo
