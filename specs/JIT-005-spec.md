# JIT-005: Protocol Version Field for Bus Messages

**Status**: Spec  
**Version**: 1.0  
**Owner**: soma (Strategic Lead)  
**Date**: 2026-06-07

---

## Overview

Add a protocol version field to the มนุษย์ Agent message format to enable forward and backward compatibility as the bus protocol evolves. Each message is stamped with the protocol version it was created under, allowing receivers to understand and handle version mismatches gracefully.

---

## Interface Design

### Message Header

Add the following header to message format:

```
from:soma
to:innova
subject:task:urgent-fix
timestamp:2026-06-07T10:00:00Z
protocol-version:1.0
correlation-id:abc-123
---
Fix the critical bug immediately
```

### Header Semantics

- **`protocol-version:<semver>`**: Semantic version of the bus protocol
  - Format: `<major>.<minor>` (e.g., `1.0`, `1.1`, `2.0`)
  - Required header (always stamped by bus.sh)
  - Default (backward compatibility): `1.0`
  - Current version: `1.0`

**Version History**:
- **1.0**: Original protocol (from, to, subject, timestamp, correlation-id)
- **1.1** (future): Add `expires-at`, `idempotency-key`, `max-retries`, `retry-after`
- **2.0** (future): Breaking changes to message format

---

## Implementation

### bus.sh send (Message Creation)

When `bus.sh send` is called, stamp message with current protocol version:

```bash
bus.sh send <to> <subject> <body>
```

**Logic**:
1. Read protocol version from single source-of-truth: `$SCRIPT_DIR/protocol-version.txt` or `BUS_PROTOCOL_VERSION` env var
2. Add header to message: `protocol-version:<version>`
3. Proceed with normal message send

**Example**:
```bash
$ cat /workspaces/Jit/network/protocol-version.txt
1.0

$ bus.sh send innova "task:create-file" "Create /tmp/test.txt"
# Automatically stamps: protocol-version:1.0
```

### bus.sh recv (Version Check)

When receiving messages, log warning if protocol version is newer than receiver's max:

```bash
_check_protocol_version() {
  local msg_file="$1"
  local receiver_agent="$2"
  local msg_version=$(grep "^protocol-version:" "$msg_file" | cut -d: -f2- | tr -d ' ')
  local max_version="${BUS_MAX_PROTOCOL_VERSION:-1.0}"
  
  if [ -z "$msg_version" ]; then
    # No version header (very old message), assume 1.0
    msg_version="1.0"
  fi
  
  # Compare versions (simple string comparison for 1.0 vs 1.1 vs 2.0)
  if _version_greater_than "$msg_version" "$max_version"; then
    log_action "BUS_WARN" "protocol version mismatch: message is $msg_version, receiver supports up to $max_version"
    
    # Optionally reject if configured
    if [ "${BUS_REJECT_NEWER_PROTOCOL:-false}" = "true" ]; then
      log_action "BUS_REJECT" "newer protocol version"
      return 1  # Reject message
    fi
  fi
  
  return 0  # OK to process
}

_version_greater_than() {
  local v1="$1"
  local v2="$2"
  # Simple comparison: 2.0 > 1.1 > 1.0
  [ "$(printf '%s\n' "$v1" "$v2" | sort -rV | head -n1)" = "$v1" ] && [ "$v1" != "$v2" ]
}
```

### router.sh dispatch (Version Compatibility)

Before dispatching, check protocol version compatibility:

```bash
# In router.sh route function
if ! _check_protocol_version "$msg_file" "$to_agent"; then
  log_action "BUS_PROTOCOL_MISMATCH" "subject:$(grep '^subject:' "$msg_file")"
  # Move to DLQ if configured to reject newer protocols
  if [ "${BUS_REJECT_NEWER_PROTOCOL:-false}" = "true" ]; then
    _move_to_dlq "$msg_file" "protocol-mismatch" "Protocol version too new"
  else
    # Just warn and dispatch anyway (permissive mode)
    _dispatch_to_organ "$msg_file" "$to_agent"
  fi
fi
```

### Source of Truth: protocol-version.txt

Create a single source-of-truth file in the network directory:

```
/workspaces/Jit/network/protocol-version.txt

1.0
```

**Usage in bus.sh**:
```bash
BUS_PROTOCOL_VERSION=$(cat "$SCRIPT_DIR/protocol-version.txt" | tr -d '\n ')
```

---

## Upgrade Strategy

### Scenario: Adding new headers (1.0 → 1.1)

When extending protocol (e.g., JIT-001 adds `expires-at`):

1. **Update protocol-version.txt**:
   ```
   # OLD: 1.0
   # NEW: 1.1
   ```

2. **bus.sh send** now stamps `protocol-version:1.1`

3. **Old receivers** (BUS_MAX_PROTOCOL_VERSION=1.0):
   - See version 1.1 message
   - Log warning: "protocol version mismatch: message is 1.1, receiver supports up to 1.0"
   - Proceed with dispatch (graceful degradation)
   - Ignore unknown headers (expires-at)

4. **New receivers** (BUS_MAX_PROTOCOL_VERSION=1.1):
   - Process message normally
   - Parse and respect `expires-at` header

5. **After all agents upgraded**: Can safely remove backward compat code

### Scenario: Breaking change (1.x → 2.0)

When making breaking changes to message format (e.g., `subject:` → `action:`):

1. **Update protocol-version.txt**: `2.0`

2. **bus.sh send** now stamps `protocol-version:2.0`

3. **Old receivers** (BUS_MAX_PROTOCOL_VERSION=1.x):
   - See version 2.0 message
   - Log error: "protocol version too new"
   - Move to DLQ OR reject message (if BUS_REJECT_NEWER_PROTOCOL=true)

4. **Coordinate deployment**:
   - Update all agents to support protocol 2.0 first
   - Set BUS_MAX_PROTOCOL_VERSION=2.0 globally
   - Then update protocol-version.txt to 2.0

---

## Data Model

### File: protocol-version.txt

```
/workspaces/Jit/network/protocol-version.txt

Content:
1.0
```

Format: Single line with semantic version (major.minor), no trailing newline needed (trimmed on read).

### Environment Variables

- **`BUS_PROTOCOL_VERSION`**: Current protocol version (read from protocol-version.txt)
  - Set by bus.sh on startup
  - Used when stamping new messages
  
- **`BUS_MAX_PROTOCOL_VERSION`**: Maximum protocol version receiver supports
  - Default: `1.0`
  - Can be set per agent or globally
  - If message version > this, warn or reject

- **`BUS_REJECT_NEWER_PROTOCOL`**: Boolean flag to reject messages with newer protocol
  - Default: `false` (permissive — log warning but dispatch)
  - Can be set to `true` for strict mode

---

## Error Cases

| Case | Behavior | Log Entry |
|------|----------|-----------|
| Message has no `protocol-version` | Assume version 1.0 | `BUS_WARN` no protocol-version |
| Message version > receiver max | Log warning, dispatch anyway | `BUS_WARN` protocol version mismatch |
| Message version > receiver max (strict) | Reject, move to DLQ | `BUS_REJECT` newer protocol |
| protocol-version.txt missing | Default to 1.0 | `BUS_WARN` protocol version not found |
| protocol-version.txt malformed | Default to 1.0 | `BUS_WARN` invalid protocol version |
| Version comparison fails | Treat as compatible | (no log, proceed) |

---

## Backward Compatibility

✅ **Fully backward compatible**:
- Messages without `protocol-version` header are assumed to be version 1.0
- Old bus.sh versions that don't stamp protocol version continue to work
- New receivers gracefully handle missing header
- Adding version header doesn't break existing parsing

**Migration path**:
1. Deploy code that reads protocol-version header (doesn't break on missing)
2. Update bus.sh to stamp protocol-version:1.0 (all new messages)
3. Old messages continue to work (assumed 1.0)
4. Future protocol changes use versioning to manage compatibility

---

## Testing Strategy

1. **Unit tests**:
   - Parse valid semantic versions (1.0, 1.1, 2.0)
   - Version comparison (is 2.0 > 1.1 > 1.0?)
   - Handle missing protocol-version header (assume 1.0)
   - Handle malformed versions gracefully

2. **Integration tests**:
   - Send message with protocol-version:1.0
   - Receive message with no protocol-version (assume 1.0)
   - Receiver with BUS_MAX_PROTOCOL_VERSION:1.0 sees version 1.0 message (no warning)
   - Receiver sees newer version (log warning, still dispatch)
   - Strict mode (BUS_REJECT_NEWER_PROTOCOL=true) rejects newer versions

3. **Edge cases**:
   - protocol-version.txt missing (default to 1.0)
   - Message with invalid version string
   - Comparison of many version numbers (1.0, 1.1, 1.2, 2.0, etc.)

---

## Success Criteria

- [ ] `protocol-version:<semver>` header added to message format
- [ ] Single source-of-truth: `network/protocol-version.txt` created
- [ ] `bus.sh send` auto-stamps current protocol version
- [ ] `bus.sh recv` checks for version mismatches and logs warnings
- [ ] `router.sh` integrates version check before dispatch
- [ ] Backward compatibility verified (messages without header work)
- [ ] Version comparison logic is correct (1.0 < 1.1 < 2.0)
- [ ] protocol.md Version History section updated with header spec
- [ ] Integration tests pass (see test_configuration.py)
- [ ] Migration guide documented in protocol.md

---

## Documentation: Version History

Add to protocol.md:

```markdown
## Version History

### v1.0 (Current)
- Headers: from, to, subject, timestamp, correlation-id, protocol-version
- All features: None yet

### v1.1 (Planning)
- Add headers: expires-at, idempotency-key, max-retries, retry-after
- No breaking changes to existing headers

### v2.0 (Future)
- Breaking change: rename subject: → action: (example)
- Coordinate all agents before deploying

## Migration Guide

### Upgrading to v1.1
1. Deploy code that understands v1.1 headers
2. Update BUS_MAX_PROTOCOL_VERSION to 1.1
3. Update protocol-version.txt to 1.1
4. All new messages will use v1.1

Older agents (BUS_MAX_PROTOCOL_VERSION=1.0) will:
- Log warning on seeing v1.1 headers
- Gracefully ignore unknown headers
- Continue operating normally

### Upgrading to v2.0 (Breaking)
**Requires coordinated deployment**:
1. All agents must be updated to understand v2.0 format
2. Set BUS_MAX_PROTOCOL_VERSION=2.0 globally
3. Update protocol-version.txt to 2.0
4. No v1.x agents should run during this transition
```

---

## Long-term Vision

This versioning enables:
- Adding new headers without breaking old agents
- Graceful handling of old and new messages during deployments
- Clear upgrade paths and migration guides
- Future protocol innovations without system-wide rewrites

