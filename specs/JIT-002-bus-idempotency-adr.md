# ADR-002: Bus Message Idempotency Key System

**Date**: 2026-06-07  
**Status**: proposed  
**Author**: lak (Solution Architect)

## Context

Duplicate messages can be processed multiple times, causing unintended side effects in the multi-agent system. When agents restart or retry failed deliveries, the same logical message may arrive multiple times. Without idempotency tracking, agents cannot distinguish between:
1. A legitimate retry of a failed message
2. A duplicate caused by network issues or retries

This violates the "Nothing is Deleted" principle — we need to track what we've seen without losing history.

## Decision

Implement an idempotency key system for all bus messages with the following design:

### Message Format Change

Add `idempotency-key:<uuid>` header to every message:

```
from:innova
to:soma
subject:task:review-architecture
timestamp:2026-06-07T10:30:00
correlation-id:abc12345
idempotency-key:sha256hash...
---
message body here
```

### Key Generation Strategy

1. **Explicit key**: If sender provides `IDEMPOTENCY_KEY` env var, use it directly
2. **Derived key**: Otherwise, derive from `from + subject + body-hash`:
   ```bash
   echo -n "${from}${subject}$(echo -n "$body" | sha256sum | cut -d' ' -f1)" | \
     sha256sum | cut -d' ' -f1
   ```

### Storage Design

Two-file approach per inbox:

1. **`.msg` file** — Contains full message including idempotency-key header
2. **`.keys` index** — Sidecar file at `/tmp/manusat-bus/<agent>/.keys`

Format of `.keys`:
```
<key>:<timestamp>:<subject>
<key>:<timestamp>:<subject>
```

### Deduplication Window

- Keys are valid for **24 hours** from first occurrence
- After 24h, keys are considered expired (allows natural cleanup)
- This balances memory usage with practical retry windows

### Processing Flow

```
sender → bus.sh send → generate key → write .msg → append to .keys
                                    ↓
receiver → bus.sh recv → check .keys → if duplicate: abort + log BUS_DUPLICATE
                                     → if new: process normally
```

### Router Integration

When `router.sh` receives a message:
1. Extract idempotency-key from message headers
2. Check if key exists in `.keys` within last 24h
3. If duplicate: log `BUS_DUPLICATE` and skip processing
4. If new: proceed with routing

## Consequences

### Positive
- ✅ Prevents duplicate processing of identical messages
- ✅ Allows safe retries without side effects
- ✅ Maintains audit trail (Nothing is Deleted)
- ✅ Simple file-based design (no external dependencies)
- ✅ 24h window balances memory vs. practical needs

### Negative
- ⚠️ Adds ~2ms overhead per message for hash computation
- ⚠️ `.keys` file grows unbounded within 24h window
- ⚠️ Derived keys may collide if body is identical but intent differs (rare)

### Trade-offs Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| UUID per message | Always unique | Can't detect intentional retries | ❌ |
| Content-derived hash | Detects duplicates naturally | Slight CPU cost | ✅ |
| Infinite key retention | Perfect dedup | Unbounded growth | ❌ |
| 24h TTL | Bounded memory | May miss long-delayed dupes | ✅ |
| External Redis store | Fast lookups | New dependency | ❌ |
| File-based index | No deps, simple | Slower at scale | ✅ (for now) |

## Implementation Plan

1. Add `generate_idempotency_key()` to `limbs/lib.sh`
2. Add `is_duplicate_key()` to `limbs/lib.sh`
3. Modify `bus.sh send` to generate and write keys
4. Modify `bus.sh recv` to check for duplicates before processing
5. Add `BUS_DUPLICATE` log entries for rejected messages
6. Write tests in `tests/test_bus_idempotency.py`

## Files to Change

| File | Change |
|------|--------|
| `limbs/lib.sh` | Add key generation + verification functions |
| `network/bus.sh` | Integrate idempotency into send/recv |
| `network/router.sh` | Check idempotency before routing |
| `tests/test_bus_idempotency.py` | New test suite |
