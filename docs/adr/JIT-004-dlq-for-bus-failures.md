# ADR-JIT-004: Dead-Letter Queue for Bus Failures

**Date**: 2026-06-07  
**Status**: accepted  
**Author**: lak (Solution Architect)

## Context

Failed messages in the bus system were lost with no way to:
- Inspect what went wrong
- Replay messages after fixing issues
- Analyze failure patterns over time

This violates the "Nothing is Deleted" principle and makes debugging multi-agent communication failures difficult.

## Decision

Implement a Dead-Letter Queue (DLQ) system with the following structure:

```
$BUS_ROOT/_dlq/
├── expired/       # Messages that exceeded TTL
├── unrouted/      # Messages with no valid recipient
├── max-retries/   # Messages that exhausted retry attempts
└── error/         # Other failures
```

Each DLQ entry consists of:
- `<timestamp>_<msg_id>.msg` — Original message preserved
- `<timestamp>_<msg_id>.reason` — Sidecar with failure metadata

### .reason Sidecar Format

```
original_to:<agent_name>
original_from:<sender>
original_subject:<subject>
failure_reason:<human-readable reason>
failed_at:<ISO8601 timestamp>
retry_count:<number>
```

### DLQ Commands

| Command | Description |
|---------|-------------|
| `dlq list [reason]` | List DLQ contents, optionally filtered by category |
| `dlq replay <file>` | Re-queue a specific message to original recipient |
| `dlq purge --older-than <N>d` | Clean up messages older than N days |
| `dlq depth` | Check total DLQ size vs threshold |

### Threshold Alert

When DLQ depth exceeds threshold (default: 10), emit `alert:dlq-growing` broadcast to all agents.

## Implementation Details

### Helper Functions

1. **dlq_move_to(msg_file, reason, failure_reason)**
   - Moves message to appropriate DLQ category
   - Creates .reason sidecar with metadata
   - Logs action for audit trail

2. **dlq_check_threshold()**
   - Counts total DLQ depth across all categories
   - Updates _metadata.json with last_alert timestamp
   - Emits broadcast alert if threshold exceeded

3. **dlq_depth()**
   - Returns total count of messages in DLQ

### Integration Points

1. **sweep command**: Expired messages now move to `DLQ/expired/` instead of just renaming to `.expired`

2. **send command**: Messages to non-existent agents move directly to `DLQ/unrouted/`

3. **Future**: Retry mechanism can move `max-retries` exhausted messages to DLQ

## Consequences

### Positive

- ✅ Failed messages preserved for analysis
- ✅ Replay capability for recovery scenarios
- ✅ Failure pattern analysis possible
- ✅ Alerting on accumulating failures
- ✅ Aligns with "Nothing is Deleted" principle

### Negative

- ⚠️ Additional disk usage for failed messages
- ⚠️ Requires periodic purge to prevent unbounded growth
- ⚠️ Slightly more complex message flow

### Mitigations

- Purge command with `--older-than` flag for cleanup
- Threshold alerts to notify operators
- Configurable threshold via `DLQ_THRESHOLD` env var

## Testing

All acceptance criteria verified in `tests/test_bus_dlq.py`:

```
✓ DLQ directory structure creation
✓ dlq list command
✓ dlq replay command  
✓ dlq purge command
✓ dlq depth command
✓ Expired messages → DLQ/expired/
✓ Unrouted messages → DLQ/unrouted/
✓ .reason sidecar format
✓ alert:dlq-growing when threshold exceeded
```

## Related Decisions

- JIT-002: Idempotency keys for deduplication
- TTL implementation in bus.sh (per-subject defaults)

## Future Considerations

1. Add DLQ webhook/integration for external monitoring
2. Automatic retry from DLQ with exponential backoff
3. DLQ statistics dashboard (messages/failure-type over time)
4. Per-agent DLQ quotas
