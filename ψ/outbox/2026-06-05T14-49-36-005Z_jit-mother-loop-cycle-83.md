# Jit Mother Loop Report

Cycle: 83
Started: 2026-06-05T14:49:17.448Z
Finished: 2026-06-05T14:49:35.817Z
Status: degraded
Failure streak: 2
Selected lanes: thaillm
Advisor used: no

## Providers

- ollama_mdes: ALIVE
- ollama_local: ALIVE
- ollama_cloud: RATE_LIMITED - Ollama HTTP 429: {"error":"you (tawin2502) have reached your weekly usage limit,
- thaillm: ALIVE
- copilot: RATE_LIMITED - Copilot CLI failed: 402 {"error":{"message":"You have no quota","code":"quota_ex
- openai: ALIVE
- openclaude: UNREACHABLE - OpenClaude request error: ECONNREFUSED
- innova_bot: ALIVE

## Fleet

- Run: dry-run
- Result: 0/0 OK, fail=0, pending=56, count=56

## Notifications

- innova-bot: ok
- discord: skipped/failed - no discord target

## Artifacts

- latest JSON: network/loop/latest-report.json
- fleet artifact: network/artifacts/fleet-batch-2026-06-05T14-38-11-753Z
