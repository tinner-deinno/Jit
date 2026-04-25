# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Jit (จิต)** is the **Master Orchestrator** of the **มนุษย์ Agent** multi-agent AI system built by MDES-Innova. This repo houses the complete 14-agent ecosystem with a parent-child hierarchy, full organ system assignment, shared protocols, and bootstrap tooling. Jit coordinates all agents through a file-based message bus and Oracle knowledge base.

**Current Status**: Complete organ system (v2.0) — all 14 organs assigned to dedicated agents, fully operational.

## Agent Tier Structure

```
Tier 0 (Master):
  jit (จิต)             — Soul/Master Orchestrator    [claude-sonnet-4.6]

Tier 1 (Leadership):
  soma (สมอง)          — Brain/Strategic Lead         [claude-opus-4.7]

Tier 2 (Core Engineering):
  innova (จิต)         — Mind/Lead Developer          [claude-sonnet-4.6]
  lak (กระดูก)        — Solution Architect           [claude-sonnet-4.6]
  neta (เนตร)          — Code Reviewer                [claude-sonnet-4.6]

Tier 3 (Specialist Organs - 9 agents):
  vaja (วาจา)          — Personal Assistant           [claude-haiku-4.5]
  chamu (จมูก)         — QA/Tester                    [claude-haiku-4.5]
  rupa (รูป)           — Designer/UI-UX               [claude-haiku-4.5]
  pada (บาท)           — DevOps/Infrastructure        [claude-haiku-4.5]
  netra (เนตร)         — Eye/Observer                 [claude-haiku-4.5]
  karn (หู)            — Ear/Listener                 [claude-haiku-4.5]
  mue (มือ)            — Hand/Executor                [claude-haiku-4.5]
  pran (หัวใจ)         — Heart/Vital Coordinator     [claude-haiku-4.5]
  sayanprasathan       — Nerve/Event Network          [claude-haiku-4.5]
```

**Agent files**: `/.github/agents/*.agent.md` (Claude Code definitions) and `/agents/*.json` (capability cards)  
**Agent registry**: `/network/registry.json` — master source of truth for all 14 agents with complete hierarchy and organ assignments

## Common Commands

### System Initialization & Health

**Bootstrap the system (first-time setup):**
```bash
bash scripts/bootstrap.sh
# Installs Bun, clones Arra Oracle V3, initializes DB, starts Oracle, runs health checks
```

**Check agent readiness (individual agent status):**
```bash
bash eval/soul-check.sh
# Verifies all agents can communicate via message bus
```

**Check full system health (comprehensive):**
```bash
bash eval/body-check.sh
# Checks all agents, message bus, Oracle, shared state, organ assignments
```

**Start Oracle knowledge base (required for system):**
```bash
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts
# Or: bash scripts/bootstrap.sh (does this automatically)
```

**Verify Oracle is running:**
```bash
curl http://localhost:47778/api/health
# Returns: {"status": "ok", "version": "3.0", ...}
```

### Inter-Agent Communication

**Send message to specific agent:**
```bash
bash organs/mouth.sh tell innova "Implement feature X"
bash organs/mouth.sh tell netra "Check system status"
```

**Broadcast to all agents:**
```bash
bash network/bus.sh broadcast "alert:critical" "System emergency alert"
```

**Check agent's inbox:**
```bash
bash organs/ear.sh inbox jit
bash organs/ear.sh inbox innova
```

**View entire message queue:**
```bash
bash network/bus.sh queue    # Show all pending messages
bash network/bus.sh stats    # Show bus statistics
```

### Oracle Knowledge Base

**Search existing knowledge:**
```bash
bash limbs/oracle.sh search "feature-flags" 10
bash limbs/oracle.sh search "multiagent" 5
```

**Learn/persist new knowledge:**
```bash
bash limbs/oracle.sh learn "system-patterns" "Jit coordinates through soma→lak→innova→specialists" "architecture,pattern,multiagent"
```

### Thai Language Processing (MDES Ollama)

**Use Ollama for Thai language tasks:**
```bash
bash limbs/ollama.sh think "จิตของมนุษย์คืออะไร"  # Thai prompt
bash limbs/ollama.sh think "What is the human spirit?"  # English also works
```
Uses `gemma4:26b` model via `https://ollama.mdes-innova.online` (token in `.github/agents/innova.agent.md`)

## Architecture

### Complete Organ System (All 14 Organs Assigned)
Every organ has a dedicated agent owner:
- **Cognitive**: สมอง→soma (brain), จิต→jit (master orchestrator)
- **Sensory**: ตา→netra (eye), หู→karn (ear), จมูก→chamu (nose)
- **Expression**: ปาก→vaja (mouth)
- **Action**: มือ→mue (hand), ขา→pada (leg)
- **Vital**: หัวใจ→pran (heart), ระบบประสาท→sayanprasathan (nerve)
- **Structural**: กระดูกสันหลัง→lak (spine/architecture)
- **Knowledge**: ปัญญา→innova (oracle/wisdom)
- **Design**: รูปลักษณ์→rupa (form/design)
- **Quality**: เนตร→neta (code review)

See `/core/body-map.md` for complete RACI matrix and organ ownership.

### Layered System (bottom → top)
1. **Organs** (`/organs/`) — Sensory/motor I/O: eye, ear, mouth, nose, hand, leg, heart, nerve
2. **Limbs** (`/limbs/`) — Core cognition: think.sh, act.sh, speak.sh, oracle.sh, ollama.sh, lib.sh
3. **Mind** (`/mind/`) — Psychological layer: ego, emotion state, reflexes (innova-specific)
4. **Memory** (`/memory/`) — Three layers: context window (short-term) → `/tmp/manusat-shared.json` (shared) → Oracle DB (permanent)

### Communication Protocol
- **Bus**: File-based, POSIX-compatible, 14 agent inboxes at `/tmp/manusat-bus/<agent-name>/`
- **Flow**: `mouth.sh` writes → `bus.sh` routes → `ear.sh` reads → `heart.sh` dispatches to organ
- **Subject prefixes**: `task:`, `think:`, `report:`, `alert:`, `broadcast:`, `learn:`, `request:`, `reply:`

### Standard Feature Flow
```
human → vaja → jit (master) → soma (brain) → lak (design) → innova (code) 
→ chamu (test) → neta (review) → pada (deploy) → vaja (report) → human
```

### Standard Bug Flow
```
chamu (detect) → jit (master) → innova (fix) → neta (review) → pada (hotfix) → vaja (notify)
```

### System Health/Monitoring Flow
```
pran (heart) ← all agents ← jit (synthesize) → sayanprasathan (broadcast alerts)
netra (eye) + karn (ear) → jit (decision) → mue (execute)
```

## Parent-Child Agent Relationships

**Master Orchestrator (Tier 0)**:
- jit manages all 13 agents below
- Reports to: human
- Delegates to: soma (strategic), innova (operational), and all Tier 3 specialists

**Strategic Chain**:
- jit → soma (for strategic decisions) → lak (architecture)
- soma also manages: neta (review), pada (deploy), innova (execution)

**Operational Chain**:
- jit → innova (lead developer) → vaja (reporting) + chamu (testing)

**Specialist Organs** (all report to innova or jit):
- netra (observation), karn (listening), mue (execution), pran (vital signs), sayanprasathan (signal network)

## Key Reference Files

| File | Purpose |
|------|---------|
| `/core/body-map.md` | Complete team RACI matrix, organ ownership, all workflows |
| `/core/identity.md` | innova's mission, values, relationships |
| `/network/protocol.md` | Message format, subject conventions, error handling |
| `/network/registry.json` | Source of truth: all 14 agents, tiers, organs, capabilities |
| `/docs/multiagent-spec.md` | Full system specification v2.0 with 14-agent hierarchy |
| `/docs/new-agent-guide.md` | Bootstrap guide for adding agents to the system |
| `/brain/reasoning.md` | Think-before-act framework, token efficiency rules |
| `/memory/architecture.md` | Three-layer memory system design (context/shared/persistent) |

## External Dependencies

- **Arra Oracle V3** — Shared knowledge base (FTS5 + LanceDB vector search), repo: `Soul-Brews-Studio/arra-oracle-v3`, runs on Bun at `http://localhost:47778`
- **MDES Ollama** — `https://ollama.mdes-innova.online`, model: `gemma4:26b`, auth token in `.github/agents/innova.agent.md`

## Design Principles

The system is aligned to **Buddhist principles** — ศีล (integrity: no secrets in output, confirm before destructive actions) · สมาธิ (focus: one message = one intent, stay in role) · ปัญญา (wisdom: query Oracle before decisions, maximize token efficiency).

**Oracle-first**: Query Oracle before major decisions to avoid duplicating stored knowledge.  
**Bus-only**: No direct function calls between agents; always communicate via mouth→bus→ear.  
**Reversible actions**: Design rollback paths; signal before destructive operations.

## Working with the System

### Interacting with Individual Agents
```bash
# Send message to any agent
bash organs/mouth.sh tell <agent-name> "<message>"

# Check an agent's inbox
bash organs/ear.sh inbox <agent-name>

# View all pending messages
bash network/bus.sh queue

# Send system-wide broadcast
bash network/bus.sh broadcast "<subject>" "<body>"
```

### Querying the Oracle Knowledge Base
```bash
# Search existing knowledge
bash limbs/oracle.sh search "topic" [limit]

# Learn new knowledge
bash limbs/oracle.sh learn "pattern" "content" "concept1,concept2,..."
```

### Using Thai Language Processing (MDES Ollama)
```bash
# Think in Thai/Thai language processing
bash limbs/ollama.sh think "your prompt in Thai or English"
```

## Adding a New Agent

The system is complete with all 14 organs assigned. To add an agent:
1. Follow `/docs/new-agent-guide.md` for detailed walkthrough
2. Create `agents/<name>.json` with capabilities
3. Create `.github/agents/<name>.agent.md` for Claude Code integration
4. Register in `/network/registry.json` (update agents[], team_structure, organs)
5. Initialize inbox: `mkdir -p /tmp/manusat-bus/<name>`
6. Test with: `bash eval/soul-check.sh`
