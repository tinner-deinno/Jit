# JIT-005 TOR: Protocol Version Field for Bus Messages

**Owner**: soma  
**Effort**: 3 hours  
**Priority**: P2  
**Status**: Open

---

## Scope

Add protocol version support to the มนุษย์ Agent message format to enable forward and backward compatibility as the bus protocol evolves. Each message is stamped with the protocol version it was created under, allowing receivers to handle version mismatches gracefully.

### In Scope
- Add `protocol-version:<semver>` header to message format
- Create `network/protocol-version.txt` as single source-of-truth
- Implement `bus.sh send` auto-stamping with current protocol version
- Implement version check in `bus.sh recv` (warn on mismatch, optionally reject)
- Implement `BUS_MAX_PROTOCOL_VERSION` and `BUS_REJECT_NEWER_PROTOCOL` env vars
- Version comparison logic (1.0 < 1.1 < 2.0)
- Documentation: migration guide in protocol.md

### Out of Scope
- Automatic agent upgrade on version mismatch
- Protocol-version negotiation (agents don't communicate versions)
- Version-specific message parsing (all versions parse same format)

---

## Deliverables

1. **Code**:
   - `network/protocol-version.txt`: single source-of-truth (content: 1.0)
   - `network/bus.sh`: read protocol version, stamp all messages
   - `limbs/router.sh`: add `_check_protocol_version()` function
   - Environment variables: `BUS_PROTOCOL_VERSION`, `BUS_MAX_PROTOCOL_VERSION`, `BUS_REJECT_NEWER_PROTOCOL`
   - Version comparison logic in bash

2. **Documentation**:
   - `network/protocol.md`: add `protocol-version` header specification
   - Version History section with 1.0, 1.1 (future), 2.0 (future)
   - Migration Guide: upgrading protocol versions without breaking agents
   - Backward compatibility notes

3. **Tests**:
   - `tests/test_configuration.py`: unit + integration tests
   - Verify messages are stamped with correct version
   - Verify version comparison logic (1.0 < 1.1 < 2.0)
   - Verify messages without header are assumed 1.0
   - Verify warning on version mismatch
   - Verify strict mode rejects newer protocols

4. **Process**:
   - Update `tickets/open/JIT-005-bus-protocol-versioning.yaml` → `tickets/closed/` on merge
   - Log action: `BUS_PROTOCOL_VERSION_FEATURE_READY`

---

## Owner Responsibilities

**soma** (Strategic Lead):
- Finalize spec (done — see JIT-005-spec.md)
- Define version numbering scheme (semantic versioning)
- Plan future protocol versions (1.1, 2.0)
- Define migration strategy for breaking changes
- Approve PR before merge

**innova** (will execute):
- Implement version stamping in `bus.sh send`
- Implement version checking in `bus.sh recv` and `router.sh`
- Create `protocol-version.txt` with source-of-truth version
- Implement version comparison logic (bash)
- Write integration tests (test_configuration.py)

**neta** (code review):
- Review version comparison logic for correctness
- Verify backward compatibility (missing headers treated as 1.0)
- Ensure migration path is sound

---

## Dependencies

- ✅ Protocol v1 baseline (network/protocol.md exists)
- ✅ Current bus.sh and router.sh (can be extended)
- No dependency on other bus protocol features (JIT-001..004)
  - Can be implemented independently

---

## Effort Breakdown

| Task | Hours | Assignee |
|------|-------|----------|
| Spec refinement + review | 0.25 | soma |
| Create protocol-version.txt | 0.1 | innova |
| bus.sh version stamping | 0.5 | innova |
| Version check + comparison logic | 0.75 | innova |
| Integration tests | 0.5 | chamu (test) |
| protocol.md update + merge | 0.25 | soma |
| **Total** | **3.0** | — |

---

## Success Criteria (Done Definition)

- [x] Spec written and reviewed by soma
- [ ] `protocol-version.txt` created with version 1.0
- [ ] Code implementation complete (bus.sh, router.sh, version logic)
- [ ] All tests pass (test_configuration.py)
- [ ] Messages stamped with current protocol version
- [ ] Version mismatch warnings logged correctly
- [ ] Backward compatibility verified (missing header = 1.0)
- [ ] Version comparison logic correct (1.0 < 1.1 < 2.0)
- [ ] Optional strict mode rejects newer versions
- [ ] PR merged to main
- [ ] Ticket moved to closed
- [ ] System health check passes (`bash eval/body-check.sh`)

---

## Testing Plan

### Unit Tests
- Parse valid semantic versions (1.0, 1.1, 1.2, 2.0)
- Version comparison (is 2.0 > 1.1 > 1.0?)
- Handle missing protocol-version header (assume 1.0)
- Handle malformed version strings

### Integration Tests
- Create message, verify protocol-version:1.0 is stamped
- Receive message without header, assume 1.0
- Receiver with BUS_MAX_PROTOCOL_VERSION=1.0 sees 1.0 message (no warning)
- Receiver sees message from future version (log warning)
- Strict mode (BUS_REJECT_NEWER_PROTOCOL=true) rejects newer versions
- Verify version comparison across multiple versions

### Regression Tests
- Old messages without protocol-version header still work
- All existing bus.sh commands work with version header

---

## Timeline

- **Start**: 2026-06-10 (independent of other features)
- **Spec review by soma**: 2026-06-10 (same day)
- **Implementation**: 2026-06-10 (1 day)
- **Testing**: 2026-06-10 to 2026-06-11 (1 day)
- **Merge**: 2026-06-11
- **Closure**: 2026-06-11

---

## Acceptance Checklist

- [ ] protocol-version.txt created with content "1.0"
- [ ] bus.sh send stamps protocol-version:1.0 on all messages
- [ ] bus.sh recv checks and warns on version mismatch
- [ ] Version comparison logic works (1.0 < 1.1 < 2.0)
- [ ] Messages without header treated as 1.0 (backward compat)
- [ ] BUS_MAX_PROTOCOL_VERSION and BUS_REJECT_NEWER_PROTOCOL env vars work
- [ ] protocol.md updated with protocol-version spec
- [ ] Migration guide documented in protocol.md
- [ ] test_configuration.py passes
- [ ] No regression in other bus tests
- [ ] Code reviewed and approved by neta

---

## Future Extensions

This work enables:

1. **v1.1 release** (when JIT-001..004 are merged):
   - Update protocol-version.txt to 1.1
   - Add expires-at, idempotency-key, max-retries, retry-after headers
   - Old agents see 1.1 messages, log warning, gracefully degrade

2. **v2.0 release** (future breaking change):
   - Requires coordinated deployment
   - Rename headers, change formats
   - Old agents reject 2.0 messages

---

## Sign-Off

- **Spec Author**: soma
- **Assigned to**: innova (implementation)
- **Reviewed by**: — (pending)
- **Approved by**: — (pending)

