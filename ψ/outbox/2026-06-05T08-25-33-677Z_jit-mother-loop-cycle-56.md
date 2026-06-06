# Jit Mother Loop Report

Cycle: 56
Started: 2026-06-05T08:09:18.551Z
Finished: 2026-06-05T08:25:33.591Z
Status: degraded
Failure streak: 1
Selected lanes: ollama_mdes, thaillm
Advisor used: no

## Providers

- ollama_mdes: ALIVE
- ollama_local: UNREACHABLE - timeout
- ollama_cloud: RATE_LIMITED - Ollama HTTP 429: {"error":"you (tawin2502) have reached your session usage limit
- thaillm: ALIVE
- copilot: RATE_LIMITED - Copilot CLI failed: 402 {"error":{"message":"You have no quota","code":"quota_ex
- openai: ALIVE
- openclaude: UNREACHABLE - OpenClaude request error: ECONNREFUSED
- innova_bot: ALIVE

## Fleet

- Fleet batch failed or dry-run: [model-router] ollama_cloud failed: Ollama HTTP 429: {"error":"you (tawin2502) have reached your session usage limit, upgrade for higher limits: https://ollama.com/upgrade (ref: a89180f0-0447-404c-880d-739a65512c9d)"}
[model-router] ollama_mdes failed: Ollama HTTP 504: error code: 504
[model-router] ollama_mdes failed: Ollama HTTP 504: error code: 504
[model-router] ollama_mdes failed: Ollama HTTP 504: error code: 504
[model-router] thaillm failed: HTTP 502: error code: 502

## Notifications

- innova-bot: ok
- discord: skipped/failed - no discord target

## Artifacts

- latest JSON: network/loop/latest-report.json
- fleet artifact: network/artifacts/fleet-batch-2026-06-05T07-56-14-374Z
