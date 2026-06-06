# Jit Mother Loop Report

Cycle: 80
Started: 2026-06-05T14:05:11.707Z
Finished: 2026-06-05T14:05:23.512Z
Status: degraded
Failure streak: 1
Selected lanes: ollama_mdes, thaillm
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

- Fleet batch failed or dry-run: [fleet] fatal: database is locked

## Notifications

- innova-bot: ok
- discord: skipped/failed - no discord target

## Artifacts

- latest JSON: network/loop/latest-report.json
- fleet artifact: network/artifacts/fleet-batch-2026-06-05T13-42-12-237Z
