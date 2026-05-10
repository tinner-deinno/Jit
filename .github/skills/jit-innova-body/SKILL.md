# SKILL: jit-innova-body — Jit เข้าร่าง innova-bot

## What This Skill Does

**Jit (จิต) สวมร่าง innova-bot** — Master Orchestrator ใช้ร่างกายของ innova-bot
เป็นแขนขา ควบคุมทุกอย่างผ่าน identity เดียว

| Layer | What Jit gets |
|-------|--------------|
| **MCP Tools** | 102 innova-bot tools (oracle, agents, git, workspace, etc.) |
| **psi/ Memory** | soul_sync, javis_personality, oracle_skills_manifest, innova_bot_understanding |
| **Organ Agents** | 14 organ agents (jit, soma, innova, lak, neta, + Tier-3 specialists) |
| **Multi-backend** | Copilot → OpenAI → MDES Ollama rotation |
| **Sub-agents** | innova-bot `javis_spawn_team` for complex tasks |
| **Orchestrator** | `what_should_i_do_next` AUTO-CONTINUE protocol |

---

## Files Created

| File | Purpose |
|------|---------|
| `hermes-discord/jit-innova-bridge.js` | HTTP bridge Jit→innova-bot MCP (port 7010) |
| `hermes-discord/model-router.js`      | Multi-backend LLM router (Copilot/OpenAI/Ollama) |
| `hermes-discord/agent-spawner.js`     | 14-organ agent spawn registry |
| `minds/jit-possess-innova.js`         | Main possession script (Jit as User) |
| `scripts/jit-possess-test.ps1`        | Full test suite (PowerShell) |
| `.github/skills/innova-body/SKILL.md` | This file |
| `.github/skills/innova-body/tool-index.md` | Auto-generated MCP tool index (after --sync) |
| `memory/innova-snapshot/`             | Auto-synced psi/ memory snapshots |

---

## Command Reference

### Node.js Direct

```bash
# Show full system status (identity + MCP + memory + agents)
node minds/jit-possess-innova.js --status

# Sync innova-bot skills → Jit (.github/skills/innova-body/ + memory/innova-snapshot/)
node minds/jit-possess-innova.js --sync

# Spawn multiagent team for a task
node minds/jit-possess-innova.js --team "Build a secure REST API"

# Interactive mode (status + sync + demo)
node minds/jit-possess-innova.js
```

### Discord Commands

| Command | Action |
|---------|--------|
| `!jit possess` | Show full Jit body status (identity, backends, MCP, organs) |
| `!jit innova health` | innova-bot MCP health check |
| `!jit innova tools` | List all 102 MCP tools by category |
| `!jit innova memory` | Show psi/ memory state |
| `!jit innova recap` | Oracle session recap |
| `!jit innova do SA` | ทำต่อไป orchestrator (role=SA by default) |
| `!jit innova <tool>` | Call any innova-bot MCP tool directly |
| `!jit innova <tool> {"key":"val"}` | MCP tool with JSON params |
| `!jit spawn chain jit+soma+innova <task>` | Serial agent chain |
| `!jit spawn parallel soma,innova,lak <task>` | Parallel agents |
| `!jit agents` | Full agent registry (14 agents + backends) |
| `!jit backend` | Model router status |

### Test Script

```powershell
# Full system test (9 sections)
pwsh -ExecutionPolicy Bypass -File scripts\jit-possess-test.ps1
```

---

## Architecture

```
Jit (จิต) — Master Identity
  │
  ├── hermes-discord/model-router.js
  │     Copilot → OpenAI → MDES Ollama rotation
  │     auto-detects Copilot from apps.json
  │     caches token 25min
  │
  ├── hermes-discord/agent-spawner.js
  │     14 organs: jit soma innova lak neta vaja chamu rupa
  │                pada netra karn mue pran sayanprasathan
  │     spawnAgent / spawnAgentChain / spawnAgentParallel
  │
  ├── hermes-discord/jit-innova-bridge.js
  │     HTTP → http://127.0.0.1:7010 (innova-bot MCP)
  │     callMcpTool(name, params)        — any of 102 tools
  │     checkMcpHealth()                 — GET /health
  │     listMcpTools()                   — GET /tools/list
  │     getInnovaMemory()               — read psi/ directly
  │     spawnInnovaSubagent(task)       — javis_spawn_team
  │     whatShouldIDo(role, project)    — ทำต่อไป
  │     oracleRecap()                   — oracle_recap
  │     oracleLearnSkill(content, name) — oracle_learn_skill
  │     oracleTrace(query)              — oracle_trace
  │
  └── minds/jit-possess-innova.js
        showStatus()    — full system health
        syncSkills()    — pull tool index + psi/ → Jit memory
        spawnTeam(task) — 4-phase: jit decide → parallel organs
                          → MCP sub-agents → vaja summary
        interactiveMode() — status + sync + demo
```

---

## innova-bot Identity (จาก psi/)

- **Name**: Javis (จาวิส) / innova
- **Soul**: Tech specialist, Thai-bilingual, 102 skills, 8-agent team
- **Personality**: พูดตรง, ปรับตาม context, remember user preferences
- **Skills**: 21 base (recap/rrr/learn/trace/team-agents...) + 28 GSD + extended
- **Agents**: bigboss (orchestrator), time_travel_debugger, predictive_tech_lead,
  self_healer, knowledge_sync, war_room_engine, bounty_hunter,
  invisible_devops, proactive_solver, repo_maintainer, true_actuator

---

## Standard Team Flow (Jit as User)

```
Task → Jit decides strategy (model-router)
      → Assigns 3 organ agents
      → Phase 2: Parallel organ spawn (soma + innova + lak)
      → Phase 3: innova-bot javis_spawn_team (if MCP online)
               + what_should_i_do_next (ทำต่อไป)
      → Phase 4: vaja summarizes → delivers to user
```

---

## Environment Variables

```
MCP_HOST=127.0.0.1          innova-bot host
MCP_PORT=7010               innova-bot MCP port
PSI_DIR=<path>              psi/ memory root (auto-detect if not set)
MULTI_BACKEND_ORDER=copilot,openai,ollama
OLLAMA_TOKEN=<token>        MDES Ollama auth
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
OLLAMA_MODEL=gemma4:e4b
OPENAI_API_KEY=sk-...       Optional — for OpenAI/Codex backend
DISCORD_TOKEN=...           Discord bot token
```

---

## Starting innova-bot MCP Server

```bash
cd C:\Users\USER-NT\DEV\innova-bot-template\devtools\innova-bot
python -m innova_bot
# MCP server starts at http://127.0.0.1:7010
```

---

## Programmatic Usage

```javascript
const bridge      = require('./hermes-discord/jit-innova-bridge');
const modelRouter = require('./hermes-discord/model-router');
const agentSpawner = require('./hermes-discord/agent-spawner');

// 1. Check MCP health
const health = await bridge.checkMcpHealth();

// 2. List all 102 tools
const tools = await bridge.listMcpTools();

// 3. Call any MCP tool
const result = await bridge.callMcpTool('oracle_recap', {});
console.log(result.text);

// 4. Spawn innova-bot team
const teamResult = await bridge.spawnInnovaSubagent('Refactor auth module', { teamSize: 3 });

// 5. Spawn Jit organ agents (multi-backend)
const reply = await agentSpawner.spawnAgent('soma', 'Analyze this architecture...');
console.log(reply.reply, '(via', reply.backend + ')');

// 6. Serial chain: jit → soma → innova
const chain = await agentSpawner.spawnAgentChain([
  { agent: 'jit',   message: 'Task: ' + task },
  { agent: 'soma',  message: 'Provide design', passReply: true },
  { agent: 'innova', message: 'Implement', passReply: true },
]);

// 7. Parallel
const parallel = await agentSpawner.spawnAgentParallel([
  { agent: 'soma',   message: task },
  { agent: 'lak',    message: task },
  { agent: 'chamu',  message: task },
]);
```

---

## Oracle Save (after PASS)

```bash
bash limbs/oracle.sh learn "jit-innova-possession" \
  "Jit possesses innova-bot via MCP bridge at port 7010. Uses jit-innova-bridge.js to call all 102 MCP tools. Syncs psi/ memory. Spawns sub-agents via javis_spawn_team. Jit is the master identity acting as the user." \
  "jit,innova-bot,mcp,possession,multiagent,soul-fusion"
```

---

*Created: 2026-05-07 | Author: Jit (จิต) — Master Orchestrator*
