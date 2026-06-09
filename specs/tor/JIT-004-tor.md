# JIT-004 TOR: Dead-Letter Queue (DLQ) for Bus Failures

**Owner**: lak  
**Effort**: 5 hours  
**Priority**: P1  
**Status**: Open

---

## Scope

Implement a dead-letter queue (DLQ) system for the มนุษย์ Agent message bus. Messages that fail permanently are moved to categorized DLQ directories with failure metadata, enabling post-mortem analysis, manual replay, and observability into bus failures.

### In Scope
- Create `_dlq/<reason>/` directory structure (expired, unrouted, max-retries, duplicate, invalid, timeout)
- Implement `bus.sh dlq` subcommand (list, replay, purge, stats)
- Write `.reason` sidecar files with failure metadata
- Integrate DLQ moves into router.sh and bus.sh sweep
- Implement `alert:dlq-growing` broadcast when threshold exceeded
- Integration tests (test_bus_idempotency_dlq.py)

### Out of Scope
- Persistence of DLQ metadata to Oracle
- Web UI for DLQ management
- Automated DLQ cleanup policies (only manual purge via `dlq purge`)
- DLQ analytics or trend reporting

---

## Deliverables

1. **Code**:
   - `network/bus.sh`: implement `dlq list|replay|purge|stats` subcommands
   - `limbs/router.sh`: implement `_move_to_dlq()` function and integrate into dispatch failures
   - `_dlq/<reason>/` directory structure (auto-create)
   - `.reason` sidecar files with failure metadata
   - `_check_dlq_depth()` function in bus.sh for alert threshold

2. **Documentation**:
   - `network/protocol.md`: DLQ category specification and `.reason` format
   - DLQ semantics, replay behavior, purge policy
   - Version History section with migration notes

3. **Tests**:
   - `tests/test_bus_idempotency_dlq.py`: unit + integration tests
   - Verify messages are moved to correct DLQ category
   - Verify `.reason` sidecar contains correct metadata
   - Verify dlq replay re-injects messages
   - Verify dlq purge deletes old messages
   - Verify alert threshold detection

4. **Process**:
   - Update `tickets/open/JIT-004-bus-dlq.yaml` → `tickets/closed/` on merge
   - Log action: `BUS_DLQ_FEATURE_READY`

---

## Owner Responsibilities

**lak** (Solution Architect):
- Finalize spec (done — see JIT-004-spec.md)
- Design DLQ category taxonomy and .reason sidecar format
- Define alert thresholds (default: 20 messages)
- Coordinate with JIT-003 (Retry) on failure flow
- Approve PR before merge

**innova** (will execute):
- Implement `bus.sh dlq` subcommand (list, replay, purge, stats)
- Implement `_move_to_dlq()` function in router.sh
- Integrate DLQ moves into failure paths
- Implement alert threshold checking
- Write integration tests (test_bus_idempotency_dlq.py)

**pada** (DevOps):
- Monitor DLQ depth and growth rate
- Set up alerts for `alert:dlq-growing` and fast-growing categories
- Define retention policies (e.g., purge after 30 days)

**neta** (code review):
- Review DLQ move logic for correctness
- Verify no messages are silently lost
- Ensure sidecar metadata is complete and accurate

---

## Dependencies

- ✅ Protocol v1 baseline (network/protocol.md exists)
- ✅ JIT-003 (Retry) — should be merged first (DLQ is end of retry chain)
- ✅ JIT-001 (TTL) and JIT-002 (Idempotency) — may feed messages to DLQ
- ✅ Current bus.sh and router.sh (can be extended)

---

## Effort Breakdown

| Task | Hours | Assignee |
|------|-------|----------|
| Spec refinement + review | 0.5 | lak |
| bus.sh dlq subcommand (list/replay/purge/stats) | 1.5 | innova |
| router.sh _move_to_dlq() + integration | 1.5 | innova |
| Alert threshold checking | 0.5 | innova |
| Integration tests | 1 | chamu (test) |
| protocol.md update + merge | 0.25 | lak |
| **Total** | **5.0** | — |

---

## Success Criteria (Done Definition)

- [x] Spec written and reviewed by lak
- [ ] Code implementation complete (bus.sh dlq, router.sh _move_to_dlq)
- [ ] All tests pass (test_bus_idempotency_dlq.py)
- [ ] DLQ categories created (expired, unrouted, max-retries, duplicate, invalid, timeout)
- [ ] Messages moved to correct DLQ category with .reason sidecar
- [ ] dlq list shows DLQ contents by category
- [ ] dlq replay re-injects messages to inbox
- [ ] dlq purge deletes old messages
- [ ] `alert:dlq-growing` emitted when threshold exceeded
- [ ] Log entries for `BUS_DLQ_MOVE` and `ALERT_DLQ_GROWING`
- [ ] PR merged to main
- [ ] Ticket moved to closed
- [ ] System health check passes (`bash eval/body-check.sh`)

---

## Testing Plan

### Unit Tests
- `.reason` sidecar format parsing
- DLQ category classification
- Threshold alert calculation (total > threshold)
- File operations (move, rename, cleanup)

### Integration Tests
- Create message, let it fail (retry exhaustion), verify moved to max-retries/
- Verify .reason sidecar contains correct metadata (original-to, from, subject, failed-at)
- dlq list --reason shows correct category
- dlq replay moves message from _dlq/ back to inbox
- dlq purge --older-than 7d deletes old messages
- Verify BUS_DLQ_MOVE and ALERT_DLQ_GROWING log entries
- Concurrent DLQ moves don't corrupt directory

### Regression Tests
- Old messages without DLQ system still work
- Messages that don't fail continue normally

---

## Timeline

- **Start**: 2026-06-08 (after JIT-003 merge)
- **Spec review by lak**: 2026-06-08 (same day)
- **Implementation**: 2026-06-09 to 2026-06-10 (2 days)
- **Testing**: 2026-06-11 (1 day)
- **Merge**: 2026-06-11
- **Closure**: 2026-06-11

---

## Acceptance Checklist

- [ ] _dlq/ directory created with reason categories
- [ ] bus.sh dlq subcommand works (list, replay, purge, stats)
- [ ] Failed messages moved to correct DLQ category
- [ ] .reason sidecar contains failure metadata
- [ ] BUS_DLQ_MOVE log entries are correct
- [ ] dlq replay re-injects messages
- [ ] dlq purge deletes old messages
- [ ] alert:dlq-growing broadcast when threshold exceeded
- [ ] protocol.md updated with DLQ spec
- [ ] test_bus_idempotency_dlq.py passes
- [ ] No regression in other bus tests
- [ ] Code reviewed and approved by neta

---

## Monitoring & Alerting

**Alerts to set up (via /workspaces/Jit/organs/mouth.sh broadcast)**:
- `alert:dlq-growing` when DLQ > 20 messages
- `alert:dlq-fast-growing` when DLQ growth > 5/hour
- `alert:dlq-<reason>-spike` for specific categories

These can be broadcast by `bus.sh` or monitored externally.

---

## Sign-Off

- **Spec Author**: lak
- **Assigned to**: innova (implementation)
- **Reviewed by**: — (pending)
- **Approved by**: — (pending)

