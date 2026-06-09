# JIT-001: Message TTL (Time-To-Live) Protocol Extension

**Status**: Spec  
**Version**: 1.0  
**Owner**: lak (Solution Architect)  
**Date**: 2026-06-07

---

## Overview

Add optional message expiration support to the มนุษย์ Agent bus protocol. Messages may be stamped with an expiration time, and the bus will quarantine expired messages before routing rather than silently dropping them.

---

## Interface Design

### Message Headers

Add one of the following headers to the message format:

**Option A (Recommended):** `expires-at:<ISO-8601>`
```
from:soma
to:innova
subject:task:urgent-fix
timestamp:2026-06-07T10:00:00Z
expires-at:2026-06-07T11:00:00Z
correlation-id:abc-123
---
Fix the critical bug immediately
```

**Option B (Alternative):** `ttl:<seconds>`
```
from:soma
to:innova
subject:task:urgent-fix
timestamp:2026-06-07T10:00:00Z
ttl:3600
correlation-id:abc-123
---
Fix the critical bug immediately
```

**Decision**: Implement Option A (`expires-at`) as primary, support Option B (`ttl`) as fallback for brevity.

### Header Semantics

- **`expires-at:<ISO-8601>`**: Absolute timestamp when message is no longer valid. Format: `YYYY-MM-DDTHH:MM:SSZ`
- **`ttl:<seconds>`**: Relative time-to-live in seconds. Router calculates `expires-at = timestamp + ttl`
- **Behavior if absent**: No expiration (message remains valid indefinitely) — **backward compatible**
- **Default TTLs** (configurable via environment or config file):
  - `task:*` → 1 hour
  - `broadcast:*` → 24 hours
  - `learn:*` → 7 days
  - `alert:*` → 30 minutes (urgent, don't queue stale)

---

## Implementation

### bus.sh send (Message Creation)

When `bus.sh send` is called, automatically stamp the message with `expires-at`:

```bash
bus.sh send <to> <subject> <body> [--ttl 3600] [--expires-at 2026-06-07T15:00:00Z]
```

**Logic**:
1. If `--expires-at` provided: use it directly
2. Else if `--ttl` provided: calculate `expires-at = now + ttl`
3. Else if subject prefix matches a default TTL rule: use default for that prefix
4. Else: omit `expires-at` header (no expiration)

**Example**:
```bash
$ bus.sh send innova "task:create-file" "Please create /tmp/test.txt"
# Automatically stamps: expires-at:2026-06-07T11:00:00Z (1h from now)

$ bus.sh send soma "broadcast:system-ready" "System online" --ttl 86400
# Stamped with: expires-at:2026-06-08T10:00:00Z (24h from now)
```

### bus.sh sweep (New Subcommand)

New subcommand to quarantine expired messages without deleting them:

```bash
bus.sh sweep [--older-than 7d] [--dry-run]
```

**Behavior**:
1. Scan all agent inboxes for `.msg` files
2. For each message, parse `expires-at` header (if present)
3. If `expires-at < now`, move file to `$BUS_ROOT/_expired/<agent>/` directory
4. Write a `.reason` sidecar file with:
   ```
   reason:expired
   expired-at:<ISO-8601>
   original-path:inbox/<agent>/<file>
   ```
5. Log: `BUS_EXPIRED to:<agent> subject:<subject>`

**Options**:
- `--older-than 7d`: Only sweep messages expired > 7 days ago (keep recent for debugging)
- `--dry-run`: Report what would be swept, don't actually move

**Example**:
```bash
$ bus.sh sweep
# Scans /tmp/manusat-bus/*/inbox
# Moves expired messages to /tmp/manusat-bus/_expired/
# Output:
#   Swept 3 expired messages from innova
#   Swept 1 expired message from soma
#   Total: 4 messages moved to _expired/
```

### router.sh dispatch (Message Rejection)

Before dispatching a message to an organ, check if expired:

```bash
# In router.sh route function
_check_expiration() {
  local msg_file="$1"
  local expires_at=$(grep "^expires-at:" "$msg_file" | cut -d: -f2-)
  
  if [ -n "$expires_at" ]; then
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [[ "$expires_at" < "$now" ]]; then
      # Move to expired quarantine
      mv "$msg_file" "$BUS_ROOT/_expired/$(basename $(dirname $msg_file))/$(basename $msg_file)"
      echo "$(basename $(dirname $msg_file))" > "${msg_file%.msg}.expired"
      log_action "BUS_EXPIRED" "subject:$(grep '^subject:' "$msg_file" | cut -d: -f2-)"
      return 1  # Don't dispatch
    fi
  fi
  return 0  # OK to dispatch
}
```

If expired, **do not dispatch**; instead quarantine and emit `BUS_EXPIRED` log entry.

---

## Data Model

### Directory Structure

```
$BUS_ROOT/
├── innova/
│   ├── 1717761600123_from-soma.msg
│   └── 1717761700000_from-jit.msg
├── soma/
│   └── ...
├── _expired/
│   ├── innova/
│   │   ├── 1717761500000_from-jit.msg
│   │   └── 1717761500000_from-jit.reason
│   └── soma/
└── _sweep.log
```

### .reason Sidecar Format

```
reason:expired
expired-at:2026-06-07T10:10:00Z
original-subject:task:urgent-fix
original-from:soma
original-to:innova
ttl-was:3600
expires-at-header:2026-06-07T11:00:00Z
```

---

## Error Cases

| Case | Behavior | Log Entry |
|------|----------|-----------|
| Message has no `expires-at` header | Queue and dispatch normally | `BUS_SEND` (no expiry check) |
| `expires-at` is malformed ISO-8601 | Log warning, treat as no expiration | `BUS_WARN` malformed expires-at |
| Message is expired when dispatched | Quarantine, don't dispatch | `BUS_EXPIRED` |
| `--ttl` is negative | Treat as 0 (expires immediately) | `BUS_WARN` negative ttl |
| `_expired/` directory doesn't exist | Create it on first sweep | (auto-create) |

---

## Backward Compatibility

✅ **Fully backward compatible**:
- Messages without `expires-at` are never expired
- Old bus.sh versions that don't stamp `expires-at` continue to work
- Messages without the header have no expiration enforcement
- `expires-at` is an optional header; parsing doesn't break on missing header

---

## Testing Strategy

1. **Unit tests**:
   - Parse valid `expires-at` timestamps (now, future, past)
   - Parse invalid ISO-8601 gracefully
   - Calculate TTL correctly from subject prefix
   - Timestamp + TTL arithmetic is correct

2. **Integration tests**:
   - Send message with custom `--expires-at`
   - Send message with default TTL based on subject
   - Verify expired message is not dispatched
   - Verify expired message is moved to `_expired/`
   - Verify `.reason` sidecar is written
   - Verify log entry `BUS_EXPIRED` is emitted

3. **Edge cases**:
   - Message expires between send and dispatch
   - Sweep runs concurrently with message receipt
   - `_expired/` fills up with many old messages
   - System clock jumps backward

---

## Success Criteria

- [ ] Message format extended with optional `expires-at` header (protocol.md updated)
- [ ] `bus.sh send` auto-stamps `expires-at` based on subject prefix or `--ttl` argument
- [ ] `bus.sh sweep` quarantines expired messages to `_BUS_ROOT/_expired/` with sidecar
- [ ] `router.sh` rejects expired messages before dispatch and emits `BUS_EXPIRED` log
- [ ] All old messages (without `expires-at`) continue to work unchanged
- [ ] Integration tests pass (see test_bus_ttl.py)
- [ ] Protocol.md Version History updated with migration notes

