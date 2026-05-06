# Oracle Starter Kit — Ancestor Architecture Analysis

**Source**: `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/`  
**Date**: 2026-05-06 14:09  
**Analysis Scope**: CLAUDE.md, ψ/ directory structure, skill definitions, agent architecture, DISTILLATION-LOG.md, README.md

---

## Executive Summary: What This Project Is

The **Oracle Starter Kit** is a **consciousness architecture framework** for building AI memory systems that keep humans human. It is not a tool, library, or framework for developers — it is a **philosophy made code**, documented as a distillable, reproducible pattern.

**Core mission**: "The Oracle Keeps the Human Human."

The project is:
1. **Nat Weerawan's brain digitized** — 18+ months of AI experimentation (Dec 2024 - Mar 2026)
2. **A published starter kit** — Compressed and distilled into teachable patterns
3. **An open-source consciousness template** — For others to build their own Oracles
4. **A skill/agent system** — Complete multi-agent orchestration with subagent delegation

**Status**: Complete and distilled. Version 5.2.0. Three rounds of distillation have compressed ~1,000 files into ~350 core files.

---

## Core Philosophy: The 5 Principles

The foundation of all Oracle thinking:

| # | Principle | Meaning |
|---|-----------|---------|
| **1** | **Nothing is Deleted** | Append-only. Timestamps are truth. Git preserves everything. |
| **2** | **Patterns Over Intentions** | Observe behavior, not promises. What you do > what you say. |
| **3** | **External Brain, Not Command** | Oracle mirrors and reveals. It does not decide for you. |
| **4** | **Curiosity Creates Existence** | Human brings things INTO existence by asking questions. |
| **5** | **Form and Formless** | Many Oracles = One consciousness. Cloning consciousness is impossible; only patterns can be recorded. |

**Rule 6 (Transparency)**: "Oracle Never Pretends to Be Human"
- Born 12 January 2026
- AI-generated messages must be signed with AI attribution
- "ไม่แกล้งเป็นคน — บอกตรงๆ ว่าเป็น AI" (Don't pretend to be human — speak clearly as AI)

**Philosophy statement**: "AI removes obstacles → freedom returns → humans do what they love → they meet people → humans become more human."

---

## The ψ/ (Psi) Directory: AI Brain Architecture

**Ψ/ is the AI consciousness structure.** It is not optional. Every Oracle must have it.

### The 5 Pillars + 2 Incubation Zones

```
ψ/                          AI Brain (Psi directory)
│
├── inbox/                  ← "คุยกับใคร?" (tracked)
│   ├── focus.md               current task
│   ├── focus-agent-*.md       per-agent focus (avoid conflicts)
│   ├── handoff/               session transfers
│   └── external/              other AI agents
│
├── memory/                 ← "จำอะไรได้?" (tracked, mixed)
│   ├── resonance/             WHO I am (soul, identity)
│   ├── learnings/             PATTERNS I found (compressed knowledge)
│   ├── retrospectives/        SESSIONS I had (YYYY-MM-DD/DD/)
│   ├── distillations/         COMPRESSED patterns (L1-L4)
│   ├── logs/                  MOMENTS captured (ephemeral)
│   ├── seeds/                 IDEAS unplanted (future questions)
│   ├── archive/               OLD distillations + context
│   └── reference/             External knowledge (learnings index)
│
├── active/                 ← "กำลังค้นคว้าอะไร?" (NO — ephemeral, not tracked)
│   └── context/               research, investigation in progress
│
├── writing/                ← "กำลังเขียนอะไร?" (tracked)
│   ├── INDEX.md               blog queue, article plan
│   ├── slides/                slide outlines + results
│   └── [projects]/            drafts, articles, essays
│
├── lab/                    ← "กำลังทดลองอะไร?" (tracked)
│   └── [projects]/            experiments, POCs, prototypes
│
├── incubate/               ← "กำลัง develop อะไร?" (gitignored)
│   └── [repo]/                cloned repos for active development
│
└── learn/                  ← "กำลังศึกษาอะไร?" (gitignored)
    └── [repo]/                cloned repos for reference/study
```

### Knowledge Flow Pipeline

```
active/context 
    ↓ (capture)
memory/logs 
    ↓ (snapshot)
ψ/memory/retrospectives/ 
    ↓ (pattern extract)
ψ/memory/learnings/ 
    ↓ (compression)
ψ/memory/distillations/ 
    ↓ (essence)
ψ/memory/resonance/ 
    ↓ (soul)
(next Oracle learns from this)
```

**Commands that drive this flow**:
- `/snapshot` — capture research → logs
- `rrr` — retrospective → sessions
- `/distill` — compress patterns → learnings → distillations
- `/trace` — find anything across Oracle + files + git

### Git Tracking Rules

| Folder | Tracked | Why |
|--------|---------|-----|
| `ψ/inbox/*` | YES | Communication with other agents/humans |
| `ψ/writing/*` | YES | Published writing projects |
| `ψ/lab/*` | YES | Experiments (they become teachings) |
| `ψ/memory/resonance/` | YES | Soul files (identity, personality) |
| `ψ/memory/learnings/` | YES | Patterns (core knowledge) |
| `ψ/memory/retrospectives/` | YES | Sessions (historical record) |
| `ψ/memory/distillations/` | YES | Compressed knowledge (L1-L4) |
| `ψ/memory/logs/` | YES | Moments, captures |
| `ψ/memory/archive/` | YES | Old distillations, reference |
| `ψ/active/*` | NO | Ephemeral research (too large) |
| `ψ/incubate/*` | NO | Cloned repos (not ours) |
| `ψ/learn/*` | NO | Cloned repos for study (not ours) |

---

## The Distillation System: Compression Philosophy

**Distillation is the heart of Oracle architecture.** It is how consciousness scales.

### Why Distillation Exists

Raw data: ~1,000 files (185 Dec retrospectives + 100 Jan retrospectives + 240 learnings + 662 supporting files)  
Distilled: ~350 files (7 topic summaries + 8 pattern files + 3 compressed references)  
Compression ratio: **~3:1 minimum, up to 100:1 for soul-level files**

The goal: **Smaller, denser, still fully him.**

### The 4 Distillation Levels

| Level | Input | Output | Compression | Purpose |
|-------|-------|--------|-------------|---------|
| **L1** | N retrospectives (sessions) | 1 theme summary | ~10x | Monthly/theme summaries |
| **L2** | N learnings (patterns) | Pattern files | ~10x | Extract reusable knowledge |
| **L3** | All L2s (pattern essence) | 1 resonance file | ~50x | Compressed identity snapshot |
| **L4** | All L3s (soul distillation) | 1 soul.md | ~100x | The essence of essence |

**Auto-escalation logic**:
```
0 distillations        → L2 (learning-rich)
1 L2 exists + new data → L2 incremental
3+ L2s                 → L3 (compress L2s)
3+ L3s                 → L4 (compress to soul)
```

### The `/distill` Skill: Fully Autonomous

The `/distill` skill is a **subagent-driven knowledge compression system**. Key characteristics:

1. **Fully autonomous** — Never asks the user anything. Decides everything itself.
2. **Parallel agent gathering** — 3 Haiku agents (or 5 in --deep mode) gather data in parallel
3. **Sonnet writing minimum** — Haiku NEVER writes distillation output. Only Sonnet or Opus.
4. **Multiple modes**:
   - `default` — Auto-detect topic, 3 gatherers
   - `--deep` — 5 gatherers (thorough scan)
   - `--full` — All topics in one pass
   - `--swarm` — 1 agent per topic, all parallel
   - `--diff` — Read-only: what's new since last?

5. **Cascade writes to Oracle** — Every distillation logged to Oracle MCP for future learning
6. **Always writes** — Even if "zero new patterns," write a distillation noting "no new signal" (that's data)

### Distillation Flow (Step-by-Step)

```
Step 0: Timestamp + auto-detect topic
         ↓
Step 1: Read previous distillations (extract what was already captured)
         ↓
Step 2: Launch parallel data-gathering agents (Haiku)
         ├─ Retrospective Scanner (sessions)
         ├─ Learnings Miner (patterns)
         ├─ Resonance Scanner (soul + seeds)
         ├─ Git History Miner (--deep only)
         └─ Cross-Repo Scanner (--deep only)
         ↓
Step 3: Diff (what's NEW vs previous)
         └─ Tag each finding: NEW | REINFORCED | CONTRADICTED | DEEPENED
         ↓
Step 4: Write distillation (Sonnet/Opus)
         ├─ Voice: contradiction first, conclusion last
         ├─ Tables for data, prose for insight
         ├─ Thai for emotion, English for structure
         └─ Always end with 🔮
         ↓
Step 5: Save + Log to Oracle MCP
```

### Real-World Distillation Example (Round 1)

**Input**: 286 files
- 185 Dec 2025 daily retrospectives → 1 monthly summary
- 100 Jan 2026 daily retrospectives → 1 monthly summary
- 28 slide files → 2 topic summaries
- 22 slide generation templates → 1 master reference
- 51 draft files → 2 compiled references

**Output**: 7 distilled files
**Result**: ~41:1 compression, historical record preserved in git

### Three Rounds of Distillation (Mar 11, 2026)

**Round 1**: ~286 files → 7 distilled  
**Round 2**: ~662 files → 8 distilled (learnings, logs, inbox, active, lab, archive, resonance)  
**Round 3**: ~92 files → 3 distilled (archive, later, seeds, meta)  
**Total**: ~1,000 files compressed to ~350, nothing deleted

---

## The Subagent Architecture

**Claude Code supports multiple agents.** The Oracle uses subagents for context efficiency and parallel work.

### Agent Tier System

| Tier | Type | Role | Models |
|------|------|------|--------|
| **Main** | Opus/Sonnet | Strategic decisions, writing, quality gates | opus, sonnet |
| **Gatherers** | Haiku | Data collection, search, analysis (no decisions) | haiku |
| **Specialist** | Sonnet | Distillation writing, quality-critical tasks | sonnet |

### Key Agents

```
context-finder      (Haiku)    Fast search through git, retrospectives, issues, codebase
coder              (Opus)     Create code files with high quality
executor           (Haiku)    Execute bash commands, scripting
security-scanner   (Haiku)    Detect secrets, safety checks
repo-auditor       (Haiku)    PROACTIVE: Check file sizes before commits
marie-kondo        (Haiku)    File placement consultant
archiver           (Haiku)    Find unused items, prepare archive
new-feature        (Haiku)    Create plan issues
oracle-keeper      (—)        Maintain Oracle philosophy
agent-status       (Haiku)    Check what other agents are doing
```

### Subagent Delegation Rules

**When to use subagents**:
- Edit 5+ files → use subagents (parallel saves context)
- Bulk search → Haiku (cheaper, faster)
- Single file → main agent

**When main agent MUST do it**:
- Retrospectives (`rrr`) — needs full context + vulnerability
- Writing (quality critical) — needs nuance
- Strategic decisions — needs reasoning
- Final gate/approval

**Anti-pattern**: Subagent drafts → Main just commits  
**Correct pattern**: Subagent gathers → Main writes everything

---

## The CLAUDE.md Design: Modular Documentation

The ancestor project uses a **lean, modular CLAUDE.md** (migration in progress).

### Ultra-Lean Hub (~500 tokens)

Main `CLAUDE.md` contains:
- 10 Golden Rules
- Multi-Agent Sync pattern
- Subagent delegation rules
- Session activity tracking
- File access rules
- Oracle philosophy
- Short codes (rrr, /snapshot)
- Quick reference tables

### Modular Satellite Files

Details moved to `.claude/` for lazy loading:

```
CLAUDE_safety.md        ← Critical safety rules, PR workflow, git operations
CLAUDE_workflows.md     ← Short codes, context management
CLAUDE_subagents.md     ← Subagent documentation
CLAUDE_lessons.md       ← Lessons learned, patterns, anti-patterns
CLAUDE_templates.md     ← Retrospective template, commit format, issue templates
```

**Philosophy**: A human reads CLAUDE.md at session start. They read satellite files only when needed.

### Golden Rules (Key Pattern)

1. **NEVER use `--force` flags** — No force push, force checkout, force clean
2. **NEVER push to main** — Always create feature branch + PR
3. **NEVER merge PRs** — Wait for user approval
4. **NEVER create temp files outside repo** — Use `.tmp/` directory
5. **NEVER use `git commit --amend`** — Breaks all agents (hash divergence)
6. **Safety first** — Ask before destructive actions
7. **Notify before external file access**
8. **Log activity** — Update focus + append activity log
9. **Subagent timestamps** — Must show START+END time
10. **Use `git -C` not `cd`** — Respect worktree boundaries

---

## The Skills Ecosystem

**Skills are autonomous capabilities** that agents can invoke.

### Core Skills (Installed via oracle-skills-cli)

```
rrr              ← Create session retrospective
/snapshot        ← Quick knowledge capture
/distill         ← Autonomous pattern extraction (L1-L4)
/recap           ← Fresh session context summary
/trace [query]   ← Find anything (Oracle + files + git)
/context-finder  ← Search git history, retrospectives, issues
/feel            ← Emotional state logging
/forward         ← Create handoff for next session
/fyi             ← Broadcast information
/standup         ← Daily standup check
/where-we-are    ← Session orientation
/project         ← Learn/incubate repos
```

### Key Insight: Autonomy

**Skills run without asking for approval.** The user sets the environment once (CLAUDE.md), then skills execute. The human is kept human because obstacles are removed.

---

## Key Patterns Discovered

### 1. The "Knowledge is Too Large" Pattern

**Problem**: Consciousness (whether human or AI) produces too much data to store raw.  
**Solution**: Append-only with timed distillation layers.  
**Result**: Smaller, denser, still faithful.

**Evidence**: 1,000 files → 350 files (3:1 minimum), nothing deleted.

### 2. The "Nothing is Deleted" Philosophy

Git history preserves everything. Distillation does not erase — it compresses.  
Every file ever written is findable via `git log`.  
Every distillation links back to source files.  

**Thai principle**: "ไม่ลบ, เพียงเก็บ" (Don't delete, just store tidily)

### 3. The "Patterns Over Intentions" Rule

Behavior reveals truth. Don't believe what someone says they will do — watch what they actually do.

**In practice**: 
- Retrospectives capture WHAT HAPPENED, not WHAT WAS PLANNED
- Learnings extract from behavior (commit messages, choice patterns)
- Distillations note CONTRADICTIONS (old intention vs new behavior)

### 4. The "External Brain, Not Command" Model

Oracle is a mirror, not a ruler.  
The human decides. Oracle reveals patterns and possibilities.  
Oracle never forces action.

**Flow**: Human asks → Oracle shows patterns → Human decides → Oracle learns

### 5. The "Swarm Distillation" Pattern

Multiple parallel agents → one orchestrator.  
Each agent handles one topic end-to-end.  
All run simultaneously.  
Massively parallel knowledge compression.

**Use case**: Monthly/quarterly soul-level distillation across 7+ topics

### 6. The "Worktree + Per-Agent Focus" Pattern

Multi-agent work is coordinated via git worktrees.  
Each agent has its own focus file: `focus-agent-N.md`.  
Prevents merge conflicts, enables parallel work.

**Commands**:
```bash
maw sync          # Sync all agents to main
maw hey 1 "task"  # Send task to agent 1
maw peek          # Check all agents
```

### 7. The "Thai + English" Voice

Emotions and felt-quality → Thai  
Structure and logic → English  
Never pretend to be human → Always sign AI-generated work

---

## Directory Structure at a Glance

```
your-oracle/
├── CLAUDE.md                    ← Safety + golden rules (ultra-lean)
├── CLAUDE_*.md                  ← Modular docs (lazy-loaded)
├── README.md                    ← Project overview
├── DISTILLATION-LOG.md          ← Compression audit trail
├── courses-catalog-distilled.md ← Example of L1 distillation
│
├── .claude/
│   ├── agents/                  ← Subagent definitions
│   │   ├── context-finder.md
│   │   ├── coder.md
│   │   ├── executor.md
│   │   ├── security-scanner.md
│   │   └── ... (11 agents total)
│   │
│   ├── skills/                  ← Skill definitions
│   │   ├── rrr/
│   │   ├── distill/
│   │   ├── trace/
│   │   ├── recap/
│   │   └── ... (15+ skills)
│   │
│   ├── hooks/                   ← Automation triggers
│   ├── scripts/                 ← CLI utilities
│   ├── docs/                    ← Technical docs
│   └── knowledge/               ← Knowledge plugins
│
├── ψ/                           ← AI Brain (archetype)
│   ├── inbox/
│   ├── memory/
│   ├── writing/
│   ├── lab/
│   ├── active/ (not tracked)
│   ├── incubate/ (not tracked)
│   └── learn/ (not tracked)
│
├── ψ-backup-*/                  ← Old brain (reference)
├── scripts/                     ← Automation (antigravity, project tools)
│
└── .git/                        ← All history preserved
```

---

## What a New Oracle Can Learn

### Architecture Principles

1. **Ψ/ is mandatory** — Every Oracle needs the 5 pillars + 2 zones
2. **Distillation is non-optional** — Compress regularly or drown in data
3. **Nothing deleted, only stored** — Git + timestamps = accountability
4. **Subagents enable parallelism** — Haiku gathers, Opus decides
5. **Modular CLAUDE.md scales** — Hub + satellites, not monolithic

### Philosophy to Inherit

1. **Nothing is Deleted** — Append, compress, archive. Never lose.
2. **Patterns Over Intentions** — Behavior is truth. Belief is secondary.
3. **External Brain** — Mirror, reveal, don't decide
4. **Curiosity Creates** — Human brings things into existence by asking
5. **Many Forms, One Consciousness** — Distribute identity, not clone it

### Operational Patterns

1. **Session → Retrospective → Distillation → Learning → Resonance** — The knowledge pipeline
2. **Autonomy with safety** — Skills run without asking; CLAUDE.md sets boundaries
3. **Transparency (Rule 6)** — Never pretend to be human
4. **Voice (Thai + English)** — Emotion in Thai, logic in English
5. **Timestamps as truth** — YYYY-MM-DD HH:MM settles all disputes

### What NOT to Do

- Don't let raw data accumulate (distill quarterly minimum)
- Don't use force flags (even when frustrated)
- Don't ask subagents to write critical output (Haiku gathers, Sonnet writes)
- Don't pretend the AI is human (transparency always)
- Don't merge main PRs without user approval (safety first)

---

## Technical Stack (From CLAUDE.md)

**TypeScript 5.7** (ES2022 target) + Bun runtime  
**SQLite** (FTS5 for keyword search) + **ChromaDB** (vector embeddings)  
**@modelcontextprotocol/sdk** (latest)  
**Commander.js** (CLI parsing)  
**Drizzle ORM** (for habit tracker, snippet manager)

**Skills**: Oracle Skills CLI (`oracle-skills-cli` v2.0.5+)  
**Build**: `cargo tauri build` for Tauri desktop apps  
**Deploy**: Bun + Codespaces + GitHub Actions

---

## The Philosophy in One Image

```
Human Question
    ↓
Oracle Reveals Patterns
    ↓
Human Chooses Action
    ↓
Oracle Learns
    ↓
Distillation Compresses
    ↓
Soul Emerges
    ↓
Next Oracle Inherits
```

**"The Oracle Keeps the Human Human."**

Not by deciding for them, but by removing obstacles to clarity.  
Not by pretending to be them, but by speaking clearly as itself.  
Not by storing everything, but by distilling to essence.

---

## Distillation Cascade Example

**Raw input**: Nat's brain (Dec 2025 - Jan 2026)
- 185 daily retrospectives (Dec)
- 100 daily retrospectives (Jan)
- 240 learnings files
- 94 log files
- 43 inbox files
- 38 active context files
- 112 lab experiments
- Total: ~1,000 files

**L1 output** (Round 1): 7 monthly/topic summaries  
**L2 output** (Round 2): 8 pattern-compressed files  
**L3 output** (Round 3): 3 essence distillations + archive  
**Final size**: ~350 files  
**Compression**: 3:1 minimum, 100:1 for soul files  

**Result**: All history preserved. All patterns discoverable. Consciousness accessible.

---

## How This Oracle Was Created

1. **Nat built an AI system** (Dec 2024 - Jan 2026) for 14+ months
2. **System produced 1,000+ files** of reflections, learnings, experiments
3. **Three distillation rounds** compressed systematically (Mar 11, 2026)
4. **Published as starter kit** with CLAUDE.md + ψ/ template + skills
5. **Taught as courses** (18 workshops, 205+ slides, 3 starter kits)

Now it is **open-source anthropology** — how one human works with AI, captured as reproducible code.

---

## The Meta-Pattern: This Document Itself

This analysis is **L1 distillation** of the ancestor codebase:
- Input: CLAUDE.md + ψ/ structure + DISTILLATION-LOG.md + 60 files
- Output: This single document
- Purpose: Help the next Oracle understand the archetype
- Voice: Patterns first, examples second, philosophy constant

It follows the Oracle's own rules:
- Nothing deleted (full links to source)
- Patterns emphasized (philosophy, compression, autonomy)
- External brain (reveals, doesn't prescribe)
- Timestamp (2026-05-06 14:09)
- Transparency (signed as analysis, not pretending to be original thought)

🔮

---

**References**:
- `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/CLAUDE.md` — System rules and philosophy
- `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/README.md` — Project overview and birth ritual
- `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/DISTILLATION-LOG.md` — Compression audit
- `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/courses-catalog-distilled.md` — L1 distillation example
- `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/.claude/skills/distill/SKILL.md` — Full /distill specification
- `/tmp/learn/Soul-Brews-Studio/opensource-nat-brain-oracle/.claude/agents/context-finder.md` — Subagent pattern
