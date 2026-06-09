# ADR-JIT-001: Add Message TTL to Bus Protocol

**Date**: 2026-06-07
**Status**: accepted

## Context

Messages in the file-based bus have no expiration mechanism, causing:
- Queue buildup from stale messages
- Processing of outdated commands/alerts
- No way to enforce message freshness

Without TTL, old messages could sit in queues indefinitely and be processed even when no longer relevant.

## Decision

Add Time-To-Live (TTL) support to the bus protocol:

### Message Format Update
```
from:agent_name
to:recipient
subject:task:something
timestamp:2026-06-08T00:00:00
ttl:3600
expires-at:2026-06-08T01:00:00
---
message body
```

### Default TTLs by Subject Type
| Subject Prefix | Default TTL | Rationale |
|---------------|-------------|-----------|
| `task:*` | 3600s (1h) | Work items should be processed within an hour |
| `broadcast:*` | 86400s (24h) | Announcements stay relevant for a day |
| `alert:*` | 900s (15m) | Urgent alerts lose value quickly |
| Other | 3600s (1h) | Safe default |

### API Changes
```bash
# New optional --ttl flag on send
bash network/bus.sh send [--ttl <seconds>] <to> <subject> <body>

# New sweep command
bash network/bus.sh sweep
```

### Sweep Logic
- Scans all `.msg` files in bus inboxes
- Moves expired messages to `.expired` quarantine (not deleted)
- Logs `BUS_EXPIRED` entries for audit trail

### Router/Ear Validation
- `ear.sh` validates TTL on message receive
- Expired messages are moved to quarantine, not processed
- Logged as `EAR_EXPIRED` for tracking

## Consequences

### Positive
- Prevents queue buildup from stale messages
- Ensures timely processing of time-sensitive messages
- Audit trail preserved via quarantine (Nothing is Deleted)
- Configurable per-message via `--ttl` flag

### Trade-offs
- Slightly larger message size (+2 headers)
- Requires clock synchronization across agents (assumed NTP)
- Sweep must be run periodically (cron or manual)

### Migration
- Existing messages without TTL headers will be processed normally (no expires-at = no expiration)
- No breaking changes to existing message flow
