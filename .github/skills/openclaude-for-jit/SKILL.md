# SKILL: openclaude-for-jit — Self-Hosted Claude API in Jit System

## Overview

**OpenClaude** integration for the **Jit (จิต)** multi-agent orchestration system.

- ✅ **Self-hosted Claude API** — use your own Claude model instance
- ✅ **Multi-backend router** — Copilot → OpenAI → OpenClaude → MDES Ollama
- ✅ **Automatic fallback** — rotates to next backend on error/quota
- ✅ **Professional model** — claude-3.5-sonnet (or higher) for sub-agents and team spawning
- ✅ **Work with Claude Code** — use Jit + OpenClaude for continuous autonomous workflows

---

## What OpenClaude Is

**GitHub**: [Gitlawb/openclaude](https://github.com/Gitlawb/openclaude)

OpenClaude = open-source **Claude API server** compatible with OpenAI format. Run locally or in Docker.

| Feature | Value |
|---------|-------|
| **Setup Time** | 2-5 minutes (Docker) or 10 minutes (venv) |
| **Port** | 8000 (configurable) |
| **API Format** | OpenAI-compatible `/v1/messages` |
| **Models** | claude-3.5-sonnet, claude-3-opus, claude-3-haiku, etc. |
| **Hardware** | CPU-only or GPU-accelerated |

---

## Installation

### Option 1: Docker (Recommended)

```bash
# Pull and run OpenClaude
docker run -p 8000:8000 --name openclaude-jit gitlawb/openclaude:latest

# Test health
curl http://localhost:8000/health
```

### Option 2: Python venv

```bash
# Clone repo
cd ~/dev
git clone https://github.com/Gitlawb/openclaude.git
cd openclaude

# Create and activate venv
python -m venv venv
.\venv\Scripts\Activate.ps1  # Windows
# source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Start server
python -m openclaude --port 8000
```

### Option 3: Automated Setup (PowerShell)

```powershell
cd C:\Users\USER-NT\DEV\Jit
pwsh -ExecutionPolicy Bypass -File scripts\setup-openclaude.ps1
```

---

## Jit Integration

### 1. Configure .env

```env
# OpenClaude Configuration
OPENCLAUDE_HOST=localhost          # or IP/hostname
OPENCLAUDE_PORT=8000
OPENCLAUDE_MODEL=claude-3.5-sonnet # or claude-3-opus, etc.
# OPENCLAUDE_API_KEY=your-key      # if required

# Multi-backend priority (first available wins)
MULTI_BACKEND_ORDER=copilot,openai,openclaude,ollama
```

### 2. Check Backend Status

```bash
cd C:\Users\USER-NT\DEV\Jit\hermes-discord
node -e "const r = require('./model-router'); console.log(JSON.stringify(r.status(), null, 2))"
```

Expected output:
```json
{
  "order": ["copilot", "openai", "openclaude", "ollama"],
  "backends": {
    "openclaude": {
      "available": true,
      "host": "localhost",
      "port": 8000,
      "model": "claude-3.5-sonnet",
      "errors": 0
    },
    ...
  },
  "primary": "copilot"
}
```

### 3. Test with Jit

```bash
# Verify syntax
node --check hermes-discord/openclaude-adapter.js
node --check hermes-discord/model-router.js

# Run multiagent test (includes openclaude backend)
node hermes-discord/test-multiagent.js

# Check Discord commands
# !jit backend              ← see all backends including openclaude
# !jit spawn openclaude <msg>  ← spawn OpenClaude as agent
```

---

## Architecture

```
Jit Multi-Backend Router (model-router.js)
    ├── Copilot (via GitHub OAuth)
    ├── OpenAI (via API key)
    ├── OpenClaude (NEW)
    │    └── openclaude-adapter.js
    │         └── http://localhost:8000/v1/messages
    └── MDES Ollama (fallback)

Rotation: if backend unavailable/quota → try next in MULTI_BACKEND_ORDER
```

### Files Created

| File | Purpose |
|------|---------|
| `hermes-discord/openclaude-adapter.js` | HTTP adapter for OpenClaude API |
| `scripts/setup-openclaude.ps1` | Automated setup (clone + Docker/venv options) |
| `.github/skills/openclaude-for-jit/SKILL.md` | This documentation |

### Modified Files

| File | Change |
|------|--------|
| `hermes-discord/model-router.js` | Added openclaude to backend rotation |
| `.env` | Added OPENCLAUDE_* config + updated MULTI_BACKEND_ORDER |

---

## Usage

### Node.js Programmatic

```javascript
const modelRouter = require('./hermes-discord/model-router');

// Call any backend (rotates automatically)
modelRouter.callModel(
  [{ role: 'user', content: 'Hello world' }],
  { preferBackend: 'openclaude' },
  (err, result) => {
    console.log('Reply:', result.reply);
    console.log('Backend:', result.backend);  // 'openclaude'
  }
);

// Or promise-based
modelRouter.callModelPromise(messages, { preferBackend: 'openclaude' })
  .then(result => console.log(result.reply))
  .catch(err => console.error(err));

// Check all backends
const status = modelRouter.status();
console.log(status.backends.openclaude);
```

### Discord Commands

```
# View backend status (including OpenClaude)
!jit backend

# Spawn OpenClaude as organ agent
!jit spawn openclaude "Translate this to Thai: Hello world"

# Use openclaude in agent chain
!jit spawn chain soma+openclaude+innova "Design REST API"

# View all backends
!jit agents
```

### Direct Adapter Usage

```javascript
const oca = require('./hermes-discord/openclaude-adapter');

// Check health
oca.checkHealth().then(health => {
  console.log(health.ok ? 'Online ✅' : 'Offline ❌');
});

// Call directly
oca.callOpenClaudePromise(
  [{ role: 'user', content: 'Explain quantum computing' }],
  { model: 'claude-3-opus' }
).then(result => console.log(result.text));

// Status
console.log(oca.status());
```

---

## Workflow: Jit + OpenClaude + Claude Code

### Scenario: 24/7 Autonomous Development with Jit

```
Claude Code                          (human-driven during work hours)
    ↓
Jit (จิต) Master Orchestrator        (always running, decision maker)
    ├── soma (strategic leader)      ← use OpenClaude (sonnet) for planning
    ├── innova (lead developer)      ← use OpenClaude (sonnet) for coding
    ├── lak (architect)              ← use OpenClaude for design review
    └── Tier-3 agents                ← fallback to MDES Ollama
         ├── chamu (QA)
         ├── neta (code review)
         └── vaja (reporting)
    ↓
innova-bot MCP                       (102 tools, sub-agents)
    ├── javis_spawn_team (parallel)
    ├── what_should_i_do_next (ทำต่อไป)
    ├── oracle_recap (memory)
    └── oracle_learn_skill (permanent learnings)
    ↓
GitHub / Workspace                   (auto-commit, PR, deploy)
```

### Setup Steps

1. **Clone and start OpenClaude**
   ```bash
   docker run -p 8000:8000 gitlawb/openclaude:latest
   ```

2. **Verify Jit .env**
   ```env
   OPENCLAUDE_HOST=localhost
   OPENCLAUDE_PORT=8000
   MULTI_BACKEND_ORDER=copilot,openai,openclaude,ollama
   ```

3. **Start Jit system**
   ```bash
   cd C:\Users\USER-NT\DEV\Jit
   
   # Start innova-bot MCP
   cd ..\innova-bot-template\devtools\innova-bot
   python -m innova_bot &
   
   # Start Discord bot (optional)
   cd ..\..\...\Jit\hermes-discord
   npm start
   ```

4. **Use from Claude Code**
   ```javascript
   // Call Jit's multi-backend system
   const modelRouter = require('./hermes-discord/model-router');
   const reply = await modelRouter.callModelPromise(
     [{ role: 'user', content: 'architect a microservices app' }],
     { preferBackend: 'openclaude' }  // prefer OpenClaude, fallback if unavailable
   );
   ```

---

## Backend Selection Logic

Jit auto-selects based on `MULTI_BACKEND_ORDER`:

| Priority | Backend | Best For | Cost |
|----------|---------|----------|------|
| 1 | Copilot | Microsoft GitHub integration | Free (GitHub user) |
| 2 | OpenAI | o1, o3, gpt-4-turbo, advanced reasoning | $$ per token |
| 3 | **OpenClaude** | Self-hosted, no API cost, GDPR-compliant | One-time setup |
| 4 | MDES Ollama | Last resort, always available, on-campus | Free (local) |

**Automatic rotation**: If backend is unavailable or hits quota → try next in line

---

## Common Issues & Troubleshooting

### OpenClaude offline
```
Error: OpenClaude unreachable at localhost:8000
Fix:
  1. docker ps | grep openclaude    (check if running)
  2. docker run -p 8000:8000 gitlawb/openclaude:latest
  3. curl http://localhost:8000/health
```

### Port already in use
```
Error: Address already in use :8000
Fix:
  # Find what's using 8000
  netstat -ano | findstr :8000
  
  # Kill it
  taskkill /PID <PID> /F
  
  # Or use different port
  docker run -p 9000:8000 gitlawb/openclaude:latest
  OPENCLAUDE_PORT=9000 in .env
```

### API key required (if OpenClaude enforces auth)
```env
OPENCLAUDE_API_KEY=your-key
```

### Model not found
```
Error: Model claude-3.5-sonnet not available
Fix: Check OpenClaude supported models, update OPENCLAUDE_MODEL
```

---

## Performance Tips

### 1. GPU Acceleration
If running on GPU machine:
```bash
docker run -p 8000:8000 \
  --gpus all \
  gitlawb/openclaude:latest
```

### 2. Resource Limits
```bash
docker run -p 8000:8000 \
  --memory 8g \
  --cpus 4 \
  gitlawb/openclaude:latest
```

### 3. Backend Preference by Role
```javascript
// Jit orchestration logic
const agentBackendMap = {
  'jit':    'copilot',        // Master — prefer advanced reasoning
  'soma':   'openclaude',     // Strategy — use self-hosted sonnet
  'innova': 'openclaude',     // Code — use self-hosted
  'lak':    'openclaude',     // Design — self-hosted
  'chamu':  'ollama',         // QA — fallback
};

// Model-router will rotate if preferred unavailable
```

---

## Oracle Save

After successful integration:

```bash
cd C:\Users\USER-NT\DEV\Jit
bash limbs/oracle.sh learn "openclaude-integration" \
  "OpenClaude (github.com/Gitlawb/openclaude) added to Jit multi-backend router as 3rd priority backend. Runs on localhost:8000. Provides self-hosted claude-3.5-sonnet for team orchestration. Rotates to next backend on unavailability. Configured via OPENCLAUDE_HOST/PORT/MODEL in .env. Docker or venv installation." \
  "openclaude,jit,multi-backend,self-hosted,llm-router"
```

---

## Related

- [model-router.js](hermes-discord/model-router.js) — Main backend router
- [agent-spawner.js](hermes-discord/agent-spawner.js) — 14 organ agents
- [jit-possess-innova.js](minds/jit-possess-innova.js) — Soul possession
- [Gitlawb/openclaude](https://github.com/Gitlawb/openclaude) — OpenClaude repo

---

*Created: 2026-05-08 | Jit System Enhancement | ศีล · สมาธิ · ปัญญา*
