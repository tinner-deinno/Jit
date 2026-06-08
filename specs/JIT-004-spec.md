# JIT-004: Dead-Letter Queue (DLQ) for Bus Failures

**Status**: Spec  
**Version**: 1.0  
**Owner**: lak (Solution Architect)  
**Date**: 2026-06-07

---

## Overview

Add a dead-letter queue (DLQ) system to the มนุษย์ Agent message bus for messages that fail permanently. Failed messages are moved to categorized DLQ directories with metadata about the failure reason, enabling post-mortem analysis and manual replay capability.

---

## Interface Design

### Message Failure Categories

Messages are moved to DLQ based on failure reason:

```
$BUS_ROOT/_dlq/
├── expired/          # Message expired (TTL exceeded)
├── unrouted/         # Agent doesn't exist or inbox unreachable
├── max-retries/      # Max retry attempts exceeded
├── duplicate/        # Idempotency key already processed
├── invalid/          # Message format invalid
└── timeout/          # Agent didn't respond in time
```

### DLQ Message Structure

```
_dlq/<reason>/
├── 1717761600123_from-soma_to-innova.msg
└── 1717761600123_from-soma_to-innova.reason
```

Each failed message has a `.reason` sidecar file with failure metadata:

```
reason:max-retries
original-to:innova
original-subject:task:run-tests
original-from:soma
failed-at:2026-06-07T10:15:00Z
original-attempt:3
failure-message:All retry attempts exhausted
retry-backoff-was:8s
last-error:Agent timeout
```

---

## Implementation

### bus.sh dlq (New Subcommand)

New subcommand for DLQ management:

```bash
bus.sh dlq list [--reason <reason>] [--older-than 7d]
bus.sh dlq replay <file> [--idempotency-key <key>]
bus.sh dlq purge --older-than 7d [--dry-run]
bus.sh dlq stats
```

**dlq list**: Show DLQ contents by category

```bash
$ bus.sh dlq list
=== Dead-Letter Queue ===
  max-retries/: 5 messages
    - 1717761600123_from-soma_to-innova.msg
    - 1717761610000_from-chamu_to-jit.msg
  expired/: 2 messages
    - 1717761700000_from-jit_to-soma.msg
  unrouted/: 1 message
    - 1717761800000_from-jit_to-unknown.msg
  
  Total: 8 messages in DLQ

$ bus.sh dlq list --reason max-retries
=== max-retries Category ===
  5 messages
  - 1717761600123_from-soma_to-innova.msg (failed at 2026-06-07T10:15:00Z)
  - 1717761610000_from-chamu_to-jit.msg (failed at 2026-06-07T10:16:00Z)

$ bus.sh dlq list --older-than 7d
=== DLQ (older than 7 days) ===
  2 messages (all categories)
  - 1717300000000_from-jit_to-soma.msg (failed 7+ days ago)
```

**dlq replay**: Re-inject a message from DLQ back to agent inbox

```bash
$ bus.sh dlq replay _dlq/max-retries/1717761600123_from-soma_to-innova.msg
# Moves message back to /tmp/manusat-bus/innova/
# Resets retry-attempt to 0
# Logs: BUS_DLQ_REPLAY
# Returns: 0 on success, non-zero on error

$ bus.sh dlq replay _dlq/max-retries/1717761600123_from-soma_to-innova.msg \
  --idempotency-key new-key-123
# Re-inject with new idempotency key (to bypass dedup if original was duplicate)
```

**dlq purge**: Delete old DLQ messages

```bash
$ bus.sh dlq purge --older-than 7d --dry-run
# Would delete:
#   - 2 messages from max-retries/ (> 7d old)
#   - 1 message from expired/

$ bus.sh dlq purge --older-than 7d
# Actually deleted:
#   - 2 messages from max-retries/
#   - 1 message from expired/
# Logs: BUS_DLQ_PURGE deleted:3 reason-counts:max-retries:2,expired:1
```

**dlq stats**: Show DLQ statistics

```bash
$ bus.sh dlq stats
=== DLQ Statistics ===
  Total messages: 8
  By reason:
    max-retries: 5
    expired: 2
    unrouted: 1
  Oldest message: 2026-06-06T08:00:00Z (1 day old)
  Largest category: max-retries (5 msgs)
```

### router.sh Move to DLQ

When a message fails permanently, move it to appropriate DLQ category:

```bash
_move_to_dlq() {
  local msg_file="$1"
  local reason="$2"          # expired, unrouted, max-retries, duplicate, invalid, timeout
  local error_message="$3"   # Human-readable error
  
  local dlq_dir="$BUS_ROOT/_dlq/$reason"
  mkdir -p "$dlq_dir"
  
  # Extract metadata
  local to_agent=$(grep "^to:" "$msg_file" | cut -d: -f2-)
  local from_agent=$(grep "^from:" "$msg_file" | cut -d: -f2-)
  local subject=$(grep "^subject:" "$msg_file" | cut -d: -f2-)
  local retry_attempt=$(grep "^retry-attempt:" "$msg_file" | cut -d: -f2- | tr -d ' ')
  
  # Move message
  local basename=$(basename "$msg_file" .msg)
  local dlq_msg="$dlq_dir/${basename}_to-${to_agent}.msg"
  mv "$msg_file" "$dlq_msg"
  
  # Write .reason sidecar
  cat > "${dlq_msg%.msg}.reason" << EOF
reason:$reason
original-to:$to_agent
original-from:$from_agent
original-subject:$subject
failed-at:$(date -u '+%Y-%m-%dT%H:%M:%SZ')
failure-message:$error_message
retry-attempt:${retry_attempt:-0}
EOF

  log_action "BUS_DLQ_MOVE" "reason:$reason subject:$subject from:$from_agent to:$to_agent"
}
```

### Integration Points

**router.sh dispatch failures**:
```bash
if ! _dispatch_to_organ "$msg_file" "$to_agent"; then
  if [ "$retry_attempt" -ge "$max_retries" ]; then
    # Max retries exceeded
    _move_to_dlq "$msg_file" "max-retries" "All retry attempts ($max_retries) exhausted"
    return 1
  else
    # Schedule retry
    _retry_with_backoff "$msg_file" "$to_agent"
  fi
fi
```

**bus.sh recv idempotency failures**:
```bash
if ! _check_idempotency "$msg_file" "$to_agent"; then
  _move_to_dlq "$msg_file" "duplicate" "Idempotency key already processed within 24h"
  return 1
fi
```

**bus.sh sweep expired messages**:
```bash
if _check_expiration "$msg_file"; then
  _move_to_dlq "$msg_file" "expired" "Message expired at $(grep '^expires-at:' "$msg_file")"
  return 1
fi
```

### Alert System

When DLQ depth exceeds threshold, emit an alert:

```bash
_check_dlq_depth() {
  local dlq_root="$BUS_ROOT/_dlq"
  local total=$(find "$dlq_root" -name "*.msg" 2>/dev/null | wc -l)
  local threshold=${DLQ_ALERT_THRESHOLD:-20}  # Configurable
  
  if [ "$total" -gt "$threshold" ]; then
    # Emit alert
    bash /workspaces/Jit/organs/mouth.sh broadcast "alert:dlq-growing" \
      "DLQ has $total messages (threshold: $threshold)"
    
    log_action "ALERT_DLQ_GROWING" "count:$total threshold:$threshold"
  fi
}
```

This can be called from `bus.sh queue` or periodically (e.g., in heartbeat).

---

## Data Model

### Directory Structure

```
$BUS_ROOT/
├── innova/
├── soma/
├── _dlq/
│   ├── expired/
│   │   ├── 1717761600123_from-jit_to-soma.msg
│   │   └── 1717761600123_from-jit_to-soma.reason
│   ├── max-retries/
│   │   ├── 1717761600123_from-soma_to-innova.msg
│   │   ├── 1717761600123_from-soma_to-innova.reason
│   │   └── 1717761610000_from-chamu_to-jit.msg
│   ├── unrouted/
│   │   └── 1717761800000_from-jit_to-unknown.msg
│   ├── duplicate/
│   ├── invalid/
│   └── timeout/
└── _dlq_purge.log
```

### .reason Sidecar Format

```
reason:max-retries|expired|unrouted|duplicate|invalid|timeout
original-to:<agent-name>
original-from:<agent-name>
original-subject:<subject>
failed-at:<ISO-8601>
failure-message:<human-readable error>
retry-attempt:<n>     # if applicable
original-attempt:<n>  # if applicable
last-error:<error>    # detailed error info
```

---

## Error Cases

| Case | DLQ Category | Behavior |
|------|--------------|----------|
| Message expired | `expired/` | Move to DLQ when sweep runs |
| Agent inbox doesn't exist | `unrouted/` | Move immediately on dispatch failure |
| Max retries exceeded | `max-retries/` | Move after retry loop exhausted |
| Duplicate idempotency key | `duplicate/` | Move on recv (optional, or drop silently) |
| Malformed message | `invalid/` | Move on parse failure |
| Organ times out | `timeout/` | Move after timeout threshold reached |

---

## Backward Compatibility

✅ **Fully backward compatible**:
- Messages without `max-retries` header default to no-retry (fail fast)
- Old bus.sh versions don't know about DLQ; messages just fail
- DLQ is an opt-in feature; its absence doesn't break anything

---

## Testing Strategy

1. **Unit tests**:
   - Parse `.reason` sidecar files
   - DLQ directory creation per reason
   - Message filename parsing (from, to, timestamp)
   - Threshold alert calculation

2. **Integration tests**:
   - Send message, let it fail, verify moved to correct DLQ category
   - Verify `.reason` sidecar contains correct metadata
   - dlq list shows all categories
   - dlq replay re-injects message to inbox
   - dlq purge deletes old messages
   - Alert `alert:dlq-growing` is emitted when threshold exceeded
   - Concurrent DLQ moves don't corrupt filesystem

3. **Edge cases**:
   - DLQ directory doesn't exist (auto-create)
   - .reason file write fails
   - dlq replay on non-existent file
   - purge with malformed timestamps

---

## Success Criteria

- [ ] DLQ directory structure created with reason categories
- [ ] `bus.sh dlq` subcommand with list, replay, purge, stats
- [ ] Failed messages moved to appropriate DLQ folder with sidecar
- [ ] `.reason` sidecar contains failure metadata
- [ ] `BUS_DLQ_MOVE` log entries emitted
- [ ] dlq replay re-injects messages back to inbox
- [ ] dlq purge deletes old messages
- [ ] `alert:dlq-growing` broadcast when threshold exceeded
- [ ] Integration points in router.sh + bus.sh sweep
- [ ] All old messages continue to work (no DLQ = no breaking change)
- [ ] Integration tests pass (see test_bus_idempotency_dlq.py)
- [ ] Protocol.md Version History updated

---

## Monitoring & Alerts

**Recommended alerts**:
- DLQ depth > 20 messages → `alert:dlq-growing`
- DLQ growth rate (e.g., > 5 messages/hour) → `alert:dlq-fast-growing`
- Specific reason explosion (e.g., > 10 expired in 1h) → `alert:dlq-expired-spike`

These can be configured in a monitoring dashboard or via `bus.sh stats`.

