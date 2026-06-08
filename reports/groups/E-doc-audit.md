# Documentation Audit Report
**Date**: 2026-06-07  
**Auditor**: vaja  
**Status**: 5 gaps identified, tickets created

---

## Summary

Audited 5 core documentation files against current system state (14-agent ecosystem v2.0). Found significant drift between docs (8 agents max) and actual system (14 agents + 4-tier hierarchy).

| File | Status | Issues |
|------|--------|--------|
| `core/body-map.md` | ⚠️ Stale | Missing 6 agents (netra, karn, mue, pran, sayanprasathan, jit); incomplete RACI; missing tier structure |
| `docs/multiagent-spec.md` | ⚠️ Stale | Only 2 agents documented; outdated model versions; no tier structure |
| `docs/new-agent-guide.md` | ⚠️ Stale | Describes single-repo bootstrap, not multi-repo multi-agent addition |
| `network/protocol.md` | ⚠️ Incomplete | Only 2 agents in Agent Roles; missing error recovery details; no troubleshooting |
| `README.md` | ⚠️ Incomplete | Describes innova + Discord sub-agent, not full 14-agent system; missing hierarchy overview |

---

## Detailed Gaps

### 1. body-map.md — Missing 6 agents + incomplete hierarchy
- **Current**: Shows 8 agents (soma, innova, lak, neta, vaja, chamu, rupa, pada)
- **Missing**: netra (eye), karn (ear), mue (hand), pran (heart), sayanprasathan (nerve), jit (master orchestrator)
- **Issue**: Diagram is incomplete; RACI matrix only covers 8; Bus paths only list 8 inboxes
- **Impact**: New agents cannot understand full team structure or their peers' roles
- **Ticket**: JIT-019

### 2. multiagent-spec.md — Severely outdated spec
- **Current**: Only soma + innova documented as 2 agents
- **Missing**: Complete tier structure (Tier 0-3); all 14 agents; model versions (shows opus-4.6, actual is opus-4.7)
- **Issue**: No reference to jit (master), no organ assignments for 10+ agents, no hierarchy explanation
- **Impact**: Spec does not match implementation; cannot onboard new team members
- **Ticket**: JIT-020

### 3. new-agent-guide.md — Wrong context (single-repo, not multi-agent)
- **Current**: Describes cloning Jit repo to create new agent as if Jit = template
- **Missing**: Steps for adding agent to existing 14-agent ecosystem (register in registry.json, assign parent, assign organ)
- **Issue**: Guide assumes new agent = new repo clone; doesn't cover: tier assignment, parent-child setup, organ ownership
- **Impact**: Cannot add agents to existing system without reverse-engineering the workflow
- **Ticket**: JIT-021

### 4. protocol.md — Agent coverage incomplete + missing recovery docs
- **Current**: Only soma + innova in "Agent Roles" section
- **Missing**: Roles for 12 other agents; error recovery procedures; message queue overflow handling; timeout recovery; fallback routes
- **Issue**: Protocol appears to only support 2 agents; lacks operational resilience documentation
- **Impact**: Agents cannot find their message handling guidelines; ops team lacks runbook for incidents
- **Ticket**: JIT-022

### 5. README.md — Missing multi-agent system overview
- **Current**: Describes innova + Discord sub-agent (อนุ) as main focus
- **Missing**: Mention of 14-agent ecosystem; jit as master orchestrator; tier hierarchy; feature/bug/design decision flows; agent decision matrix
- **Issue**: Quick start doesn't explain parent-child coordination or how agents delegate work
- **Impact**: First-time reader thinks system is innova-centric, not jit-orchestrated 14-agent system
- **Ticket**: JIT-023

---

## Tickets Created

| Ticket | Title | Owner | Priority | Status |
|--------|-------|-------|----------|--------|
| JIT-019 | Update body-map.md for 14-agent ecosystem | vaja | P2 | open |
| JIT-020 | Rewrite multiagent-spec.md with Tier 0-3 hierarchy | vaja | P2 | open |
| JIT-021 | Rewrite new-agent-guide.md for multi-agent addition | vaja | P2 | open |
| JIT-022 | Expand protocol.md with all 14 agents + error recovery | vaja | P2 | open |
| JIT-023 | Rewrite README.md for 14-agent system overview | vaja | P3 | open |

---

## Quick Assessment

**Root Cause**: Documentation was last updated for 8-agent v1.0 system. Current system is 14-agent v2.0 with Tier 0 (jit) master orchestrator.

**Scope**: ~200 lines of updates needed across 5 files.

**Recommended order**: 
1. Update multiagent-spec.md (spec is source of truth)
2. Update body-map.md (visual reference)
3. Rewrite new-agent-guide.md (operational docs)
4. Expand protocol.md (technical reference)
5. Rewrite README.md (first impression)

