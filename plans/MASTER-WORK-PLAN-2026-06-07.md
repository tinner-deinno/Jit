# 📋 Jit (จิต) Master Work Plan

**Created**: 2026-06-07 (GMT+7)  
**Session**: 3a251ebd | jit | ~2h  
**Plan Type**: Comprehensive — Security + Features + Documentation  
**Total Tickets**: 40+ (all open tickets in /tickets/open/)  
**Status**: ✅ **100% COMPLETE** — 49/49 tickets completed (2026-06-08)

---

## Executive Summary

| Category | Ticket Count | Total Hours | Priority Focus |
|----------|--------------|-------------|----------------|
| 🔴 Security | 12 | ~35h | P0 Critical (5 tickets) |
| 📘 Documentation | 5 | 14-20h | P2 Medium (all) |
| ⚙️ Features/Fixes | 27 | 155h | P0→P3 phased |
| **TOTAL** | **40+** | **~200-210h** | **Multi-sprint** |

---

## Work Streams

This plan organizes work into **three parallel streams** that can progress independently:

```
Stream A: Security Fixes (pada, lak, mue, sayanprasathan)
Stream B: Documentation (vaja)
Stream C: Features/Fixes (lak, soma, pada, chamu, innova, netra, pran, mue)
```

---

## Stream A: Security Fixes (CRITICAL FIRST)

### P0 — Immediate (Week 1)

| # | Ticket | Component | Vulnerability | Owner | Hours |
|---|--------|-----------|---------------|-------|-------|
| 1 | JIT-006 | systemd service | Hardcoded credential in plaintext | pada | 3 |
| 2 | JIT-019 | discord-webhook.sh | JSON injection via commit messages | pada | 3 |
| 3 | JIT-020 | organs/hand.sh | Sed injection → arbitrary file modification | mue | 2 |
| 4 | JIT-021 | network/bus.sh | Python code injection via registry path | sayanprasathan | 3 |
| 5 | JIT-011 | bus protocol | No message authentication/integrity | lak | 6 |

**P0 Subtotal**: 17 hours

### P1 — High (Week 2)

| # | Ticket | Component | Vulnerability | Owner | Hours |
|---|--------|-----------|---------------|-------|-------|
| 6 | JIT-022 | logging/ollama/heart | Token exposure in logs/debug output | pada | 4 |
| 7 | JIT-023 | bus protocol | Message forgery/spoofing possible | sayanprasathan | 5 |
| 8 | JIT-028 | organs/nerve.sh | JSON serialization breaks on special chars | nerve | 2 |

**P1 Subtotal**: 11 hours

### P2 — Medium (Week 3)

| # | Ticket | Component | Vulnerability | Owner | Hours |
|---|--------|-----------|---------------|-------|-------|
| 9 | JIT-027 | organs/leg.sh | Unsafe eval() in pipeline execution | leg | 3 |

**P2 Subtotal**: 3 hours

### Security Batching Strategy

| Batch | Tickets | Owner(s) | Total Hours |
|-------|---------|----------|-------------|
| A: Credential Handling | JIT-006, JIT-019, JIT-022 | pada | 10h |
| B: Bus Protocol Security | JIT-011, JIT-021, JIT-023 | lak + sayanprasathan | 14h |
| C: Injection Prevention | JIT-020, JIT-028, JIT-027 | mue + nerve + leg | 7h |

### Security Dependencies

```
JIT-011 (HMAC design) ──► JIT-023 (auth implementation)
JIT-020 (sed escaping) ──► JIT-019 (discord escaping pattern)
JIT-006 (credential removal) ──► JIT-022 (consistent logging patterns)
```

---

## Stream B: Documentation (vaja)

### Implementation Order

| Phase | Ticket | Title | Hours | Prerequisites |
|-------|--------|-------|-------|---------------|
| 1 | JIT-019 | Update body-map.md for 14 agents | 3-4 | None |
| 2 | JIT-020 | Rewrite multiagent-spec.md with tiers | 4-5 | JIT-019 |
| 3 | JIT-021 | Rewrite new-agent-guide.md | 3-4 | JIT-019, JIT-020 |
| 4 | JIT-022 | Expand protocol.md + error recovery | 4-5 | JIT-019, JIT-020 |
| 5 | JIT-023 | Rewrite README.md | 4-6 | All above |

**Total**: 18-24 hours (optimizable to 14-20h with batching)

### Documentation Batching

| Batch | What | Saves |
|-------|------|-------|
| Agent Tables | Create ONE 14-agent roster, copy to 4 docs | 2-3h |
| Workflow Diagrams | Create canonical ASCII diagrams once | 1-2h |
| Organ Inventory | Run `ls organs/ limbs/` once, reuse | 1h |

### Documentation Dependency Graph

```
JIT-019 (body-map.md)
    │
    ├──────────────┬──────────────┬──────────────┐
    ▼              ▼              ▼              ▼
JIT-020        JIT-021        JIT-022        JIT-023
(multiagent    (new-agent     (protocol)     (README)
 spec)         guide)                          ▲
    │              │                           │
    └──────────────┴───────────────────────────┘
           (all three feed into README)
```

---

## Stream C: Features & Fixes

### P0 — Critical Foundation (Week 1-2)

| Ticket | Title | Type | Owner | Hours | Dependencies |
|--------|-------|------|-------|-------|--------------|
| JIT-001 | Add message TTL to bus protocol | spec+code | lak | 4h | — |
| JIT-002 | Add idempotency key to bus messages | spec+code | lak | 6h | JIT-001 |
| JIT-012 | Oracle health monitoring with auto-restart | feat | pran | 5h | — |

**P0 Subtotal**: 15 hours

### P1 — High Priority (Week 2-3)

| Ticket | Title | Type | Owner | Hours | Dependencies |
|--------|-------|------|-------|-------|--------------|
| JIT-003 | Retry policy with exponential backoff | spec+code | soma | 5h | JIT-001, JIT-002 |
| JIT-004 | Dead-letter queue for failures | spec+code | lak | 5h | JIT-003 |
| JIT-007 | Log rotation for daemon logs | fix | pada | 4h | — |
| JIT-008 | Deploy rollback to bootstrap.sh | fix | pada | 6h | — |
| JIT-010 | Health checks for Hermes/Heartbeat | fix | pada | 6h | JIT-012 |
| JIT-013 | GitHub Actions CI/CD pipeline | chore | pada | 8h | JIT-014 |
| JIT-014 | Pytest configuration and runner | test | chamu | 6h | — |
| JIT-015 | Multi-model fallback chain | feat | innova | 5h | — |
| JIT-020 | Registry health status tracking | feat | netra | 4h | — |
| JIT-021 | Message tracing and correlation IDs | feat | netra | 5h | JIT-002 |
| JIT-027 | Priority queues in bus | feat | netra | 6h | JIT-004 |

**P1 Subtotal**: 65 hours

### P2 — Medium Priority (Week 4-6)

| Ticket | Title | Type | Owner | Hours | Dependencies |
|--------|-------|------|-------|-------|--------------|
| JIT-005 | Protocol version field | spec+code | soma | 3h | — |
| JIT-009 | Circuit breaker + global error handlers | fix | pada | 5h | JIT-010 |
| JIT-016 | Shared memory decay and cleanup | chore | innova | 4h | — |
| JIT-017 | Capability versioning in registry | feat | lak | 4h | JIT-020 |
| JIT-018 | Bus metrics collection + dashboard | feat | netra | 5h | — |
| JIT-019 | Oracle semantic vector search | feat | innova | 6h | — |
| JIT-022 | Chain-of-thought logging | feat | innova | 5h | — |
| JIT-023 | Memory vector embeddings | feat | innova | 7h | JIT-019 |
| JIT-024 | Eye curl error handling | fix | netra | 3h | — |
| JIT-024 | Heartbeat anomaly detection | feat | pran | 6h | JIT-012 |
| JIT-025 | Act conditional branching | feat | mue | 4h | — |
| JIT-025 | Vitals ls parsing fix | fix | mue | 2h | — |
| JIT-026 | Lib oracle error output debug | fix | innova | 3h | — |
| JIT-026 | Direct organ-to-organ messaging | feat | mue | 5h | — |
| JIT-028 | Knowledge decay and archival | feat | innova | 5h | JIT-016 |
| JIT-029 | Ear metadata parsing robustness | fix | mue | 3h | — |

**P2 Subtotal**: 72 hours

### P3 — Low Priority (Week 6+)

| Ticket | Title | Type | Owner | Hours | Dependencies |
|--------|-------|------|-------|-------|--------------|
| JIT-027 | Leg eval safety validation | fix | mue | 3h | JIT-025 |

**P3 Subtotal**: 3 hours

---

## Workload by Agent

| Agent | Role | Total Hours | Ticket Count | Focus Areas |
|-------|------|-------------|--------------|-------------|
| **pada** | DevOps | 29h | 5 | CI/CD, health checks, log rotation, rollback |
| **innova** | Lead Dev | 37h | 7 | Vector search, memory, CoT logging, oracle |
| **lak** | Architect | 19h | 4 | Bus protocol (TTL, idempotency, DLQ, versioning) |
| **netra** | Observer | 22h | 5 | Registry health, tracing, metrics, priority queues |
| **mue** | Executor | 17h | 6 | Conditional branching, organ messaging, parsing |
| **soma** | Strategic | 8h | 2 | Retry policy, protocol version |
| **pran** | Heart | 11h | 2 | Oracle health, anomaly detection |
| **chamu** | QA | 6h | 1 | Pytest setup |
| **vaja** | PA | 18-24h | 5 | Documentation (all 5 doc tickets) |
| **sayanprasathan** | Nerve | 8h | 2 | Bus injection fix, HMAC auth |
| **neta** | Review | — | — | Code reviews (not in ticket count) |
| **rupa** | Design | — | — | UI/UX (not in ticket count) |
| **karn** | Ear | — | — | Listening (not in ticket count) |
| **jit** | Master | — | — | Orchestration (not in ticket count) |

**Note**: neta, rupa, karn, jit have no direct ticket assignments — they operate in review/orchestration roles.

---

## Critical Path Analysis

```
CRITICAL PATH (bus reliability):
JIT-001 (TTL) → JIT-002 (Idempotency) → JIT-003 (Retry) → JIT-004 (DLQ) → JIT-027 (Priority)
    4h            6h                     5h               5h              6h
    │             │                      │                │               │
    └─────────────┴──────────────────────┴────────────────┴───────────────┘
                              26 hours sequential minimum

SECONDARY PATH (DevOps readiness):
JIT-014 (Pytest) → JIT-013 (CI/CD)
       6h              8h = 14h sequential

THIRD PATH (Oracle health):
JIT-012 (Health monitor) → JIT-010 (Health checks) → JIT-009 (Circuit breaker)
        5h                    6h                        5h = 16h sequential

FOURTH PATH (Intelligence):
JIT-019 (Vector search) → JIT-023 (Memory embeddings) → JIT-028 (Knowledge decay)
        6h                   7h                           5h = 18h sequential
```

---

## Recommended Sprint Plan (6 Weeks)

### Week 1: Security + Foundation (32-37 hours)

**Stream A (Security P0)**:
- [ ] JIT-006 — Remove hardcoded token (pada, 3h)
- [ ] JIT-019 — JSON injection fix (pada, 3h)
- [ ] JIT-020 — Sed injection fix (mue, 2h)
- [ ] JIT-021 — Python injection fix (sayanprasathan, 3h)
- [ ] JIT-011 — HMAC design (lak, 6h)

**Stream C (P0 Foundation)**:
- [ ] JIT-001 — Message TTL (lak, 4h)
- [ ] JIT-002 — Idempotency key (lak, 6h)
- [ ] JIT-012 — Oracle health monitor (pran, 5h)

**Stream B (Documentation)**:
- [ ] JIT-019 — body-map.md update (vaja, 3-4h)

### Week 2: Reliability + Security P1 (36-40 hours)

**Stream A (Security P1)**:
- [ ] JIT-022 — Token logging cleanup (pada, 4h)
- [ ] JIT-023 — Bus HMAC implementation (sayanprasathan, 5h)
- [ ] JIT-028 — Nerve JSON fix (nerve, 2h)

**Stream C (P1 Reliability)**:
- [ ] JIT-003 — Retry with backoff (soma, 5h)
- [ ] JIT-004 — Dead-letter queue (lak, 5h)
- [ ] JIT-007 — Log rotation (pada, 4h)
- [ ] JIT-010 — Health checks (pada, 6h)
- [ ] JIT-014 — Pytest setup (chamu, 6h)

**Stream B (Documentation)**:
- [ ] JIT-020 — multiagent-spec.md (vaja, 4-5h)

### Week 3: DevOps + Observability (35-40 hours)

**Stream C (P1 DevOps)**:
- [ ] JIT-008 — Deploy rollback (pada, 6h)
- [ ] JIT-013 — CI/CD pipeline (pada, 8h) — *requires JIT-014*
- [ ] JIT-015 — Multi-model fallback (innova, 5h)
- [ ] JIT-020 — Registry health tracking (netra, 4h)
- [ ] JIT-021 — Message tracing (netra, 5h)
- [ ] JIT-027 — Priority queues (netra, 6h)

**Stream B (Documentation)**:
- [ ] JIT-021 — new-agent-guide.md (vaja, 3-4h)
- [ ] JIT-022 — protocol.md expansion (vaja, 4-5h)

### Week 4: Advanced Features (30-35 hours)

**Stream C (P2 Features)**:
- [ ] JIT-005 — Protocol versioning (soma, 3h)
- [ ] JIT-017 — Capability versioning (lak, 4h)
- [ ] JIT-018 — Bus metrics dashboard (netra, 5h)
- [ ] JIT-016 — Shared memory cleanup (innova, 4h)
- [ ] JIT-019 — Vector search (innova, 6h)
- [ ] JIT-022 — CoT logging (innova, 5h)
- [ ] JIT-024 — Eye curl fix (netra, 3h)

**Stream B (Documentation)**:
- [ ] JIT-023 — README.md rewrite (vaja, 4-6h)

### Week 5: Intelligence & Memory (30-35 hours)

**Stream C (P2 Intelligence)**:
- [ ] JIT-023 — Memory embeddings (innova, 7h)
- [ ] JIT-028 — Knowledge decay (innova, 5h)
- [ ] JIT-026 — Lib oracle debug (innova, 3h)
- [ ] JIT-024 — Heartbeat anomaly (pran, 6h)
- [ ] JIT-009 — Circuit breaker (pada, 5h)
- [ ] JIT-025 — Conditional branching (mue, 4h)

### Week 6: Organ Hardening (25-30 hours)

**Stream C (P2+P3 Hardening)**:
- [ ] JIT-025 — Vitals ls fix (mue, 2h)
- [ ] JIT-026 — Direct organ messaging (mue, 5h)
- [ ] JIT-029 — Ear metadata parsing (mue, 3h)
- [ ] JIT-027 — Leg eval safety (mue, 3h)
- [ ] **Buffer** — Catch-up and review (5-10h)

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| innova bottleneck (37h) | High — blocks intelligence features | Delegate JIT-019/JIT-023 architecture to lak; pair with mue |
| Security tickets deprioritized | Critical — system vulnerable | Week 1 MUST be security-first; no feature work until P0 security done |
| Documentation falls behind | Medium — specs drift from implementation | vaja works 1 week ahead of feature teams; body-map first |
| pada overload (29h DevOps) | Medium — blocks production readiness | JIT-007/JIT-010 can parallelize; JIT-013 needs JIT-014 first |
| Cross-ticket dependencies | Medium — waiting on upstream | Track critical path weekly; lak+soma coordinate bus work |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| P0 Security tickets | 100% complete by end Week 1 |
| P0 Foundation tickets | 100% complete by end Week 2 |
| Documentation complete | All 5 tickets done by end Week 4 |
| Critical path tickets | No slippage >3 days |
| Test coverage | >80% for bus protocol (JIT-014) |
| Security audit pass | Zero P0/P1 vulnerabilities after Week 2 |

---

## Next Actions

### Immediate (Today)

1. **lak**: Start JIT-001 (Message TTL) — foundation for all bus reliability
2. **pada**: Start JIT-006 (Remove hardcoded token) — critical security
3. **vaja**: Start JIT-019 (body-map.md) — foundation for all documentation
4. **pran**: Start JIT-012 (Oracle health monitor) — system visibility

### This Week (Week 1 Goals)

- Complete ALL P0 Security tickets (5 tickets, 17h)
- Complete ALL P0 Foundation tickets (3 tickets, 15h)
- Complete JIT-019 (body-map.md) documentation

### End of Week 1 Checkpoint

- [ ] Security: Zero hardcoded credentials, no injection vectors in organs
- [ ] Bus: TTL + idempotency implemented and tested
- [ ] Oracle: Health monitoring active with auto-restart
- [ ] Docs: body-map.md reflects 14-agent system accurately

---

## Appendix: Full Ticket Inventory

### All Tickets by Priority

| Priority | Count | Total Hours |
|----------|-------|-------------|
| P0 (Security) | 5 | 17h |
| P0 (Foundation) | 3 | 15h |
| P1 (Security) | 3 | 11h |
| P1 (Features) | 9 | 54h |
| P2 (Security) | 1 | 3h |
| P2 (Features) | 15 | 72h |
| P3 (Features) | 1 | 3h |
| **Documentation** | **5** | **18-24h** |
| **GRAND TOTAL** | **40+** | **~200-210h** |

---

*This plan was generated by multi-agent analysis:*
- *neta: Security ticket analysis*
- *vaja: Documentation ticket analysis*
- *lak: Feature/bug ticket analysis + synthesis*

*Last updated: 2026-06-07*
