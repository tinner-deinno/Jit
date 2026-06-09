# Spec Numbering Reconciliation (Iteration 3)

**Issue**: TICKET-009 and TICKET-010 scope definitions differ between JSON spec file and backlog markdown.

## Current State

### JSON File (TICKET-009-PERFORMANCE-SPEC.json)
**Actually describes**: Performance Optimization + LRU cache + DJB2 fairness
**Should be labeled**: TICKET-010

### Backlog Markdown (innomcp_dev_backlog.md lines 29-66)
**TICKET-009**: Regression & Variance Testing (28-phrase corpus, 10 runs, distribution variance)
**TICKET-010**: Performance Audit & Optimization (latency, memory, DJB2 fairness)

## Action Items (Iteration 4+)

1. [ ] Rename: `TICKET-009-PERFORMANCE-SPEC.json` → `TICKET-010-PERFORMANCE-SPEC.json`
2. [ ] Create: `TICKET-009-REGRESSION-SPEC.json` (based on backlog lines 29-47)
3. [ ] Verify: Both specs committed to main with clear numbering
4. [ ] Assign: 009 to available dev once spec merged
5. [ ] Monitor: 010 completion on `heartbeat-codespace-20260608` (benchmark ~67% done)

## Reference

- Backlog source of truth: `C:\Users\USER-NT\Jit\innomcp_dev_backlog.md`
- Current 010 work: `heartbeat-codespace-20260608` branch (benchmark.js, baseline-2026-06-09.md)
- Status: Both 009 and 010 will be READY once reconciliation complete (est. next iteration)
