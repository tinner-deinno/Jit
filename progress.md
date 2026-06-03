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

## Iteration 4 — Leaderboard DB Hydration (Phase 36.5) ✅

| Task | How | Status | Evidence |
|------|-----|--------|----------|
| Durable store | `limbs/leaderboard-db.js` (node:sqlite, no dep) | ✅ | `network/leaderboard.db` (gitignored; JSON is portable seed) |
| Hydrate/seed in engine | `hydrateLeaderboard()` in loadState | ✅ | DB=source of truth, JSON=mirror |
| Survives JSON reset | wipe JSON → rehydrate | ✅ | innova 78.43 preserved |
| Verify swarm (5 Haiku) | concurrency/injection/scale/corruption/migration | ✅ | injection-safe, corruption-graceful, lossless |
| Fixes from swarm | txn-wrap (630x), finite-guard, WAL+busy_timeout | ✅ | persist 5001 agents 43s→68ms |

## Iteration 5 — Unified Status Board ✅ (Manus-like control surface)

`node eval/status-board.js` — one read-only view: bridge health + provider
status/usable + proven-agent leaderboard + recent dispatch phases. `--json` for
machines. Burns no LLM quota. Verify swarm (5 Haiku): accuracy exact, bridge
timeouts bounded, pipeline correct; fixed a null-artifact crash + data guards.
**Live-proven:** ran a real phase → board shows `LiveProof ollama_mdes avg 93`,
provider phases=1, leaderboard advanced, atomicCommit touched only 1 file.

## Iteration 6 — Reliability-Weighted Dispatch ✅ (self-improving)

`provider_stats` table learns per-provider success_rate + latency from real
dispatches (attributed by `results[].backend`). `pickLiveProvider` ranks usable
lanes: cost → learned reliability (≥3 calls) → latency. Status board shows a
reliability column. Verify swarm (5 Haiku) confirmed math/attribution/board
accuracy + found a **gate-inversion bug** (untested neutral=1 beat proven 0.99);
fixed to neutral=0.5 (proven-good > untested > proven-bad, verified A>B>C).
**Live:** board shows ollama_mdes 100%(3), copilot 50%(2) from real runs.

## Iteration 7 — Real MCP Bridge to innova-bot ✅ (genuine talk)

debug-mantra discovery: bot is a full **MCP server (innova-bot v3.0.2, 31 tools)**.
The old `dispatchTask` called a non-existent `execute_task` → bot rejected with
`-32602` on SSE, which the bridge **ignored** (every task silently dropped — the
"talking" was an illusion). Rebuilt: SSE request/response correlation (pending
map by JSON-RPC id), `initialize()` handshake, `callTool()`, `askBot()`;
`dispatchTask` now uses real `publish_event` on the A2A bus. Verify swarm (5
Haiku) fixed 2 bugs (FastMCP `isError` not rejected; handshake not reset on
reconnect), refuted the string-id risk. **Live-proven:** `publish_event`
executed (event visible on bot's bus via `fetch_pending_events`), `ask_local_ai`
returns real output, `jit_bridge_status` returns structured data.

### Bot tools worth integrating next (all live-confirmed)
- `ask_local_ai` — bot's own Gemma4/Qwen backend → extra provider lane.
- `fetch_pending_events`/`publish_event` — real A2A inbox/outbox for Mother↔bot.
- `what_should_i_do_next` — bot's task-suggestion brain.
- `jit_runtime_snapshot` — one-call health/observability.

## innova-bot bridge
**ALIVE & genuinely talking (MCP).** `node eval/innova-bot-mcp-probe.js` lists the
31 tools. Port 7010; `/gui` (37KB) + `/sse` work; `/health` 404 (cosmetic).

## Known gaps / next
- ~~Phase 38 event-log export~~ ✅ DONE (iteration 3).
- ~~Leaderboard DB hydration (Phase 36.5)~~ ✅ DONE (iteration 4).
- **Provider widening (user action):** refresh ThaiLLM token; start local ollama; restore MDES quota/cloud; start openclaude. Then re-probe.
- **Reliability scoring:** probe is point-in-time; cloud quota exhausts mid-run. Consider per-call health tracking in the leaderboard.
