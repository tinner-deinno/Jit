# JIT-002: Idempotency Key Protocol Extension

**Status**: Spec  
**Version**: 1.0  
**Owner**: lak (Solution Architect)  
**Date**: 2026-06-07

---

## Overview

Add idempotency key support to the มนุษย์ Agent bus protocol to prevent duplicate message processing. Each message is assigned a unique idempotency key that can be checked to deduplicate messages within a 24-hour window.

---

## Interface Design

### Message Headers

Add the following header to message format:

```
from:innova
to:chamu
subject:task:run-tests
timestamp:2026-06-07T10:00:00Z
idempotency-key:550e8400-e29b-41d4-a716-446655440000
correlation-id:abc-123
---
Please run full test suite and report results
```

### Header Semantics

- **`idempotency-key:<uuid>`**: Unique identifier for deduplicating this message within 24 hours
  - Format: UUID v4 (32 hex chars + 4 hyphens)
  - May be explicitly provided by sender or auto-derived by bus
  - If same key received twice within 24h window, second is treated as duplicate

**Three modes of key generation**:

1. **Explicit** (sender specifies):
   ```bash
   bus.sh send innova "task:urgent" "Fix now" --idempotency-key "550e8400-e29b-41d4-a716-446655440000"
   ```

2. **Deterministic** (derived from message content):
   ```
   idempotency-key = md5(from + subject + body) → uuid-like format
   Example: hash(innova + task:urgent + "Fix now") → 550e8400-e29b-41d4-a716-446655440000
   ```

3. **Automatic** (auto-generated UUID):
   ```bash
   bus.sh send innova "task:urgent" "Fix now"
   # auto-generates: idempotency-key:550e8400-e29b-41d4-a716-446655440000
   ```

**Recommendation**: Use mode 2 (deterministic from content) so identical messages sent twice get the same key automatically.

---

## Implementation

### bus.sh send (Message Creation)

When `bus.sh send` is called, generate or use provided idempotency key:

```bash
bus.sh send <to> <subject> <body> [--idempotency-key <uuid>]
```

**Logic**:
1. If `--idempotency-key` provided: use it directly
2. Else: derive from `hash(from + subject + body)` → UUID-like format
3. Add header to message: `idempotency-key:<generated-or-provided>`
4. Write sidecar `.key` file to agent inbox with key mapping

**Example**:
```bash
$ bus.sh send innova "task:create-file" "Create /tmp/test.txt"
# Auto-derives: idempotency-key:a1b2c3d4-e5f6-7890-abcd-ef1234567890
# Creates sidecar: /tmp/manusat-bus/innova/.keys/a1b2c3d4-e5f6-7890-abcd-ef1234567890

$ bus.sh send innova "task:create-file" "Create /tmp/test.txt" --idempotency-key my-key-123
# Uses explicit: idempotency-key:my-key-123
```

### .keys Sidecar Index

Each agent inbox has a `.keys/` directory tracking processed idempotency keys:

```
/tmp/manusat-bus/innova/
├── 1717761600123_from-soma.msg
├── 1717761600123_from-soma.key (sidecar)
└── .keys/
    ├── a1b2c3d4-e5f6-7890-abcd-ef1234567890 → "2026-06-07T10:00:00Z"
    ├── b2c3d4e5-f6a7-8901-bcde-f12345678901 → "2026-06-07T09:30:00Z"
    └── ... (one entry per processed key, stores timestamp)
```

**Format of .keys index file**:
```
# One line per key: <idempotency-key>:<timestamp-processed>:<subject>
a1b2c3d4-e5f6-7890-abcd-ef1234567890:2026-06-07T10:00:00Z:task:create-file
b2c3d4e5-f6a7-8901-bcde-f12345678901:2026-06-07T09:30:00Z:task:run-tests
```

### bus.sh recv (Message Deduplication)

When receiving messages, check if idempotency key was already processed:

```bash
_check_idempotency() {
  local msg_file="$1"
  local agent="$2"
  local idem_key=$(grep "^idempotency-key:" "$msg_file" | cut -d: -f2-)
  
  if [ -z "$idem_key" ]; then
    return 0  # No key, proceed
  fi
  
  local keys_file="/tmp/manusat-bus/$agent/.keys/index"
  mkdir -p "$(dirname $keys_file)"
  
  # Check if key was seen in last 24h
  if grep -q "^${idem_key}:" "$keys_file" 2>/dev/null; then
    local seen_at=$(grep "^${idem_key}:" "$keys_file" | cut -d: -f2)
    local now=$(date -u +%s)
    local seen_ts=$(date -d "$seen_at" -u +%s)
    local age=$((now - seen_ts))
    
    if [ "$age" -lt 86400 ]; then
      # Duplicate within 24h window
      log_action "BUS_DUPLICATE" "key:${idem_key} age:${age}s"
      return 1  # Skip processing
    fi
  fi
  
  # Mark key as processed
  echo "${idem_key}:$(date -u '+%Y-%m-%dT%H:%M:%SZ'):$(grep '^subject:' "$msg_file" | cut -d: -f2-)" >> "$keys_file"
  return 0  # OK to process
}
```

**24-hour window**:
- Keys older than 24h are automatically expired
- Cleanup: purge keys older than 24h when index file grows > 10k lines
- Fallback: if Oracle is available, persist keys there (longer retention)

### router.sh dispatch (Idempotency Check)

Before dispatching a message, check if it's a duplicate:

```bash
# In router.sh route function
if ! _check_idempotency "$msg_file" "$to_agent"; then
  log_action "BUS_DUPLICATE" "subject:$(grep '^subject:' "$msg_file" | cut -d: -f2-)"
  # Do NOT dispatch; remove from queue
  mv "$msg_file" "${msg_file%.msg}.duplicate"
  return 1
fi
```

If duplicate is detected, **do not dispatch**; mark as `.duplicate` and emit `BUS_DUPLICATE` log.

---

## Data Model

### Message Header

```
idempotency-key:<uuid-or-string>
```

- UUID format: `550e8400-e29b-41d4-a716-446655440000` (standard UUID v4)
- String format: any alphanumeric key (e.g., `task-123-run-1`) if sender wants custom
- Max length: 256 characters
- Required: No (messages without it are never deduplicated)

### Directory Structure

```
$BUS_ROOT/
├── innova/
│   ├── 1717761600123_from-soma.msg
│   ├── 1717761600123_from-soma.key (sidecar)
│   └── .keys/
│       └── index  (sorted file of processed keys)
├── soma/
│   ├── .keys/
│   └── index
└── ... (per agent)
```

### .keys/index Format

```
a1b2c3d4-e5f6-7890-abcd-ef1234567890:2026-06-07T10:00:00Z:task:create-file
b2c3d4e5-f6a7-8901-bcde-f12345678901:2026-06-07T09:30:00Z:task:run-tests
c3d4e5f6-a7b8-9012-cdef-123456789012:2026-06-07T08:15:00Z:broadcast:system-ready
```

---

## Error Cases

| Case | Behavior | Log Entry |
|------|----------|-----------|
| Message has no `idempotency-key` | Queue and dispatch normally | `BUS_SEND` (no dedup) |
| Key is malformed UUID | Accept it, treat as string key | `BUS_WARN` malformed uuid |
| Duplicate key seen < 24h ago | Don't dispatch, mark as duplicate | `BUS_DUPLICATE` |
| Duplicate key seen > 24h ago | Accept and process (key expired) | `BUS_SEND` (re-process allowed) |
| .keys/index file corrupted | Rebuild from sidecar files | `BUS_WARN` rebuild keys index |
| .keys/index grows > 10k lines | Trim old entries (> 24h) | `BUS_CLEANUP` trimmed N keys |

---

## Backward Compatibility

✅ **Fully backward compatible**:
- Messages without `idempotency-key` header are never deduplicated
- Old bus.sh versions that don't provide idempotency keys continue to work
- Adding the header is optional; its absence doesn't break anything

---

## Testing Strategy

1. **Unit tests**:
   - Parse valid UUID formats
   - Parse custom string keys
   - Handle malformed UUID gracefully
   - 24-hour window calculation

2. **Integration tests**:
   - Send message without key → processes normally
   - Send same message twice with auto-derived key → second is deduplicated
   - Send message with explicit key → key is used
   - Send duplicate within 24h → rejected with `BUS_DUPLICATE` log
   - Send duplicate after 24h → accepted (key expired)
   - Verify .keys/index tracks all keys correctly

3. **Edge cases**:
   - Key is empty string
   - Key contains special characters
   - .keys/index becomes very large (10k+ entries)
   - System clock jumps backward
   - Concurrent duplicate arrivals

---

## Success Criteria

- [ ] Message format extended with optional `idempotency-key` header (protocol.md updated)
- [ ] `bus.sh send` auto-derives or uses provided idempotency key
- [ ] `.keys/` directory created per agent inbox
- [ ] `bus.sh recv` checks idempotency within 24-hour window
- [ ] `router.sh` rejects duplicates before dispatch and emits `BUS_DUPLICATE` log
- [ ] Duplicate messages are marked `.duplicate` (not deleted)
- [ ] All old messages (without key) continue to work unchanged
- [ ] 24-hour key expiration works correctly
- [ ] Integration tests pass (see test_bus_idempotency_dlq.py)
- [ ] Protocol.md Version History updated with migration notes

