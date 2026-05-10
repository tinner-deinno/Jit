# JIT-LIFE Skill — ชีวิตอัตโนมัติของ Jit (จิต)

## Description
`jit-life` คือระบบชีวิตครบวงจรสำหรับ innova (จิต) — รวม **ollama-claude**, **Discord**, **MCP loop**, **memory sweep**, และ **agent autonomy** ไว้เป็น JARVIS เดียวที่ไม่หยุด

## Trigger Words
`jit-life`, `jarvis`, `เริ่มชีวิต`, `ชีวิต`, `autonomous`, `life system`, `daemon`, `เปิดเครื่อง`, `สตาร์ท innova`

---

## Architecture

```
╔══════════════════════════════════════════════════════╗
║  JIT-LIFE — Master Autonomous Daemon                 ║
╠══════════════════════════════════════════════════════╣
║  1. 🤖 Ollama Proxy (port 4321)                      ║
║     Claude Code ← HTTP → MDES Ollama                 ║
║                                                      ║
║  2. 💬 hermes-discord (bot "อนุ")                   ║
║     Discord ← gemma4:e4b → thought-loop              ║
║                                                      ║
║  3. 🔌 MCP Loop (port 7010)                          ║
║     innova-bot MCP keepalive + task poll             ║
║                                                      ║
║  4. ♥  Heartbeat daemon                              ║
║     15-min git commit+push state                     ║
║                                                      ║
║  5. 🧠 Agent Autonomy bus router                    ║
║     Routes jit-bus → specialist agents              ║
║                                                      ║
║  6. 🔍 Memory Sweep (every 30 cycles)               ║
║     Inbox + state + retros → Oracle                 ║
╚══════════════════════════════════════════════════════╝
```

---

## Files Created

| File | Platform | Purpose |
|------|----------|---------|
| `minds/jit-life.sh` | WSL/Linux | Master life loop |
| `scripts/jarvis-life.ps1` | Windows | Windows counterpart |
| `scripts/mcp-loop.sh` | WSL/Linux | MCP realtime loop |
| `scripts/memory-sweep.sh` | WSL/Linux | Memory consolidation |
| `scripts/discord-reporter.sh` | WSL/Linux | Discord REST reports |
| `scripts/ollama-proxy.py` | Any | Anthropic↔Ollama proxy |
| `minds/ollama-claude.sh` | WSL/Linux | Ollama orchestrator |
| `scripts/jarvis-claude.ps1` | Windows | Windows Ollama daemon |

---

## Quick Start

### Windows (PowerShell)
```powershell
# Start all daemons (never stops)
pwsh -File C:\Users\USER-NT\DEV\Jit\scripts\jarvis-life.ps1 -Action start

# Background (minimized window)
Start-Process pwsh -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Minimized -NoExit -File `"C:\Users\USER-NT\DEV\Jit\scripts\jarvis-life.ps1`" -Action start"

# Check status
pwsh -File scripts\jarvis-life.ps1 -Action status

# Send Discord report now
pwsh -File scripts\jarvis-life.ps1 -Action discord
```

### WSL / Linux
```bash
# Start all daemons
bash /workspaces/Jit/minds/jit-life.sh start

# Background
nohup bash /workspaces/Jit/minds/jit-life.sh start > /tmp/jit-life.log 2>&1 &

# Check status
bash minds/jit-life.sh status

# Memory sweep now
bash minds/jit-life.sh sweep
```

---

## Env Vars Required (`.env`)

```bash
OLLAMA_TOKEN=9e34679b9d60d8b984005ec46508579c
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
DISCORD_TOKEN=<bot-token>
JIT_REPORT_CHANNEL_ID=<channel-id>    # Discord channel for reports
MCP_PORT=7010
ORACLE_PORT=47778
INNOVA_BOT_PATH=C:\Users\USER-NT\DEV\innova-bot-template
```

> ⚠️ **Missing**: `JIT_REPORT_CHANNEL_ID` — ต้องใส่ Discord channel ID สำหรับ innova reports

---

## Discord Reports

### Heartbeat (every 10 cycles = every ~20 min)
```
♥ innova heartbeat (cycle 10, uptime 20m)
🤖 Ollama | 🔌 MCP | 📚 Oracle | 💬 Discord
2026-05-xx 00:00:00
```

### System alive
```
🌅 innova (จิต) ตื่นขึ้น — JIT-LIFE started
Node: MDES-TEST1 | Cycle: 120s
```

### Alert
```
🚨 Alert: [event message]
```

---

## MCP Loop Logic
```
every 30s:
  1. GET /health → online?
  2. if online: poll tasks → route to jit bus
  3. POST /heartbeat → keepalive
  4. if offline: try restart innova-bot
```

---

## Memory Sweep Logic
```
every 30 cycles:
  1. scan /tmp/manusat-bus/*/  (inbox count)
  2. read retrospectives/
  3. read all state files
  4. build digest → /tmp/memory-sweep-digest.json

every 60 cycles:
  5. oracle learn digest
  6. Discord post summary
```

---

## Fallback (Ollama offline)
- Proxy detects HTTP 429/402/403 → rotates model pool
- Models: `gemma4:26b` → `gemma4:e4b` → `qwen2.5-coder:7b` → `llama3.2:latest`
- If all fail: loop waits, retries next cycle
- Discord alert sent when offline > 5 min

---

## Related Skills
- `/.github/skills/ollama-claude/SKILL.md` — Ollama proxy + Claude Code setup
- `minds/agent-autonomy.sh` — bus router
- `minds/innova-life.sh` — innova life loop
- `scripts/heartbeat.sh` — 15-min git heartbeat
