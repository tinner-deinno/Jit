# JIT-003: Retry Policy with Exponential Backoff

**Status**: Spec  
**Version**: 1.0  
**Owner**: soma (Strategic Lead)  
**Date**: 2026-06-07

---

## Overview

Add automatic retry support with exponential backoff to the มนุษย์ Agent message bus. Messages that fail routing can be automatically retried with increasing delays, improving resilience for transient failures.

---

## Interface Design

### Message Headers

Add the following headers to support retry configuration:

```
from:innova
to:chamu
subject:task:run-tests
timestamp:2026-06-07T10:00:00Z
max-retries:3
retry-after:2
correlation-id:abc-123
---
Please run full test suite
```

### Header Semantics

- **`max-retries:<n>`**: Maximum number of retry attempts (default: 3)
  - Value must be >= 0
  - 0 means no retries (fail immediately)
  - Each failed attempt increments internal counter
  
- **`retry-after:<seconds>`**: Initial backoff delay in seconds (default: 2)
  - First retry waits `retry-after` seconds
  - Second retry waits `retry-after * 2` seconds (4s)
  - Third retry waits `retry-after * 4` seconds (8s)
  - Maximum backoff capped at 300 seconds (5 minutes)

**Retry Schedule Example** (max-retries:3, retry-after:2):
```
Attempt 1: Immediate (first delivery)
  ↓ (fail)
Attempt 2: Wait 2s, then retry
  ↓ (fail)
Attempt 3: Wait 4s, then retry
  ↓ (fail)
Attempt 4: Wait 8s, then retry
  ↓ (fail)
→ Move to DLQ (max retries exceeded)
```

---

## Implementation

### bus.sh send (Message Creation)

When `bus.sh send` is called, stamp message with retry headers:

```bash
bus.sh send <to> <subject> <body> [--max-retries 3] [--retry-after 2]
```

**Logic**:
1. If `--max-retries` provided: use it
2. Else: default to 3
3. If `--retry-after` provided: use it
4. Else: default to 2 seconds
5. Add headers to message:
   ```
   max-retries:3
   retry-after:2
   retry-attempt:0
   ```

**Example**:
```bash
$ bus.sh send chamu "task:run-tests" "Full suite" --max-retries 5 --retry-after 3
# Stamps: max-retries:5, retry-after:3, retry-attempt:0

$ bus.sh send chamu "task:run-tests" "Full suite"
# Stamps: max-retries:3, retry-after:2, retry-attempt:0 (defaults)
```

### router.sh route (Retry Loop)

Wrap organ dispatch in exponential backoff retry loop:

```bash
_retry_with_backoff() {
  local msg_file="$1"
  local to_agent="$2"
  local max_retries=$(grep "^max-retries:" "$msg_file" | cut -d: -f2- | tr -d ' ')
  local retry_after=$(grep "^retry-after:" "$msg_file" | cut -d: -f2- | tr -d ' ')
  local retry_attempt=$(grep "^retry-attempt:" "$msg_file" | cut -d: -f2- | tr -d ' ')
  
  max_retries=${max_retries:-3}
  retry_after=${retry_after:-2}
  retry_attempt=${retry_attempt:-0}
  
  # Dispatch organ call
  if _dispatch_to_organ "$msg_file" "$to_agent"; then
    log_action "BUS_DISPATCH_OK" "subject:$(grep '^subject:' "$msg_file")"
    return 0
  fi
  
  # Failed, check if we can retry
  if [ "$retry_attempt" -ge "$max_retries" ]; then
    log_action "BUS_MAX_RETRIES_EXCEEDED" "subject:$(grep '^subject:' "$msg_file") attempts:$((retry_attempt+1))"
    return 1  # Don't retry
  fi
  
  # Calculate backoff: 2s, 4s, 8s, 16s, ... capped at 300s
  local backoff=$((retry_after * (2 ** retry_attempt)))
  if [ "$backoff" -gt 300 ]; then
    backoff=300
  fi
  
  # Increment attempt counter, re-queue for retry
  local next_attempt=$((retry_attempt + 1))
  
  # Update message with new attempt count and schedule
  sed -i "s/^retry-attempt:.*/retry-attempt:$next_attempt/" "$msg_file"
  
  # Move to .failed queue with scheduled retry time
  local retry_at=$(date -d "+${backoff}s" '+%Y-%m-%dT%H:%M:%SZ')
  local failed_dir="$BUS_ROOT/_failed"
  mkdir -p "$failed_dir"
  
  # Rename with retry-scheduled timestamp
  local failed_file="$failed_dir/$(basename ${msg_file%.msg}).retry-at-${retry_at}.msg"
  mv "$msg_file" "$failed_file"
  
  log_action "BUS_RETRY" "subject:$(grep '^subject:' "$msg_file") attempt:$next_attempt backoff:${backoff}s retry-at:$retry_at"
  
  return 2  # Queued for retry
}
```

### bus.sh retry (New Subcommand)

New subcommand to re-queue failed messages whose retry window has passed:

```bash
bus.sh retry [--dry-run] [--older-than 1h]
```

**Behavior**:
1. Scan `$BUS_ROOT/_failed/` for `.retry-at-*.msg` files
2. Parse the `retry-at-<ISO-8601>` timestamp from filename
3. If `retry-at <= now`, move message back to agent inbox
4. Increment internal retry counter
5. Update `retry-attempt` header
6. Log: `BUS_RETRY_REQUEUE` subject:... attempt:...

**Options**:
- `--dry-run`: Show what would be retried, don't actually move
- `--older-than 1h`: Only requeue messages scheduled for retry > 1h ago

**Example**:
```bash
$ bus.sh retry
# Scans /tmp/manusat-bus/_failed/
# Re-queues messages whose retry window has passed
# Output:
#   Re-queued 5 messages from _failed/
#   Oldest retry-at: 2026-06-07T10:15:00Z

$ bus.sh retry --dry-run
# Showing 5 messages would be re-queued (not actually moved)

$ bus.sh retry --older-than 1h
# Only re-queue messages scheduled > 1h ago
```

### Scheduling Retry Scans

Recommend cron job or heartbeat to run `bus.sh retry` periodically:

```bash
# In heart.sh or pran agent
# Run every 30 seconds
*/1 * * * * bash /workspaces/Jit/network/bus.sh retry >> /tmp/bus-retry.log 2>&1
```

Or integrate into `pran` (heart) agent's heartbeat loop to check every 30s.

---

## Data Model

### Retry Queue Directory

```
$BUS_ROOT/
├── innova/
│   ├── 1717761600123_from-soma.msg
│   └── ...
├── _failed/
│   ├── 1717761600123_from-soma.retry-at-2026-06-07T10:10:00Z.msg
│   ├── 1717761610000_from-chamu.retry-at-2026-06-07T10:15:00Z.msg
│   └── 1717761620000_from-jit.retry-at-2026-06-07T10:20:00Z.msg
└── ...
```

### Message Header Extensions

```
max-retries:3          # Max attempts (including first)
retry-after:2         # Initial backoff in seconds
retry-attempt:0       # Current attempt (increments on failure)
```

### Retry Queue Filename Format

```
<timestamp>_from-<sender>.retry-at-<ISO-8601>.msg
```

Example:
```
1717761600123_from-soma.retry-at-2026-06-07T10:10:00Z.msg
```

---

## Error Cases

| Case | Behavior | Log Entry |
|------|----------|-----------|
| max-retries not set | Use default 3 | `BUS_SEND` (default applied) |
| retry-after not set | Use default 2 | `BUS_SEND` (default applied) |
| max-retries: 0 | Don't retry (fail immediately) | `BUS_DISPATCH_FAIL` (no retry) |
| Organ times out | Treat as transient failure, retry | `BUS_RETRY` attempt:N |
| max retries exceeded | Move to DLQ | `BUS_MAX_RETRIES_EXCEEDED` |
| Backoff calculation overflows | Cap at 300s | `BUS_RETRY` backoff:300s (capped) |
| .retry-at timestamp malformed | Skip message, log warning | `BUS_WARN` malformed retry-at |
| _failed/ directory full | Create, expand as needed | (auto-create) |

---

## Backward Compatibility

✅ **Fully backward compatible**:
- Messages without `max-retries` and `retry-after` use sensible defaults
- Old bus.sh versions that don't provide retry headers get defaults
- Messages without headers still work; they just fail immediately on error
- DLQ system integrates with retry (see JIT-004)

---

## Testing Strategy

1. **Unit tests**:
   - Backoff calculation (2, 4, 8, ... capped at 300)
   - Exponential backoff is correct for each attempt
   - Retry window (retry-at comparison with now)
   - Handle malformed max-retries or retry-after values

2. **Integration tests**:
   - Send message, simulate organ failure, verify retry
   - Each retry has correct backoff delay
   - Verify retry-attempt counter increments
   - Verify `BUS_RETRY` log entries
   - Re-queue messages after retry window passes
   - Messages with max-retries:0 don't retry
   - After max retries exceeded, move to DLQ

3. **Edge cases**:
   - Backoff overflow (very large retry_attempt)
   - System clock jumps backward during retry wait
   - Concurrent retry + message receipt
   - Very large backoff values (capped at 300s)

---

## Success Criteria

- [ ] Message format extended with `max-retries` and `retry-after` headers
- [ ] `bus.sh send` auto-stamps retry headers with sensible defaults
- [ ] `router.sh route` wraps dispatch in exponential backoff retry loop
- [ ] Failed messages moved to `_failed/` with `retry-at-<ISO>` timestamp
- [ ] `retry-attempt` counter increments on each failure
- [ ] Backoff is exponential (2s, 4s, 8s, ...) and capped at 300s
- [ ] `bus.sh retry` re-queues messages whose retry window has passed
- [ ] `BUS_RETRY` log entries include attempt number and backoff
- [ ] Backward compatibility verified (defaults work)
- [ ] Integration tests pass (see test_bus_error_recovery.py)
- [ ] Protocol.md Version History updated

---

## Scheduling & Integration

**Cron-based retry scanning**:
```bash
# In pran's heartbeat or separate cron
* * * * * bash /workspaces/Jit/network/bus.sh retry 2>/dev/null
```

Or **heartbeat-based** (every 30s):
```bash
# In pran (heart) agent loop
while true; do
  bus.sh retry
  sleep 30
done
```

---

## References

- **Exponential Backoff**: AWS SDK retry strategy (2^attempt * base, capped)
- **DLQ Integration**: See JIT-004 (messages move to DLQ after max retries)
- **Idempotency**: See JIT-002 (retries should be idempotent)

