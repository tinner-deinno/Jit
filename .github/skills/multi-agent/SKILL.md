# multi-agent Skill — Claude Code Multi-Backend + Multiagent

## Description
ใช้ Claude Code กับหลาย AI backend พร้อมกัน:  
**OpenAI/Codex + GitHub Copilot + MDES Ollama** — auto-rotate เมื่อ token หมด  
รองรับ multiagent (Task tool spawn sub-agents) ทุก backend

## Trigger Words
`codex`, `openai backend`, `copilot backend`, `multi-proxy`, `multi-agent`,  
`multiagent`, `claude pro หมด`, `limit แล้ว`, `สลับ backend`, `spawn sub-agent`

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Claude Code (claude --dangerously-skip-permissions)    │
│  ANTHROPIC_BASE_URL=http://127.0.0.1:4322               │
└──────────────────────┬──────────────────────────────────┘
                       │ POST /v1/messages (Anthropic format)
                       ▼
┌─────────────────────────────────────────────────────────┐
│  multi-proxy.py (port 4322)                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Backend Router (auto-rotate on 429/402/403)      │   │
│  ├──────────────┬──────────────┬───────────────────┤   │
│  │ 1. OpenAI   │ 2. Copilot   │ 3. MDES Ollama    │   │
│  │  gpt-4o     │  gpt-4o      │  gemma4:26b        │   │
│  │  gpt-4.1    │  claude-s4.5 │  gemma4:e4b        │   │
│  │  o4-mini    │  (copilot)   │  (fallback)        │   │
│  └──────────────┴──────────────┴───────────────────┘   │
│  + Tool-calling conversion (Anthropic ↔ OpenAI format) │
│  + Streaming (SSE fake-stream)                          │
└─────────────────────────────────────────────────────────┘
```

---

## Files

| File | Purpose |
|------|---------|
| `scripts/multi-proxy.py` | Unified proxy — OpenAI + Copilot + Ollama |
| `scripts/test-multi-proxy.ps1` | Windows test suite (6 sections) |
| `scripts/jarvis-life.ps1` | Windows daemon (เริ่ม proxy อัตโนมัติ) |
| `minds/jit-life.sh` | Linux daemon |
| `.env` | Config (OPENAI_API_KEY, COPILOT_TOKEN, etc.) |

---

## Quick Start

### 1. ตั้งค่า API Keys ใน `.env`

```bash
# OpenAI/Codex — https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-proj-...
OPENAI_MODEL=gpt-4o          # หรือ gpt-4.1, o4-mini

# GitHub Copilot — ดูวิธีได้ token ด้านล่าง
COPILOT_TOKEN=tid_...
COPILOT_MODEL=gpt-4o

# MDES Ollama (fallback — มีอยู่แล้ว)
OLLAMA_TOKEN=9e34679b9d60d8b984005ec46508579c
```

### 2. เริ่ม Multi-Proxy

**Windows PowerShell:**
```powershell
cd C:\Users\USER-NT\DEV\Jit
# Load .env
Get-Content .env | Where-Object { $_ -match '=' } | ForEach-Object {
    $k,$v = $_ -split '=',2; [System.Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim(), "Process")
}
# Start proxy
python3 scripts\multi-proxy.py
```

**Background (minimized):**
```powershell
Start-Process python3 -ArgumentList "scripts\multi-proxy.py" -WindowStyle Minimized
```

**WSL/Linux:**
```bash
source .env && nohup python3 scripts/multi-proxy.py > /tmp/multi-proxy.log 2>&1 &
```

### 3. ใช้กับ Claude Code

```powershell
# Windows
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:4322"
$env:ANTHROPIC_API_KEY  = "multi-proxy"
claude --dangerously-skip-permissions

# Linux/WSL
export ANTHROPIC_BASE_URL=http://127.0.0.1:4322
export ANTHROPIC_API_KEY=multi-proxy
claude --dangerously-skip-permissions
```

### 4. ทดสอบ

```powershell
# Full test suite
pwsh -File scripts\test-multi-proxy.ps1

# Skip multiagent test (faster)
pwsh -File scripts\test-multi-proxy.ps1 -SkipMultiAgent

# Health check
Invoke-RestMethod http://127.0.0.1:4322/health
```

---

## วิธีได้ GitHub Copilot Token

### วิธีที่ 1 — Auto-detect (ถ้า VS Code + Copilot ติดตั้งแล้ว)
proxy จะ auto-detect token จาก:
- Windows: `%LOCALAPPDATA%\github-copilot\apps.json`
- Linux: `~/.config/github-copilot/hosts.json`

### วิธีที่ 2 — GitHub CLI
```bash
# Install gh: https://cli.github.com
gh auth login --scopes copilot
gh auth token   # → ghu_xxxxx (OAuth token)

# Exchange for Copilot token
curl -s -H "Authorization: Bearer $(gh auth token)" \
     https://api.github.com/copilot_internal/v2/token \
| python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
```
Copy token → ใส่ `COPILOT_TOKEN=tid_...` ใน `.env`

### วิธีที่ 3 — ตั้ง GITHUB_TOKEN
```bash
GITHUB_TOKEN=ghu_xxxxx   # OAuth token จาก gh auth token
```
proxy จะ auto-exchange เป็น Copilot token ให้

---

## Backend Rotation Logic

```
Request → Current Backend
  ↓ 429 Too Many Requests (2+ errors)  → rotate
  ↓ 402 Payment Required                → rotate
  ↓ 403 Forbidden                       → rotate
  ↓ 401 Unauthorized                    → rotate
  ↓ Exception (2+ times)               → rotate
  ↓ All backends exhausted              → return 500
```

Default order: `openai → copilot → ollama`  
Override: `MULTI_BACKEND_ORDER=copilot,openai,ollama`

---

## Multiagent (Claude Code Task Tool)

Claude Code รองรับ `Task` tool — spawn sub-agents อัตโนมัติ:

```
Parent Claude Code (ANTHROPIC_BASE_URL=:4322)
  └── Task: spawn sub-agent 1 (inherits env → same proxy)
  └── Task: spawn sub-agent 2 (inherits env → same proxy)
  └── Task: spawn sub-agent 3 (rotated to different backend)
```

**Sub-agents ทุกตัว inherit `ANTHROPIC_BASE_URL`** → ใช้ proxy เดียวกัน  
proxy rotate backend ให้อัตโนมัติ → sub-agents อาจใช้ backend ต่างกัน

**ตัวอย่าง prompt สำหรับ multiagent:**
```
Use the Task tool to spawn 2 sub-agents:
  Sub-agent 1: "Write a Python function to sort a list"
  Sub-agent 2: "Write a test for the sorting function"
Then combine their outputs.
```

---

## Jit Master Agent (spawn sub-agents)

```bash
# ใน agent-autonomy หรือ jit-life
ANTHROPIC_BASE_URL=http://127.0.0.1:4322
ANTHROPIC_API_KEY=multi-proxy

# Spawn claude sub-agent for specific task
claude --dangerously-skip-permissions \
  "task:code-review: Review the changes in git diff HEAD~1"

# Spawn multiple sub-agents
for TASK in "analyze" "fix" "test"; do
    claude --dangerously-skip-permissions "$TASK: ..." &
done
wait
```

---

## Health Check Response

```json
{
  "status": "ok",
  "current_backend": "openai",
  "available": ["openai", "copilot", "ollama"],
  "backends": {
    "openai":  true,
    "copilot": true,
    "ollama":  true
  },
  "requests": 42,
  "rotations": 1,
  "uptime_secs": 300
}
```

---

## Test Results (expected)

```
=== 1. Proxy Health ===
  [PASS] Proxy online at http://127.0.0.1:4322

=== 2. Q&A Test ===
  [PASS] Q: Reply with exactly: HELLO_WORLD... → HELLO_WORLD
  [PASS] Q: What is 2+2?... → 4
  [PASS] Q: Name one planet... → Mars
  [PASS] Q: Reply in Thai... → สวัสดีครับ

=== 3. Backend Info ===
  [PASS] Requests served: 4 | Errors: 0 | Rotations: 0

=== 4. Tool-Calling ===
  [PASS] Tool call returned: get_weather(city=Bangkok)

=== 5. Streaming (SSE) ===
  [PASS] SSE stream received (7 data events)

=== 6. Multiagent ===
  [PASS] Claude Code responded via multi-proxy: MULTIAGENT_OK
  [PASS] Multiagent Task spawn successful!

RESULTS: 9 PASSED | 0 FAILED
```

---

## Known Limitations

| Issue | Workaround |
|-------|-----------|
| Copilot token expires (~28 min) | proxy auto-refreshes if GITHUB_TOKEN set |
| OpenAI tool format slightly different | proxy converts automatically |
| GitHub Copilot Enterprise required for API | use OpenAI or Ollama fallback |
| Streaming: fake SSE (not true token-by-token) | works for Claude Code, no visual typing effect |

---

## Integration with JIT-LIFE

`jarvis-life.ps1` และ `jit-life.sh` สามารถ start multi-proxy ได้:

```powershell
# เพิ่มใน jarvis-life.ps1
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:4322"
Start-Process python3 -ArgumentList "scripts\multi-proxy.py" -WindowStyle Hidden
```

```bash
# เพิ่มใน jit-life.sh  
ensure_multi_proxy() {
    curl -sf http://127.0.0.1:4322/health >/dev/null 2>&1 || \
    nohup python3 "$JIT_ROOT/scripts/multi-proxy.py" &
}
```
