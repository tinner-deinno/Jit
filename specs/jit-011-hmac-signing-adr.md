# ADR-JIT-011: HMAC-SHA256 Message Signing for Bus Protocol

**Date**: 2026-06-07  
**Status**: accepted  
**Author**: lak (Solution Architect)  
**Implemented**: 2026-06-07  
**Tests**: 6/6 passing

## Context

The file-based message bus (`/tmp/manusat-bus/`) currently has no authentication or integrity verification. Any process with filesystem access can:
- Forge messages from any agent
- Tamper with message content in transit
- Replay old messages

This violates security principle of **message authenticity** and **integrity**.

## Decision

Add HMAC-SHA256 signature to every message using shared secret (`MANUSAT_BUS_SECRET`).

### Signature Scheme

| Component | Value |
|-----------|-------|
| Algorithm | HMAC-SHA256 |
| Key | `MANUSAT_BUS_SECRET` (env var, 32+ bytes recommended) |
| Coverage | `from + to + subject + timestamp + body` |
| Encoding | Hex (64 chars) |
| Header | `x-signature: hmac-sha256=<hex>` |

### Message Format (Updated)

```
from:agent_name
to:recipient
subject:task:something
timestamp:2026-06-07T12:34:56Z
x-signature:hmac-sha256=abc123def456...
---
message body here
```

### Configuration

| Env Var | Default | Purpose |
|---------|---------|---------|
| `MANUSAT_BUS_SECRET` | (required) | Shared HMAC key |
| `MANUSAT_STRICT_AUTH` | `1` | `0` = accept unsigned legacy messages |

### Implementation Points

1. **mouth.sh** — Generate signature on `tell()` and `broadcast()`
2. **ear.sh** — Verify signature on `recv()` before inbox delivery
3. **lib/bus.sh** — Shared `compute_signature()` and `verify_signature()` functions

## Consequences

### Positive
- ✅ Message authenticity guaranteed (only holders of secret can sign)
- ✅ Integrity protection (tampered messages fail verification)
- ✅ Replay detection possible (add nonce in future)
- ✅ Backward compatible via `MANUSAT_STRICT_AUTH=0`

### Negative
- ⚠️ Requires secret distribution to all agents
- ⚠️ Slight performance overhead (~5ms per message for HMAC)
- ⚠️ Breaking change if `MANUSAT_STRICT_AUTH=1` and sender lacks secret

### Reversibility
- Set `MANUSAT_STRICT_AUTH=0` to temporarily disable verification
- Remove signature generation by commenting single line in mouth.sh

## Related Tickets
- JIT-011: Add HMAC message signing
- JIT-023: Bus lacks auth integrity (parent issue)

## Test Plan
1. Valid signed message → accepted
2. Tampered body → rejected
3. Invalid signature → rejected
4. Missing signature + STRICT_AUTH=0 → accepted with warning
5. Missing signature + STRICT_AUTH=1 → rejected
