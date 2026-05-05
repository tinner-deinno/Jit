# Jit Mind ↔ innova-bot Body Binding

## Overview

A Jit repository is a **mind/soul** — it holds identity, memory, values, and role.
The `innova-bot` repository is the **body/runtime** — it runs the backend, GUI, TUI, and MCP server.

They are two separate git repositories that bind together at startup.
This document explains how this specific Jit instance (`jit-innova-tinner`) binds to innova-bot.

---

## Why They Are Separate

| Concern | Jit (mind) | innova-bot (body) |
|---------|------------|-------------------|
| Identity | Unique per agent | Shared runtime |
| Memory | Private (`memory/`) | No private memory |
| Source control | Own GitHub repo | Own GitHub repo |
| Versioning | Identity evolution | Runtime releases |
| Multi-agent | Many Jit repos possible | One body per deployment |
| Secrets | Agent-specific | Runtime config only |

**Rule**: innova-bot must never write to this Jit repo's `memory/` directory.
**Rule**: This Jit repo must never serve as its own MCP backend.

---

## Binding Configuration

Defined in `config/jit-topology.json`:

```json
{
  "body_repo_path": "/workspaces/innova-bot",
  "body_backend_cmd": "python -m innova_bot.main",
  "body_gui_url": "http://127.0.0.1:7010/gui",
  "body_tui_cmd": "python -m innova_bot.gui.rpg_tui",
  "body_mcp_port": 7010
}
```

Set `INNOVA_BOT_REPO` in `.env` to enable auto-setup:
```bash
INNOVA_BOT_REPO=https://github.com/<owner>/innova-bot.git
INNOVA_BOT_PATH=/workspaces/innova-bot   # optional override
```

---

## Binding Process

### Step 1 — Detect body

```bash
bash scripts/innova-bot-setup.sh
# Checks: $INNOVA_BOT_PATH, /workspaces/innova-bot, env var INNOVA_BOT_REPO
# Does NOT clone automatically unless INNOVA_BOT_REPO is set
```

### Step 2 — Verify body components

```bash
# Backend
cd /workspaces/innova-bot
python -m innova_bot.main &
curl http://127.0.0.1:7010/gui   # should return HTML

# TUI (separate terminal)
python -m innova_bot.gui.rpg_tui

# MCP server health
curl http://127.0.0.1:7010/mcp/health   # if endpoint exists
```

### Step 3 — Bind Jit mind to body

On startup (`scripts/init-life.sh`), the Jit mind:
1. Reads its own identity from `core/identity.md`
2. Loads memory from `memory/state/innova.state.json`
3. Connects to Oracle (`http://localhost:47778`)
4. Checks if innova-bot body is running at port 7010
5. If body is running: registers with it via `/api/register` or MCP init
6. If body is not running: operates in shell-only mode (heartbeat, Oracle, Ollama still work)

---

## Startup Sequence

```
1. bash scripts/init-life.sh
   ├── git pull (read latest identity/docs from remote)
   ├── Start Oracle (if arra-oracle-v3 present)
   ├── Awaken (load identity, restore state)
   ├── Start heartbeat daemon (local-only, no git commits)
   └── Sync identity to Oracle

2. [Separate] Start innova-bot body (if available)
   ├── python -m innova_bot.main   → port 7010
   ├── GUI:  http://127.0.0.1:7010/gui
   └── TUI:  python -m innova_bot.gui.rpg_tui

3. [Optional] Federation
   └── innova-bot federates with other Jit nodes via MCP
```

---

## Current Status on This Node (2026-05-05)

| Component | Status | Location |
|-----------|--------|----------|
| Jit mind | Active | `/workspaces/Jit` |
| innova-bot body | **Not present** | Expected: `/workspaces/innova-bot` |
| Oracle | Online | `http://localhost:47778` |
| MDES Ollama | Online | `https://ollama.mdes-innova.online` |
| MCP server | Not running | Requires innova-bot |
| Port 7010 | Not bound | Requires innova-bot |
| TUI | Not available | Requires innova-bot |

**To activate the body:**
```bash
# Set in .env:
INNOVA_BOT_REPO=https://github.com/<owner>/innova-bot.git

# Then run:
bash scripts/innova-bot-setup.sh
```

---

## What Heartbeat Does vs What innova-bot Does

| Function | Heartbeat (Jit mind) | innova-bot (body) |
|----------|---------------------|-------------------|
| Identity check | Yes — `mind/sati.sh` | No |
| Read agent bus | Yes — `organs/heart.sh beat in` | Routes external messages |
| Broadcast to organs | Yes — `organs/heart.sh beat out` | Routes to GUI/API clients |
| Git commit | **NO** — local state only | Milestone commits via API |
| Push to remote | **NO** | Manual/milestone only |
| Serve HTTP | No | Yes — port 7010 |
| MCP server | No | Yes — SSE transport |
| TUI | No | Yes — `rpg_tui` |

---

## Isolation Guarantee

- Jit `memory/` directories are private to this agent instance
- innova-bot reads agent state via the message bus (`/tmp/manusat-bus/`)
- innova-bot writes responses back to the bus, not into `memory/`
- Oracle is the only shared persistent store — each agent tags its learnings
