# Jit Mother Loop Report

Cycle: 3
Started: 2026-06-04T20:01:03.029Z
Finished: 2026-06-04T20:07:24.237Z
Status: pass
Failure streak: 0
Selected lanes: ollama_mdes, thaillm, ollama_cloud
Advisor used: no

## Providers

- ollama_mdes: UNREACHABLE - getaddrinfo ENOTFOUND ollama.mdes-innova.online
- ollama_local: UNREACHABLE - timeout
- ollama_cloud: ERROR - Ollama HTTP 502: {"error":"Post \"https://ollama.com:443/api/chat?ts=1780603269\
- thaillm: UNREACHABLE - getaddrinfo ENOTFOUND thaillm.or.th
- copilot: ERROR - Copilot CLI failed: Error: No authentication information found.

Copilot can be 
- openai: ERROR - Codex CLI failed: 2026-06-04T20:01:09.831449Z  WARN codex_core_plugins::remote::
- openclaude: UNREACHABLE - OpenClaude request error: ECONNREFUSED
- innova_bot: ERROR - non-usable probe reply: [SYSTEM OVERRIDE]: Local AI query failed (Ollama may be offl

## Fleet

- Run: fleet-batch-2026-06-04T20-02-17-343Z
- Result: 56/56 OK, fail=0, pending=0, count=56
- ollama_mdes: 20/20 OK, avg 28607ms
- thaillm: 18/18 OK, avg 11570ms
- ollama_cloud: 18/18 OK, avg 3773ms

## Notifications

- innova-bot: ok
- discord: skipped/failed - no discord target

## Artifacts

- latest JSON: network/loop/latest-report.json
- fleet artifact: network/artifacts/fleet-batch-2026-06-04T20-02-17-343Z
