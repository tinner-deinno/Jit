# Jit Mother Loop Report

Cycle: 95
Started: 2026-06-05T15:55:19.079Z
Finished: 2026-06-05T15:57:14.436Z
Status: pass
Failure streak: 0
Selected lanes: thaillm
Advisor used: no

## Providers

- ollama_mdes: ALIVE
- ollama_local: UNREACHABLE - timeout
- ollama_cloud: RATE_LIMITED - Ollama HTTP 429: {"error":"you (tawin2502) have reached your weekly usage limit,
- thaillm: ALIVE
- copilot: RATE_LIMITED - Copilot CLI failed: 402 {"error":{"message":"You have no quota","code":"quota_ex
- openai: ERROR - Codex CLI failed: 2026-06-05T15:25:14.937861Z  WARN codex_core_plugins::manifest
- openclaude: UNREACHABLE - OpenClaude request error: ECONNREFUSED
- innova_bot: ERROR - non-usable probe reply: [SYSTEM OVERRIDE]: Local AI query failed (Ollama may be offl

## Fleet

- Run: fleet-batch-2026-06-05T15-55-28-494Z
- Result: 56/56 OK, fail=0, pending=0, count=56
- thaillm: 56/56 OK, avg 8372ms

## Notifications

- innova-bot: ok
- discord: skipped/failed - no discord target

## Artifacts

- latest JSON: network/loop/latest-report.json
- fleet artifact: network/artifacts/fleet-batch-2026-06-05T15-55-28-494Z
