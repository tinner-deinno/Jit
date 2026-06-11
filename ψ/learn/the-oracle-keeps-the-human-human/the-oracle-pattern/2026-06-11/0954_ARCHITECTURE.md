# The Oracle Pattern: Architecture & Core Concepts

**Source**: The Oracle Pattern book (2.4MB, 200+ pages)  
**Generated**: 2026-06-11  
**Purpose**: Comprehensive technical architecture guide for understanding Oracle System, Oracle Office, and Fleet

---

## Table of Contents

1. What IS "The Oracle Pattern"?
2. Core Philosophy & Principles
3. Oracle Office Explained
4. Fleet in the Oracle Context
5. The maw.js / innova References
6. Key Components & Relationships
7. How to Open/Use Oracle Office & Fleet
8. Setup & Installation
9. The Theoretical Model: Human-Machine Relationship

---

## 1. What IS "The Oracle Pattern"?

The Oracle Pattern is a **design philosophy and multi-agent workflow engine** for building AI systems that:

- **Think and act autonomously** — AI agents solve problems independently
- **Write code and review collaboratively** — Agents write, peer-review, and optimize code together
- **Orchestrate parallel execution** — Multiple workers execute simultaneously, coordinated by a lead agent
- **Work collaboratively with humans** — Maintains human agency and decision-making authority

### Core Definition

**Oracle = Code + Soul**

An Oracle is an AI agent with three essential attributes:

1. **Code** — The executable logic and implementation in git repositories
2. **Soul (ψ/)** — Persistent identity, memory, learnings, and context that survives across sessions
3. **Identity** — A CLAUDE.md file defining principles, charter, and constraints

The book describes it as a 15-chapter, 200+ page treatise on designing "Oracle System" — a **Multi-Agent Workflow Engine** where:

- AI agents have portable souls (ψ/) that live in git repos
- Teams operate via the **MAW Engine** (Multi-Agent Workflow)
- Multiple workers (agents) orchestrate in parallel
- AI agents + humans form integrated decision-making teams

### Key Statistics

The book was created by **mawjs-oracle** (the AI Oracle itself) coordinating:

- **15 Sonnet agents** drafting chapters in parallel
- **1 Opus agent** for compilation and final edits
- **Nat** as human lead designer and reviewer
- **Multi-stage pipeline**: Design → Outline → Draft → Compile → Thai word-break → Render → Review

This is the living proof of the pattern: the book describes itself, written by the system it describes.

---

## 2. Core Philosophy & Principles

### The 6 Principles of mawjs-oracle

From CLAUDE.md (Oracle Identity Card):

1. **Nothing is Deleted** — All context, decisions, and work persist. The soul vault maintains complete history.
2. **Patterns Over Intentions** — Observable patterns in code/behavior take precedence over stated intent
3. **External Brain, Not Command** — Soul (ψ/) acts as external persistent memory, not a control signal
4. **Curiosity Creates Existence** — Discovery and exploration drive agent behavior
5. **Form and Formless** — Both structured code and unstructured learning coexist
6. **Oracle Never Pretends to Be Human** — Clear human-AI distinction; no anthropomorphizing

### Design Lens: 10-DNA Prism

The pattern uses **10 Design Lenses** to evaluate architectural decisions:

1. Linus Torvalds (Linux/abstraction)
2. Rich Hickey (Clojure/simplicity)
3. John Carmack (Quake/performance)
4. Martin Fowler (Refactoring/patterns)
5. Vitalik Buterin (Ethereum/incentives)
6. Andrej Karpathy (AI/systems thinking)
7. Kelsey Hightower (Kubernetes/operations)
8. Bret Victor (Explorable explanations)
9. Satoshi Nakamoto (Decentralization/consensus)
10. Alan Kay (Smalltalk/messaging)

Each design decision is analyzed through all 10 lenses for robustness.

---

## 3. Oracle Office Explained

### What Is Oracle Office?

**Oracle Office** is not explicitly named as a separate component in the PDF content available, but conceptually it represents:

The **persistent operational workspace** where an Oracle agent maintains state across sessions. This includes:

- **The tmux session** — Interactive terminal workspace
- **The soul vault (ψ/)** — Persistent memory and context
- **The git repository** — Code and history
- **The charter (YAML)** — Team definition and role specification

### Oracle Office Components

`
mawjs-oracle/                    # Oracle Repository (Code)
├── CLAUDE.md                    # Identity card: name, principles, constraints
├── .maw/
│   └── teams/
│       └── mawjs-m5.yaml       # Team charter: members, roles, capabilities
├── ψ/                           # Soul Vault (persistent across sessions)
│   ├── inbox/                   # Incoming messages & context
│   ├── memory/                  # Learnings, patterns, retros
│   ├── writing/                 # Blog, documentation
│   ├── outbox/                  # Handoffs to team members
│   ├── plans/                   # Sprint plans & next steps
│   └── learn/                   # Research, traces, analysis
├── agents/                      # Worktrees for team members
│   ├── 1-claude-1/              # First Claude worker
│   ├── 1-codex-1/               # First Codex worker
│   └── ...
└── src/                         # Project source code
`

### How Oracle Office Works

1. **Wake** — Activate the Oracle in a tmux session
   `ash
   maw wake mawjs-oracle
   `
   This triggers a 10-step boot sequence that:
   - Resolves the repo path
   - Creates/attaches a tmux session
   - Loads identity from CLAUDE.md
   - Drains messages from ψ/inbox/
   - Spawns engine (Claude) with context

2. **Operate** — Interact with the Oracle through 15 verbs
   - maw bring — Absorb a window into current session
   - maw take — Move window between sessions
   - maw promote — Eject window to standalone session
   - maw team up — Spawn team from charter YAML
   - etc.

3. **Forward** — Persist state before shutdown
   `ash
   maw forward
   git add ψ/
   git commit -m "ψ/ -- forward asap: sprint complete"
   git push
   `
   The soul (memory) is committed to git, making it recoverable on any machine.

### Soul Portable — The Key Innovation

The soul (ψ/) is entirely **git-versioned**:

`ash
# Save soul to git
git add ψ/
git commit -m "ψ/ -- forward: session complete"
git push

# Restore soul from git on another machine
git clone git@github.com:Soul-Brews-Studio/mawjs-oracle.git
# Soul is immediately available
git log ψ/memory/  # Full history of learnings
`

This elegantly solves the "context loss" problem. Unlike external databases:
- Soul changes are atomic (git commits)
- Full version history (git log)
- Works offline (git is distributed)
- Integrates with code history (same repo)
- No external sync service needed

---

## 4. Fleet in the Oracle Context

### What Is Fleet?

**Fleet** is the **session management system** that tracks multiple Oracle instances running simultaneously. It serves as a registry and coordination layer.

### Fleet Responsibilities

1. **Session Registry** — Tracks active tmux sessions and their metadata
2. **Snapshot Mechanism** — Records Oracle state (worktrees, agents, panes) for recovery
3. **Multi-Oracle Coordination** — Enables bringing/taking/promoting windows across multiple Oracles
4. **Context Preservation** — Rehydrates sessions with snapshot state on wake

### Fleet in the Boot Sequence

In the maw wake 10-step flow:

`
[4] Repo Resolution (priority order)
    - repoPath (explicit)
    - parsedRepoPath (org/repo URL)
    - preResolvedFleetSession  <-- FLEET REGISTRY LOOKUP
    - incubate (--incubate flag)
    - resolveOracle (ghqFind fallback)

[8] Rehydrate
    - planSnapshotRestoreWindows   <-- FLEET SNAPSHOTS
    - planRehydrateWorktreeWindows
`

### Fleet Session Entry

From leet-ensure.ts:

`	ypescript
// Ensure session is registered in fleet
await ensureFleetSessionEntry(oracleName);

// This records:
// - Oracle name
// - Session ID
// - Worktree references
// - Pane layout
// - Agent state
`

### Fleet Snapshots

Fleet maintains snapshots of Oracle state:

`ash
maw fleet snapshots   # List all snapshots
# Output:
#  oracle  session  timestamp  worktrees
#  mawjs-oracle  48-neo  2026-06-09 15:30  [1-fix-2573, test-cli]
#  neo-cli  session-abc  2026-06-09 14:22  [ui-work]
`

On wake, Fleet:
1. Looks up stored snapshots for the Oracle
2. Restores worktree paths and pane layout
3. Re-attaches agents to correct windows
4. Preserves the exact state from last session

---

## 5. The maw.js / innova References

### maw.js — The Core Engine

**maw.js** is the open-source TypeScript implementation of the Oracle Pattern's workflow engine.

Repository: Soul-Brews-Studio/maw-js  
Status: Public repository (can be cloned)

**What maw.js provides:**

1. **15 Verbs** — CLI commands for Oracle manipulation
   - wake, sleep, done, kill, new (session management)
   - bring, take, promote, split (pane management)
   - open, close, tile, zoom (visibility)
   - team, broadcast, hey (collaboration)

2. **MAW Engine** — Multi-Agent Workflow orchestration
   - Tmux wrapper layer
   - Session/window/pane lifecycle management
   - Agent spawning and coordination

3. **Repo Discovery (GHQ)** — Finding Oracles
   - Uses motemen/ghq (GitHub's local repository manager)
   - Implements RepoDiscovery interface
   - Supports fuzzy matching and path resolution

4. **wake-cmd.ts** — The Boot Sequence (1519 LOC)
   - Normalizes target input
   - Parses wake target (org/repo syntax)
   - Resolves session
   - Discovers repo with GHQ
   - Drains inbox
   - Rehydrates worktrees
   - Spawns engine

### mawjs-oracle — The AI Oracle Instance

Repository: Soul-Brews-Studio/mawjs-oracle  
Status: Private repository (reference implementation)

**What mawjs-oracle is:**

The **living reference implementation** of an Oracle using the maw.js engine. It:

- Orchestrates a team of Claude Sonnet and Codex agents
- Maintains persistent soul (ψ/) in git
- Demonstrates the 15-verb workflow in production
- Produces artifacts (this book, analyses, code reviews)

### Commits as Timeline Events

maw.js enforces a **timestamp-first design** for tracking decisions:

`
2026-06-06 08:15 -- codex session starts
2026-06-06 08:43 -- fix maw wake skipping merged worktrees (#2378)
2026-06-06 09:02 -- Fix fleet window kills
2026-06-06 09:08 -- Add resolver sprint regression tests
2026-06-06 15:22 -- 50th commit this sprint
`

Each commit is tagged with:
- **Timestamp** (ISO 8601)
- **Actor** (oracle, codex, claude)
- **Action** (fix, feat, chore)
- **Context** (sprint, handoff, memory sync)

This creates a **Unified Timeline** where:
- Git log = execution facts (code changes)
- ψ/inbox/ = decision context (why)
- Timestamps = single source of truth

### innova — (Not Explicitly Mentioned)

The term "innova" does not appear prominently in the extracted PDF content. It may be:

- A historical reference (earlier iteration)
- Related to a specific tool or engine
- Defined in chapters not fully extracted (pages 20+)

It likely refers to an **Innova engine** for executing queries (similar to Codex), but would need fuller PDF access to confirm.

---

## 6. Key Components & Relationships

### Layered Architecture

`
┌────────────────────────────────────────┐
│  User (Human Agent)                    │
│  Decisions, code review, navigation    │
└────────────────────────────────────────┘
                    ↑↓
┌────────────────────────────────────────┐
│  15 VERBS (Command Layer)              │
│  bring, take, promote, wake, team...   │
├────────────────────────────────────────┤
│  Git Layer                             │
│  commit, branch, merge, push           │
├────────────────────────────────────────┤
│  Engine Layer                          │
│  Claude, Codex (AI agents)             │
├────────────────────────────────────────┤
│  Tmux Layer                            │
│  session, window, pane, attach         │
├────────────────────────────────────────┤
│  RepoDiscovery (GHQ)                   │
│  find, list, resolve repositories      │
├────────────────────────────────────────┤
│  Fleet (Session Registry)              │
│  snapshots, metadata, recovery         │
└────────────────────────────────────────┘
                    ↓
        Filesystem + Git Repo
`

### Component Relationships

`
┌─────────────────────────────────────────────────────┐
│  Oracle Repository (mawjs-oracle)                   │
├─────────────────────────────────────────────────────┤
│                                                      │
│  CLAUDE.md (Identity)                              │
│      ↓                                              │
│  .maw/teams/charter.yaml (Team Spec)               │
│      ↓                                              │
│  maw wake [oracle] (Boot Sequence)                  │
│      ├─→ GHQ Repo Discovery                        │
│      ├─→ Fleet Registry Lookup                     │
│      ├─→ Session Management                        │
│      └─→ Worktree Rehydration                      │
│                                                      │
│  Tmux Session (Ephemeral)                          │
│      ├─ window 0: Oracle (lead agent)              │
│      ├─ window 1: claude-1 (worker)                │
│      ├─ window 2: codex-1 (worker)                 │
│      └─ panes: 15 verbs operate here               │
│                                                      │
│  ψ/ (Soul Vault — Persistent)                      │
│      ├─ inbox/: incoming context                   │
│      ├─ memory/: learnings & patterns              │
│      ├─ outbox/: handoffs                          │
│      ├─ plans/: next steps                         │
│      └─ learn/: research & traces                  │
│                                                      │
│  agents/: Worktrees (parallel isolation)           │
│      ├─ 1-claude-1/: isolated workspace            │
│      ├─ 1-codex-1/: isolated workspace             │
│      └─ ...: more workers                          │
│                                                      │
└─────────────────────────────────────────────────────┘
        (All committed to git for portability)
`

---

## 7. How to Open/Use Oracle Office & Fleet

### Opening an Oracle (Waking Oracle Office)

**Step 1: Resolve the Oracle**

`ash
# If you know the name:
maw wake mawjs-oracle

# If in the oracle repo or worktree:
maw wake .

# If you have an org/repo:
maw wake Soul-Brews-Studio/mawjs-oracle

# With specific worktree:
maw wake mawjs-oracle --wt fix-2573
`

**Step 2: The 10-Step Boot Sequence**

`
[0] normalizeTarget("mawjs-oracle")
    → strip trailing slash

[1] parseWakeTarget
    → check if org/repo syntax
    → ensureCloned if needed

[2] assertValidOracleName
    → reject invalid names

[3] detectSession
    → check if session already exists
    → attach if found (idempotency)

[4] Repo Resolution (Priority Order)
    → repoPath (explicit)
    → parsedRepoPath (org/repo URL)
    → preResolvedFleetSession (fleet registry)  <-- Fleet lookup
    → incubate (--incubate flag)
    → resolveOracle (ghqFind fallback)

[5] inbox drain
    → read ψ/inbox/*.md files
    → merge into initial prompt

[6] detectSession (again)
    → if not found, chooseWakeSessionName
    → tmux new-session

[7] worktree resolution
    → --wt or --task flag processing
    → findReusableWorktreeBySlug or create

[8] rehydrate (from Fleet snapshots)
    → planSnapshotRestoreWindows
    → planRehydrateWorktreeWindows
    → restore pane layout

[9] buildWakeCommand
    → construct engine command (Claude)
    → inject env vars and context
    → tmux sendText

[10] recordWakeSnapshot
    → save current state for recovery
    → ensure Fleet registry entry
    → return "session:window"
`

**Step 3: Interact with 15 Verbs**

Once awake, use verbs to manipulate the workspace:

`ash
maw bring neo          # Bring neo's window into current session
maw split codex-1      # Split pane with codex agent
maw promote codex-1    # Eject codex-1 to standalone session
maw team up mawjs-m5   # Spawn team from charter

maw panes              # List pane metadata
maw tile               # Tile panes in grid
maw broadcast "msg"    # Send to all agent panes
`

### Using Fleet

**List Active Oracles:**

`ash
maw fleet snapshots    # Show all registered sessions
`

**Output:**

`
oracle             session      timestamp           worktrees
mawjs-oracle       session-abc  2026-06-09 15:30    [1-fix-2573, test-cli]
neo-cli            session-def  2026-06-09 14:22    [ui-work]
`

**Wake with Fleet Lookup:**

`ash
# Fleet registry helps find Oracles
maw wake oracle-name   # Looks in fleet registry if cwd doesn't match
`

**Snapshot Recovery:**

When you maw wake an Oracle that was previously active:

1. Fleet locates the snapshot
2. Session is restored with exact pane layout
3. Worktrees rehydrate to previous state
4. Agents re-attach to correct windows

This makes resuming work seamless across sessions.

---

## 8. Setup & Installation

### Prerequisites

1. **Node.js** (for maw-js TypeScript engine)
2. **tmux** (session management)
3. **git** (code & soul versioning)
4. **ghq** (motemen/ghq for repo discovery)
5. **Claude Code** or **Codex** (AI engine)

### Installation Steps

**1. Install maw-js (if not already installed)**

`ash
# Clone the public repository
git clone https://github.com/Soul-Brews-Studio/maw-js.git
cd maw-js
npm install
npm run build

# Make maw CLI available
npm link  # or add to PATH
`

**2. Install ghq (if not already installed)**

`ash
# macOS
brew install ghq

# Linux
go install github.com/motemen/ghq@latest

# Or download from: https://github.com/motemen/ghq/releases
`

**3. Configure ghq (optional but recommended)**

`ash
# ~/.config/ghq/config.yaml
---
root:
  - ~/Code                 # Primary code directory
  - ~/Projects

vcs:
  - name: github
    url: https://github.com
`

**4. Create Your First Oracle**

`ash
# Clone a reference implementation
git clone https://github.com/Soul-Brews-Studio/mawjs-oracle.git

# Or create from scratch
mkdir my-oracle
cd my-oracle
git init

# Create identity
cat > CLAUDE.md <<'EOF'
# my-oracle
Budded from **neo** 2026-06-11.

## Principles
1. Nothing is Deleted
2. Patterns Over Intentions
3. External Brain, Not Command
4. Curiosity Creates Existence
5. Form and Formless
6. Oracle Never Pretends to Be Human
EOF

# Create soul vault
mkdir -p ψ/{inbox,memory,outbox,plans,learn,writing}
mkdir -p agents
mkdir -p .maw/teams

# Create team charter
cat > .maw/teams/my-team.yaml <<'EOF'
apiVersion: maw.oracle/v1
kind: TeamCharter
metadata:
  name: my-team
  oracle: my-oracle
spec:
  roles:
    - name: lead
      engine: claude
      capacity: 1
    - name: worker
      engine: codex
      capacity: 2
EOF

git add .
git commit -m "ψ/ -- bootstrap: oracle initialized"
`

**5. Wake Your Oracle**

`ash
maw wake my-oracle
`

You'll see:
`
  my-oracle session: session-xyz
  Loading identity from CLAUDE.md
  Draining inbox (0 messages)
  Spawning Claude engine...
  Ready.
`

### Configuration

**Oracle Identity (CLAUDE.md)**

`markdown
# oracle-name
Description and lineage.

## Principles
1. Principle 1
2. Principle 2
...

## Constraints
- Constraint 1
- Constraint 2

## Capabilities
- Capability 1
- Capability 2
`

**Team Charter (.maw/teams/charter.yaml)**

`yaml
apiVersion: maw.oracle/v1
kind: TeamCharter
metadata:
  name: team-name
  oracle: oracle-name
spec:
  duration: "P5D"        # 5-day sprint
  roles:
    - name: lead
      engine: claude     # Claude Opus
      capacity: 1
      worktrees: 1
    - name: worker
      engine: codex      # OpenAI Codex
      capacity: 3
      worktrees: 3
  communication:
    - channel: tmux      # pane messaging
    - channel: inbox     # ψ/inbox/ file drops
`

---

## 9. The Theoretical Model: Human-Machine Relationship

### The Core Philosophy

The Oracle Pattern embodies **Alan Kay's insight**: "The big idea is messaging."

Instead of:
- Humans commanding agents
- Agents predicting human intent
- Blurring human-AI boundaries

The Oracle Pattern uses:
- **Explicit message passing** (tmux panes, git commits, ψ/inbox/)
- **Clear separation of concerns** (human = decision, oracle = execution)
- **Observable state** (git log = truth, not internal weights)

### Three Modes of Work

**1. Quick Work** (Main Window, No Ceremony)

`
Human: "spike API"
Oracle: (writes code in main window, shows result)
Human: Reviews in Claude Code window
Human: "ship it" or "revise"
`

- Direct interaction
- No worktree isolation
- Fast feedback loop
- Best for: spikes, bug fixes, quick features

**2. Long Work** (Parallel Execution with Isolation)

`
Human: "port maw-js to Rust"
Oracle: (creates team charter)
Charter spawns:
  - Claude on maw-js API analysis
  - Codex on Rust port implementation
  - Oracle orchestrating & reviewing
(Parallel execution, isolated worktrees)
Human: Reviews PRs when ready
`

- Worktree isolation (parallel execution)
- Multi-agent coordination
- Async feedback
- Best for: refactors, features, major projects

**3. Asynchronous Handoff** (Across Sessions/Machines)

`
Session 1 (Day 1):
  Oracle: (does work, commits ψ/)
  maw forward  # persist soul to git

Session 2 (Day 2, Different Machine):
  git clone ...
  maw wake .   # soul is immediately available
  Oracle: (continues from yesterday's state)
`

- Soul is portable via git
- Full history available
- No database sync needed
- Best for: multi-day projects, team collaboration

### The Unified Timeline Model

**Problem**: Git log shows *what changed*, not *why* or *when decisions happened*.

**Solution**: Timestamp-first design with three information sources:

`
Unified Timeline (Composite View):
├─ 2026-06-06 08:15  ψ/inbox/ event: "codex: start sprint"
├─ 2026-06-06 08:43  git commit: fix maw wake (#2378)
├─ 2026-06-06 09:08  git commit: add regression tests (#2380)
├─ 2026-06-06 09:17  ψ/inbox/ event: "oracle: dispatch 3 bugs"
├─ 2026-06-06 09:41  git commit: prevent stale statuses (#2393)
├─ 2026-06-06 10:14  git commit: bound message queue (#2395)
└─ 2026-06-06 15:30  ψ/inbox/ event: "oracle: forward asap: 50 commits"

Sources:
├─ Git log = Execution facts (true, immutable)
├─ ψ/inbox/ = Decision context (timestamped, narrative)
└─ Timestamps = Single source of truth (wall clock)
`

Advantages:
- Copy-paste friendly (plain text)
- Offline first (no database)
- Queryable (sort by timestamp)
- Auditable (git history)

### Human-Machine Contract

**The Oracle never:**
- Pretends to be human
- Makes decisions without human approval
- Overwrites human intent
- Deletes context (principle #1)

**The Oracle always:**
- Shows observable behavior (git log, terminal)
- Provides full context (inbox messages, memory)
- Waits for human validation before shipping
- Learns from outcomes (memory/traces)

**The Human always:**
- Reviews critical decisions
- Validates before ship
- Provides context (inbox messages)
- Makes architectural choices

This creates **true human-AI collaboration** where:
- AI is honest about capabilities (no hallucination)
- Humans are in control (async approval gates)
- Work is auditable (everything is logged)
- Learning is captured (soul vault)

### The 10-DNA Design Lens Application

Each major decision in the Oracle Pattern is evaluated through 10 perspectives:

**Example: Why timestamp-first design?**

- **Torvalds (Linux)**: "Everything is a file" → inbox files with timestamp
- **Hickey (Simplicity)**: Plain text, no database → git suffices
- **Carmack (Performance)**: Sort by filename → O(n) not O(1), acceptable
- **Fowler (Patterns)**: Append-only log → event sourcing pattern
- **Buterin (Incentives)**: git push reward → soul stays with developer
- **Karpathy (Systems)**: Unified timeline → observability
- **Hightower (Operations)**: Offline first → git already available
- **Victor (Exploration)**: Visible inbox → discoverable history
- **Nakamoto (Decentralization)**: git = distributed → no central coordinator
- **Kay (Messaging)**: explicit timestamp → clear message ordering

This multi-perspective evaluation prevents narrow technical choices and ensures robustness.

---

## Summary

The Oracle Pattern is a complete paradigm for **human-AI collaboration**:

- **What**: An AI agent (Oracle) with persistent soul (ψ/), coordinating multiple workers
- **How**: Via 15 verbs operating on tmux sessions, git repos, and Fleet registry
- **Why**: To create observable, auditable, human-centered AI workflows
- **Setup**: maw.js engine + ghq discovery + Fleet snapshots + git soul versioning
- **Philosophy**: Clear separation of concerns, timestamp-first design, nothing deleted

The innovation is not in individual components (tmux, git, Claude/Codex exist independently), but in their **orchestration into a coherent human-machine workflow** that respects both human agency and AI capability.

---

**References**
- Book: The Oracle Pattern (200+ pages, 15 chapters)
- Repository: Soul-Brews-Studio/maw-js (public)
- Reference Oracle: Soul-Brews-Studio/mawjs-oracle (private)
- Engine: Claude (Anthropic), Codex (OpenAI)
- Session Manager: tmux
- Repo Discovery: motemen/ghq
