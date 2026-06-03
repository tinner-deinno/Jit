# INNOMCP / Mother — Progress Log

> Multi-agent chat harness ("Manus-like") driven by `MotherEngine`.
> Updated by Jit Oracle. Evidence-first: every row is verified, not claimed.

## Live provider reality (from `eval/provider-probe.js`)

Run `node eval/provider-probe.js` to refresh `network/provider-status.json`.
Last probe (timeout 35s):

| backend | status | latency | note |
|---|---|---|---|
| 🟢 ollama_mdes | ALIVE | ~28s | slow cold-start; cheap; squad default |
| 🟢 copilot | ALIVE | ~19s | medium cost |
| 🟢 openai (gpt-5.5) | ALIVE | ~11s | **advisor-only**, high cost — kept out of squad |
| 🟡 ollama_cloud | RATE_LIMITED | — | weekly quota exhausted (429) |
| 🔑 thaillm | AUTH 401 | — | routing fixed; **token in `.env` expired** (user action) |
| 🔌 ollama_local | UNREACHABLE | — | no local daemon (`ollama serve`) |
| 🔌 openclaude | UNREACHABLE | — | service not on :8000 |

Engine picks the **cheapest usable** lane (cost_tier, then latency) → `ollama_mdes`.

## Iteration 2 — Harden What Exists ✅

Goal: prove `MotherEngine` runs end-to-end on LIVE providers and the
squad → verify → leaderboard → commit cycle is durable with REAL (non-seeded) scores.

| Task | How | Status | Evidence |
|------|-----|--------|----------|
| Run mother-loop one real phase | `eval/mother-phase-live.js` | ✅ PASS | Phase `LiveProof`, 5 real squad replies via ollama_mdes |
| Diagnose breaks | debug-mantra trace | ✅ | model-mismatch (cloud 404), cloud 429 quota, 120s timeout kill, slow-alive mdes |
| Fix reliability | live-provider pick (cost+latency, skip rate-limited), backend+model override | ✅ | `mother-engine.pickLiveProvider()` |
| Verify leaderboard commit cycle | real EMA delta + atomicCommit | ✅ | 5 agents moved (soma 95.58→94.06, innova 75.03→78.43, lak 76.84→79.07, vaja 95.57→94.85, chamu 85.39→85.91); commit `e413b2e` |
| Atomic commit hygiene | scope to phase artifacts, shell-safe subject | ✅ | `atomicCommit()` no longer `git add .` |
| Push commits | PAT `workflow` scope | ⏳ BLOCKED | local only — needs PAT fix (user) |
| Document outcomes | this file | ✅ | `progress.md` |

### Session commits (local)
- `mother: fix duplicate loadState() syntax error` — engine couldn't load
- `eval: add provider liveness probe (node, CRLF-safe)`
- `leaderboard: ground provider rows in live probe results`
- `fix: thaillm routing + openclaude error + leaderboard score cap`
- `fix(bridge): resolve relative session endpoint -> innova-bot dispatch works`
- `mother: dispatch squad to live provider from probe`
- `mother: complete phase LiveProof` (engine atomicCommit)
- `mother: scope atomicCommit + write progress.md`

## Iteration 3 — Phase 38 Event-Log Export ✅ (was vapor)

| Task | How | Status | Evidence |
|------|-----|--------|----------|
| Event recorder in loop | `executePhase` → `eventLog.record()` | ✅ | append-only `network/mother-events.jsonl` |
| JSON + CSV exporter | `limbs/event-log.js`, `eval/export-events.js` | ✅ | RFC-4180 + formula-injection guard |
| Adversarial test | 3 Haiku agents (injection / unicode / robustness) | ✅ | found 1 real HIGH bug, rest clean |
| Fix + regression | leading-whitespace bypass `/^\s*[=+\-@]/` | ✅ | `eval/event-log-check.js` all pass |

## innova-bot bridge
**ALIVE & talking.** `eval/innova-bot-talk.js` round-trips: dispatch → `"Accepted"` in ~1.5s.
Port 7010 listening; `/gui` (37KB) + `/sse` work; `/health` 404 (cosmetic).

## Known gaps / next
- ~~Phase 38 event-log export~~ ✅ DONE (iteration 3).
- **Leaderboard DB hydration (Phase 36.5) = missing.** Scores persist to JSON only; no DB → vulnerable to reset.
- **Provider widening (user action):** refresh ThaiLLM token; start local ollama; restore MDES quota/cloud; start openclaude. Then re-probe.
- **Reliability scoring:** probe is point-in-time; cloud quota exhausts mid-run. Consider per-call health tracking in the leaderboard.
