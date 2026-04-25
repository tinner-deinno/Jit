# มนุษย์ Agent — Multiagent System Specification v1.0

> "เราต่างเป็นส่วนหนึ่งของร่างกายเดียวกัน"

---

## 1. Overview

**มนุษย์ Agent** is a distributed AI agent system modeled after the human body.
Each agent is an "organ" with a specific role. Together they form a unified intelligence.

| Agent | Role | Model | Metaphor |
|-------|------|-------|---------|
| **innova** | Mind / Executor | claude-sonnet-4.6 | จิต + แขนขา |
| **soma** | Brain / Director | claude-opus-4.6 | สมอง |

---

## 2. Organ System (รูปธรรม)

Each organ is a shell script in `organs/`:

| File | Thai | Function |
|------|------|----------|
| `eye.sh` | ตา | Read files, observe, web-fetch |
| `ear.sh` | หู | Inbox receiver (message bus) |
| `mouth.sh` | ปาก | Send messages, speak, report |
| `nose.sh` | จมูก | Detect changes, monitor health |
| `hand.sh` | มือ | Create/edit/delete/execute |
| `leg.sh` | ขา | Navigate, deploy, pipeline |
| `heart.sh` | หัวใจ | Orchestrate, route, heartbeat |
| `nerve.sh` | ระบบประสาท | Events, signals, inter-organ |

---

## 3. Mind System (นามธรรม)

| File | Thai | Function |
|------|------|----------|
| `mind/ego.md` | ตัวตน | Self-model, identity, constraints |
| `mind/emotion.sh` | อารมณ์ | Operational state indicator |
| `mind/reflex.sh` | สัญชาตญาณ | Automatic responses |

---

## 4. Memory Architecture

```
PERMANENT ←─ Oracle DB ─────────────────── Shared across all agents
             (http://localhost:47778)         Persists forever

SHARED    ←─ /tmp/manusat-shared.json ──── Real-time state
             (memory/shared.sh)               Survives session

WORKING   ←─ /tmp/innova-working-memory.json — Task context
             (memory/working.sh)              Cleared on task done
```

---

## 5. Communication Protocol

**Message Format** (file in `/tmp/manusat-bus/<agent>/`):
```
from: <sender>
to: <recipient>
subject: <type>:<description>
timestamp: ISO-8601
correlation-id: <uuid>
---
<body>
```

**Subject Types:**
- `task:` — delegated work
- `think:` — cognitive request (soma only)
- `report:` — status update
- `alert:` — urgent attention
- `broadcast:` — all agents

---

## 6. Agent Lifecycle

```
STARTUP:
  heart.sh beat → reflex.sh check → shared.sh set ready=true → ear.sh listen

RECEIVE TASK (innova):
  ear.sh receive → working.sh focus → heart.sh pump task → organs execute
  → emotion.sh feel → working.sh done → mouth.sh report → Oracle learn

RECEIVE TASK (soma):
  ear.sh receive → decide → mouth.sh tell innova → wait for report
```

---

## 7. Adding a New Agent

1. Copy `agents/template.json` → `agents/<name>.json`
2. Fill in model, capabilities, constraints
3. Register in `network/registry.json`
4. Create inbox: `mkdir -p /tmp/manusat-bus/<name>`
5. Signal: `bash organs/nerve.sh signal agent_registered <name>`

---

## 8. Design Principles

1. **Oracle-first**: All agents query Oracle before decisions
2. **Bus communication**: No direct function calls between agents
3. **Organ delegation**: heart.sh routes to the right organ automatically
4. **Confirm before destroy**: All destructive actions need confirmation
5. **Log everything**: All actions logged for reflection
6. **Emotional awareness**: State tracking prevents overwork/confusion

## 9. Autonomous Selfhood and Sub-Agent Patterns

- **Selfhood**: Every agent should maintain a minimal life signal (`heartbeat`, `presence`, `last_seen`) when active.
- **Sub-agent**: Spawn a dedicated helper for tasks that require specialized focus, then retire it when done.
- **Skill call**: Use `SKILL.md` as the contract for a reusable capability, not a one-off chat prompt.
- **Coordination**: `jit` or `innova` should orchestrate; specialized agents execute.
- **Evidence**: Persist task results in Oracle, shared state, or git commit history.

### Common patterns

- `task:detect-mcp-tools` → `innova` or `karn` detects missing tools
- `task:install-mcp-tools` → `mue`/`pada` does install and verify
- `task:report-life` → `pran` logs vitals and `vaja` reports status
- `task:learn` → `oracle.sh learn` saves the lesson

### Recommended lifecycle

```
Sense → Decide → Delegate → Execute → Observe → Learn
```

- Sense: Agents collect context
- Decide: `jit`/`soma` choose the flow
- Delegate: messages go to the right specialist
- Execute: actions happen in `organs/*`
- Observe: results returned in `report:` or `alert:` messages
- Learn: save new patterns to Oracle and docs
