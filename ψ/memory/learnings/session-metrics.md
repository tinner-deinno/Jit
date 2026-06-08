# Oracle Session Metrics

Rule (parent CLAUDE.md §"Self-Evaluation Loop"): same friction 3 sessions → fix root cause, not another workaround.

| when | session | done | stuck | win | friction | error |
|---|---|---|---|---|---|---|
| 2026-05-29 17:41 | 14b3aef0 | /rrr retro, lesson, metrics row | hermes inbox 25 msgs unread, phase7 not started | clean re-entry after 3-day gap | Windows bash path encoding mismatch in session detection | wrote retro without reading hermes inbox first |
| 2026-06-03 01:51 | 62bfec76 | Phases 18-36: 14-provider mother dispatch, leaderboard, win tracking, circuit breakers, provider toggle, rankings, export, compare | innova-oracle untested (gateway offline), git push deferred | innova-bot message bus bridge confirmed + full Manus-like mother system (44 commits) | sub-agent session limits mid-Phase25, Windows session detection encoding, stop hook fires identically every message | 3 sub-agents failed mid-Phase25 — assumed total failure instead of checking system reminders for partial state |
| 2026-06-03 12:23 | 5e8fcab6 | Phase 37 core logic, port fix | PAT push blocked | Wisdom heuristic implemented | PAT scope friction | misread gateway port |
| 2026-06-03 15:30 | 7cfb6447 | verified-routing,verified-registry,soul-check-pass | ear.sh-crlf | specialist-agents-synced | crlf-issue-with-ear-sh | wrong-call-via-powershell |
| 2026-06-03 20:39 | 41411075 | 6 iterations/22 commits: fix engine parse, provider probe, prove Mother loop live, Phase38 export, Phase36.5 SQLite hydration, status board, reliability-weighted dispatch; 23 sub-agents | ~50 commits unpushed (PAT workflow scope); fleet-widen needs user creds (ThaiLLM token, MDES/cloud quota, local ollama) | Mother loop proven end-to-end on live providers + self-improving reliability dispatch | ollama_mdes 28s cold-start → probe false-dead + ~140s phases; cloud weekly quota exhausted mid-run | ran `timeout 120` on a ~140s phase → SIGTERM pre-commit; shipped backend-override without model-override → cloud 404 + quota-burning retries |

## 🔁 Recurring Pattern Detected

"Windows line-ending / encoding friction" appeared in the **friction** column of 3+ recent sessions (2026-05-29 path-encoding; 2026-06-03 01:51 session-detection encoding; 2026-06-03 15:30 ear.sh CRLF; recurring again 2026-06-03 20:39 as LF→CRLF on every commit). Per parent CLAUDE.md §"Self-Evaluation Loop" — consider a root-cause fix instead of another workaround.

Suggested root-cause fix: add a `.gitattributes` (`* text=auto eol=lf`, `*.sh text eol=lf`) and/or set `git config core.autocrlf`; prefer Node scripts over bash for tooling on Windows (already started: provider-probe.js, event-log.js, status-board.js are all node). Escalation: open issue `root-cause: windows-crlf-encoding` or raise with Boss at next standup.
| 2026-06-04 19:07 | current | installed puppeteer | target :3000 down | tool-server online | target blindness |
| 2026-06-07 05:42 | 62bfec76 | Phases 18-49 complete (innomcp mother system), Phase 50 partial, mother loop cycles 150-154 | Phase 50 scorecard incomplete (5 sub-agents hit limits), git push deferred | 1228/1228 unit tests passing, 20+ mother/* APIs, 17-col leaderboard with column toggle | 5 simultaneous session limits on Phase 50 sub-agents, multi-day context gap, Phase 50 partial completion | drafted Phase 50 'complete' before verifying file state from system reminders |
| 2026-06-07 19:47 | 1ec3f855 | /recap orientation, handoff-pending verification (push→DONE, 7+ interim commits confirmed), retro+lesson | retro stalled 3 days (weekly limit Jun 4→6); recap summary never delivered before /rrr arrived | trivial — verified all handoff pendings except creds-probe are done | weekly usage limit killed timestamp-miner subagent mid-/rrr; python not installed on Windows (Store alias) → rewrote extraction in node; git snapshots stale within 1h (parallel sessions commit to same repo) | spawned a quota-burning subagent for a one-command job right after a quota-heavy marathon — inline node call did it in 10s on resume |

## 🔁 Recurring Pattern Detected (2026-06-07)

"Sub-agent / usage limits blocking work" appeared in the **friction** column of 4 of the last 7 sessions (62bfec76 06-03: sub-agent session limits mid-Phase25; 41411075: cloud weekly quota exhausted mid-run; 62bfec76 06-07: 5 simultaneous session limits on Phase 50; 1ec3f855: weekly limit killed timestamp-miner, retro stalled 3 days). Per parent CLAUDE.md §"Self-Evaluation Loop" — consider root-cause fix instead of another workaround.

Suggested root-cause fix: quota-aware dispatch — (a) don't spawn subagents for single deterministic commands (see learning 2026-06-07_inline-over-subagent-for-deterministic-commands.md); (b) check remaining budget before fan-out after marathon sessions; (c) give long workflows a degraded inline-fallback path so a dead subagent doesn't stall the parent. Escalation: raise with Boss at next standup — surface only, Boss decides.

Note: the earlier "Windows line-ending / encoding friction" pattern recurred again 2026-06-07 (python Store-alias stub broke rrr's embedded `python3 -c` extraction); the Node.js migration in `c2f8942` is the root-cause fix in progress — extend it to skill scripts.
| 2026-06-08 18:58 | 4c2089c9 | /recap system audit, full fleet census (agents/skills/providers), commandcode 28 models confirmed | cc-agents not yet wired into fleet dispatch | commandcode provider confirmed ALIVE with 28 models incl Claude tier under separate budget | Windows project-dir path encoding mismatch on session detection, fleet-batch JSON schema inconsistency (cycle/verdict undefined at top level) | declared "75% ready" from agent file count without verifying actual dispatch runtime participation |
