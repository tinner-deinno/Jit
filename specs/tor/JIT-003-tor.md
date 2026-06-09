# JIT-003 TOR: Retry Policy with Exponential Backoff

**Owner**: soma  
**Effort**: 5 hours  
**Priority**: P1  
**Status**: Open

---

## Scope

Extend the มนุษย์ Agent message bus with automatic retry support and exponential backoff. Messages that fail routing are automatically retried with increasing delays, improving system resilience for transient failures.

### In Scope
- Add `max-retries:<n>` and `retry-after:<seconds>` headers
- Implement exponential backoff retry loop in `router.sh` (2s, 4s, 8s, ..., capped at 300s)
- Create `_failed/` queue for messages awaiting retry
- Implement `bus.sh retry` subcommand to re-queue messages
- Integrate retry scheduling into heartbeat or cron
- Update retry-attempt counter on each failure
- Integration tests (test_error_recovery.py)

### Out of Scope
- Configurable backoff strategies (exponential only)
- Per-agent custom retry limits
- Retry cost limits or budgets
- Web UI for manual retry management

---

## Deliverables

1. **Code**:
   - `network/bus.sh`: stamp `max-retries` and `retry-after` in `send`, implement `retry` subcommand
   - `limbs/router.sh`: wrap dispatch in `_retry_with_backoff()` function
   - `_failed/` directory for queued retries with `retry-at-<ISO>` timestamps
   - Heartbeat integration (pran or cron job) to run `bus.sh retry` periodically
   - Update `retry-attempt` header on each failure

2. **Documentation**:
   - `network/protocol.md`: add `max-retries` and `retry-after` header specification
   - Exponential backoff formula and capping logic
   - Retry queue semantics and scheduling
   - Version History section with migration notes

3. **Tests**:
   - `tests/test_error_recovery.py`: unit + integration tests
   - Verify exponential backoff calculation
   - Verify retry-attempt counter increments
   - Verify max-retries limit is respected
   - Verify messages are re-queued after backoff window
   - Verify log entries for `BUS_RETRY` and `BUS_MAX_RETRIES_EXCEEDED`

4. **Process**:
   - Update `tickets/open/JIT-003-bus-retry-backoff.yaml` → `tickets/closed/` on merge
   - Log action: `BUS_RETRY_FEATURE_READY`

---

## Owner Responsibilities

**soma** (Strategic Lead):
- Finalize spec (done — see JIT-003-spec.md)
- Define exponential backoff semantics (formula, cap, defaults)
- Coordinate with JIT-004 (DLQ) on failure flow
- Define retry scheduling (heartbeat vs. cron)
- Approve PR before merge

**innova** (will execute):
- Implement retry loop in `router.sh`
- Implement `bus.sh retry` subcommand
- Manage `_failed/` queue and `retry-at` timestamps
- Implement heartbeat or cron integration
- Write integration tests (test_error_recovery.py)

**pada** (DevOps):
- Set up cron job if heartbeat-based retry is not used
- Monitor retry queue depth and alert if growing unbounded
- Configure retry backoff caps based on system load

**neta** (code review):
- Review retry loop logic for correctness
- Verify exponential backoff is implemented correctly
- Ensure no messages are lost during retries
- Verify log entries are comprehensive

---

## Dependencies

- ✅ Protocol v1 baseline (network/protocol.md exists)
- ✅ JIT-002 (Idempotency) — should be merged first (retries need idempotency)
- ⏳ JIT-004 (DLQ) — coordinate failure flow (retry → max retries → DLQ)
- ✅ Current bus.sh and router.sh (can be extended)
- Requires: `pran` (heart) agent for heartbeat-based retry, or cron access

---

## Effort Breakdown

| Task | Hours | Assignee |
|------|-------|----------|
| Spec refinement + review | 0.5 | soma |
| Exponential backoff retry loop | 1.5 | innova |
| bus.sh retry subcommand + _failed queue | 1 | innova |
| Heartbeat/cron integration | 1 | innova + pada |
| Integration tests | 1 | chamu (test) |
| protocol.md update + merge | 0.25 | soma |
| **Total** | **5.0** | — |

---

## Success Criteria (Done Definition)

- [x] Spec written and reviewed by soma
- [ ] Code implementation complete (bus.sh, router.sh, retry loop)
- [ ] All tests pass (test_error_recovery.py)
- [ ] Exponential backoff calculated correctly (2, 4, 8, ..., capped)
- [ ] retry-attempt counter increments on each failure
- [ ] Messages re-queued after backoff window via `bus.sh retry`
- [ ] Heartbeat or cron job runs `bus.sh retry` periodically
- [ ] Log entries for `BUS_RETRY` and `BUS_MAX_RETRIES_EXCEEDED`
- [ ] max-retries limit respected (no retries if exceeded)
- [ ] PR merged to main
- [ ] Ticket moved to closed
- [ ] System health check passes (`bash eval/body-check.sh`)

---

## Testing Plan

### Unit Tests
- Exponential backoff calculation (2^attempt * base, capped at 300s)
- retry-attempt counter increments
- max-retries validation (0, 1, 3, 100)
- retry-after validation (positive, zero, negative)

### Integration Tests
- Create message, simulate organ failure, verify retry with correct backoff
- Verify BUS_RETRY log entries include attempt and backoff
- Re-queue messages from _failed/ after retry window passes
- Messages with max-retries:0 don't retry
- Messages with max-retries:3 stop after 3 failures
- Verify backoff window respected (wait 2s, 4s, 8s, etc.)
- Verify retry-at timestamp in filename is parsed and honored

### Regression Tests
- Messages without retry headers use defaults
- Non-retryable failures don't go into _failed queue
- Concurrent retries handled correctly

---

## Timeline

- **Start**: 2026-06-07
- **Spec review by soma**: 2026-06-07 (same day)
- **Implementation**: 2026-06-08 to 2026-06-09 (2 days)
- **Testing & integration**: 2026-06-10 (1 day)
- **Merge**: 2026-06-10
- **Closure**: 2026-06-10

---

## Acceptance Checklist

- [ ] bus.sh send auto-stamps max-retries and retry-after headers
- [ ] router.sh implements exponential backoff retry loop
- [ ] _failed/ queue created and messages moved there on failure
- [ ] retry-at-<ISO> timestamp format in filename
- [ ] retry-attempt header increments on each failure
- [ ] bus.sh retry re-queues messages after backoff window
- [ ] Heartbeat or cron integration working
- [ ] BUS_RETRY and BUS_MAX_RETRIES_EXCEEDED log entries correct
- [ ] Max retries limit enforced (no infinite loops)
- [ ] protocol.md updated with retry header spec
- [ ] test_error_recovery.py passes
- [ ] No regression in other tests
- [ ] Code reviewed and approved by neta

---

## Integration with Other Features

- **JIT-002 (Idempotency)**: Retried messages should have same idempotency key (auto-derived)
- **JIT-004 (DLQ)**: Messages exceeding max-retries move to DLQ, not dropped
- **JIT-001 (TTL)**: Messages with TTL may expire during retry window

---

## Sign-Off

- **Spec Author**: soma
- **Assigned to**: innova (implementation)
- **Reviewed by**: — (pending)
- **Approved by**: — (pending)

