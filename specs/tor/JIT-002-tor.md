# JIT-002 TOR: Idempotency Key Protocol Extension

**Owner**: lak  
**Effort**: 6 hours  
**Priority**: P0  
**Status**: Open

---

## Scope

Extend the มนุษย์ Agent message bus with idempotency key support to prevent duplicate message processing. Each message is assigned a unique key, and duplicate keys within a 24-hour window are rejected before dispatch.

### In Scope
- Add `idempotency-key:<uuid>` header support
- Implement auto-derivation of keys from message content (deterministic)
- Implement `.keys/` index per agent inbox to track processed keys
- Support explicit key provision via `--idempotency-key` argument
- Implement 24-hour deduplication window with automatic expiration
- Update `bus.sh recv` to check idempotency
- Update `router.sh` to reject duplicates before dispatch
- Integration tests (test_bus_idempotency_dlq.py)

### Out of Scope
- Persistence of idempotency keys to Oracle (future enhancement)
- Replay mechanism for deduplicated messages
- Per-agent custom deduplication windows (all use 24h)

---

## Deliverables

1. **Code**:
   - `network/bus.sh`: add idempotency key generation in `send`, dedup check in `recv`
   - `limbs/router.sh`: add `_check_idempotency()` function, reject duplicates before dispatch
   - `.keys/` directory creation per agent inbox
   - Key index file format (line-delimited: key:timestamp:subject)

2. **Documentation**:
   - `network/protocol.md`: add `idempotency-key` header specification
   - Semantics: explicit vs. auto-derived vs. deterministic generation
   - 24-hour window behavior and key expiration
   - Version History section with migration notes

3. **Tests**:
   - `tests/test_bus_idempotency_dlq.py`: unit + integration tests
   - Verify duplicate keys are rejected within 24h
   - Verify keys expire after 24h
   - Verify log entries for `BUS_DUPLICATE`
   - Verify backward compatibility (no key = no dedup)

4. **Process**:
   - Update `tickets/open/JIT-002-bus-idempotency-key.yaml` → `tickets/closed/` on merge
   - Log action: `BUS_IDEMPOTENCY_FEATURE_READY`

---

## Owner Responsibilities

**lak** (Solution Architect):
- Finalize spec (done — see JIT-002-spec.md)
- Design key index file format and .keys/ directory structure
- Define 24-hour window semantics and expiration behavior
- Review backward compatibility
- Approve PR before merge

**innova** (will execute):
- Implement key generation logic (explicit, auto-derived, deterministic hash)
- Implement `.keys/` index management and cleanup
- Implement `bus.sh recv` deduplication check
- Write integration tests (test_bus_idempotency_dlq.py)
- Verify with existing agents

**neta** (code review):
- Review deduplication logic for correctness
- Verify 24-hour window logic is sound
- Ensure no messages are silently lost
- Verify log entries are comprehensive

---

## Dependencies

- ✅ Protocol v1 baseline (network/protocol.md exists)
- ✅ JIT-001 (TTL) — independent, but both modify protocol.md (coordinate merge order)
- ✅ Current bus.sh implementation (can be extended)
- Requires: `router.sh` to exist

---

## Effort Breakdown

| Task | Hours | Assignee |
|------|-------|----------|
| Spec refinement + review | 0.5 | lak |
| Key generation (explicit/auto/deterministic) | 1.5 | innova |
| .keys/ index management + cleanup | 1.5 | innova |
| bus.sh recv + router.sh integration | 1.5 | innova |
| Integration tests | 1 | chamu (test) |
| protocol.md update + merge | 0.25 | lak |
| **Total** | **6.0** | — |

---

## Success Criteria (Done Definition)

- [x] Spec written and reviewed by lak
- [ ] Code implementation complete (bus.sh, router.sh, key index)
- [ ] All tests pass (test_bus_idempotency_dlq.py)
- [ ] Backward compatibility verified (messages without key work)
- [ ] Deterministic key generation works (same message → same key)
- [ ] 24-hour window enforced and expired keys are cleaned up
- [ ] Log entries for `BUS_DUPLICATE` are emitted correctly
- [ ] PR merged to main
- [ ] Ticket moved to closed
- [ ] System health check passes (`bash eval/body-check.sh`)

---

## Testing Plan

### Unit Tests
- Generate explicit UUID keys
- Auto-derive deterministic keys from content
- Parse and validate UUID format
- Handle custom string keys
- 24-hour window calculation and expiration
- Key index cleanup logic

### Integration Tests
- Create message without key → no dedup
- Create message and send twice → second is rejected
- Explicit key provision → key is used
- Deterministic generation → same content = same key
- Duplicate within 24h → `BUS_DUPLICATE` log
- Duplicate after 24h → accepted (key expired)
- Verify .keys/index tracks all keys

### Regression Tests
- Messages without key still work
- Broadcast messages work with idempotency
- Concurrent duplicate arrivals handled correctly

---

## Timeline

- **Start**: 2026-06-07
- **Spec review by lak**: 2026-06-07 (same day)
- **Implementation**: 2026-06-08 to 2026-06-10 (3 days)
- **Testing**: 2026-06-11 (1 day)
- **Merge**: 2026-06-11
- **Closure**: 2026-06-11

---

## Acceptance Checklist

- [ ] bus.sh send auto-derives or accepts idempotency key
- [ ] .keys/index created per agent inbox
- [ ] 24-hour deduplication window enforced
- [ ] router.sh rejects duplicates before dispatch
- [ ] BUS_DUPLICATE log entries are correct
- [ ] Keys expire and are cleaned up after 24h
- [ ] protocol.md updated with idempotency-key spec
- [ ] test_bus_idempotency_dlq.py passes
- [ ] No regression in other bus tests
- [ ] Backward compat verified
- [ ] Code reviewed and approved by neta

---

## Sign-Off

- **Spec Author**: lak
- **Assigned to**: innova (implementation)
- **Reviewed by**: — (pending)
- **Approved by**: — (pending)

