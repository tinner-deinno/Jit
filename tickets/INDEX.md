# Ticket Index — Jit (จิต)

> จัดการโดย: หัวหน้า SA (Solution Architect Lead) — fan-out loops
> Source of Truth: `/tickets/open/*.yaml`
> Created: 2026-06-06 (heartbeat iteration #1)

## States

| State | Meaning | Files |
|-------|---------|-------|
| `open` | New, awaiting owner | `tickets/open/` |
| `in_progress` | Being worked on | `tickets/open/` |
| `blocked` | Stuck on dep | `tickets/blocked/` |
| `done` | Complete, awaiting close | `tickets/done/` |
| `closed` | Archived | `tickets/archive/` |

## Schema (YAML)

```yaml
id: JIT-001
title: Short actionable title
priority: P0|P1|P2|P3
type: feat|fix|chore|spec|test|doc|audit
status: open
owner: agent-name
created: 2026-06-06
updated: 2026-06-06
spec_ref: path/to/spec.md
acceptance:
  - Specific testable criterion
  - Another criterion
effort_hours: 2
tags: [tag1, tag2]
```

## Open Tickets

### P0 Critical (4 tickets — block release)

| ID | Title | Type | Owner |
|----|-------|------|-------|
| JIT-001 | Add message TTL (time-to-live) to bus protocol | spec+code | lak |
| JIT-002 | Add idempotency key to bus messages | spec+code | lak |
| JIT-006 | Remove hardcoded OLLAMA_TOKEN from jit-heartbeat.service | fix+security | pada |
| JIT-012 | Add Oracle health monitoring with auto-restart | feat | pran |

### P1 High (8 tickets)

| ID | Title | Type | Owner |
|----|-------|------|-------|
| JIT-003 | Add retry policy with exponential backoff to bus | spec+code | soma |
| JIT-004 | Add dead-letter queue (DLQ) for bus failures | spec+code | lak |
| JIT-007 | Add log rotation for daemon logs | fix | pada |
| JIT-008 | Add deploy rollback and pinned artifact version to bootstrap.sh | fix | pada |
| JIT-010 | Add health checks / liveness probes for Hermes and Heartbeat | fix | pada |
| JIT-013 | Add GitHub Actions CI/CD pipeline for Jit system | chore | pada |
| JIT-014 | Add pytest configuration and test runner setup | test | chamu |
| JIT-015 | Add multi-model fallback chain to limbs/ollama.sh | feat | innova |

### P2 Medium (3 tickets)

| ID | Title | Type | Owner |
|----|-------|------|-------|
| JIT-005 | Add protocol-version field to bus messages | spec+code | soma |
| JIT-009 | Add circuit breaker and global Node error handlers | fix+reliability | pada |
| JIT-017 | Add capability versioning to agent registry | feat | lak |
| JIT-018 | Add bus metrics collection and dashboard command | feat | netra |

## Workflow

```
new ticket → /tickets/open/JIT-NNN.yaml
in_progress → in-place status change
done → mv to /tickets/done/
closed → mv to /tickets/archive/ (monthly)
```

Last updated: 2026-06-08 (JIT-011, JIT-016, JIT-022, JIT-025 completed)

## Completed Tickets

| ID | Title | Completed | Owner |
|----|-------|-----------|-------|
| JIT-011 | Add HMAC message signing to bus protocol | 2026-06-08 | lak |
| JIT-016 | Add shared memory decay and cleanup policy | 2026-06-07 | innova |
| JIT-022-token-exposure | Mask tokens from logs (redact, log_token) | 2026-06-08 | innova |
| JIT-022-doc-protocol | Expand protocol.md with 14 agents + error recovery | 2026-06-08 | vaja |
| JIT-022-act-sed | Add safe string handling docs to act.sh | 2026-06-08 | innova |
| JIT-025 | Add conditional branching to act.sh + fix vitals ls parsing | 2026-06-08 | mue |

