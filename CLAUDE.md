# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Jit (จิต)** is the Mind/Soul orchestrator of the **มนุษย์ Agent** multi-agent AI system built by MDES-Innova. This repo houses innova, the core executor agent (claude-sonnet-4.6), along with agent definitions, shared protocols, and bootstrap tooling for the full 8-agent body metaphor system.

## Agent Tier Structure

```
Tier 1: soma (สมอง)      — Brain/Director        [claude-opus-4.7]
Tier 2: innova (จิต)     — Mind/Orchestrator     [claude-sonnet-4.6]  ← THIS REPO
         lak (กระดูก)    — Solution Architect    [claude-sonnet-4.6]
         neta (เนตร)     — Code Reviewer         [claude-sonnet-4.6]
Tier 3: vaja (วาจา)      — Personal Assistant    [claude-haiku-4.5]
         chamu (จมูก)    — QA/Tester             [claude-haiku-4.5]
         rupa (รูป)       — Designer/UI-UX        [claude-haiku-4.5]
         pada (บาท)       — DevOps/Infrastructure [claude-haiku-4.5]
```

Agent definitions: `/.github/agents/*.agent.md` (Claude Code) and `/agents/*.json` (capability cards)  
Agent registry: `/network/registry.json` — master source of truth for all 8 agents

## Common Commands

**Bootstrap the system (first-time or new agent):**
```bash
bash /workspaces/Jit/scripts/bootstrap.sh [agent-name]
# Installs Bun, clones arra-oracle-v3, initializes DB, starts Oracle
```

**Health checks:**
```bash
bash /workspaces/Jit/eval/soul-check.sh   # agent readiness
bash /workspaces/Jit/eval/body-check.sh   # full system health
curl http://localhost:47778/api/health      # Oracle status
```

**Start the Oracle knowledge base (must run before agents use it):**
```bash
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts
```

**Oracle queries via limb:**
```bash
bash /workspaces/Jit/limbs/oracle.sh search "keyword" [limit]
bash /workspaces/Jit/limbs/oracle.sh learn "pattern" "content" "concepts"
```

**Inter-agent messaging:**
```bash
bash /workspaces/Jit/organs/mouth.sh tell <agent-name> "message"
bash /workspaces/Jit/organs/mouth.sh broadcast "message"
```

**MDES Ollama (Thai language, gemma4:26b):**
```bash
bash /workspaces/Jit/limbs/ollama.sh think "prompt"
```

## Architecture

### Layered System (bottom → top)
1. **Organs** (`/organs/`) — Sensory/motor I/O: eye (read), ear (listen), mouth (send), nose (detect), hand (write files), leg (navigate/deploy), heart (orchestrate), nerve (events)
2. **Limbs** (`/limbs/`) — Core cognition: `think.sh`, `act.sh`, `speak.sh`, `oracle.sh`, `ollama.sh`, `lib.sh`
3. **Mind** (`/mind/`) — Psychological layer: ego, emotion state, reflexes
4. **Memory** (`/memory/`) — Three layers: context window (short-term) → `/tmp/manusat-shared.json` (shared state) → Oracle DB (permanent)

### Communication Protocol
- **Bus**: File-based, POSIX-compatible, inboxes at `/tmp/manusat-bus/<agent-name>/`
- **Flow**: `mouth.sh` writes → `bus.sh` routes → `ear.sh` reads → `heart.sh` dispatches to organ
- **Subject prefixes**: `task:`, `think:`, `report:`, `alert:`, `broadcast:`, `learn:`, `request:`, `reply:`

### Standard Feature Flow
```
human → vaja → soma → lak → innova → chamu → neta → pada → vaja → human
```

### Standard Bug Flow
```
chamu (detect) → innova (fix) → neta (review) → pada (hotfix) → vaja (notify)
```

## Key Reference Files

| File | Purpose |
|------|---------|
| `/core/body-map.md` | Team RACI matrix, organ ownership, all flows |
| `/core/identity.md` | innova's mission, values, relationships |
| `/network/protocol.md` | Message format, subject conventions, error handling |
| `/docs/multiagent-spec.md` | Full system specification v1.0 |
| `/docs/new-agent-guide.md` | Bootstrap guide for adding new agents |
| `/brain/reasoning.md` | Think-before-act framework, token efficiency rules |
| `/memory/architecture.md` | Three-layer memory system design |

## External Dependencies

- **Arra Oracle V3** — Shared knowledge base (FTS5 + LanceDB vector search), repo: `Soul-Brews-Studio/arra-oracle-v3`, runs on Bun at `http://localhost:47778`
- **MDES Ollama** — `https://ollama.mdes-innova.online`, model: `gemma4:26b`, auth token in `.github/agents/innova.agent.md`

## Design Principles

The system is aligned to **Buddhist principles** — ศีล (integrity: no secrets in output, confirm before destructive actions) · สมาธิ (focus: one message = one intent, stay in role) · ปัญญา (wisdom: query Oracle before decisions, maximize token efficiency).

**Oracle-first**: Query Oracle before major decisions to avoid duplicating stored knowledge.  
**Bus-only**: No direct function calls between agents; always communicate via mouth→bus→ear.  
**Reversible actions**: Design rollback paths; signal before destructive operations.

## Adding a New Agent

Follow `/docs/new-agent-guide.md`. At minimum: create `agents/<name>.json`, `.github/agents/<name>.agent.md`, register in `/network/registry.json`, and add inbox initialization in `scripts/bootstrap.sh`.
