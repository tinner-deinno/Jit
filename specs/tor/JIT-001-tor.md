# JIT-001 TOR: Message TTL (Time-To-Live) Protocol Extension

**Owner**: lak  
**Effort**: 4 hours  
**Priority**: P0  
**Status**: Open

---

## Scope

Extend the มนุษย์ Agent message bus with optional message expiration via `expires-at` headers. Messages can be stamped with a deadline, and the bus will quarantine (not silently drop) expired messages before routing.

### In Scope
- Add `expires-at:<ISO-8601>` and `ttl:<seconds>` header support
- Implement `bus.sh send` auto-stamping with configurable default TTLs per subject
- Implement `bus.sh sweep` quarantine subcommand
- Update `router.sh` to reject expired messages before dispatch
- Create `.reason` sidecars for quarantined messages
- Update protocol.md with new header specification
- Integration tests (test_bus_ttl.py)

### Out of Scope
- Persistence of expired message metadata to Oracle (that's a future enhancement)
- Automatic re-delivery of expired messages
- Web UI for viewing expired messages

---

## Deliverables

1. **Code**:
   - `network/bus.sh`: add `sweep` subcommand, auto-stamp `expires-at` in `send`
   - `limbs/router.sh`: add `_check_expiration()` function, reject expired before dispatch
   - `scripts/config.sh` or `network/bus.conf`: define default TTLs per subject prefix
   - Directory structure: `/tmp/manusat-bus/_expired/`

2. **Documentation**:
   - `network/protocol.md`: add `expires-at` and `ttl` header specification
   - Header semantics, examples, and error handling
   - Version History section with migration notes

3. **Tests**:
   - `tests/test_bus_ttl.py`: unit + integration tests
   - Verify expired messages are quarantined, not dispatched
   - Verify log entries for `BUS_EXPIRED`
   - Verify backward compatibility (no `expires-at` = no expiration)

4. **Process**:
   - Update `tickets/open/JIT-001-bus-message-ttl.yaml` → `tickets/closed/` on merge
   - Log action: `BUS_TTL_FEATURE_READY`

---

## Owner Responsibilities

**lak** (Solution Architect):
- Finalize spec (done — see JIT-001-spec.md)
- Design `bus.sh sweep` subcommand and directory layout
- Implement `router.sh _check_expiration()`
- Review backward compatibility
- Approve PR before merge

**innova** (will execute):
- Implement `bus.sh send` auto-stamping logic
- Write integration tests (test_bus_ttl.py)
- Add config file for default TTLs
- Verify with existing agents (soma, chamu, etc.)

**neta** (code review):
- Review implementation for correctness
- Ensure no silent failures
- Verify error logging is comprehensive

---

## Dependencies

- ✅ Protocol v1 baseline (network/protocol.md exists)
- ✅ Current bus.sh implementation (can be extended)
- ✅ Test framework (test suite already exists)
- Requires: `router.sh` to exist (check `/workspaces/Jit/limbs/router.sh`)

---

## Effort Breakdown

| Task | Hours | Assignee |
|------|-------|----------|
| Spec refinement + review | 0.5 | lak |
| bus.sh `send` + `sweep` implementation | 1.5 | innova |
| router.sh expiration check | 1 | innova |
| Config file (default TTLs) | 0.5 | innova |
| Integration tests | 0.75 | chamu (test) |
| protocol.md update + merge | 0.25 | lak |
| **Total** | **4.0** | — |

---

## Success Criteria (Done Definition)

- [x] Spec written and reviewed by lak
- [ ] Code implementation complete (bus.sh, router.sh, config)
- [ ] All tests pass (test_bus_ttl.py)
- [ ] Backward compatibility verified (messages without `expires-at` work)
- [ ] Log entries for `BUS_EXPIRED` are emitted correctly
- [ ] PR merged to main
- [ ] Ticket moved to closed
- [ ] System health check passes (`bash eval/body-check.sh`)

---

## Testing Plan

### Unit Tests
- Parse ISO-8601 timestamps (valid, invalid, edge cases)
- TTL calculation (positive, zero, negative)
- Subject prefix matching for default TTLs

### Integration Tests
- Create message with custom `--expires-at`
- Create message with `--ttl` (auto-calculate)
- Verify expired message is not routed
- Verify expired message appears in `_expired/`
- Verify `.reason` sidecar contains correct metadata
- Verify `BUS_EXPIRED` log entry is written

### Regression Tests
- Old messages (no `expires-at`) still queue and dispatch
- Broadcast messages work with and without TTL
- Concurrent sweep + message receipt doesn't corrupt queue

---

## Timeline

- **Start**: 2026-06-07
- **Spec review by lak**: 2026-06-07 (same day)
- **Implementation**: 2026-06-08 to 2026-06-09 (2 days)
- **Testing**: 2026-06-10 (1 day)
- **Merge**: 2026-06-10
- **Closure**: 2026-06-10

---

## Acceptance Checklist

- [ ] bus.sh send auto-stamps `expires-at` based on subject or `--ttl`
- [ ] bus.sh sweep quarantines expired messages (no deletion)
- [ ] router.sh rejects expired before dispatch
- [ ] BUS_EXPIRED log entries are correct
- [ ] protocol.md updated with expires-at spec
- [ ] test_bus_ttl.py passes
- [ ] No regression in other bus tests
- [ ] Backward compat verified
- [ ] Code reviewed and approved by neta

---

## Sign-Off

- **Spec Author**: lak
- **Assigned to**: innova (implementation)
- **Reviewed by**: — (pending)
- **Approved by**: — (pending)

