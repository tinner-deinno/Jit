# OpenClaude Integration for Jit System — Complete Guide

## Status: ✅ READY FOR INSTALLATION

OpenClaude has been fully integrated into the Jit multi-backend system. This guide provides step-by-step instructions for setup, testing, and deployment.

---

## What's New

### 📦 Files Added
| File | Purpose |
|------|---------|
| `hermes-discord/openclaude-adapter.js` | HTTP bridge to OpenClaude API (localhost:8000) |
| `hermes-discord/test-openclaude.js` | Standalone test suite for OpenClaude backend |
| `scripts/setup-openclaude.ps1` | Automated setup (clone repo + Docker/venv options) |
| `.github/skills/openclaude-for-jit/SKILL.md` | Professional skill documentation for Claude Code |

### 🔧 Files Modified
| File | Change |
|------|--------|
| `hermes-discord/model-router.js` | ✅ Added `openclaude` to multi-backend rotation |
| `.env` | ✅ Added `OPENCLAUDE_HOST`, `OPENCLAUDE_PORT`, `OPENCLAUDE_MODEL` |

### ✨ New Capabilities
- Multi-backend rotation: **Copilot → OpenAI → OpenClaude → MDES Ollama**
- Self-hosted Claude API in Jit system
- Automatic fallback if backend unavailable/quota-limited
- Professional claude-3.5-sonnet (or better) for team orchestration
- Zero-cost inference at scale (self-hosted)

---

## Quick Start (5 minutes)

### Step 1: Start OpenClaude

**Option A: Docker (Recommended)**
```bash
docker run -p 8000:8000 --name openclaude-jit gitlawb/openclaude:latest
```

**Option B: Python venv**
```bash
git clone https://github.com/Gitlawb/openclaude.git ~/dev/openclaude
cd ~/dev/openclaude
python -m venv venv
.\venv\Scripts\Activate.ps1  # Windows
pip install -r requirements.txt
python -m openclaude --port 8000
```

**Option C: Automated Setup**
```powershell
cd C:\Users\USER-NT\DEV\Jit
pwsh -ExecutionPolicy Bypass -File scripts\setup-openclaude.ps1
```

### Step 2: Verify Installation

```bash
# Test health
curl http://localhost:8000/health

# Run OpenClaude test
cd C:\Users\USER-NT\DEV\Jit\hermes-discord
node test-openclaude.js
```

### Step 3: Verify Jit Integration

Check that OpenClaude is available in the backend router:

```javascript
// In Node.js
const r = require('./hermes-discord/model-router');
console.log(r.status().backends.openclaude);
// Expected: { available: true, host: 'localhost', port: 8000, ... }
```

### Step 4: Use in Discord / Jit

```
# View all backends
!jit backend

# Spawn OpenClaude as agent
!jit spawn openclaude "Explain quantum computing in simple terms"

# Use in chain
!jit spawn chain soma+openclaude+innova "Design a REST API"
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Jit (จิต) — Master Orchestrator                       │
│  ศีล · สมาธิ · ปัญญา                                    │
└────────────────────────┬────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    ┌─────────────┐ ┌─────────────┐ ┌──────────────┐
    │  Discord    │ │ Node.js CLI │ │ Claude Code  │
    │  Commands   │ │   Direct    │ │  Integration │
    └──────┬──────┘ └──────┬──────┘ └───────┬──────┘
           │                │               │
           └────────────────┼───────────────┘
                            │
        ┌───────────────────────────────────────┐
        │  Model Router (model-router.js)       │
        │  Auto-rotate on failure/quota         │
        └──┬────┬───────────┬──────────────┬────┘
           │    │           │              │
        ┌──▼─┐┌─▼──┐ ┌──────▼────┐ ┌─────▼─────┐
        │ CP ││ OAI│ │ OpenClaude │ │   Ollama  │
        └────┘└────┘ │(NEW) ✨   │ └───────────┘
                     │localhost  │
                     │:8000      │
                     └────────────┘
                            │
                ┌───────────┴──────────────┐
                │                          │
            ┌───▼────┐             ┌──────▼──┐
            │ Docker │  or         │  venv   │
            │ Image  │             │ Python  │
            └────────┘             └─────────┘
```

---

## Configuration

### .env Settings

```env
# OpenClaude Backend
OPENCLAUDE_HOST=localhost          # hostname or IP
OPENCLAUDE_PORT=8000               # port (default 8000)
OPENCLAUDE_MODEL=claude-3.5-sonnet # model name
# OPENCLAUDE_API_KEY=...           # if required by your instance

# Multi-Backend Priority (left = highest priority)
MULTI_BACKEND_ORDER=copilot,openai,openclaude,ollama
```

### How Rotation Works

When a request comes in:

1. **Try Copilot** → if available and no error, use it ✅
2. **Try OpenAI** → if Copilot unavailable, use it ✅
3. **Try OpenClaude** → if OpenAI unavailable ✅ **(NEW)**
4. **Try Ollama** → if all else fails (always available) ✅

If any backend returns HTTP 429/402/403 (quota), skip to next.

---

## Testing

### Test 1: Health Check
```bash
curl http://localhost:8000/health
# Expected: { "status": "ok" }
```

### Test 2: OpenClaude Direct Call
```bash
curl -X POST http://localhost:8000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3.5-sonnet",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

### Test 3: Jit Integration Test
```bash
cd C:\Users\USER-NT\DEV\Jit\hermes-discord
node test-openclaude.js
```

Expected output:
```
[TEST 1] OpenClaude Health Check
✅ OpenClaude online at http://localhost:8000

[TEST 2] Model Router Backend Status
Backend order: copilot → openai → openclaude → ollama
✅ openclaude    localhost:8000 (claude-3.5-sonnet)

[TEST 3] Model Router Call
✅ Backend used: openclaude
Reply: OpenClaude is an open-source...

[TEST 4] Direct Adapter Call
✅ Direct call successful
   Reply: working
```

### Test 4: Full Multiagent Pipeline
```bash
node hermes-discord/test-multiagent.js
# Should show openclaude in backend rotation
```

---

## Usage Examples

### Example 1: CLI Agent Spawn

```bash
node minds/jit-possess-innova.js --team \
  "Implement a Python async task queue with Redis backing"
```

This will:
1. Jit (master) decides using available backend (might use OpenClaude)
2. Assigns 3 organ agents (soma, innova, lak)
3. Spawns them in parallel, all potentially using OpenClaude
4. innova-bot subagents run (javis_spawn_team)
5. vaja summarizes results

### Example 2: Discord Commands

```
# Simple spawn
!jit spawn openclaude "Explain the CAP theorem"

# Serial chain (passes replies forward)
!jit spawn chain soma+openclaude+innova \
  "Design a microservices authentication system"

# Parallel (all run simultaneously)
!jit spawn parallel soma,openclaude,lak,chamu \
  "Code review this function: ..."
```

### Example 3: Programmatic (Node.js)

```javascript
const modelRouter = require('./hermes-discord/model-router');

// Prefer OpenClaude, fallback if unavailable
const result = await modelRouter.callModelPromise(
  [{ role: 'user', content: 'Write a Python web scraper' }],
  { preferBackend: 'openclaude', model: 'claude-3-opus' }
);

console.log('Backend:', result.backend);  // might be 'openclaude'
console.log('Reply:', result.reply);
```

### Example 4: Direct Adapter Usage

```javascript
const oca = require('./hermes-discord/openclaude-adapter');

// Health check
const health = await oca.checkHealth();
console.log(health.ok ? 'Online' : 'Offline');

// Direct call
const result = await oca.callOpenClaudePromise(
  [{ role: 'user', content: 'Your prompt' }],
  { model: 'claude-3.5-sonnet' }
);

console.log(result.text);
```

---

## Performance & Optimization

### 1. GPU Acceleration (if available)

```bash
# Docker with GPU
docker run -p 8000:8000 \
  --gpus all \
  gitlawb/openclaude:latest

# Set resource limits
docker run -p 8000:8000 \
  --memory 16g \
  --cpus 8 \
  gitlawb/openclaude:latest
```

### 2. Backend Selection Strategy

```javascript
// Jit can route by role
const rolePriority = {
  'jit':    'copilot',        // Master decision-maker
  'soma':   'openclaude',     // Strategy planning
  'innova': 'openclaude',     // Code generation
  'lak':    'openai',         // Complex architecture
  'chamu':  'ollama',         // Fast testing
};

// Model router will auto-fallback if preferred unavailable
```

### 3. Token Budget

- **Copilot**: ~150 RPM (free for GitHub users)
- **OpenAI**: Pay-as-you-go (tokens + premium)
- **OpenClaude**: ✅ **Zero additional cost** (self-hosted)
- **Ollama**: ✅ **Zero cost** (local/campus network)

---

## Troubleshooting

### ❌ "OpenClaude unreachable"

```bash
# Check if it's running
docker ps | grep openclaude

# Start it
docker run -p 8000:8000 gitlawb/openclaude:latest

# Test health
curl http://localhost:8000/health
```

### ❌ "Port 8000 already in use"

```bash
# Find and kill process
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Or use different port
docker run -p 9000:8000 gitlawb/openclaude:latest

# Update .env
OPENCLAUDE_PORT=9000
```

### ❌ "Model not found"

Check available models in OpenClaude docs. Update:
```env
OPENCLAUDE_MODEL=claude-3-opus  # or claude-3-haiku
```

### ⚠️ Slow responses

1. **CPU bottleneck?** → allocate more CPU/GPU
2. **Network latency?** → check localhost:8000 directly
3. **Queue depth?** → check OpenClaude server logs

---

## Next Steps

1. **Install OpenClaude** (Docker or venv)
2. **Verify with `test-openclaude.js`**
3. **Use in Discord/Jit**: `!jit spawn openclaude <task>`
4. **Monitor in production**: check status with `!jit backend`
5. **Save learnings to Oracle**:
   ```bash
   bash limbs/oracle.sh learn "openclaude-integration" \
     "Integrated OpenClaude (self-hosted Claude API) into Jit multi-backend router..." \
     "openclaude,jit,multi-backend"
   ```

---

## Support & Resources

- **OpenClaude GitHub**: https://github.com/Gitlawb/openclaude
- **Jit System**: `/workspaces/Jit`
- **Model Router**: `hermes-discord/model-router.js`
- **Skill Docs**: `.github/skills/openclaude-for-jit/SKILL.md`

---

*OpenClaude + Jit Integration*
*2026-05-08 | ศีล · สมาธิ · ปัญญา*
