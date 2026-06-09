# JIT-011 Implementation Guide: HMAC Message Signing

## Overview

JIT-011 adds HMAC-SHA256 message authentication to the file-based message bus, ensuring:
- **Authenticity**: Only agents with the secret can send messages
- **Integrity**: Tampered messages are detected and rejected
- **Backward Compatibility**: Legacy mode accepts unsigned messages

## Configuration

### Environment Variables

Add to your `.env` file (copy from `.env.example`):

```bash
# Generate a strong secret (min 32 bytes recommended)
MANUSAT_BUS_SECRET=$(openssl rand -hex 32)

# Strict mode: 1 = require signatures, 0 = accept unsigned (legacy)
MANUSAT_STRICT_AUTH=1
```

### Distribution

All agents must share the same `MANUSAT_BUS_SECRET`. Distribute via:
- Shared `.env` file (loaded by agent scripts)
- Secret management system (Vault, AWS Secrets Manager, etc.)
- Environment variable injection (Docker, Kubernetes)

## Message Format

### Before (Unsigned)
```
from:innova
to:soma
subject:task:deploy
timestamp:2026-06-07T12:34:56
---
Deploy to production
```

### After (Signed)
```
from:innova
to:soma
subject:task:deploy
timestamp:2026-06-07T12:34:56
x-signature:hmac-sha256=99c0fc0d096545e7b5e8d9f...
---
Deploy to production
```

## Signature Computation

### Canonical String

The signature is computed over a canonical string:

```
canonical = from + to + subject + timestamp + body
```

Example:
```bash
from=innova
to=soma
subject=task:deploy
timestamp=2026-06-07T12:34:56
body="Deploy to production"

canonical = "innovasomatask:deploy2026-06-07T12:34:56Deploy to production"
```

### HMAC Generation

```bash
signature=$(echo -n "$canonical" | openssl dgst -sha256 -hmac "$MANUSAT_BUS_SECRET" | awk '{print $NF}')
```

### Verification

1. Parse headers from message file
2. Extract `from`, `to`, `subject`, `timestamp`, `x-signature`
3. Read body (after `---`)
4. Re-compute signature over same data
5. Compare with provided signature

## Implementation Details

### Files Modified

| File | Changes |
|------|---------|
| `limbs/lib.sh` | Added `bus_compute_signature()`, `bus_verify_signature()`, `bus_parse_signature()` |
| `organs/mouth.sh` | `_send_msg()` now generates and adds `x-signature` header |
| `organs/ear.sh` | Added `_verify_message()` called in `listen()` and `receive()` |

### Function Signatures

```bash
# Compute signature
bus_compute_signature "$from" "$to" "$subject" "$timestamp" "$body"
# Returns: hex string (64 chars) or empty if no secret

# Verify signature
bus_verify_signature "$from" "$to" "$subject" "$timestamp" "$body" "$signature"
# Returns: 0 if valid, 1 if invalid

# Parse signature from headers
bus_parse_signature "$headers"
# Returns: signature value or empty
```

### Error Handling

| Scenario | Behavior (STRICT_AUTH=1) | Behavior (STRICT_AUTH=0) |
|----------|--------------------------|--------------------------|
| Valid signature | ✅ Accept | ✅ Accept |
| Invalid signature | ❌ Reject + log | ❌ Reject + log |
| Missing signature | ❌ Reject + log | ⚠️ Accept + warning |
| No secret configured | ❌ Reject + error | ⚠️ Accept + warning |

### Rejected Messages

Messages that fail verification are moved to:
```
/tmp/manusat-bus/<agent>/rejected/
```

And logged with `EAR_REJECTED` action.

## Testing

Run the test suite:

```bash
python3 tests/test_bus_hmac.py
```

Expected output:
```
Total: 6/6 tests passed
```

### Manual Testing

```bash
# Set up secret
export MANUSAT_BUS_SECRET="my-secret-key"
export MANUSAT_STRICT_AUTH=1

# Send signed message
bash organs/mouth.sh tell soma "task:test" "Hello with signature"

# Receive and verify
AGENT_NAME=soma bash organs/ear.sh receive
```

## Migration Guide

### For New Systems

1. Set `MANUSAT_BUS_SECRET` before first run
2. Set `MANUSAT_STRICT_AUTH=1`
3. All messages will be signed automatically

### For Existing Systems

1. **Phase 1**: Deploy with `MANUSAT_STRICT_AUTH=0`
   - Existing agents continue working
   - New agents can sign messages

2. **Phase 2**: Update all agents to support signing
   - Test signing on each agent

3. **Phase 3**: Enable strict mode
   - Set `MANUSAT_STRICT_AUTH=1` on all agents
   - Unsigned messages will be rejected

### Rollback

To disable signing temporarily:
```bash
export MANUSAT_STRICT_AUTH=0
```

To fully disable (remove code changes):
- Revert `mouth.sh` to unsigned version
- Revert `ear.sh` to skip verification

## Security Considerations

### Secret Strength

Use at least 32 bytes (256 bits):
```bash
openssl rand -hex 32  # 64-char hex string
```

### Secret Rotation

To rotate the secret:
1. Generate new secret
2. Deploy to all agents simultaneously
3. Old messages with old signatures will fail verification

### Timing Attacks

Current implementation uses string comparison. For high-security environments, consider constant-time comparison:
```bash
# Using openssl cmp for constant-time comparison
echo -n "$sig1$sig2" | openssl dgst -sha256 | cut -d' ' -f2
```

## Related Tickets

- JIT-011: Add HMAC message signing
- JIT-023: Bus lacks auth integrity (parent issue)

## References

- ADR: `/workspaces/Jit/specs/jit-011-hmac-signing-adr.md`
- Tests: `/workspaces/Jit/tests/test_bus_hmac.py`
- Config: `/workspaces/Jit/.env.example`
