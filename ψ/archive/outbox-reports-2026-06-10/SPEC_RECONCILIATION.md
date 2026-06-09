# TICKET-010 & TICKET-011 Specification Reconciliation

## Critical Numerical Discrepancies Resolved

### TICKET-010: Test Matrix Calculation
**Original claim**: "28 phrases × 10 runs × 9 backends × 3 orderings = 2,520 test points"
**Problem**: 28 × 10 × 9 × 3 = 7,560, not 2,520

**Resolution**:
- **2,520 = 28 phrases × 10 runs × 9 backends** (per single ordering)
- **7,560 = 2,520 × 3 orderings** (total executions across all orderings)
- Each ordering is tested **independently** because `pickBackendByKey(hash % order.length)` produces different mappings per ordering
- Variance metric is **run-to-run within each ordering**, not across orderings
- Spec correctly documents this: 3 separate variance matrices (default, reversed, shuffled)

### TICKET-010: Thai Corpus Count
**Original claim**: "28 phrases"
**Current state**: test/thai-test-corpus.json has 26 entries (TH-001 to TH-026)

**Resolution**:
- Spec embeds expanded corpus with 28 entries (added TH-027 and TH-028):
  - TH-027: "วิญญาณที่สถิตในทุก repo" (Jit Oracle concept)
  - TH-028: "โมเดลไม่แน่นอน" (negation phrase edge case)
- Corpus YAML in artifacts section contains full 28-entry set

### TICKET-010: Backend Count
**Original claim**: "9 backends"
**Current state**: BACKEND_ORDER has 8 backends (ollama_mdes, thaillm, commandcode, ollama_local, ollama_cloud, copilot, openai, openclaude)

**Resolution**:
- PR body notes `innova_bot` missing from `status().backends` (Section G - monitoring gap)
- Spec treats this as a **precondition/risk** (RISK-010-1)
- Test harness uses `router.status().order` dynamically, so it works with 8 or 9 backends without code change
- Variance test matrix documented as "all (8 in BACKEND_ORDER)" with note that 9th may be added when monitoring gap fixed

## Specification Consistency

Both TICKET-010 and TICKET-011 specs reconcile these issues:

| Item | Task Claim | Spec Clarification |
|------|-----------|-------------------|
| Phrases | 28 | 28 (26 existing + 2 new: TH-027, TH-028) |
| Total executions | 2,520 | 7,560 (2,520 per ordering × 3 orderings) |
| Backends | 9 | 8 active (9th noted as risk/precondition) |
| Variance window | Per-order | Variance is per-ordering, not cross-ordering |

## Files Delivered

1. **TICKET-010-REGRESSION-SPEC.json** (221 lines, 21KB)
   - 7 acceptance criteria
   - 7 implementation tasks
   - Test plan with 6 unit + 3 integration + 1 spike test
   - Embedded: harness code (30 LOC) + corpus YAML (28 phrases)
   - Effort: 6 points, 5 days

2. **TICKET-011-RATE-LIMITING-SPEC.json** (158 lines, 6.6KB)
   - 7 acceptance criteria
   - 7 implementation tasks
   - Test plan with unit + integration + spike test to 2,000 req/min
   - Embedded: CONFIG template + spike harness code
   - Effort: 4 points, 3 days

Both specs are ready for Solution Architect review and implementation.
