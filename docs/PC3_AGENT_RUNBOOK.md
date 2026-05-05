# PC3 Jit Agent Runbook

Node: **PC3-Jit** | Host: codespaces-a07d24 | Bootstrapped: 2026-05-05

## Overview

This node runs the Jit (จิต) Master Orchestrator shell-based agent system.
There is no web backend on port 7010 unless `innova-bot` is separately cloned and configured.
The system is shell-driven: heartbeat commits, Oracle RAG, MDES Ollama API, message bus.

## Quick Start

```bash
# One-click start (Oracle + init-life + heartbeat daemon)
bash scripts/pc3_start_all.sh

# Status check
bash scripts/pc3_start_all.sh --status
```

## Component Status (as of 2026-05-05)

| Component | Status | Notes |
|---|---|---|
| Python 3.12.1 | OK | `/home/codespace/.python/current/bin/python3` |
| Shell scripts | OK | heartbeat, init-life, life-checklist, awaken, soul-check |
| Heartbeat | Requires start | `bash scripts/heartbeat.sh start` |
| Arra Oracle V3 | Offline | `arra-oracle-v3` not in workspace |
| MDES Ollama | External | `https://ollama.mdes-innova.online` (token in .env) |
| innova-bot MCP | Not cloned | Run `scripts/innova-bot-setup.sh <url>` |
| Port 7010 | Not bound | Requires innova-bot |
| Message bus | `/tmp/manusat-bus/` | Recreated each session |

## Key Scripts

| Script | Purpose |
|---|---|
| `scripts/init-life.sh` | Full bootstrap (pull, Oracle, awaken, cron, heartbeat) |
| `scripts/heartbeat.sh start` | Start adaptive heartbeat daemon |
| `scripts/life-checklist.sh` | Show life checklist status |
| `scripts/pc3_start_all.sh` | One-click PC3 node start |
| `eval/soul-check.sh` | Agent soul verification |
| `eval/body-check.sh` | Full system health check |
| `scripts/sync-cross-machine.sh pull` | Pull latest memory from GitHub |
| `scripts/sync-cross-machine.sh push` | Push state to GitHub |

## Environment Variables (.env)

| Variable | Value | Purpose |
|---|---|---|
| `INNOVA_NODE_ID` | `PC3-Jit` | Node identity |
| `MCP_TRANSPORT` | `sse` | MCP server transport |
| `MCP_HOST` | `127.0.0.1` | MCP bind host |
| `MCP_PORT` | `7010` | MCP server port |
| `ORACLE_PORT` | `47778` | Oracle server port |
| `OLLAMA_BASE_URL` | remote URL | MDES Ollama endpoint |
| `OLLAMA_TOKEN` | [secret] | Auth token (in .env, not committed) |

## Oracle Setup (when needed)

```bash
# Install bun
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"

# Clone Oracle
git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3 /workspaces/arra-oracle-v3
cd /workspaces/arra-oracle-v3
bun install

# Start Oracle
ORACLE_PORT=47778 bun run src/server.ts &

# Verify
curl http://localhost:47778/api/health
```

## MCP / Antigravity Setup

See `docs/MCP_PYVENV_TROUBLESHOOTING.md` for fixing pyvenv.cfg errors.

To activate MCP server (innova-bot):
```bash
bash scripts/innova-bot-setup.sh <your-innova-bot-git-url>
```

## Cross-Machine Memory Sync

State files are git-tracked and sync across all nodes:
- `memory/state/innova.state.json` — persistent agent state
- `memory/state/heartbeat.log` — pulse history

```bash
bash scripts/sync-cross-machine.sh pull   # receive latest
bash scripts/sync-cross-machine.sh push   # send this node's state
bash scripts/sync-cross-machine.sh sync   # both
```

## Monitoring

```bash
# Daemon status
bash scripts/heartbeat.sh status

# Cron status
crontab -l | grep innova

# Recent heartbeats
tail -20 memory/state/heartbeat.log

# Oracle health
curl http://localhost:47778/api/health

# Ollama
curl https://ollama.mdes-innova.online/api/tags -H "Authorization: Bearer $OLLAMA_TOKEN"
```

## Tests

```bash
python3 -m pytest tests/ -v
```

## .GCC Checkpoints

Stable state is logged in `.GCC/branches/main/log.md`.
Update this file after significant system changes.
