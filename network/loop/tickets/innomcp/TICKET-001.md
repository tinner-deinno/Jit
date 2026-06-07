# TICKET-001: Setup CommandCode Provider Bridge
**Team**: innomcp
**Status**: pending
**Owner**: Jit (จิต) — Mother Orchestrator
**Priority**: P0 (blocker for innomcp)
**Cycle assigned**: 176

## Goal
Wire `https://commandcode.ai/Evergreen-TH` as a first-class provider in the innomcp proxy so fleet workers can route queries through it. Today CommandCode is mentioned in the env file only — no provider in `eval/provider-probe.js`, no lane in `config/subagent-routing.json`.

## Steps
1. Read `.env` and `eval/provider-probe.js` to understand existing provider pattern.
2. Add a new `commandcode` backend that:
   - Probes `https://commandcode.ai/Evergreen-TH/settings/usage` (or a health endpoint) with auth.
   - Returns `ALIVE` / `UNREACHABLE` / `ERROR`.
3. Register `commandcode` in `config/subagent-routing.json` budget_order (priority 2, after thaillm).
4. Add a `commandcode` worker template in `eval/fleet-batch.js` (model: `commandcode-1`, persona: `coordinator`).
5. Run `node eval/provider-probe.js --backends commandcode,thaillm` and verify it shows ALIVE.

## Acceptance
- `network/provider-status.json` shows `commandcode: ALIVE` with `ms < 5000`.
- Fleet cycle with `--include-commandcode` flag completes >=10 OK out of 10 workers.
- Token usage from CommandCode is visible in `latest-report.md` providers section.

## Risk
- CommandCode API auth may use a different scheme than other providers — may need 2FA / session cookie.
- If auth fails, fall back to thaillm only and mark this ticket degraded.

## Confidence: 70
