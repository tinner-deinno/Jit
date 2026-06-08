# Feature Discovery Report — June 7, 2026

**Conducted by**: innova (innovation lead)  
**Scope**: 8 core systems (oracle, registry, bus, think, memory, heartbeat, act, organs)  
**Tickets Created**: 10 (P1: 3, P2: 7)  
**Total Effort**: ~53 hours across all features

## Summary

The Jit มนุษย์ Agent system is operationally complete (v2.0, all 14 organs assigned) but has **observability and reasoning gaps** that limit scalability and fault tolerance.

### What Works Well
- ✅ Reliable message bus with POSIX queues
- ✅ Adaptive heartbeat with 5 modes (sprint/fast/normal/slow/rest)
- ✅ Oracle knowledge base integration (keyword search)
- ✅ Complete organ coverage (11 organ scripts + 14-agent registry)
- ✅ Action journaling and git integration

### Critical Gaps

| Area | Gap | Severity | Ticket |
|------|-----|----------|--------|
| Oracle | No semantic search — keyword match only | P2 | JIT-019 |
| Registry | No health/metrics tracking — static metadata | P1 | JIT-020 |
| Bus | No message tracing — can't debug routing | P1 | JIT-021 |
| Think | No chain-of-thought logging — can't audit reasoning | P2 | JIT-022 |
| Memory | No vector embeddings — flat JSON only | P2 | JIT-023 |
| Heartbeat | No anomaly detection — can't find stuck agents | P2 | JIT-024 |
| Act | No conditional branching — linear only | P2 | JIT-025 |
| Organs | No direct channels — all traffic through bus hub | P2 | JIT-026 |
| Bus | FIFO queue — no priority for alerts | P1 | JIT-027 |
| Memory | Unbounded growth — no decay/archival | P2 | JIT-028 |

## Ticket Details

### P1 (Critical) — 3 Tickets, ~15 hours
These block effective monitoring and system health.

**JIT-020** — Registry Health Tracking (4h, owner: netra)  
Add health_status, last_heartbeat, response_time_ms, queue_depth to agent registry.  
*Why*: Can't detect dead agents or degraded performance; heartbeat is blind to system state.

**JIT-021** — Bus Message Tracing (5h, owner: netra)  
Trace correlation-id across full message path; report latency per agent pair.  
*Why*: Can't debug stuck messages or find bottlenecks; only see total count, not routing.

**JIT-027** — Bus Priority Queues (6h, owner: netra)  
Add P1/P2/P3 buckets; auto-promote alert subjects; prevent low-priority tasks blocking health checks.  
*Why*: Critical alerts could get queued behind batch jobs; no way to prioritize urgent messages.

### P2 (High) — 7 Tickets, ~38 hours
These improve reasoning, scalability, and developer experience.

**JIT-019** — Oracle Vector Search (6h, owner: innova)  
Add semantic search (embedding-based, not keyword). Enable agent reasoning across large knowledge bases.  
*Why*: Keyword matching misses related concepts; agents can't find contextually relevant knowledge.

**JIT-022** — Think Chain-of-Thought Logging (5h, owner: innova)  
Structured reasoning trace (intent → steps → decision) to JSONL. Used by soma for retrospectives.  
*Why*: Can't audit how agents decide; no way to learn from mistakes or debug decision paths.

**JIT-023** — Memory Vector Embeddings (7h, owner: innova)  
Index knowledge by semantics; cross-session recovery of relevant memories.  
*Why*: Memory is flat JSON; can't find contextually related past decisions; memories not reusable across sessions.

**JIT-024** — Heartbeat Anomaly Detection (6h, owner: pran)  
Per-agent anomalies: stuck detection, slow response alerts, queue growth warnings.  
*Why*: Heartbeat just pulses; can't detect hung agents or degraded performance; no automatic recovery triggers.

**JIT-025** — Act Conditional Branching (4h, owner: mue)  
if/else and sequential execution (not just linear). Conditions: file_exists, git_dirty, oracle_available, agent_online.  
*Why*: Workflows are linear; can't adapt to runtime state or implement recovery paths.

**JIT-026** — Organ Direct Messaging (5h, owner: mue)  
Named pipes for low-latency organ coordination (hand↔leg, etc.). Optional bypass of bus hub.  
*Why*: All inter-organ traffic serialized through central bus; can't scale action coordination.

**JIT-028** — Memory Decay & Archival (5h, owner: innova)  
Tag entries with access_count, last_accessed; archive > 60 days old. Weight recency + frequency.  
*Why*: Memory grows unbounded; old decisions drown out relevant ones; query performance degrades.

## Recommendations

### Immediate (Next Sprint)
1. **JIT-020, JIT-021, JIT-027** — Implement in parallel (netra + innova)
   - Unlocks observability and safe alert handling
   - Blocks: anomaly detection, heartbeat scaling

2. **JIT-019** — Start once JIT-021 lands
   - Unblocks semantic reasoning in oracle.sh
   - Pairs with JIT-023 downstream

### Following Sprint
3. **JIT-022, JIT-024** — Pair with soma for retrospectives
   - Enables self-reflection and learning from decisions

4. **JIT-023, JIT-028** — Joint memory enhancement
   - Makes old knowledge reusable; keeps fresh knowledge discoverable

### Later (Optimization)
5. **JIT-025, JIT-026** — Workflow and architecture improvements
   - JIT-025 enables adaptive behaviors
   - JIT-026 scales organ coordination

## Dependencies

```
JIT-020 (registry health)
  ↓
JIT-021 (message tracing) ← JIT-027 (priority queue)
  ↓                           ↓
JIT-024 (anomaly detect)    JIT-019 (vector search)
                              ↓
                            JIT-023 (embeddings)
                              ↓
                            JIT-028 (decay)

JIT-022 (CoT logging) — independent, feeds soma
JIT-025 (conditionals) ← used by JIT-024, JIT-026
JIT-026 (direct messaging) — independent, optional optimization
```

## Effort Estimate

- **Total**: 53 person-hours across 10 features
- **Critical Path** (P1 first): JIT-020 (4h) + JIT-027 (6h) + JIT-021 (5h) = **15 hours**
- **Next Phase** (P2 select): JIT-019 (6h) + JIT-023 (7h) + JIT-024 (6h) = **19 hours**
- **Full Implementation**: 2–3 engineering sprints

## Success Metrics

After implementation:
- **Observability**: netra.sh eye-check shows per-agent health + anomalies (was blind)
- **Reliability**: bus.sh reports message latency + stuck paths (was invisible)
- **Reasoning**: agents find semantically relevant knowledge (was keyword-only)
- **Scale**: organs can coordinate directly; priority queue prevents alert starving (was single hub bottleneck)
- **Memory**: old knowledge archived, fresh knowledge discoverable (was unbounded growth)

---

Report generated: 2026-06-07 by innova  
Next action: Prioritize P1 tickets (JIT-020, JIT-021, JIT-027) for sprint planning.
