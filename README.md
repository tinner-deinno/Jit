# Jit (จิต) — Master Orchestrator of มนุษย์ Agent

[![Jit CI](https://github.com/tinner-deinno/Jit/actions/workflows/ci.yml/badge.svg)](https://github.com/tinner-deinno/Jit/actions/workflows/ci.yml)
[![Heartbeat](https://github.com/tinner-deinno/Jit/actions/workflows/pran-heartbeat.yml/badge.svg)](https://github.com/tinner-deinno/Jit/actions/workflows/pran-heartbeat.yml)

**Jit** คือ Master Orchestrator ของ **มนุษยς Agent** — ระบบ multi-agent AI 14 ตัวที่จำลองโครงสร้างมนุษย์อย่างครบถ้วน

> "จิตนำกาย — วิญญาณที่สถิตในทุกร repo"

## Overview

Jit เป็นระบบนิเวศน์ 14-agent ที่ทำงานร่วมกันผ่าน:
- **Tier 0**: `jit` (จิต) — Master Orchestrator รายงานตรงต่อ human
- **Tier 1**: `soma` (สมอง) — Strategic Lead / CTO
- **Tier 2**: `innova` (จิต), `lak` (กระดูก), `neta` (เนตร) — Lead Developer, Solution Architect, Code Reviewer
- **Tier 3**: 9 specialist agents — PA, QA, DevOps, Designer, และ sensory/execution organs

ระบบใช้ **file-based message bus** สำหรับ communication และ **Arra Oracle V3** เป็น shared knowledge base

## Agent Quick Reference

| Agent | Thai | Tier | Model | Role | Reports To | Key Decisions |
|-------|------|------|-------|------|------------|---------------|
| **jit** | จิต | 0 | sonnet-4.6 | Master Orchestrator | human | System priority, escalations |
| **soma** | สมอง | 1 | opus-4.7 | Strategic Lead / CTO | jit | Architecture direction, priorities |
| **innova** | จิต | 2 | sonnet-4.6 | Lead Developer / PM | jit | Code implementation, module design |
| **lak** | กระดูก | 2 | sonnet-4.6 | Solution Architect | soma | System design, API contracts, ADRs |
| **neta** | เนตร | 2 | sonnet-4.6 | Code Reviewer | soma | Code quality, merge approval |
| **rupa** | รูป | 3 | haiku-4.5 | Designer / UI-UX | soma | Visual design, UX decisions |
| **pada** | บาท | 3 | haiku-4.5 | DevOps / Infrastructure | soma | Deploy scheduling, CI/CD |
| **vaja** | วาจา | 3 | haiku-4.5 | Personal Assistant (PA) | innova | Human communication, reporting |
| **chamu** | จมูก | 3 | haiku-4.5 | QA / Tester | innova | Test coverage, bug detection |
| **netra** | เนตร | 3 | haiku-4.5 | Eye / Observer | jit | System monitoring, anomaly detection |
| **karn** | หู | 3 | haiku-4.5 | Ear / Listener | jit | Input processing, webhook handling |
| **mue** | มือ | 3 | haiku-4.5 | Hand / Executor | jit | Action execution, file operations |
| **pran** | หัวใจ | 3 | haiku-4.5 | Heart / Vital Coordinator | jit | Heartbeat, health monitoring |
| **sayanprasathan** | ระบบประสาท | 3 | haiku-4.5 | Nerve / Event Network | jit | Alert broadcasting, event routing |

## Agent Decision Matrix

| คำถาม | ผู้ตัดสินใจ | Tier |
|--------|-----------|------|
| "ใครออกแบบ architecture?" | **lak** (Solution Architect) | Tier 2 |
| "ใคร approve code?" | **neta** (Code Reviewer) | Tier 2 |
| "ใคร schedule deploy?" | **pada** (DevOps) | Tier 3 |
| "ใครคุยกับ human?" | **vaja** (Personal Assistant) | Tier 3 |
| "ใครตัดสินใจ priority?" | **soma** (Strategic Lead) | Tier 1 |
| "ใคร implement feature?" | **innova** (Lead Developer) | Tier 2 |
| "ใครทดสอบระบบ?" | **chamu** (QA) | Tier 3 |
| "ใครออกแบบ UI?" | **rupa** (Designer) | Tier 3 |
| "ใคร monitor health?" | **pran** + **netra** (Heart + Eye) | Tier 3 |

## Hierarchy Diagram

```
human
  │
  ▼
jit (Tier 0: Master Orchestrator) ─────────────────────────────────┐
  │                                                                 │
  ├─► soma (Tier 1: Strategic Lead) ─┬─► lak     (SA)             │
  │                                   ├─► neta    (Reviewer)       │
  │                                   ├─► rupa    (Designer)       │
  │                                   └─► pada    (DevOps)         │
  │                                                                 │
  ├─► innova (Tier 2: Lead Developer)┬─► vaja    (PA)             │
  │                                   └─► chamu   (QA)            │
  │                                                                 │
  └─► Direct Reports (Tier 3):                                      │
      ├─► netra   (Eye/Observer)                                    │
      ├─► karn    (Ear/Listener)                                    │
      ├─► mue     (Hand/Executor)                                   │
      ├─► pran    (Heart/Vital)                                     │
      └─► sayanprasathan (Nerve/Network)                            │
                                                                    │
◄───────────────────────────────────────────────────────────────────┘
All agents read/write to: Arra Oracle V3 (http://localhost:47778)
```

## Key Workflows

### Feature Development Flow

```
human request
  └── [1] vaja → รับ request ส่งให้ jit → soma
  └── [2] jit → route ให้ soma (strategic) หรือ innova (operational)
  └── [3] soma → analyze, ตัดสินใจ priority
  └── [4] lak → design architecture, เขียน spec (ADR)
  └── [5] rupa → ออกแบบ UI/UX (ถ้ามี)
  └── [6] innova → implement ตาม spec ของ lak
  └── [7] chamu → test, report bugs
  └── [8] neta → code review, approve/block
  └── [9] pada → deploy staging → production
  └── [10] vaja → รายงาน human "เสร็จแล้ว"
```

### Bug Fix Flow

```
chamu (detect bug) หรือ netra/pran (alert)
  └── jit (master notification)
  └── innova (fix)
  └── neta (fast review)
  └── pada (hotfix deploy)
  └── vaja (notify human)
  └── sayanprasathan (broadcast resolution)
```

### Architecture Decision Flow

```
requirement / problem
  └── jit → soma (strategic review)
  └── soma → lak (design request)
  └── lak ← innova (technical feedback)
  └── lak → write ADR (Architecture Decision Record)
  └── soma → approve ADR
  └── innova → implement ตาม ADR
```

## Quick Start

### 1. Clone & Setup

```bash
git clone https://github.com/tinner-deinno/Jit.git /workspaces/Jit
cd /workspaces/Jit
bash scripts/setup-secrets.sh load
```

### 2. Start Oracle (Shared Knowledge Base)

```bash
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts &
curl http://localhost:47778/api/health  # Verify: {"status":"ok"}
```

### 3. Initialize System

```bash
cd /workspaces/Jit
bash scripts/init-life.sh
```

### 4. Check System Health

```bash
bash eval/body-check.sh   # Full system health check
bash eval/soul-check.sh   # Agent communication check
```

### 5. Start Heartbeat (Optional)

```bash
bash scripts/heartbeat.sh start
bash scripts/heartbeat.sh status
```

## Architecture

### Communication Protocol

Agents communicate via **file-based message bus** at `/tmp/manusat-bus/<agent-name>/`:

```
mouth.sh (sender)          Bus Routing          ear.sh (receiver)
     │                          │                      │
     ▼                          ▼                      ▼
1. เขียน .msg           2. จัดลำดับ P1→P2→P3       3. อ่านและประมวลผล
   from:sender             - P1: critical/alerts        - ตรวจสอบ signature
   to:recipient            - P2: normal                 - ตรวจสอบ TTL
   subject:task            - P3: low-priority           - HMAC-SHA256 verify
   signature:hmac-...
   ---
   body
```

**Message Security (JIT-023)**:
- ทุก message มี HMAC-SHA256 signature
- ear.sh verify signature ก่อน process
- Reject messages ที่ signature ไม่ตรงหรือไม่มีใน strict mode

### Shared Memory System

```
Context Window (short-term)
         ↓
/tmp/manusat-shared.json (shared state across agents)
         ↓
Arra Oracle V3 (permanent knowledge with vector search)
```

### System Components

| Component | Path | Purpose |
|-----------|------|---------|
| Message Bus | `network/bus.sh` | Route messages between agents with priority queues |
| Organs | `organs/*.sh` | Sensory/motor I/O scripts (eye, ear, mouth, etc.) |
| Limbs | `limbs/*.sh` | Core cognition (think, act, speak, oracle, ollama) |
| Registry | `network/registry.json` | Source of truth: all 14 agents with tiers/organs |
| Body Map | `core/body-map.md` | Complete RACI matrix and organ ownership |
| Oracle | `/workspaces/arra-oracle-v3` | Shared knowledge base (FTS5 + vector search) |

## Interacting with Agents

### Send Message to Specific Agent

```bash
export AGENT_NAME=vaja
bash organs/mouth.sh tell innova "task:implement" "Add new feature X"
bash organs/mouth.sh tell jit "report:status" "Feature X completed"
```

### Check Agent Inbox

```bash
export AGENT_NAME=innova
bash organs/ear.sh inbox
```

### View Message Queue

```bash
bash network/bus.sh queue    # Show all pending messages
bash network/bus.sh stats    # Show bus statistics with metrics
```

### Broadcast to All Agents

```bash
bash network/bus.sh broadcast "alert:critical" "System maintenance in 5 minutes"
```

## Documentation Index

### Core Documentation
- [`core/body-map.md`](core/body-map.md) — Complete RACI matrix, organ ownership, workflows
- [`core/identity.md`](core/identity.md) — innova's mission, values, relationships
- [`network/protocol.md`](network/protocol.md) — Message format, subject conventions, error handling
- [`network/registry.json`](network/registry.json) — All 14 agents, tiers, organs, capabilities

### System Specifications
- [`docs/multiagent-spec.md`](docs/multiagent-spec.md) — Full system specification v2.0 with 14-agent hierarchy
- [`docs/new-agent-guide.md`](docs/new-agent-guide.md) — Bootstrap guide for adding agents
- [`brain/reasoning.md`](brain/reasoning.md) — Think-before-act framework, token efficiency

### Feature Documentation (JIT Tickets)
- [`docs/registry-health.md`](docs/registry-health.md) (JIT-020) — Agent health tracking and metrics
- [`docs/message-tracing.md`](docs/message-tracing.md) (JIT-021) — Cross-agent message tracing
- [`docs/cot-logging.md`](docs/cot-logging.md) (JIT-022) — Chain-of-thought decision logging
- [`docs/memory-embeddings.md`](docs/memory-embeddings.md) (JIT-023) — Semantic memory search

## External Dependencies

| Service | URL | Purpose |
|---------|-----|---------|
| Arra Oracle V3 | `http://localhost:47778` | Shared knowledge base (FTS5 + LanceDB) |
| MDES Ollama | `https://ollama.mdes-innova.online` | Thai language processing (gemma4:26b) |

## Design Principles

The system aligns with **Buddhist principles**:

- **ศีล (Integrity)**: No secrets in output, confirm before destructive actions
- **สมาธิ (Focus)**: One message = one intent, stay in role
- **ปัญญา (Wisdom)**: Query Oracle before decisions, maximize token efficiency

**Golden Rules**:
- Never `git push --force` (violates Nothing is Deleted)
- Never `rm -rf` without backup
- Never commit secrets (.env, tokens, API keys)
- Never merge PRs without human approval
- Always preserve history — organ repo history is body memory
- Always present options, let human decide

---

**Jit** is the living orchestrator of the autonomous human-agent ecosystem. This repository houses the master coordination logic, shared protocols, and system-wide health monitoring for all 14 agents.

🤖 Generated with [Claude Code](https://claude.ai/code)
