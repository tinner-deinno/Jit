---
name: dlq-monitoring-integration
description: DLQ handler script created and integrated into pran's (heart) responsibilities for monitoring and alerting on dead letter queue issues
metadata:
  type: project
---

## DLQ Monitoring Implementation

**Status**: COMPLETE  
**Created**: 2026-06-08  
**Handler**: `/workspaces/Jit/organs/dlq-handler.sh`  
**Primary Owner**: pran (ปราณ — heart coordinator)  
**Supporting Agent**: sayanprasathan (nerve — event network)  

## Current DLQ State

- **Total DLQ count**: 219 messages (CRITICAL — exceeds 100 threshold)
- **Breakdown**:
  - Expired: 213 (TTL exceeded, mostly intended for innova)
  - Unrouted: 6 (unknown recipients: leg, testagent, test-agent, nonexistent_agent)
  - Error: 0
  - Max-retries: 0

## Handler Script Features

### Commands
1. **status** — DLQ summary + threshold assessment
2. **audit** — Deep inspection of failure patterns, recipients, senders
3. **remediate** — Alert pran/innova based on threshold
4. **monitor [interval]** — Background loop checking DLQ periodically
5. **clean [days]** — Archive old DLQ entries

### Thresholds
- **DLQ_THRESHOLD**: 50 (warning level)
- **DLQ_CRITICAL**: 100 (critical escalation level)
- Current: 219 messages = CRITICAL state

## Integration into pran (Heart)

Added two new commands to `/workspaces/Jit/organs/pran.sh`:
- `bash organs/pran.sh dlq-status` — View DLQ status
- `bash organs/pran.sh dlq-check` — Run DLQ remediation/alert dispatch

pran now manages:
1. Ollama load balancing (existing)
2. Shared memory monitoring (JIT-016)
3. DLQ monitoring and alerting (new)

## Key Failure Pattern

**Primary Issue**: 213 expired messages intended for innova  
- Reason: TTL exceeded before delivery
- Action: innova should review message bus delay or increase TTL
- Secondary: 6 unrouted to non-existent agents (leg, testagent variants)

## Next Steps (for innova)

1. Investigate why 213 messages to innova expired
2. Check bus routing latency or message validity
3. Consider archiving/cleaning DLQ periodically with `dlq-handler.sh clean 7`
4. Set up background monitor: `bash organs/dlq-handler.sh monitor 60`
