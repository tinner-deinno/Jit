# TICKET-002: Thai Knowledge Routing Audit (Phase 10.14)
**Team**: innomcp
**Status**: pending
**Owner**: Jit (จิต) — Mother Orchestrator
**Priority**: P1
**Cycle assigned**: 176
**Depends on**: TICKET-001 (need CommandCode bridge to compare routes)

## Goal
Verify that Thai-language queries (จิต, มนุษย์, อวัยวะ) route deterministically to the Thai LLM lane (thaillm), not to a general-purpose lane like ollama_mdes. This is Phase 10.14 of the Thai Knowledge routing plan.

## Steps
1. Define 20+ Thai test prompts covering: pure Thai, mixed Thai-English, Thai with code-switching, Thai with English technical terms, Thai idiom/proverbs.
2. Run each prompt against thaillm and ollama_mdes through `eval/fleet-batch.js` (count=40, lanes=thaillm+ollama_mdes).
3. Capture routing decision in artifact JSON: which lane was selected, response language, response latency.
4. Compute routing determinism: same prompt → same lane 100% of the time?
5. Compute response quality: Thai-coherent response >= 80% of the time?

## Acceptance
- Routing determinism >= 95% on the test corpus.
- Thai-coherent response rate >= 80% on thaillm lane.
- Routing report committed to `ψ/memory/learnings/thai-routing-audit-2026-06-08.md`.

## Risk
- thaillm may not be available for all 4 models simultaneously — some fallbacks to ollama_mdes.
- Mixed Thai-English is a known hard case — document failure modes.

## Confidence: 75
