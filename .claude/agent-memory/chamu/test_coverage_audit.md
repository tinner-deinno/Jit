---
name: jit_bus_test_coverage_audit
description: Comprehensive QA audit of Jit bus reliability tickets JIT-001 to JIT-010; 22 test stubs identified, P0 blocker is TTL implementation
metadata:
  type: project
---

# Jit Bus Reliability Test Coverage Audit (June 7, 2026)

## Findings

**22 test stubs** created across 6 feature areas; **3 critical bugs** found.

### Covered Features (existing tests)
- Circuit breaker: 20 tests (test_error_recovery.py) — COMPLETE
- Exponential backoff: 8 tests — COMPLETE  
- Secrets encryption: 13 tests (test_infrastructure.py) — COMPLETE
- Bus message format: 12 tests (test_network.py) — COMPLETE
- State recovery: 7 tests — COMPLETE
- Log rotation (flush): 2 tests — COMPLETE

**Total existing: ~102 tests**

### Gaps (test stubs ready to implement)

**P0 — Critical Path (JIT-001 TTL)**
- Message TTL header parsing & default TTL by type (task 1h, broadcast 24h, reply 5m)
- Expired message quarantine to `.expired/` (never silent delete)
- router.sh rejection of expired messages + BUS_EXPIRED log
- Effort: 3.5 hours, 7 tests

**P1 — High Impact (JIT-002, JIT-004, JIT-010)**
- Idempotency key deduplication + store persistence  
- Dead-letter queue quarantine + size monitoring
- Hermes health endpoint (/healthz:47780) + systemd watchdog integration
- Effort: 7 hours, 10 tests

**P2 — Enhancement (JIT-005, JIT-006, JIT-007, JIT-008)**
- Protocol version negotiation & fallback
- Invalid subject prefix rejection
- Secrets in service unit without env leak
- Deploy rollback on health failure
- Effort: 4 hours, 5 tests

### Critical Bugs Found

**BUG-CHAMU-001**: Message deduplication missing — retry storms cause duplicates  
**BUG-CHAMU-002**: DLQ not quarantining — undeliverable messages pile up  
**BUG-CHAMU-003**: TTL not enforced — stale messages processed past expiry

## Execution Plan

**Batch 1 (P0)**: 3.5h — TTL foundation (7 tests)  
**Batch 2 (P1)**: 3.5h — Idempotency + DLQ + Health (7 tests)  
**Batch 3 (P1-P2)**: 2.5h — Protocol versioning (3 tests)  
**Batch 4 (P2)**: 2.5h — Systemd + Deploy (5 tests)  
**Total**: ~14-15 hours

## Quality Assessment

- **102 existing tests** cover foundation (bus, infra, error recovery)
- **22 test stubs** ready with acceptance criteria
- **No blockers** — can start P0 immediately
- **Recommendation**: Proceed to Batch 1 for JIT-001 (TTL) implementation

## QA Sign-Off Status

✓ Assessment complete  
✓ Gaps identified with priority levels  
✓ Test stubs have acceptance criteria  
✓ Bugs documented for engineering handoff  
→ Ready for Batch 1 execution

**Auditor**: chamu (จมูก) — QA Engineer  
**Audit Date**: 2026-06-07  
**Report**: /workspaces/Jit/QA_ASSESSMENT_REPORT.md
