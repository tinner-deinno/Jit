# The Oracle Pattern — Code Snippets & Patterns
**Source**: the-oracle-pattern.pdf + README.md  
**Extracted**: 2026-06-11 09:54

---

## Oracle Repo Structure (Code + Soul)
```
mawjs-oracle/
├── CLAUDE.md          # identity card
├── .maw/teams/        # team charters (YAML)
├── ψ/                 # soul vault
│   ├── inbox/         # messages
│   ├── memory/        # learnings
│   ├── outbox/        # handoffs
│   ├── plans/         # sprint plans
│   └── learn/         # research
└── agents/            # worktrees (codex-1, claude-1 ...)
```

## maw 15 Verbs
```bash
# Session
maw wake <oracle>      # open oracle in tmux window
maw sleep              # detach session
maw done               # close finished oracle
maw kill               # force kill

# Transport
maw bring <oracle>     # absorb window INTO current session
maw take <s>:<w>       # move window BETWEEN sessions
maw promote <window>   # eject window → new session

# Pane
maw open / close       # show/hide pane
maw split              # split pane beside

# Team
maw team up <charter>  # spawn all team members
maw team status        # show live/dead/missing per member

# Messaging
maw hey <member> "msg" # send message to agent
maw broadcast "msg"    # send to all

# Layout
maw tile               # arrange panes
```

## Team Charter (YAML)
```yaml
# .maw/teams/my-team.yaml
name: my-team
project: org/repo

members:
  - role: lead
    name: my-oracle
    engine: claude
    worktree: false
    prompt: "Lead orchestrator. Dispatch only, do NOT code."

  - role: builder
    name: codex-1
    engine: omx          # OpenAI Codex
    worktree: true
    prompt: "Wait for task via maw hey. PRs target alpha."
```

## Soul Portable (Git-versioned Memory)
```bash
# Commit soul + code together
git add ψ/
git commit -m "ψ/ -- forward: session complete"
git push

# View soul history
git log ψ/memory/
git diff HEAD~5 ψ/memory/
```

## Timestamp-First Inbox Files
```
ψ/inbox/2026-06-11_09-54_soma_task-implement-feature.md
ψ/outbox/2026-06-11_10-30_oracle_forward-session.md
Format: YYYY-MM-DD_HH-MM_source_slug.md
```

## Fleet Snapshot Pattern
```bash
maw fleet snapshots    # list all oracle sessions
# Fleet = registry of all running oracle sessions
# Enables: session recovery, multi-machine coordination
```

## Oracle Office = arra-oracle-v3
```bash
# Start (already running at localhost:47778)
ORACLE_PORT=47778 bun run src/server.ts
curl http://localhost:47778/api/health
# → {"status":"ok","version":"26.6.1","oracle":"connected"}

# Search knowledge
curl -X POST http://localhost:47778/api/search \
  -H "Content-Type: application/json" \
  -d '{"query":"oracle pattern","limit":5}'
```

## Fleet Batch (already in Jit repo)
```bash
# node eval/fleet-batch.js
node eval/fleet-batch.js --count 84 --concurrency 8 \
  --include-commandcode --include-thaillm
node mother.js chat|run|status|probe|events
```

## 10-DNA Design Lens
```
Torvalds   → layers, abstraction
Carmack    → precision verbs (15 verbs = Carmack principle)
Hickey     → immutability (ψ/ never deleted)
Kay        → messaging paradigm
Victor     → direct manipulation
Hashimoto  → composable CLI
Fowler     → seams, refactoring
Hightower  → declarative desired state
Buterin    → hub-and-spoke
Karpathy   → optimization
```

## Key Differences
| Term | Meaning |
|---|---|
| **arra-oracle-v3** | Actual implementation (REST API, FTS5+vector DB) |
| **Oracle Office** | Any running arra-oracle instance = localhost:47778 |
| **Fleet** | maw fleet / mother.js = multi-agent session registry |
| **oracle-pattern** | Design philosophy book (200+ pages) by Soul-Brews-Studio |
| **maw.js** | Open-source engine: 15 verbs + team charters + tmux |
| **ψ/ vault** | Soul = git-versioned persistent memory |
