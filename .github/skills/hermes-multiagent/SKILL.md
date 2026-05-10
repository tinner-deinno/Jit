# Skill: hermes-multiagent

## What This Skill Does

Enables Hermes Discord bot (`hermes-discord/bot.js`) to **spawn organ agents** from multiple model backends:
- **GitHub Copilot** (auto-detect from VS Code, or `COPILOT_TOKEN`)
- **OpenAI / Codex** (`OPENAI_API_KEY`)
- **MDES Ollama** fallback (`OLLAMA_TOKEN`)

Adds `!jit spawn` commands so jit (master) can orchestrate multi-agent chains and parallel spawns **live in Discord**.

---

## Files

| File | Purpose |
|------|---------|
| `hermes-discord/model-router.js` | Multi-backend router (Copilot→OpenAI→Ollama rotation) |
| `hermes-discord/agent-spawner.js` | Agent registry + spawn/chain/parallel functions |
| `hermes-discord/bot.js` | Wires model-router + spawn commands |
| `hermes-discord/test-multiagent.js` | Standalone Node.js test (no Discord) |
| `scripts/hermes-multiagent-test.ps1` | Windows PowerShell test orchestrator |

---

## Quick Start

```powershell
# Run full test (auto-detect all backends)
cd C:\Users\USER-NT\DEV\Jit
pwsh -ExecutionPolicy Bypass -File scripts\hermes-multiagent-test.ps1
```

Or just the Node test directly:
```powershell
cd C:\Users\USER-NT\DEV\Jit\hermes-discord
node test-multiagent.js
```

---

## Discord Commands (after `!jit` prefix)

### Single Agent
```
!jit spawn innova Write a Python function to validate email addresses
!jit spawn soma   What are the risks of using a monolithic architecture?
!jit spawn chamu  List test cases for a login form
```

### Serial Chain (output flows forward)
```
!jit spawn chain jit+soma+innova  Design and implement a JWT auth system
!jit spawn chain soma+lak+innova  Plan a microservices migration
```

### Parallel Spawn (concurrent, independent)
```
!jit spawn parallel lak,chamu    Design the DB schema for user management
!jit spawn parallel neta,vaja    Review and summarize our latest PR
```

### Agent & Backend Info
```
!jit agents     — list all 14 agents with backend preferences
!jit backend    — show model-router status (which backends available)
```

---

## Agent Backend Registry

| Agent | Tier | Organ | Preferred Backend |
|-------|------|-------|-------------------|
| jit | 0 | จิต (soul) | copilot |
| soma | 1 | สมอง (brain) | copilot |
| innova | 2 | ปัญญา (wisdom) | copilot |
| lak | 2 | กระดูกสันหลัง (spine) | openai |
| neta | 2 | เนตร (review) | openai |
| vaja | 3 | ปาก (mouth) | ollama |
| chamu | 3 | จมูก (QA) | ollama |
| rupa | 3 | รูปลักษณ์ (design) | ollama |
| pada | 3 | ขา (DevOps) | ollama |
| netra | 3 | ตา (eye) | ollama |
| karn | 3 | หู (ear) | ollama |
| mue | 3 | มือ (hand) | ollama |
| pran | 3 | หัวใจ (heart) | ollama |
| sayanprasathan | 3 | ระบบประสาท (nerve) | ollama |

---

## Backend Rotation Logic

```
Request → try copilot (if token available)
        ↓ 429/402/403 or no token
        → try openai (if OPENAI_API_KEY set)
        ↓ quota or no key
        → try ollama (MDES Ollama always available)
        ↓ all fail
        → Error: All backends exhausted
```

Token detection order for Copilot:
1. `COPILOT_TOKEN` env var
2. `%LOCALAPPDATA%\github-copilot\apps.json` (VS Code on Windows)
3. `%APPDATA%\GitHub Copilot\hosts.json`
4. `~/.config/github-copilot/hosts.json` (Linux/WSL)

---

## Environment Variables

```env
# .env (C:\Users\USER-NT\DEV\Jit\.env)

# Backend credentials (at least one required)
OLLAMA_TOKEN=<your-mdes-ollama-token>        # always fallback
OPENAI_API_KEY=sk-...                         # Codex/OpenAI
COPILOT_TOKEN=ghu_...                         # optional, auto-detect from VS Code

# Backend priority order
MULTI_BACKEND_ORDER=copilot,openai,ollama     # default

# Ollama config
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
OLLAMA_MODEL=gemma4:e4b
```

---

## Programmatic Usage (in Node.js)

```javascript
const spawner = require('./hermes-discord/agent-spawner');

// Single agent
const result = await spawner.spawnAgent('innova', 'Write a hello world in Go');
console.log(result.reply);     // the response
console.log(result.backend);   // which backend was used

// Serial chain
const chain = await spawner.spawnAgentChain([
  { agent: 'jit',    message: 'Task: build REST API' },
  { agent: 'soma',   message: 'Plan architecture', passReply: true },
  { agent: 'innova', message: 'Implementation steps', passReply: true },
]);
chain.results.forEach(r => console.log(r.agent, ':', r.reply));

// Parallel
const parallel = await spawner.spawnAgentParallel([
  { agent: 'lak',   message: 'Database design' },
  { agent: 'chamu', message: 'Test cases' },
]);
```

---

## Test Results (2026-05-07)

```
══ SECTION 1: Backend Status ══
  copilot: auto-detected from VS Code
  openai:  from OPENAI_API_KEY (when set)
  ollama:  https://ollama.mdes-innova.online (always)

══ SECTION 3: Serial Chain jit → soma → innova ══
  ✅ chain-jit     via copilot
  ✅ chain-soma    via copilot
  ✅ chain-innova  via copilot
  ✅ chain-complete

══ SECTION 4: Parallel lak + chamu ══
  ✅ parallel-lak   via openai
  ✅ parallel-chamu via ollama
  ✅ parallel-concurrent (both ran simultaneously)

══ SECTION 5: Full Pipeline ══
  ✅ jit → soma → innova → neta → vaja  (5/5 agents)

  PASS
```

---

## Maintenance

- To **add a new agent**: add entry to `AGENT_REGISTRY` in `agent-spawner.js`
- To **change backend order**: set `MULTI_BACKEND_ORDER=openai,copilot,ollama` in `.env`
- To **force a backend**: `!jit spawn innova <msg>` always tries Copilot first (innova's preference)
- Copilot token is **cached 25 minutes** in-memory — bot restart refreshes it

---

## PASS Verification

Run this to get PASS verdict:
```powershell
cd C:\Users\USER-NT\DEV\Jit
pwsh -ExecutionPolicy Bypass -File scripts\hermes-multiagent-test.ps1
```

Expected final line: `PASS` or `PARTIAL PASS` (if only Ollama available)
