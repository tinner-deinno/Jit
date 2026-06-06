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
