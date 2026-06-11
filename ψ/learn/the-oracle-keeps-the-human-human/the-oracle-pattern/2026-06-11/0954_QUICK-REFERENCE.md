# The Oracle Pattern — Quick Reference Cheatsheet

**Source**: the-oracle-pattern.pdf + Jit system documentation  
**Date**: 2026-06-11  
**Focus**: Practical "how to" for Oracle Office, Fleet, maw.js, and innova setup

---

## 1. ORACLE OFFICE & ORACLE SERVERS

### What Is Oracle Office?
- **Oracle Office** = Long-term memory engine (Arra Oracle V3) running as a git-tracked knowledge base
- **Not a GUI office app** — it's a REST API server that stores and searches learned knowledge
- **Purpose**: Knowledge base with FTS5 full-text search + LanceDB vector search
- **Port**: 47778 (default, configured in $ORACLE_PORT env var)
- **Tech**: Runs on Bun (fast TypeScript runtime)

### Key Oracle Instances in This Codebase
1. **arra-oracle-v3** (production long-term memory)
   - GitHub: Soul-Brews-Studio/arra-oracle-v3
   - Candidates: C:\Users\USER-NT\DEV\arra-oracle-v3 or /workspaces/arra-oracle-v3
   - Role: Long-term learned knowledge; queried before major decisions

### How to Set Up Oracle Office

#### Step 1: Clone Arra Oracle V3
`bash
git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3.git /workspaces/arra-oracle-v3
cd /workspaces/arra-oracle-v3
`

#### Step 2: Install Bun (if not already installed)
`bash
curl -fsSL https://bun.sh/install | bash
export PATH="C:\Users\USER-NT/.bun/bin:"
`

#### Step 3: Install Dependencies & Set Up Database
`bash
bun install
cp .env.example .env
# Edit .env: set OLLAMA_BASE_URL=https://ollama.mdes-innova.online
mkdir -p ~/.oracle
bun run db:push    # Create database schema
bun run index      # Index knowledge
`

#### Step 4: Start Oracle Server
`bash
ORACLE_PORT=47778 bun run src/server.ts &
# Or in background:
ORACLE_PORT=47778 bun run src/server.ts > /tmp/oracle-server.log 2>&1 &
`

#### Step 5: Verify Oracle Health
`bash
curl http://localhost:47778/api/health
# Should return: {"status":"ok"}
`

### Oracle API Usage (from Agent Code)
- Health check: GET http://localhost:47778/api/health
- Learn/store knowledge: POST to Oracle endpoints (see limbs/oracle.sh)
- Search knowledge: Full-text and vector search (before decisions)

---

## 2. INNOVA-BOT BODY & GUI BINDING

### What Is innova-bot?
- **innova-bot** = The shared "body" (runtime, GUI, backend) for any Jit agent
- Separate from Jit mind — Jit holds identity/memory, innova-bot is execution engine
- Provides: REST backend (port 7010), Web GUI, TUI, MCP server, message routing
- **Jit Mind** = your-agent repository (identity, memory, values)
- **innova-bot Body** = /workspaces/innova-bot or C:\Users\USER-NT\DEV\innova-bot-template

### How to Access innova-bot GUI

#### Web GUI (if innova-bot is running)
`
http://127.0.0.1:7010/gui
`

#### TUI (Text User Interface)
`bash
cd /workspaces/innova-bot
python -m innova_bot.gui.rpg_tui
`

#### Start innova-bot Backend
`bash
cd /workspaces/innova-bot
python -m innova_bot.main &
# Backend will listen on port 7010
`

### Binding Configuration (config/jit-topology.json)
`json
{
  "body_repo_path": "/workspaces/innova-bot",
  "body_repo_candidates": [
    "/workspaces/innova-bot",
    "/mnt/c/Users/USER-NT/DEV/innova-bot-template",
    "C:\Users\USER-NT\DEV\innova-bot-template"
  ],
  "body_backend_cmd": "python -m innova_bot.main",
  "body_gui_url": "http://127.0.0.1:7010/gui",
  "body_tui_cmd": "python -m innova_bot.gui.rpg_tui",
  "body_mcp_port": 7010,
  "body_bridge_dir": ".jit-bridge/inbox"
}
`

#### Auto-Setup innova-bot Binding
`bash
# Set env var in .env:
INNOVA_BOT_REPO=https://github.com/<owner>/innova-bot.git
INNOVA_BOT_PATH=/workspaces/innova-bot

# Then run:
bash scripts/innova-bot-setup.sh
`

### innova-bot Ports & Endpoints
| Port | Service | URL |
|------|---------|-----|
| 7010 | Backend + GUI | http://127.0.0.1:7010/gui |
| 7010 | MCP Server | http://127.0.0.1:7010/sse (SSE transport) |
| 7012 | Alternative SSE | http://127.0.0.1:7012/sse |

---

## 3. FLEET — MULTI-AGENT BATCH ORCHESTRATION

### What Is Fleet?
- **Fleet** = Multi-provider worker batch system that runs 80+ AI agents in parallel
- Splits work across multiple LLM backends (MDES Ollama, ThaiLLM, Copilot, OpenAI, etc.)
- Tracks worker completion, retries on failure (up to 2 attempts)
- Discord notifications every 10 minutes (if configured)

### Fleet Command Basics

#### Command: node mother.js chat
Run a single phase with a goal/prompt:
`bash
node mother.js chat "Find security risks in the codebase"
# Streams result back to console; one squad -> verify -> leaderboard cycle
`

#### Command: node mother.js run
Run multiple phases until convergence:
`bash
node mother.js run "Harden the system" 10
# Runs up to 10 phases automatically; stops early if stable
`

#### Command: node mother.js status
Show unified system status:
`bash
node mother.js status
# Shows: providers alive, leaderboard, event loop, bridge status
`

#### Command: node mother.js probe
Refresh provider liveness (detect outages):
`bash
node mother.js probe
# Tests: ollama_mdes, thaillm, ollama_cloud, copilot, etc.
# Updates: network/provider-status.json
`

#### Command: node mother.js events
Show dispatch history:
`bash
node mother.js events      # Last 10 events
node mother.js events 50   # Last 50 events
`

### Fleet Batch Direct Command (eval/fleet-batch.js)
For detailed control:
`bash
node eval/fleet-batch.js \
  --count 84 \
  --concurrency 8 \
  --attempts 2 \
  --lanes ollama_mdes,thaillm,ollama_cloud \
  --goal "Find concrete risks in innomcp"
`

**Fleet Command Flags:**
- --count N: number of workers (default 84)
- --concurrency N: parallel workers (default 8)
- --attempts N: retries on failure (default 2)
- --lanes lane1,lane2: comma-sep provider lanes (default: automatic)
- --exclude-lanes lane: exclude specific providers
- --goal "text": the goal/prompt for all workers
- --goal-file path.txt: read goal from file
- --worker-timeout-ms N: timeout per worker (default 45000ms)
- --require-min-count N: fail batch if < N workers built
- --require-min-ok N: fail batch if < N workers succeeded
- --no-discord: skip Discord reporting
- --include-openai: add OpenAI to lanes
- --include-innova-bot: add innova-bot to lanes

### Fleet Provider Lanes (Backends)
| Lane | Backend | Models | Status |
|------|---------|--------|--------|
| ollama_mdes | Remote Ollama | gemma4:26b | Usually alive |
| 	haillm | ThaiLLM cluster | 4 models (OpenThaiGPT, Pathumma, Typhoon, THaLLE) | Usually alive |
| ollama_cloud | Cloud Ollama | gemma4:31b-cloud, nemotron-3-super:cloud | Usually alive |
| commandcode | CommandCode | DeepSeek, other models | Medium usage |
| copilot | GitHub Copilot | claude-sonnet-4.6 | Often quota-limited |
| ollama_local | Local Ollama | qwen2.5-coder:7b | May timeout |
| openai | OpenAI API | gpt-5.5 (if enabled) | Expensive; kept out by default |
| innova_bot | innova-bot SSE | Local model | Fallback; low concurrency |

### Fleet Artifacts & Output
After running 
ode eval/fleet-batch.js:
- **Directory**: 
etwork/artifacts/fleet-batch-<TIMESTAMP>/
- **summary.json**: Full results, per-worker replies, metrics
- **summary.md**: Markdown report
- **proof-manifest.json**: Command, git state, requirement verdict, SHA-256 hashes
- **latest-fleet-progress.json**: Live streaming progress (updated every N workers)

### Fleet Health Checks
`bash
# Check all providers (smoke test content usability)
./.codex/skills/agent-fleet-budget/scripts/check-fleet.mjs --smoke

# Provider probe (detailed backend status)
node eval/provider-probe.js --timeout 70000

# Doctor (full system health)
node eval/doctor.js
`

---

## 4. MAW.JS — MULTI-AGENT WORKFLOW ENGINE

### What Is MAW?
- **MAW** = Multi-Agent Workflow orchestration engine (written in TypeScript/Bun)
- Orchestrates AI agents across tmux sessions (macOS/Linux) or Windows terminal
- 15 CLI verbs to manage agent teams, workspaces, UI, status
- Controls: team charters, standing multi-agent pipelines, cross-repo worktrees

### MAW Repository
`
C:\Users\USER-NT\DEV\maw-js
/mnt/c/Users/USER-NT/DEV/maw-js
`

### MAW CLI Installation
`bash
# Clone maw-js
git clone https://github.com/Soul-Brews-Studio/maw-js.git C:\Users\USER-NT\DEV\maw-js
cd maw-js
bun install

# Install global shim (optional)
bun run build
# Creates: C:\Users\USER-NT\.bun\bin\maw.exe or maw.bunx
`

### MAW Commands (Core 15 Verbs)

#### Team Management
`bash
maw team status            # List all teams
maw t status              # Shorthand for team status
maw team add <name>       # Create new team
maw team remove <name>    # Delete team
maw team edit <name>      # Edit team charter (YAML)
`

#### Workspace Management
`bash
maw workspace status      # List workspaces
maw workspace add <path>  # Register workspace
maw workspace remove <name>
`

#### Agent Orchestration
`bash
maw start <team>          # Start all agents in team (uses tmux/terminal)
maw stop <team>           # Stop all agents
maw restart <team>        # Restart agents
maw status <team>         # Agent process status
`

#### UI & TUI
`bash
maw ui status             # Check if maw-ui plugin installed
maw ui start              # Launch web dashboard (if available)
`

#### Live Verbs (Watch Logs)
`bash
maw logs <team> <agent>   # Stream agent logs
maw watch <team>          # Watch all agents in team
`

#### Example: Running an innomcp Team
`bash
# List teams
maw team status
# Output: innomcp, innova-bot-template, jit (all configured in this Jit instance)

# Start the innomcp team
maw start innomcp

# Watch status
maw status innomcp

# View logs
maw logs innomcp backend
maw logs innomcp frontend

# Stop
maw stop innomcp
`

### Team Charter (YAML Format)
Teams are defined in 	eams/team-charter.yaml:
`yaml
teams:
  innomcp:
    agents:
      - name: backend
        repo: /path/to/innomcp/backend
        cmd: npm start
      - name: frontend
        repo: /path/to/innomcp/frontend
        cmd: npm run dev
    parallel: true
    retries: 2
`

---

## 5. INNOVA-BOT & MAW.JS INTEGRATION

### Step-by-Step: Running Oracle Office + Fleet + innova-bot Together

#### Phase 1: Prepare Directories
`bash
# Ensure paths exist (from config/jit-topology.json):
ls /workspaces/arra-oracle-v3              # Oracle code
ls /workspaces/innova-bot                  # innova-bot code
ls C:\Users\USER-NT\DEV\maw-js            # MAW code (if on Windows)
`

#### Phase 2: Start Oracle Office (Background)
`bash
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts > /tmp/oracle-server.log 2>&1 &
sleep 2
curl http://localhost:47778/api/health
`

#### Phase 3: Start innova-bot Backend (Background)
`bash
cd /workspaces/innova-bot
python -m innova_bot.main > /tmp/innova-bot.log 2>&1 &
sleep 2
curl http://127.0.0.1:7010/gui
# Should return HTML
`

#### Phase 4: Optional — Use MAW to Manage Agents
`bash
# If using MAW:
maw start innomcp    # Start all innomcp agents
maw status innomcp   # Check status
maw logs innomcp     # Watch logs
`

#### Phase 5: Run Fleet Phase or Chat
From Jit repo:
`bash
cd /path/to/Jit
node mother.js chat "Verify innomcp hardness"
# Uses all running providers (Oracle, Ollama, Copilot, etc.)
`

#### Phase 6: Monitor via Dashboard
- **innova-bot GUI**: http://127.0.0.1:7010/gui
- **Leaderboard**: 
etwork/leaderboard.json (updated in real-time)
- **Fleet Events**: 
ode mother.js events 50
- **Provider Status**: 
etwork/provider-status.json

---

## 6. KEY DIFFERENCES: arra-oracle vs oracle-office vs oracle-pattern

### arra-oracle (Repository)
- **What it is**: The actual knowledge base + vector search server (Soul-Brews-Studio/arra-oracle-v3)
- **Technology**: Bun runtime, FTS5, LanceDB, REST API
- **Port**: 47778
- **Purpose**: Long-term memory; indexed learning events

### oracle-office (Concept)
- **What it is**: Any running instance of arra-oracle serving as an agent's memory office
- **Not a GUI**: It's a REST API endpoint; can be called from CLI, scripts, or agents
- **Binding**: config/jit-topology.json → oracle_url: http://127.0.0.1:47778
- **Usage**: curl http://localhost:47778/api/health, /api/learn, /api/search

### oracle-pattern (This Book)
- **What it is**: A design philosophy + implementation guide for multi-agent systems
- **Key concepts**:
  - Agents have a mind (Jit repo: identity, memory, values) + body (innova-bot: runtime)
  - Oracle is the collective long-term memory organ
  - MAW orchestrates teams of agents via tmux/terminal
  - Fleet runs 80+ agents in parallel across multiple LLM backends
- **Chapters**: 15 topics covering design, technical implementation, DNA lenses, soul portability
- **PDF**: 200+ pages, written entirely by AI agents (mawjs-oracle orchestrated Sonnet team)

---

## 7. ENVIRONMENT VARIABLES & CONFIGURATION

### .env (Never Committed)
`bash
INNOVA_NODE_ID=PC3-Jit
MCP_TRANSPORT=sse
MCP_HOST=127.0.0.1
MCP_PORT=7010
ORACLE_PORT=47778
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
OLLAMA_TOKEN=<secret-token>
DISCORD_TOKEN=<secret>
INNOVA_BOT_REPO=https://github.com/<owner>/innova-bot.git
INNOVA_BOT_PATH=/workspaces/innova-bot
`

### config/jit-topology.json (Agent Identity Binding)
`json
{
  "jit_id": "jit-innova-tinner",
  "oracle_url": "http://127.0.0.1:47778",
  "oracle_health": "http://127.0.0.1:47778/api/health",
  "body_repo_path": "/workspaces/innova-bot",
  "body_gui_url": "http://127.0.0.1:7010/gui",
  "body_mcp_port": 7010,
  "ollama_url": "https://ollama.mdes-innova.online"
}
`

### config/subagent-routing.json (Provider Routing)
Defines which agents route to which LLM backends (ollama_mdes, thaillm, copilot, etc.)

---

## 8. MANU API & INNOVA-BOT MESSAGE BUS

### MANU (Manus-like API)
- Not visible in PDF; inferred from mother.js code
- Mother provides a front-door CLI to the entire system
- Routes through innova-bot's MCP server (port 7010)

### Message Bus
- **Location**: /tmp/manusat-bus/ (local ephemeral) or file-based
- **Purpose**: Inter-agent communication on same machine
- **Protocol**: File events, JSON payloads
- **Bridge**: innova-bot reads/writes .jit-bridge/inbox for Jit mind

---

## 9. QUICK START COMMANDS (Copy-Paste)

### One-Line: Oracle + innova-bot + Fleet
`bash
# Terminal 1: Oracle
cd /workspaces/arra-oracle-v3 && \
ORACLE_PORT=47778 bun run src/server.ts

# Terminal 2: innova-bot
cd /workspaces/innova-bot && \
python -m innova_bot.main

# Terminal 3: Fleet chat
cd /path/to/Jit && \
node mother.js chat "Harden system security"
`

### Check System Health
`bash
node eval/oracle-readiness.ps1 -Json
# or (bash):
bash scripts/pc3_start_all.sh --status
`

### View Fleet Results
`bash
node mother.js status              # Current state
node mother.js events 20           # Last 20 dispatch events
node mother.js artifacts           # Show artifact runs
`

### Access innova-bot GUI
`
http://127.0.0.1:7010/gui
`

---

## 10. TROUBLESHOOTING

### Oracle Server Won't Start
`bash
# Check port 47778 is free
lsof -i :47778
# Kill stale process if needed:
kill -9 <PID>
# Check Bun is installed:
bun --version
`

### innova-bot Backend Errors
`bash
# Verify Python >= 3.10:
python --version
# Check port 7010 is free:
lsof -i :7010
# Read logs:
tail /tmp/innova-bot.log
`

### Fleet Workers Failing
`bash
# Check provider status:
node eval/provider-probe.js --timeout 70000
# Check leaderboard corruption:
cat network/leaderboard.json | jq .fleet
`

### MAW Team Status Offline
`bash
# Verify team is in teams/team-charter.yaml
cat teams/team-charter.yaml | grep -A 5 "^  <team-name>:"
# Start team:
maw start <team-name>
# Watch logs:
maw logs <team-name>
`

---

## 11. FURTHER READING

- **Jit Architecture**: docs/JIT_ARCHITECTURE.md
- **innova-bot Binding**: docs/JIT_INNOVA_BODY_BINDING.md
- **New Agent Bootstrap**: docs/new-agent-guide.md (Thai + English)
- **PC3 Runbook**: docs/PC3_AGENT_RUNBOOK.md
- **Fleet Details**: docs/FLEET_BATCH_2026_06_04.md
- **The Oracle Pattern PDF**: the-oracle-pattern.pdf (200+ pages, 15 chapters)

---

**Generated**: 2026-06-11 09:54 UTC  
**Format**: Markdown quick-reference for rapid copy-paste usage  
**Audience**: Developers, DevOps, AI agent engineers integrating Oracle + Fleet + innova-bot