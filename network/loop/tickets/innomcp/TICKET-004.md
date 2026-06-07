# TICKET-004: Routing Determinism Test Suite
**Team**: innomcp
**Status**: pending
**Owner**: Jit (จิต) — Mother Orchestrator
**Priority**: P2
**Cycle assigned**: 176

## Goal
Build an automated test suite that verifies routing decisions are deterministic — same input always picks the same lane, regardless of timing, fleet concurrency, or provider response order.

## Steps
1. Read `eval/fleet-batch.js` lane selection logic.
2. Build a Node.js test in `eval/routing-determinism.test.js` that:
   - Defines 20 input prompts (mix of Thai, English, code).
   - Runs each prompt 5 times through `selectLanes()`.
   - Asserts the same lane is chosen every time (modulo provider availability).
3. Add a `--determinism-test` flag to `innova-loop-controller.js` that runs the suite once per cycle.
4. Wire test results into `latest-report.md` as a new section.

## Acceptance
- Test suite runs in <30s and exits 0 on 20/20 prompts.
- Loop continues to call the suite every cycle; failures are logged to `ψ/memory/learnings/determinism-failures.md`.

## Confidence: 80
