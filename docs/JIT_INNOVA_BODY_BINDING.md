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
   "body_repo_candidates": [
      "/workspaces/innova-bot",
      "/mnt/c/Users/USER-NT/DEV/innova-bot-template",
      "C:\\Users\\USER-NT\\DEV\\innova-bot-template"
   ],
  "body_backend_cmd": "python -m innova_bot.main",
  "body_gui_url": "http://127.0.0.1:7010/gui",
  "body_tui_cmd": "python -m innova_bot.gui.rpg_tui",
   "body_mcp_port": 7010,
   "body_bridge_dir": ".jit-bridge/inbox"
}
```

Set `INNOVA_BOT_REPO` in `.env` to enable auto-setup:
```bash
INNOVA_BOT_REPO=https://github.com/<owner>/innova-bot.git
INNOVA_BOT_PATH=/workspaces/innova-bot   # optional override
# or Windows/WSL: C:\Users\USER-NT\DEV\innova-bot-template
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

## Hermes Discord Control Plane

Hermes สามารถเป็น front-end ของ Jit บน Discord ได้โดยตรง:

- `!อนุ` = chat mode ไปที่ MDES Ollama ตามเดิม
- `!jit` = control mode สำหรับ Jit / bus / innova-bot body
- รองรับ mention mode เช่น `@bot jit status`

คำสั่งหลัก:

- `!jit status` — ดูสถานะรวมของ Jit, Oracle, Ollama, body, bus
- `!jit body` — ดู path binding และ bridge ไปยัง innova-bot
- `!jit queue innova` — ดู inbox ของ agent บน bus
- `!jit dev <task>` — ส่ง dev task เข้า `jit,soma,innova` และ mirror ไป body bridge
- `!jit tell <agent> <subject> <body>` — ส่ง message ตรงเข้า bus
- `!jit report` — ส่ง startup/status report ไป channel ที่กำหนด

Env เพิ่มเติม:

```bash
JIT_COMMAND_PREFIX=!jit
JIT_REPORT_CHANNEL_ID=<discord-channel-id>
JIT_DISCORD_DEV_RECIPIENTS=jit,soma,innova
INNOVA_BOT_BRIDGE_DIR=/workspaces/innova-bot/.jit-bridge/inbox
INNOVA_BOT_BRIDGE_URL=http://127.0.0.1:7010/api/jit/discord
INNOVA_BOT_HEALTH_URL=http://127.0.0.1:7010/mcp/health
JIT_BODY_BRIDGE_HEALTH_URL=http://127.0.0.1:7011/health
JIT_BODY_EXECUTOR_COMMAND="bash /workspaces/Jit/scripts/discord-dev-executor.sh"
JIT_BODY_EXECUTOR_FORWARD="bash /mnt/c/Users/USER-NT/DEV/innova-bot-template/scripts/dev-dispatch.sh"
JIT_THOUGHT_LOOP_ENABLED=true
JIT_THOUGHT_LOOP_CHANNELS=<discord-channel-id>
JIT_THOUGHT_LOOP_INTERVAL_MS=300000
```

หมายเหตุ:

- ถ้า `INNOVA_BOT_PATH` เป็น Windows path บน Linux/WSL ระบบจะ normalize เป็น `/mnt/<drive>/...`
- ถ้าไม่ทราบ API ของ body ล่วงหน้า ให้ใช้ file bridge (`.jit-bridge/inbox`) ได้ก่อน
- startup report จะถูกส่งอัตโนมัติเมื่อกำหนด `JIT_REPORT_CHANNEL_ID`
- body side สามารถรัน `bash scripts/start-innova-body-bridge.sh --daemon` เพื่ออ่าน `.jit-bridge/inbox` และเปิด webhook ที่ `127.0.0.1:7011/api/jit/discord`
- executor ฝั่งเครื่องปลายทางเริ่มจาก `bash scripts/discord-dev-executor.sh <payload.json>` และจะ forward ต่อถ้าตั้ง `JIT_BODY_EXECUTOR_FORWARD`
- Hermes thought loop ใช้ transcript ล่าสุดใน channel เพื่อสร้างข้อความใหม่ทุก 5 นาที และตอบ `[[NO_REPLY]]` เองเมื่อยังไม่ควรพูด

คำสั่ง loop เพิ่มเติม:

- `!jit loop on` — เปิด grounded thought loop ใน channel ปัจจุบัน
- `!jit loop off` — ปิด loop ใน channel ปัจจุบัน
- `!jit loop status` — ดูสถานะ loop ของ channel ปัจจุบัน
- `!jit loop now` — บังคับให้วิเคราะห์ข้อความล่าสุดและลองโพสต์ทันทีหนึ่งครั้ง

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
