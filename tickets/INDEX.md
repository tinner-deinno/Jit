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

## Auto-Generated Tickets (PM+SA loop iter #1)

| ID | Title | Priority | Type | Status | Owner |
|----|----|----------|------|--------|-------|
| JIT-011 | Message bus authentication/signing gap | P0 | fix | open | pada |
| JIT-012 | Oracle health monitor integration | P0 | feat | open | pran |
| JIT-013 | Agent heartbeat timeout tuning | P1 | spec | open | sayanprasathan |
| JIT-014 | Memory persistence layer audit | P1 | audit | open | innova |
| JIT-015 | Organ protocol enforcement test suite | P1 | test | open | chamu |
| JIT-016 | Documentation: agent onboarding guide | P2 | doc | open | vaja |
| JIT-017 | Bus latency profiling + optimization | P2 | perf | open | pada |
| JIT-018 | Arra Oracle sync consistency check | P2 | spec | open | soma |

Background audit: wf_94fec3ef-34d (deeper system analysis still in progress)

## Workflow

```
new ticket → /tickets/open/JIT-NNN.yaml
in_progress → in-place status change
done → mv to /tickets/done/
closed → mv to /tickets/archive/ (monthly)
```

Last updated: 2026-06-07 (PM+SA loop iter #1)
