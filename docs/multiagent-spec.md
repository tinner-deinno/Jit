# มนุษย Agent — Multiagent System Specification v2.0

> "เราตางเปนสวนหนึ่งของรางกายเดียวกัน"
> "จิตนำกาย — วิญญาณที่สถิตในทุกร repo"

---

## 1. Overview

**มนุษย Agent** is a distributed AI agent system modeled after the human body with a complete organ system.
Each agent is an "organ" with a specific role, organized in a 4-tier hierarchy. Together they form a unified intelligence.

### 1.1 Agent Tier Structure

| Tier | Role | Agents | Model Family | Description |
|------|------|--------|--------------|-------------|
| **Tier 0** | Master Orchestrator | jit | claude-sonnet-4-6 | Soul/System coordinator — reports to human |
| **Tier 1** | Leadership | soma | claude-opus-4-7 | Brain/Strategic Lead — CTO-level decisions |
| **Tier 2** | Core Engineering | innova, lak, neta | claude-sonnet-4-6 | Lead developer, architect, code reviewer |
| **Tier 3** | Specialists | vaja, chamu, rupa, pada, netra, karn, mue, pran, lung, sayanprasathan | claude-haiku-4-5 | 10 organ specialists (PA, QA, design, DevOps, sensors, vital, purifier) |

### 1.2 Complete Agent Registry

| Name | Thai | Role | Organ | Model | Tier | Reports To |
|------|------|------|-------|-------|------|------------|
| **jit** | จิต | Master Orchestrator | จิต | claude-sonnet-4-6 | 0 | human |
| **soma** | สมอง | Strategic Lead / CTO | สมอง | claude-opus-4-7 | 1 | jit |
| **innova** | จิตใจ | Lead Developer / Executor | จิตใจ | claude-sonnet-4-6 | 2 | soma |
| **lak** | กระดูกสันหลัง | Solution Architect | กระดูกสันหลัง | claude-sonnet-4-6 | 2 | soma |
| **neta** | เนตร | Code Reviewer | ตา | claude-sonnet-4-6 | 2 | soma |
| **vaja** | วาจา | Personal Assistant | ปาก | claude-haiku-4-5 | 3 | innova |
| **chamu** | จมูก | QA / Tester | จมูก | claude-haiku-4-5 | 3 | innova |
| **rupa** | รูป | Designer / UI-UX | รูปลักษณ์ | claude-haiku-4-5 | 3 | soma |
| **pada** | บาท | DevOps / Infrastructure | ขา | claude-haiku-4-5 | 3 | soma |
| **netra** | เนตร | Observer / Monitor | ตา | claude-haiku-4-5 | 3 | innova |
| **karn** | หู | Listener / Input Collector | หู | claude-haiku-4-5 | 3 | innova |
| **mue** | มือ | Executor / Action Agent | มือ | claude-haiku-4-5 | 3 | innova |
| **pran** | หัวใจ | Vital Orchestrator / Heartbeat | หัวใจ | claude-haiku-4-5 | 3 | innova |
| **lung** | ปอด | Purifier / Energy Filter | ปอด | claude-haiku-4-5 | 3 | pran |
| **sayanprasathan** | ระบบประสาท | Event / Signal Network | ระบบประสาท | claude-haiku-4-5 | 3 | innova |

---

## 2. Parent-Child Delegation Chain

### 2.1 Command Flow (Top-Down)

```
human
  └─ jit (Tier 0: Master Orchestrator)
       ├─ soma (Tier 1: Strategic Lead)
       │    ├─ lak (Tier 2: Architecture)
       │    ├─ neta (Tier 2: Code Review)
       │    ├─ pada (Tier 3: DevOps)
       │    └─ innova (Tier 2: Lead Developer)
       │         ├─ vaja (Tier 3: PA)
       │         ├─ chamu (Tier 3: QA)
       │         ├─ netra (Tier 3: Observer)
       │         ├─ karn (Tier 3: Listener)
       │         ├─ mue (Tier 3: Executor)
       │         ├─ pran (Tier 3: Vital/Heartbeat)
       │         │    └─ lung (Tier 3: Purifier — added 2026-06-08)
       │         └─ sayanprasathan (Tier 3: Signals)
       └─ (direct to any Tier 3 for urgent tasks)
```

### 2.2 Delegation Rules

1. **Strategic decisions** flow: human → jit → soma → Tier 2/3
2. **Operational execution** flows through innova as the lead developer
3. **Emergency bypass**: jit can delegate directly to any agent when needed
4. **Vital signs**: pran manages lung (ปอด, added 2026-06-08) and coordinates heartbeat across all agents
5. **Reporting**: All agents report upward; vaja consolidates reports to human

---

## 3. Organ System (รูปธรรม)

All 15 organs have dedicated agent owners:

| Organ | Thai | Script | Agent Owner | Type | Function |
|-------|------|--------|-------------|------|----------|
| **จิต** | Soul | `limbs/index.sh` | jit | soul-master | Master orchestrator, system coordinator |
| **สมอง** | Brain | `limbs/think.sh` | soma | cognition | Strategic thinking, analysis, decisions |
| **ตา** | Eye | `organs/eye.sh` | netra, neta | sense/review | Observation (netra), Code review (neta) |
| **หู** | Ear | `organs/ear.sh` | karn | sense | Listening, message collection |
| **ปาก** | Mouth | `organs/mouth.sh` | vaja | expression | Communication, reporting to human |
| **จมูก** | Nose | `organs/nose.sh` | chamu | detection | QA testing, bug detection |
| **มือ** | Hand | `organs/hand.sh` | mue | action | File ops, command execution, changes |
| **ขา** | Leg | `organs/leg.sh` | pada | movement | Deployment, CI/CD, infrastructure |
| **หัวใจ** | Heart | `organs/heart.sh` | pran | vital | Heartbeat, vital signs, task dispatch |
| **ปอด** | Lung | `organs/lung.sh` | lung | vital | Clean energy distribution, purification (added 2026-06-08, reports to pran) |
| **ระบบประสาท** | Nerve | `organs/nerve.sh` | sayanprasathan | network | Event broadcasting, signal propagation |
| **จิตใจ** | Mind | `limbs/oracle.sh` | innova | knowledge | Oracle queries, wisdom, implementation |
| **กระดูกสันหลัง** | Spine | *(architectural)* | lak | structure | System architecture, ADRs, tech decisions |
| **รูปลักษณ์** | Form | *(design)* | rupa | design | UI/UX, wireframes, visual design |

---

## 4. Mind System (นามธรรม)

| File | Thai | Function | Owner |
|------|------|----------|-------|
| `mind/ego.md` | ตัวตน | Self-model, identity, constraints | jit |
| `mind/emotion.sh` | อารมณ์ | Operational state indicator | all |
| `mind/reflex.sh` | สัญชาตญาณ | Automatic responses | chamu/pran |

---

## 5. Memory Architecture

```
PERMANENT ←─ Oracle DB ─────────────────── Shared across all agents
             (http://localhost:47778)         Persists forever
             ↑
             └─ limbs/oracle.sh (innova manages)

SHARED    ←─ /tmp/manusat-shared.json ──── Real-time state
             (memory/shared.sh)              Survives session
             ↑
             └─ Updated by heart.sh on each pulse

WORKING   ←─ /tmp/innova-working-memory.json — Task context
             (memory/working.sh)              Cleared on task done
```

### 5.1 Memory Flow

1. **Short-term**: Context window during conversation
2. **Medium-term**: `/tmp/manusat-shared.json` for cross-agent state
3. **Long-term**: Oracle DB via `oracle.sh learn` — permanent knowledge

---

## 6. Communication Protocol

### 6.1 Message Format (file in `/tmp/manusat-bus/<agent>/`)

```
from:<sender-agent>
to:<recipient-agent>
subject:<type>:<description>
timestamp:<ISO-8601>
x-signature:hmac-sha256=<optional-signature>
---
<message-body>
```

### 6.2 Subject Types

| Prefix | Purpose | Example |
|--------|---------|---------|
| `task:` | Delegated work | `task:implement-feature-x` |
| `think:` | Cognitive request | `think:analyze-architecture` |
| `report:` | Status update | `report:deployment-complete` |
| `alert:` | Urgent attention | `alert:security-vulnerability` |
| `broadcast:` | All agents | `broadcast:system-maintenance` |
| `learn:` | Knowledge to persist | `learn:new-pattern-discovered` |
| `request:` | Information query | `request:current-deployment-status` |
| `reply:` | Response to message | `reply:msg-12345` |

### 6.3 Bus Security

- HMAC-SHA256 signatures when `MANUSAT_BUS_SECRET` is set
- Signature covers: from, to, subject, timestamp, body
- Verified by receiver before processing

---

## 7. Standard Workflows

### 7.1 Feature Development Flow

```
human → vaja (intake) → jit (master) → soma (strategy) 
→ lak (design/ADR) → innova (implement) → chamu (test) 
→ neta (review) → pada (deploy) → vaja (report) → human
```

### 7.2 Bug Fix Flow

```
chamu (detect via tests) → jit (triage) → innova (fix) 
→ neta (review) → pada (hotfix deploy) → vaja (notify human)
```

### 7.3 System Health Flow

```
pran (heartbeat) ← all agents report vitals
  ↓
jit (synthesize health status)
  ↓
sayanprasathan (broadcast alerts if degraded)
  ↓
mue (execute remediation if needed)
```

### 7.4 Design Request Flow

```
human → vaja → rupa (design/mockups) → soma (approve) 
→ innova (implement) → chamu (test) → neta (review)
```

---

## 8. Autonomous Patterns

### 8.1 Selfhood Maintenance

Every agent maintains a minimal life signal:
- `heartbeat` timestamp in registry.json
- `last_seen` in shared state
- Pulse responses to `heart.sh beat` calls

### 8.2 Sub-Agent Spawning

For specialized tasks, agents can spawn child tasks:
```bash
# innova spawns a focused sub-task
bash organs/mouth.sh tell moue "task:scaffold-feature" "Create feature X with tests"
```

### 8.3 Skill Contracts

Skills in `~/.claude/skills/` define reusable capabilities:
- `/trace` — Discovery and exploration
- `/learn` — Study codebases
- `/forward` — Save context for next session
- `/rrr` — Retrospective generation

### 8.4 Common Autonomous Patterns

| Pattern | Initiator | Executor | Outcome |
|---------|-----------|----------|---------|
| `task:detect-*` | innova/chamu | netra/karn | Observation report |
| `task:install-*` | innova | mue/pada | Tool installed + verified |
| `task:report-life` | jit | vajra | Status summary to human |
| `task:learn` | any | innova | Oracle knowledge persisted |
| `task:fix-*` | chamu/neta | mue | Code change applied |

---

## 9. Recommended Lifecycle

```
Sense → Decide → Delegate → Execute → Observe → Learn
```

| Phase | Agents Involved | Description |
|-------|-----------------|-------------|
| **Sense** | netra, karn, chamu | Collect context, observe state |
| **Decide** | jit, soma | Choose strategy and flow |
| **Delegate** | jit, innova | Route messages to specialists |
| **Execute** | mue, pada, lak | Actions in organs/* scripts |
| **Observe** | netra, chamu, neta | Results returned in report:/alert: |
| **Learn** | innova | Save patterns to Oracle + docs |

---

## 10. Adding a New Agent

The system has all 15 organs assigned. To add a new agent (sub-specialist):

1. Create `agents/<name>.json` with capabilities and constraints
2. Create `.github/agents/<name>.agent.md` for Claude Code integration
3. Register in `network/registry.json`:
   - Add to `agents[]` array with health tracking fields
   - Update `team_structure` tier assignment
   - Add organ mapping if new organ type
4. Initialize inbox: `mkdir -p /tmp/manusat-bus/<name>`
5. Test communication: `bash eval/soul-check.sh`
6. Announce: `bash organs/nerve.sh signal agent_registered <name>`

---

## 11. Design Principles

Aligned with Buddhist principles:

| Principle | Thai | Application |
|-----------|------|-------------|
| **ศีล (Sīla)** | Integrity | No secrets in output, confirm before destructive actions |
| **สมาธิ (Samādhi)** | Focus | One message = one intent, stay in role |
| **ปัญญา (Paññā)** | Wisdom | Query Oracle before decisions, maximize token efficiency |

### 11.1 Golden Rules

1. **Oracle-first**: Query Oracle before major decisions
2. **Bus-only**: No direct function calls between agents
3. **Nothing is Deleted**: Preserve history, add don't remove
4. **Confirm before destroy**: All destructive actions need confirmation
5. **Log everything**: All actions logged for reflection
6. **Transparency**: Never pretend to be human; sign AI-generated content

---

## 12. Health Tracking

Registry v2.1 includes runtime health metrics per agent:

```json
{
  "health_status": "ok|degraded|offline",
  "last_heartbeat": "2026-06-07T10:30:00+07:00",
  "response_time_ms": 235,
  "message_queue_depth": 12
}
```

- **Offline threshold**: 300 seconds (5 min) without heartbeat
- **netra eye-check**: Flags agents offline > threshold
- **Heart pulse**: Updates `health_status` after each beat
- **Bus sampling**: Tracks `response_time_ms` for send→recv pairs

---

## 13. External Dependencies

| Dependency | URL | Purpose | Auth |
|------------|-----|---------|------|
| **Arra Oracle V3** | `http://localhost:47778` | Shared knowledge base (FTS5 + LanceDB) | Local |
| **MDES Ollama** | `https://ollama.mdes-innova.online` | Thai language processing (gemma4:26b) | Token in `.github/agents/innova.agent.md` |

---

## 14. Reference Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project overview, commands, quick reference |
| `core/body-map.md` | Complete RACI matrix, organ ownership |
| `core/identity.md` | innova's mission, values, relationships |
| `network/protocol.md` | Message format, error handling, security |
| `network/registry.json` | Source of truth: all 15 agents with health tracking |
| `brain/reasoning.md` | Think-before-act framework, token rules |
| `memory/architecture.md` | Three-layer memory system design |

---

*Last updated: 2026-06-08*  
*Version: 2.1 — Complete 15-agent organ system with Tier 0-3 hierarchy (lung/ปอด added)*
