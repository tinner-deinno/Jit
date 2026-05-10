---
name: ollama-claude
description: "ใช้ MDES Ollama เป็น Claude Code AI backend แบบ custom remote — มี 4 models หมุนเวียนอัตโนมัติเมื่อ token หมด พร้อม JARVIS daemon ทำงานต่อเนื่อง. Use when: token หมด, ต้องการ Ollama backend, รัน claude --dangerously-skip-permissions ด้วย MDES Ollama, autonomous dev loop"
argument-hint: "start | test | proxy | jarvis | status | stop"
---

# SKILL: ollama-claude — Claude Code + MDES Ollama JARVIS

## เมื่อไหร่ใช้ skill นี้

- เมื่อ Claude/Copilot token หมดหรือใกล้หมด → switch ไป MDES Ollama
- ต้องการรัน `claude --dangerously-skip-permissions` ด้วย Ollama model
- ต้องการ JARVIS loop ทำงานต่อเนื่องอัตโนมัติ
- ทดสอบ 3-4 Ollama models

---

## Architecture

```
User / JARVIS
  │
  ├─ scripts/ollama-proxy.py      ← Anthropic API ↔ Ollama bridge (Python)
  │    Port: 4321
  │    Converts: POST /v1/messages → /api/chat
  │    Auto-rotates models on error/quota
  │
  ├─ minds/ollama-claude.sh       ← bash orchestrator (WSL)
  │
  └─ scripts/jarvis-claude.ps1   ← Windows PowerShell JARVIS daemon
```

## Model Pool (4 models)

| Priority | Model | Use |
|----------|-------|-----|
| 1 | `gemma4:26b` | Deep thinking, Thai language |
| 2 | `gemma4:e4b` | Fast, general purpose |
| 3 | `qwen2.5-coder:7b` | Code specialist |
| 4 | `llama3.2:latest` | Fallback |

---

## Quick Start

### Windows (PowerShell)
```powershell
# 1. ทดสอบ 4 models
.\scripts\jarvis-claude.ps1 -Action test

# 2. Start proxy + Claude Code
.\scripts\jarvis-claude.ps1 -Action start

# 3. JARVIS loop (ไม่หยุด)
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$(pwd)\scripts\jarvis-claude.ps1`" -Action jarvis" -WindowStyle Minimized
```

### WSL / Linux (bash)
```bash
# 1. ทดสอบ models
bash scripts/test-ollama-models.sh

# 2. Start proxy only
bash minds/ollama-claude.sh proxy

# 3. Start proxy + claude
bash minds/ollama-claude.sh start

# 4. JARVIS daemon
bash minds/ollama-claude.sh jarvis &
```

### Manual (หลัง proxy start)
```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:4321
export ANTHROPIC_API_KEY=mdes-ollama
claude --dangerously-skip-permissions
```

---

## Token หมด → Auto Rotate

เมื่อ Ollama ส่ง HTTP 429/402/403 กลับ proxy จะ:
1. เพิ่ม error count
2. หลัง 2 errors → rotate ไป model ถัดไป
3. วนซ้ำจนครบ 4 models

```
gemma4:26b → gemma4:e4b → qwen2.5-coder:7b → llama3.2:latest → gemma4:26b
```

---

## JARVIS Loop Logic

```
every 120s:
  1. ตรวจ proxy — restart ถ้าตาย
  2. ping 4 models — ยืนยัน Ollama online
  3. ถ้า online → notify innova via mouth.sh
  4. บันทึก JARVIS state
  5. heartbeat pulse
  6. sleep 120s → repeat
```

---

## Files

| File | หน้าที่ |
|------|--------|
| `scripts/ollama-proxy.py` | Python proxy server (Anthropic↔Ollama) |
| `minds/ollama-claude.sh` | bash orchestrator + JARVIS loop |
| `scripts/jarvis-claude.ps1` | Windows PowerShell JARVIS daemon |
| `scripts/test-ollama-models.sh` | ทดสอบ 4 models + proxy |

---

## Environment Variables

```bash
OLLAMA_BASE_URL=https://ollama.mdes-innova.online   # ใน .env
OLLAMA_TOKEN=<your-token>                            # ใน .env (ไม่ commit)
PROXY_PORT=4321                                      # default
```

---

## Sub-agent Workflow

```
jit (จิต/Master)
  └── innova (Lead Dev) receives mouth.sh message:
        "JARVIS cycle N: MDES Ollama online. ANTHROPIC_BASE_URL=... Ready."
            → innova uses proxy for autonomous dev tasks
            → mue (hand) executes code changes
            → chamu (QA) tests results
            → neta (review) checks quality
```

---

## Proxy Health Check

```bash
curl http://127.0.0.1:4321/health
# Returns:
{
  "status": "ok",
  "current_model": "gemma4:26b",
  "model_pool": ["gemma4:26b", "gemma4:e4b", ...],
  "requests": 42,
  "rotations": 1,
  "uptime_secs": 3600
}
```
