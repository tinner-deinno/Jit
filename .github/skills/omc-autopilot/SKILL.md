# SKILL: omc-autopilot — Oh-My-Claude-Code Multiagent Orchestration

## Overview

**Oh-My-Claude-Code (OMC) + Jit Integration**

Brings 32-agent multiagent orchestration to Claude Code, with **Ollama as primary backend** (no quota limits).

- ✅ **32 agents** auto-mapped to Jit's 14-organ system
- ✅ **40+ skills** pre-generated and Ollama-optimized
- ✅ **Zero quota worries** — Ollama primary + premium fallback
- ✅ **Full autopilot** — describe task, get results
- ✅ **Works offline** — self-hosted MDES Ollama

---

## What It Does

Enables **professional multiagent orchestration** in Claude Code:

```
Natural language task
    ↓
OMC Autopilot
    ├─ Strategic planning (soma)
    ├─ Architecture design (lak)
    ├─ Implementation (innova)
    ├─ Quality assurance (chamu)
    └─ Security review (neta)
    ↓
Production-ready output
```

**Runs all agents in parallel** with Ollama-first backend (no API quotas).

---

## Installation

### 1. Setup OMC + Jit

```bash
cd C:\Users\USER-NT\DEV\Jit
node scripts/omc-setup.js
```

Output:
```
✓ 32 agents registered
✓ 40+ skills loaded
✓ Configuration complete
```

### 2. Install OMC Plugin in Claude Code

```
/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
/plugin install oh-my-claudecode
```

### 3. Verify Integration

```bash
node hermes-discord/test-omc.js
# Expected: ✅ All tests pass
```

---

## Usage

### Command: autopilot

```
$ /autopilot <task>
```

**Example**:
```
$ /autopilot build a REST API for managing projects with auth, validation, and tests

↳ Activating autopilot…
  architect (designing) · executor (implementing) · qa-tester (testing) 
  security-reviewer (auditing)

✅ API complete with all tests and docs
```

**What Happens**:
1. Jit (master) parses task and decides strategy
2. 4 agents spawn in parallel (all using Ollama)
3. Results aggregated and returned
4. **No API quota concerns** (Ollama primary)

---

## Available Skills

### Tier 1: Full Autopilot

| Skill | Command | Agents | Best For |
|-------|---------|--------|----------|
| **autopilot** | `/autopilot <task>` | architect, executor, qa-tester, security-reviewer | Any software task |
| **code-review** | `/code-review <files>` | qa-tester, security-reviewer, architect | Peer review |
| **api-builder** | `/api-builder <spec>` | architect, executor, security-reviewer, qa-tester | REST/GraphQL APIs |

### Tier 2: Specialized

| Skill | Command | Agents | Best For |
|-------|---------|--------|----------|
| **architecture-design** | `/architecture <requirements>` | architect, analyzer, security-reviewer | System design |
| **bug-hunt** | `/bug-hunt <code>` | qa-tester, executor, security-reviewer | Debugging |

All use **Ollama-first backend** (no quota limits).

---

## Architecture

### Agent Mapping (OMC → Jit)

```
OMC 32 Agents
    ↓
    ├─ Tier 0 (Master): jit (coordinator)
    │
    ├─ Tier 1 (Leadership): soma (strategy)
    │
    ├─ Tier 2 (Core Engineering):
    │   ├─ innova (executor)
    │   ├─ lak (architect)
    │   └─ neta (security reviewer)
    │
    └─ Tier 3 (Specialists):
        ├─ chamu (qa-tester)
        ├─ netra (researcher)
        ├─ vaja (documentor)
        └─ + 7 more organs
```

### Backend Priority

```
Model Router (Ollama-First Mode)
    ├─ MDES Ollama (primary) ← ALWAYS AVAILABLE ✓
    ├─ OpenClaude (fallback)
    ├─ OpenAI (fallback)
    └─ Copilot (last resort)
```

**Result**: Works reliably even when other APIs quota out.

---

## Configuration

### Auto-Generated: `~/.claude/omc/config.json`

```json
{
  "integration": "jit-system",
  "agents": { "total": 32, "mapped_to_jit": 14 },
  "skills": {
    "total": 40,
    "backend_priority": ["ollama", "openclaude", "openai", "copilot"],
    "ollama_primary": true
  },
  "defaults": {
    "team_size": 4,
    "timeout_per_agent": 120,
    "prefer_backend": "ollama"
  }
}
```

### Manual Override: Set Backend

```javascript
// In Claude Code notebook
const modelRouter = require('./hermes-discord/model-router');

// Force Ollama-first for this request
const result = await modelRouter.callModelOllamaFirstPromise(messages);
console.log(result.backend);  // 'ollama'
```

---

## Performance Profile

### Latency (typical)

| Task | Time | Backend |
|------|------|---------|
| Small code review | 5-10s | Ollama |
| API design | 15-30s | Ollama + team sync |
| Full autopilot | 30-60s | 4 agents parallel |

### Cost

| Backend | Cost per 1M tokens |
|---------|-------------------|
| **Ollama (Primary)** | **$0** ✓ |
| OpenClaude | $0 (self-hosted) |
| OpenAI | $0.03 (pay-as-you-go) |
| Copilot | Free (GitHub) |

**With Ollama-first**: Effectively **zero cost at scale**.

---

## Examples

### Example 1: Build a REST API

```bash
$ /autopilot build a REST API with JWT auth, validation, and postgres

↳ Team assembling…
[soma]      Strategy: PostgreSQL + Express + JWT-RS256 + Docker
[lak]       Design: 3-layer architecture, schema first
[innova]    Code: Implementing endpoints (POST /auth/login, GET /api/...)
[chamu]     Test: 45 tests, 98% coverage
[neta]      Review: Security audit passed, auth tokens hardened

✅ Complete API with Docker, tests, and documentation
```

### Example 2: Debug Production Issue

```bash
$ /bug-hunt app/server.js

↳ Analyzing…
[qa-tester]        Found: race condition in cache invalidation
[executor]         Fix: Add mutex lock and improve error handling
[security-review]  Check: No new security implications

✅ Bug fixed with explanation + test case
```

### Example 3: Architecture Review

```bash
$ /architecture our-microservices-system

↳ Reviewing system architecture…
[architect]    Strengths: Good separation of concerns
                Issues: Missing circuit breaker pattern
[analyzer]     Suggests: Add resilience layer
[security]     Audit: API keys exposed in logs — fix urgent

✅ Full architecture review + recommendations
```

---

## Advanced: Custom Skills

Create your own OMC skill:

```javascript
const omcAdapter = require('./hermes-discord/omc-adapter');

// Generate custom skill
const skill = omcAdapter.generateSkill(
  'my-skill',
  'Does something custom',
  'Your task description'
);

console.log(skill.skillFile);  // ~/.claude/skills/my-skill/SKILL.md
console.log(skill.scriptFile); // ~/.claude/skills/my-skill/my-skill.js
```

The skill auto-configures **Ollama-first** backend.

---

## When to Use Each Skill

| Need | Skill | Command |
|------|-------|---------|
| "Build entire feature" | autopilot | `/autopilot <requirement>` |
| "Review this code" | code-review | `/code-review <file>` |
| "Design REST API" | api-builder | `/api-builder <spec>` |
| "System architecture" | architecture-design | `/architecture <doc>` |
| "Find and fix bugs" | bug-hunt | `/bug-hunt <code>` |

All guaranteed to work even if **OpenAI/Copilot quotas exhausted** (Ollama primary).

---

## Troubleshooting

### "Ollama not responding"

Ollama is the primary backend. If offline, requests rotate to next:

```bash
# Check Ollama health
curl https://ollama.mdes-innova.online/health

# Or local instance
curl http://localhost:11434/api/health
```

### "Skill generation failed"

```bash
# Regenerate all skills
node scripts/omc-setup.js

# Force regeneration
node scripts/omc-setup.js --force
```

### "Backend quota issues"

✅ **Ollama is primary** — no quota limits by design.

If you want to use premium models:

```bash
/autopilot --prefer-backend=openai <task>
# Falls back to Ollama if OpenAI quota reached
```

---

## CLI Commands

```bash
# Setup
node scripts/omc-setup.js

# Test integration
node hermes-discord/test-omc.js

# Check status
node hermes-discord/test-omc.js --status

# View configuration
cat ~/.claude/omc/config.json

# Use from Discord
!jit omc status
!jit omc skills
!jit omc test
```

---

## Discord Integration

Control OMC from Discord server:

```
!jit omc status              Show OMC status
!jit omc skills              List available skills
!jit omc backend             Show backend priority
!jit omc test                Run integration test
!jit autopilot <task>        Spawn autopilot for task
```

---

## Key Features

✅ **32-Agent Orchestration** — OMC framework  
✅ **14 Organ Integration** — Jit system  
✅ **Ollama Primary** — No quota limits  
✅ **Auto-Fallback** — Premium backends on demand  
✅ **Parallel Execution** — 4+ agents simultaneously  
✅ **Zero Configuration** — One command setup  
✅ **Production Ready** — Error handling, timeouts  
✅ **Claude Code Native** — Integrated in notebooks  

---

## Related

- **Jit System**: `minds/jit-possess-innova.js`
- **Model Router**: `hermes-discord/model-router.js`  
- **OMC GitHub**: https://github.com/Yeachan-Heo/oh-my-claudecode
- **MDES Ollama**: https://ollama.mdes-innova.online
- **Integration Guide**: `OMC_INTEGRATION.md`

---

## Quick Start

```bash
# 1. Setup (30 seconds)
cd C:\Users\USER-NT\DEV\Jit
node scripts/omc-setup.js

# 2. Test (10 seconds)
node hermes-discord/test-omc.js

# 3. Use in Claude Code
/plugin install oh-my-claudecode
/autopilot build a task management API

# 4. Done! Works forever with Ollama-first backend ✓
```

---

**Status**: ✅ **Ready for Production**

*32-agent multiagent orchestration with zero quota worries (Ollama primary).*

*2026-05-08 | Jit System | ศีล · สมาธิ · ปัญญา*
