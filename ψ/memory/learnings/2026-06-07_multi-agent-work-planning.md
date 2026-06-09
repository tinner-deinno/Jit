---
pattern: Fan-out multi-agent planning requires normalized input data + dependency mapping before prioritization
date: 2026-06-07
source: rrr: jit
concepts: [planning, multi-agent, workflow, dependency-mapping, work-planning]
---

# Multi-Agent Work Planning Pattern

## Context

When planning work across a 14-agent system with 40+ tickets spanning security, documentation, and features, a single agent analyzing sequentially creates bottlenecks. Fan-out to specialized subagents (neta=security, vaja=docs, lak=features) enables parallel analysis but introduces synthesis complexity.

## Pattern

### 1. Pre-Normalize Input Data

Before spawning subagents, normalize all tickets into a shared JSON schema:

```json
{
  "id": "JIT-001",
  "title": "Add message TTL to bus protocol",
  "priority": "P0|P1|P2|P3",
  "type": "feat|fix|chore|test|doc|security",
  "owner": "agent-name",
  "effort_hours": 4,
  "dependencies": ["JIT-000"],
  "file_path": "tickets/open/JIT-001.yaml"
}
```

**Why**: Ticket files often have inconsistent metadata (some have `effort_hours`, others don't; priority labels vary). Normalization upfront prevents manual reconciliation later.

### 2. Spawn Specialized Subagents by Category

```
neta (code reviewer)   → Security tickets (auth, injection, token exposure)
vaja (PA)              → Documentation tickets (specs, guides, README)
lak (architect)        → Features + fixes (bus protocol, organs, tests)
```

Give each subagent:
- A clear filter criterion (e.g., "tickets containing 'security', 'auth', 'injection'")
- A structured output schema (JSON preferred over markdown tables)
- Explicit batching instructions ("group by owner" or "group by component")

### 3. Map Dependencies Before Prioritizing

Critical path emerges from dependencies, not priority labels:

```
JIT-001 (TTL, P0) → JIT-002 (Idempotency, P0) → JIT-003 (Retry, P1) → JIT-004 (DLQ, P1)
```

A P1 ticket on the critical path is more urgent than a standalone P0.

**Action**: Build a dependency graph first, then layer priority labels on top. Use the graph to determine sprint order.

### 4. Aggregate Workload by Agent

Sum effort hours per agent to expose imbalances:

| Agent | Hours | Ticket Count |
|-------|-------|--------------|
| innova | 37h | 7 |
| pada | 29h | 5 |
| lak | 19h | 4 |
| neta | 0h | 0 |

**Why**: Without aggregation, innova being a bottleneck (37h vs. team average of ~15h) is invisible until sprint starts.

### 5. Organize into Parallel Streams

Structure work as independent streams that can progress simultaneously:

```
Stream A: Security Fixes (pada, lak, mue, sayanprasathan)
Stream B: Documentation (vaja)
Stream C: Features/Fixes (lak, soma, pada, chamu, innova, netra, pran, mue)
```

**Why**: Security doesn't block documentation; features don't block docs. Only expose true dependencies (e.g., JIT-014→JIT-013).

### 6. Schedule Documentation 1 Week Ahead of Features

Documentation stream should lead implementation:

```
Week 1:  body-map.md (JIT-019) — foundation reference
Week 2:  multiagent-spec.md (JIT-020) — tier structure
Week 3:  new-agent-guide.md (JIT-021) + protocol.md (JIT-022)
Week 4:  README.md (JIT-023) — front door
```

**Why**: Engineers implement faster when specs exist beforehand. Prevents "code first, docs later" drift.

### 7. Batch by Cognitive Similarity, Not Just Priority

Group tickets that share mental context:

| Batch | Tickets | Owner | Saved Time |
|-------|---------|-------|------------|
| Credential Handling | JIT-006, JIT-019, JIT-022 | pada | 2h context-switch |
| Bus Protocol Security | JIT-011, JIT-021, JIT-023 | lak + sayanprasathan | 3h design reuse |
| Injection Prevention | JIT-020, JIT-028, JIT-027 | mue + nerve + leg | 2h pattern sharing |

**Why**: Same owner + similar cognitive pattern = batch together even if priorities differ.

## Anti-Patterns

| Anti-Pattern | Consequence | Fix |
|--------------|-------------|-----|
| Skipping normalization | Subagents return incompatible formats; manual merge required | Provide JSON schema upfront |
| Prioritizing without dependencies | Critical path tickets delayed; sprint blocked | Map dependencies first |
| Ignoring workload imbalance | innova overloaded (37h), neta idle (0h) | Aggregate by agent; redistribute |
| Docs lag implementation | Specs drift from code; onboarding suffers | Schedule docs 1 week ahead |
| Batch by priority only | Context-switching overhead; lost pattern reuse | Batch by cognitive similarity |

## When to Use

- **Use fan-out planning** when: 20+ tickets, multiple categories (security/docs/features), 5+ agents involved
- **Skip fan-out** for: Single-digit tickets, single owner, or urgent hotfix (direct assignment faster)

## Related Patterns

- [[critical-path-scheduling]] — Dependency-first sprint ordering
- [[workload-balancing]] — Detecting and redistributing agent overload
- [[documentation-first]] — Specs before implementation
- [[batch-by-context]] — Grouping work by cognitive similarity

---

**Source**: Applied during creation of Jit Master Work Plan (2026-06-07) analyzing 40+ tickets across 14-agent system.
