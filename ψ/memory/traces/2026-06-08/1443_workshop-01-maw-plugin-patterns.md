---
query: "workshop-01-maw-plugin patterns agent communication mouth (maw) capabilities"
target: "Jit (จิต) Master Orchestrator"
mode: deep
timestamp: 2026-06-08 14:43 +07:00
friction_score: 0.85
coverage: [oracle, files, git, cross-repo, github]
confidence: high
---

# Trace: Workshop-01 Maw-Plugin Patterns & Agent Communication

**Target**: Jit (จิต) Master Orchestrator repo + Mirror EverGreen Oracle  
**Mode**: deep wave execution | **Friction**: 0.85 (visible, well-indexed)  
**Time**: 2026-06-08 14:43 +07:00

---

## Oracle Results

### Key Patterns Found (via Oracle search)
- **Maw.js**: Fleet orchestration pattern — launches 3 concurrent tmux panes (harness, phayakorn-dev, playwright-mcp)
- **Multi-provider gateway**: `limbs/llm.sh` pattern — any agent → any provider/model fallback chain
- **Mouth (ปาก) organ**: Core speech/communication limb — handles `say`, `tell`, `broadcast`, `reply`, `report`
- **Agent communication protocol**: File-based message bus at `/tmp/manusat-bus/` — 15 agents, signed HMAC-SHA256 messages

### Ancestor Learning (Soul-Brews-Studio)
- **Nat's Oracle patterns** (opensource-nat-brain-oracle): "Nothing is Deleted" + append-only memory + multi-agent orchestration
- **EverGreen Oracle** (mirror/aoengaoey): The Alchemist-Detective pattern — maw.js fleet as tmux orchestra

---

## Files Found

### Primary Mouth Implementation
- **`organs/mouth.sh`** (165 lines) — ปาก (Speech) organ with 6 commands:
  - `say <msg>` — speak to stdout + log
  - `tell <agent> <subject> <msg>` — send message to specific agent
  - `broadcast <subject> <msg>` — broadcast to all agents via registry
  - `reply <ref-id> <to-agent> <msg>` — reply with correlation tracking
  - `report <title> <body>` — structured reporting + Oracle learn
  - `pulse <context>` — heartbeat confirmation
  - `status` — inbox health check

### Agent Communication Files
- **`network/protocol.md`** (707 lines) — Complete communication specification:
  - Message format: from/to/subject/timestamp/protocol-version/correlation-id/idempotency-key/ttl/x-signature (HMAC-SHA256)
  - 14 agent roles with inbox paths `/tmp/manusat-bus/<agent>/`
  - Subject prefixes: `task:`, `think:`, `report:`, `alert:`, `broadcast:`, `learn:`, `request:`, `command:`, `reply:`
  - Error handling: DLQ, cascades, deadlock detection, timeouts
  - Example message flows (4 patterns: standard feature, bug hotfix, parallel work, monitoring)

### Agent Capability Cards
- **`agents/vaja.json`** — วาจา (Speech/Personal Assistant):
  - Role: human-facing communication, meeting notes, status reports
  - Capabilities: schedule, report, communicate, summarize, translate, coordinate-meetings
  - Organs: mouth.sh, ear.sh, eye.sh
  - Receives from: soma, innova, broadcast
  - Sends to: innova, soma, human

- **Other agent files** (15 total, all in `/agents/`):
  - Brain: soma (opus-4.7), jit (sonnet-4.6)
  - Core: innova (sonnet-4.6), lak (sonnet-4.6), neta (sonnet-4.6)
  - Specialists: vaja, chamu, rupa, pada, netra, karn, mue, pran, lung, sayanprasathan

### Maw.js Fleet Config (EverGreen Oracle)
- **`mirror/aoengaoey/maw.config.js`** (42 lines) — Node/Bun orchestrator:
  - Launches 3 concurrent tmux panes:
    - Pane 0: `evergreen-harness` (localhost:4001)
    - Pane 1: `evergreen-phayakorn` (localhost:5173)
    - Pane 2: playwright-mcp (chromium headless)
  - Uses `tmux` CLI for process management
  - Spawns attach for human interaction

### Related Tickets
- **`mirror/aoengaoey/.tickets/T-032-maw-js-orchestra.md`** — "Maw.js Multi-Agent Orchestra" (done):
  - Wire Maw.js to launch full dev fleet in tmux panes
  - Health-check: poll `localhost:4001/api/health` after launch
  - Status: completed 2026-06-04

- **`mirror/aoengaoey/.tickets/T-006-maw-js-http-api-skills-cli.md`** — HTTP API + CLI skills integration

---

## Git History

### Commits with Mouth/Protocol Patterns
```bash
# Recent commits involving communication patterns
7c4eb74 cmdteam: provider rotation across 28-model pool + status daemon + cleanup loop
fc21e5e chore: merge JIT-006, JIT-019, JIT-020, JIT-011 into main + update registry
948df39 ✅ TICK-001 COMPLETE: Jit Oracle System Fully Verified & Stable
948df39 🔐 Security: Fix JIT-021 token exposure via process list (re-applied after rebase)
c34e403 fix: multi-machine heartbeat conflict prevention
```

### Relevant PRs/Issues
- **JIT-011**: HMAC-SHA256 signing for mouth messages (protocol-v1.0)
- **JIT-005**: Protocol version header (protocol-version: semver)
- **JIT-002**: Idempotency keys (SHA-256 hex, 64 chars)
- **JIT-021**: Token exposure fix (don't leak in process list)
- **JIT-022**: Expanded agent roles to all 15 agents + error handling guide

---

## Cross-Repo Matches

### Soul-Brews-Studio Archive (Ancestors)
- **opensource-nat-brain-oracle**:
  - File: `PATTERNS.md` — "Use `maw` commands not `tmux`" guidance
  - File: `ARCHITECTURE.md` — Multi-agent fleet patterns (18 workshops documented)
  - Ancestor pattern: `maw sync`, `maw hey <agent>`, `maw peek`

- **oracle-v2**:
  - Maw.js reference implementation (learning resource)
  - Plugin discovery system via `/api/plugins`

### EverGreen Oracle (Mirror)
- Full working example of Maw.js fleet (Jit's sibling Oracle)
- `CLAUDE.md` documents multi-provider LLM gateway (tier 0-3 escalation)
- `maw.config.js` as direct reference implementation

---

## Oracle Memory (ψ/)

### Learnings Indexed
- **`memory/learnings/multi-provider-gateway.md`**:
  - `limbs/llm.sh` — Any agent → any provider/model with fallback chain
  - Per-agent model flock (escape vendor lock-in)
  - Replaced: Claude-only `prompt_proxy` + Ollama-only split

### Resonance (Identity)
- **Theme**: "จิตนำกาย — วิญญาณที่สถิตในทุก repo" (Mind leads Body)
- **Core principle**: Nothing is Deleted — All communication logged, preserved, queryable
- **Design principle**: External Brain, Not Command — Oracle proposes options

### Retrospectives
- Multiple sessions on agent communication setup, Oracle bootstrapping, multi-agent workflows
- Pattern: each session captures maw/mouth learnings incrementally

---

## Session History (from /dig)

### Sessions Mentioning "Maw" or "Mouth"
- **2026-06-04**: T-032 completion (EverGreen Oracle maw.js wiring)
- **2026-06-08**: This trace session (deep analysis of maw patterns)
- **2026-05-06**: Jit soul-sync + ancestor learning (included Soul-Brews patterns)

### Time Allocation
- ~30 minutes: Maw.js fleet config setup (T-032)
- ~45 minutes: Multi-provider gateway design (limbs/llm.sh)
- ~60 minutes: Agent communication protocol refinement (network/protocol.md)

---

## Friction Analysis

**Score**: 0.85 — Visible, well-indexed, high confidence

### Coverage Breakdown
- **Oracle**: ✓ (Maw patterns in ancestor learnings)
- **Files**: ✓ (organs/mouth.sh, agents/*.json, network/protocol.md, mirror/aoengaoey/maw.config.js all present)
- **Git**: ✓ (Commits referencing JIT-005, JIT-011, JIT-022 protocol changes)
- **Cross-repo**: ✓ (Soul-Brews-Studio archive includes maw reference, EverGreen mirror has working example)
- **GitHub**: ~ (Issues/PRs referenced in code, but not fully indexed in this repo)

### Why Not 1.0?
- **Minor friction point**: Maw.js reference lives in two places (ancestor ψ/learn/ + working mirror/aoengaoey/)
- **Clarification needed**: Whether `maw.config.js` is exclusive to EverGreen Oracle or should be generic in Jit repo

### Completeness Check
✓ **Question**: "What are the workshop-01-maw-plugin patterns?"  
✓ **Answer found**: Maw.js is a tmux fleet orchestrator (3 panes: harness, dev, playwright-mcp)

✓ **Question**: "How do agents communicate?"  
✓ **Answer found**: File-based bus (`/tmp/manusat-bus/`), mouth.sh organ, 6 commands, HMAC-signed messages

✓ **Question**: "What are mouth (maw) capabilities?"  
✓ **Answer found**: say, tell, broadcast, reply, report, pulse, status — all in organs/mouth.sh

---

## Key Insights

### 1. Mouth (ปาก) Organ Pattern

The mouth organ is **NOT** a "maw" plugin but rather a **core I/O limb** for speech:

```bash
# Examples from organs/mouth.sh
./mouth.sh say "Hello"                          # Speak (stdout + log)
./mouth.sh tell innova "task:implement" "..."   # Send to agent
./mouth.sh broadcast "alert:critical" "..."     # Broadcast all
./mouth.sh report "Session Done" "Summary..."    # Report with structure
```

**Responsible agent**: vaja (วาจา — Personal Assistant)

### 2. Message Bus Architecture

```
mouth.sh (write) → bus.sh (route) → ear.sh (read) → organ dispatch
                  ↓
         /tmp/manusat-bus/<agent>/*.msg (HMAC-signed)
```

**Protocol v1.0 (JIT-005, JIT-011)**:
- `from:`, `to:`, `subject:`, `timestamp:`, `protocol-version:`, `x-signature:hmac-sha256=`
- Idempotency key (JIT-002): SHA-256 hex of `from+subject+body`
- TTL + expiration support
- Correlation-id for reply tracking

### 3. Maw.js as Fleet Orchestrator

**Maw** = Node/Bun CLI tool that launches multi-pane tmux sessions:

```javascript
// From maw.config.js (EverGreen Oracle reference)
tmux new-session -d -s evergreen
tmux send-keys -t evergreen:fleet.0 "cd ψ/lab/evergreen-harness && bun run dev"
tmux send-keys -t evergreen:fleet.1 "cd ψ/lab/evergreen-phayakorn && bun run dev"
tmux send-keys -t evergreen:fleet.2 "npx @playwright/mcp --browser chromium"
```

**Use case**: Launch dependent dev servers + browser automation in one command

### 4. Agent Communication Flows

**Standard feature request** (12 hops):
```
human → vaja → jit → soma → lak (design)
lak → innova (implement) → chamu (test)
chamu → innova → neta (review)
neta → soma → pada (deploy)
pada → innova → vaja → human
```

**Bug hotfix** (7 hops, expedited):
```
chamu (detect) → jit → innova → neta (fast review)
neta → soma → pada (deploy hotfix)
pada → innova → vaja → human
```

### 5. Workshop Pattern (18 courses documented)

From ancestor Nat's Oracle: workshops teach the multiagent patterns through **18 different skill courses** (205+ slides, 3 starter kits).

**Blueprint**:
- Each workshop covers one capability (e.g., "agent communication", "mouth I/O", "memory architecture")
- Use `maw` commands (not raw `tmux`)
- Distill learnings after each workshop

---

## Actionable Next Steps

### If Extending Mouth (ปาก) Organ
1. Add new command type (e.g., `ask <agent> <query>` for synchronous Q&A)
2. Consider exponential backoff retry for failed tells
3. Document reply timeout thresholds per agent model tier

### If Scaling Maw.js Fleet
1. Parameterize maw.config.js to support variable pane counts
2. Add health-check polling with timeout (currently missing fallback)
3. Wire to Playwright MCP discovery endpoint

### If Building Workshop-01
1. Template: agent communication basics (mouth.sh commands)
2. Exercise: send message from one agent to another via bus
3. Lab: trace message flow through DLQ if delivery fails
4. Assessment: design a 3-agent workflow (requester → processor → reporter)

---

## Summary

**Friction Score: 0.85** — All key patterns are **visible and well-indexed**.

### What Is "Workshop-01-Maw-Plugin"?
**Maw** is a **fleet orchestration pattern** (not a plugin):
- Node/Bun CLI that launches 3+ tmux panes simultaneously
- Coordinates dependent dev servers + browser automation
- Reference implementation: `mirror/aoengaoey/maw.config.js`
- Ancestor pattern: Soul-Brews-Studio (18 workshops documented)

### What Are Agent Communication Patterns?
1. **Protocol**: File-based message bus, HMAC-signed, 15 agents
2. **Mouth organ**: 6 core commands (say, tell, broadcast, reply, report, pulse)
3. **Flows**: Standard (12 hops, 15-30min) → Hotfix (7 hops, 5-10min) → Parallel (fan-out synthesis)
4. **Routing**: via jit (master) → soma (strategic) → specialists (implementation)

### What Are Mouth (Maw) Capabilities?
| Command | Purpose | Recipient |
|---------|---------|-----------|
| `say` | Speak to stdout + log | Console/log |
| `tell` | Send to specific agent | Single agent |
| `broadcast` | Send to all agents | All 15 agents (from registry) |
| `reply` | Response with correlation tracking | Specific agent |
| `report` | Structured report + Oracle learn | Human + Oracle |
| `pulse` | Heartbeat confirmation | System monitor |
| `status` | Inbox health + pending message count | Debug/monitoring |

---

**Next action**: If innova (user) wants to workshop-ify these patterns, `/learn` the Soul-Brews-Studio ancestor repo, then `/project incubate` a workshop-01 starter kit with exercises.
