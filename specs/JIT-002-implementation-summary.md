# JIT-002 Implementation Summary: Bus Message Idempotency

**Date**: 2026-06-07  
**Status**: ✅ Implemented & Tested  
**Author**: lak (Solution Architect)

## Overview

Implemented idempotency key system for the multi-agent message bus to prevent duplicate message processing. This ensures that even if messages are retried or duplicated in transit, each logical message is processed exactly once within a 24-hour window.

## Files Changed

| File | Changes |
|------|---------|
| `limbs/lib.sh` | Added 4 new functions for idempotency key management |
| `network/bus.sh` | Modified `send`, `recv`, and `broadcast` commands |
| `network/router.sh` | Added `check-idem` command and `check_idempotency()` function |
| `tests/test_bus_idempotency.sh` | New test suite (7 tests) |
| `specs/JIT-002-bus-idempotency-adr.md` | Architecture Decision Record |

## Key Generation Logic

### Function: `generate_idempotency_key(from, subject, body)`

```bash
generate_idempotency_key() {
  local FROM="$1" SUBJECT="$2"
  shift 2
  local BODY="$*"

  # Step 1: Hash the body
  local BODY_HASH
  BODY_HASH=$(echo -n "$BODY" | sha256sum | cut -d' ' -f1)

  # Step 2: Hash from+subject+body-hash
  echo -n "${FROM}${SUBJECT}${BODY_HASH}" | sha256sum | cut -d' ' -f1
}
```

**Output**: 64-character hexadecimal SHA-256 hash

**Properties**:
- Deterministic: Same inputs always produce same key
- Unique: Different inputs produce different keys (collision-resistant)
- Content-addressable: Key derived from message content, not random UUID

## Key Index Format

**Location**: `/tmp/manusat-bus/<agent>/.keys`

**Format**:
```
<key>:<timestamp>:<subject>
<key>:<timestamp>:<subject>
```

**Example**:
```
518859f7efa75be8ad23f2107748529829e2e5379f49290a910d733e13a122cc:1780878967:task:test
```

## Deduplication Flow

### Send Path (bus.sh send)

```
1. Generate idempotency key (or use $IDEMPOTENCY_KEY env var)
2. Write message to .msg file with idempotency-key header
3. Append key to .keys index with timestamp
4. Send confirmation to caller
```

### Receive Path (bus.sh recv)

```
1. For each .msg file in inbox:
   a. Parse idempotency-key header
   b. Call is_duplicate_key(key, agent)
   c. If duplicate (within 24h):
      - Move to .dup/ quarantine directory
      - Log BUS_DUPLICATE event
      - Skip processing
   d. If new:
      - Process normally
      - Rename to .read
```

### Router Integration

```bash
# Before routing any message:
router.sh check-idem <msg-file> <agent>

# Exit codes:
#   0 = duplicate detected (abort)
#   1 = not duplicate (proceed)
#   2 = error (no idempotency key, legacy message)
```

## Test Results

All 7 tests pass:

```
========================================
  JIT-002: Bus Idempotency Key Tests
========================================
✅ Key generation deterministic
✅ Key generation unique
✅ bus.sh send writes idempotency-key
✅ Key recorded to .keys index
✅ Duplicate detection within 24h
✅ Expired keys treated as new (>24h)
✅ Explicit IDEMPOTENCY_KEY env var

Results: 7/7 passed, 0 failed
========================================
```

## Message Format Change

### Before JIT-002

```
from:innova
to:soma
subject:task:review
timestamp:2026-06-07T10:30:00
correlation-id:abc12345
---
message body
```

### After JIT-002

```
from:innova
to:soma
subject:task:review
timestamp:2026-06-07T10:30:00
correlation-id:abc12345
idempotency-key:518859f7efa75be8ad23f2107748529829e2e5379f49290a910d733e13a122cc
---
message body
```

## API Reference

### `generate_idempotency_key(from, subject, body)` → string

Generate a deterministic idempotency key from message components.

### `is_duplicate_key(key, agent)` → exit code

Check if a key was seen within the last 24 hours.
- Returns 0 if duplicate (reject)
- Returns 1 if new (accept)

### `record_idempotency_key(key, agent, subject)` → void

Append a key to the agent's `.keys` index.

### `parse_idempotency_key(msg_file)` → string

Extract the idempotency-key header from a message file.

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `IDEMPOTENCY_KEY` | (auto-generated) | Override auto-generation with custom key |

## Design Decisions

### Why 24-hour window?

- **Short enough**: Limits memory growth, practical retry windows are usually <1h
- **Long enough**: Covers network delays, agent restarts, batch retries

### Why content-derived keys instead of UUIDs?

- **Detects true duplicates**: Same message content = same key
- **Enables safe retries**: Retry with same content gets deduped
- **UUID limitation**: Every retry looks "new" even if identical

### Why file-based index instead of Redis/SQLite?

- **No external dependencies**: Works out of the box
- **POSIX-compatible**: Portable across systems
- **Simple to debug**: Human-readable format
- **Can upgrade later**: If scale demands, can migrate to database

## Migration Notes

### For Existing Messages

- Messages without `idempotency-key` header are treated as legacy
- `is_duplicate_key()` returns 1 (not duplicate) for missing keys
- System gracefully handles mixed old/new messages

### For New Agents

- No configuration needed — works automatically
- Optional: Set `IDEMPOTENCY_KEY` for explicit control
- Keys are auto-managed per-agent inbox

## Future Enhancements

1. **Key rotation policy**: Configurable TTL per subject type
2. **Metrics**: Track duplicate rate per agent
3. **Compression**: Rotate `.keys` file to `.keys.gz` after N entries
4. **Cross-agent dedup**: Detect duplicates across multiple agents

## Related Tickets

- JIT-002: Add idempotency key to bus messages (this ticket)
- JIT-004: Dead-letter queue for undeliverable messages (companion)

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| Add idempotency-key header to message format | ✅ Done |
| bus.sh send writes key to .msg and .keys index | ✅ Done |
| bus.sh recv filters duplicates from last 24h | ✅ Done |
| router.sh aborts with BUS_DUPLICATE log entry | ✅ Done |

---

*Implementation follows Buddhist principles:*
- *อิทัปปจฺจยตา (dependent origination): Each message has causal chain via idempotency key*
- *สตฺิ (mindfulness): System remembers what it has seen*
- *ไม่เบียดเบียน (non-harm): Prevents duplicate side effects*
