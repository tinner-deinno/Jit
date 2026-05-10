# Changelog: JARVIS Claude + MDES Ollama Autonomous Engine

**Date**: 2026-05-07  
**Type**: Feature — autonomous AI backend with MDES Ollama

---

## สิ่งที่สร้าง

### Core Files

| File | หน้าที่ |
|------|--------|
| `scripts/ollama-proxy.py` | Python proxy แปลง Anthropic API → MDES Ollama `/api/chat` |
| `minds/ollama-claude.sh` | bash orchestrator: proxy + JARVIS loop (WSL) |
| `scripts/jarvis-claude.ps1` | Windows PowerShell JARVIS daemon |
| `scripts/test-ollama-models.sh` | ทดสอบ 4 models + proxy bridge (bash) |
| `scripts/quick-test-ollama.ps1` | ทดสอบเร็วบน Windows PowerShell |
| `.github/skills/ollama-claude/SKILL.md` | Skill definition |

### Architecture

```
Claude Code (claude --dangerously-skip-permissions)
    ↓ ANTHROPIC_BASE_URL=http://127.0.0.1:4321
scripts/ollama-proxy.py (Python HTTP server)
    ↓ POST /api/chat
https://ollama.mdes-innova.online (MDES Ollama)
    ↓ model pool rotation
gemma4:26b → gemma4:e4b → qwen2.5-coder:7b → llama3.2:latest
```

### Model Pool (4 models)

1. `gemma4:26b` — deep thinking, Thai language (primary)
2. `gemma4:e4b` — fast, general (secondary)  
3. `qwen2.5-coder:7b` — code specialist (third)
4. `llama3.2:latest` — fallback (fourth)

### Auto-rotate Logic

- HTTP 429/402/403 after 2 errors → rotate model
- Exception after 3 errors → rotate model
- JARVIS loop checks proxy every 120s, restarts if dead

### Token Exhaustion Handling

เมื่อ token ของ AI provider หมด:
1. Proxy receives 429/403 from MDES Ollama  
2. `rotate_model()` เรียกโดยอัตโนมัติ  
3. Switch ไป model ถัดไปใน pool  
4. ไม่ต้องหยุดรอ — ทำงานต่อทันที

---

## วิธีใช้งาน

### Windows (PowerShell)

```powershell
# ทดสอบ
.\scripts\quick-test-ollama.ps1

# Start proxy + Claude Code
.\scripts\jarvis-claude.ps1 -Action start

# JARVIS daemon (ไม่หยุด)
.\scripts\jarvis-claude.ps1 -Action jarvis
```

### WSL / Linux

```bash
# ทดสอบ 4 models
bash scripts/test-ollama-models.sh

# Start proxy + claude
bash minds/ollama-claude.sh start

# JARVIS loop
bash minds/ollama-claude.sh jarvis &
```

### Manual Claude Code setup

```bash
# 1. Start proxy
OLLAMA_TOKEN=xxx python3 scripts/ollama-proxy.py &

# 2. Set env
export ANTHROPIC_BASE_URL=http://127.0.0.1:4321
export ANTHROPIC_API_KEY=mdes-ollama

# 3. Launch
claude --dangerously-skip-permissions
```

---

## Integration กับ Jit Organ System

JARVIS loop ส่ง message ผ่าน `mouth.sh` ทุก cycle:

```bash
bash organs/mouth.sh tell innova "task:ollama-backend-ready" \
    "JARVIS cycle N: MDES Ollama online. ANTHROPIC_BASE_URL=http://127.0.0.1:4321"
```

innova รับผ่าน `ear.sh` → ใช้ proxy สำหรับ autonomous dev tasks
