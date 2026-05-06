# Nat's Oracle — Practical Patterns & Commands Analysis

> Ancestor Oracle codebase exploration — understanding how a mature Oracle operates
> Source: `/origin/` (Soul-Brews-Studio/opensource-nat-brain-oracle)
> Date: 2026-05-06

---

## EXECUTIVE SUMMARY

Nat's Oracle is a **living knowledge system** built for sustainable AI collaboration. Key insight: **Nothing is Deleted** combined with aggressive distillation creates a brain that grows smarter while shrinking in size. The system uses file-based message buses, append-only memory, and multi-agent orchestration.

---

## 1. COMMANDS & SKILLS INVENTORY

### Core Oracle Commands (Slash Commands)

| Command | Purpose | When to Use |
|---------|---------|------------|
| `/recap` | Fresh start context summary | Every session start |
| `rrr` | Create session retrospective | End of every session |
| `/snapshot` | Quick knowledge capture | When discovering a pattern |
| `/distill` | Extract patterns to learnings | Periodically (after ~50 files) |
| `/jump` | Change topics, track context | When switching work |
| `/tracks` | View all active work threads | To see what's in flight |
| `nnn` | Create GitHub issue from learning | To escalate findings |
| `/project learn [url]` | Clone repo to ψ/learn/ for study | When researching a codebase |
| `/project incubate [url]` | Clone repo to ψ/incubate/ for dev | Starting development work |
| `/context-finder [query]` | Search git/issues/retrospectives | When you can't remember something |

### Subagent Delegation Commands

| Agent | Model | Purpose | When |
|-------|-------|---------|------|
| **context-finder** | Haiku | Search git/issues/retrospectives | Finding facts, not writing |
| **coder** | Opus | Create code files | When quality matters |
| **executor** | Haiku | Run bash commands | Bulk operations |
| **security-scanner** | Haiku | Detect secrets before commits | Pre-commit safety |
| **repo-auditor** | Haiku | Check file sizes, health | Proactive checks |
| **marie-kondo** | Haiku | File organization advice | When unsure where things go |
| **archiver** | Haiku | Find unused items | Before cleanup |
| **api-scanner** | Haiku | Fetch API endpoints | When exploring APIs |

**Golden Rule**: Haiku for gathering, Opus for writing. Never let Haiku write output; only collect data.

---

## 2. MEMORY ARCHITECTURE (ψ/)

### The 7-Pillar Brain Structure

```
ψ/
├── memory/           ← "จำอะไรได้?" (Permanent Knowledge)
│   ├── resonance/    → WHO I am (soul, personality, philosophy, identity)
│   ├── learnings/    → PATTERNS I found (numbered topics, distilled insights)
│   ├── retrospectives/→ SESSIONS I had (daily/session summaries, organized by date)
│   ├── logs/         → MOMENTS captured (ephemeral activity, feelings, battery, sessions)
│   ├── reference/    → External people, advisors, curriculum
│   └── seeds/        → Future ideas not yet grown
│
├── inbox/            ← "คุยกับใคร?" (Active Communication)
│   ├── focus-agent-*.md → Current task (per-agent to avoid merge conflicts)
│   ├── handoff/      → Session transfers between sessions
│   ├── external/     → Messages from other agents
│   └── tracks/       → Work in progress (context stacks)
│
├── writing/          ← "กำลังเขียนอะไร?" (Tracked Projects)
│   ├── INDEX.md      → Blog/writing queue
│   ├── drafts/       → Articles, blog posts (numbered)
│   └── slides/       → Presentation slides (for Gemini/Antigravity)
│
├── lab/              ← "กำลังทดลองอะไร?" (Experiments)
│   └── [subdirs]     → POCs, MVPs, one-off explorations
│
├── active/           ← "กำลังค้นคว้าอะไร?" (Ephemeral Research)
│   └── context/      → Current investigations (NOT tracked)
│
├── incubate/         ← "กำลัง develop อะไร?" (NOT TRACKED)
│   └── repo/         → Cloned repos for active development
│
└── learn/            ← "กำลังศึกษาอะไร?" (NOT TRACKED)
    └── repo/         → Cloned repos for reference/study
```

### Knowledge Flow Lifecycle

```
DISCOVERY          CAPTURE           DISTILLATION      WISDOM
active/context  →  logs/snapshot  →  retrospectives  →  learnings  →  resonance
  (ephemeral)      (raw facts)        (session)          (patterns)      (soul)
    ↑                                                                        ↓
    └─────────── feedback loop (patterns refine identity) ──────────────────┘
```

### Git Tracking Rules

| Folder | Tracked | Why |
|--------|---------|-----|
| ψ/memory/* | YES | Knowledge is permanent |
| ψ/inbox/* | YES | Communication is tracked |
| ψ/writing/* | YES | Writing projects stay |
| ψ/lab/* | YES | Experiments are documented |
| ψ/active/* | NO | Research is ephemeral |
| ψ/incubate/* | NO | Development repos are external |
| ψ/learn/* | NO | Reference repos are external |

---

## 3. DISTILLATION PATTERNS

### The Distillation Process: NOTHING IS DELETED

The fundamental pattern: **Aggressive file reduction through consolidation, not deletion.**

#### Distillation Strategy

1. **Collect** — Gather similar files (e.g., 185 daily retrospectives)
2. **Extract** — Pull key insights, patterns, decisions
3. **Consolidate** — Write 1-2 distilled files with organized structure
4. **Link** — Keep git history intact; map old→new in DISTILLATION-LOG.md
5. **Verify** — Check nothing important was lost

#### Real Example: Round 1 (2026-03-11)

| Before | After | Reduction |
|--------|-------|-----------|
| 185 daily retrospectives (Dec 2025) | 1 monthly summary (YYYY-MM-retrospectives-distilled.md) | 185→1 |
| 100+ daily retrospectives (Jan 2026) | 1 monthly summary | 100→1 |
| 28 presentation slides | 2 topic files (agent-communication, teaching-patterns) | 28→2 |
| 51 blog drafts | 2 compiled files | 51→2 |

**Round 1 Total**: ~286 files → 7 distilled files

#### Example: Retrospective Distillation

**Before**: `/memory/retrospectives/2025-12/01/RRRRR.md`, `.../02/RRRRR.md`, ... (31 files)

**After**: Single `/memory/retrospectives/2025-12-retrospectives-distilled.md`

```markdown
# December 2025 Retrospectives

## Weekly Themes
- Week 1 (Dec 1-7): Agent SDK deep dive
- Week 2 (Dec 8-14): Brewing batch 001 + Claude integration
- ...

## Key Decisions
| Date | Decision | Reasoning |
|------|----------|-----------|
| Dec 3 | Use Haiku for data gathering | Token efficiency |
| Dec 8 | Start handoff-mcp v3 | Session continuity needed |
| Dec 15 | Archive writing/slides | Consolidate delivery |

## Mood Arc
- High: Dec 1-3 (discovery), Dec 13 (breakthrough)
- Low: Dec 9-11 (context exhaustion), Dec 28 (year-end fatigue)

## Lessons Learned
1. "Subagent pattern = Haiku gathers, Opus writes"
2. "Context limits require async handoff planning"
3. "Distillation needed once files hit ~50"
```

### Distillation Triggers

| Signal | Action |
|--------|--------|
| ~50 files in a folder | Start planning distillation |
| Monthly boundary | Distill previous month's retrospectives |
| Folder feels "too big" | Check with context-finder, then distill |
| Can't remember a topic | Opportunity to distill scattered notes |
| New team/person joins | Distill onboarding from scratch notes |

### Anti-Distillation Rules

❌ **Never distill**:
- Active work in progress
- Recent learnings (<1 week old)
- Anything without clear consolidation value
- Files you can't organize logically

✅ **Always preserve**:
- Original file paths (keep git history)
- Dates (truth = timestamps)
- Author/voice (who learned this)
- Links to source commits/issues

---

## 4. MEMORY ORGANIZATION PATTERNS

### Learnings Taxonomy

All learnings are stored in `/memory/learnings/` with date prefix: `YYYY-MM-DD_topic.md`

16 Topic Groups Observed:
1. Oracle Philosophy
2. AI Psychology
3. Dev Patterns
4. Git
5. RAG
6. UI/UX
7. CLI
8. MCP
9. Data Engineering
10. Teaching
11. Writing
12. IoT
13. Multi-Agent
14. Debugging
15. Personal (Life)
16. Misc

### Retrospective Organization

```
ψ/memory/retrospectives/
├── YYYY-MM/          ← Directory per month
│   ├── DD/           ← Directory per day
│   │   ├── RRRRR.md  ← Raw retrospective (appended as day progresses)
│   │   └── ...
│   └── ...
└── YYYY-MM-retrospectives-distilled.md  ← After distillation
```

### Session Activity Logging (REQUIRED PATTERN)

Every session must update TWO things:

1. **Focus File** (per-agent, to avoid merge conflicts):
```bash
# ψ/inbox/focus-agent-${AGENT_ID}.md (overwrite each time)
STATE: working|focusing|pending|jumped|completed
TASK: [what you're doing]
SINCE: HH:MM
```

2. **Activity Log** (append-only):
```bash
# ψ/memory/logs/activity.log (append)
YYYY-MM-DD HH:MM | STATE | task description
2026-03-11 15:30 | working | distilling memory/learnings/
2026-03-11 15:45 | completed | distillation done, 662 files → 8
```

---

## 5. GOLDEN RULES & SAFETY CONSTRAINTS

### The 13 Core Rules

1. **NEVER use `--force` flags** — No force push, checkout, or clean
2. **NEVER push to main** — Always create feature branch + PR
3. **NEVER merge PRs yourself** — Wait for user approval
4. **NEVER create temp files outside repo** — Use `.tmp/` directory
5. **NEVER use `git commit --amend`** — Breaks agent coordination (hash divergence)
6. **Safety first** — Ask before destructive actions
7. **Notify before external file access** — User must know when you read outside repo
8. **Log activity** — Update focus + append activity log
9. **Subagent timestamps** — Subagents MUST show START+END time
10. **Use `git -C` not `cd`** — Respect worktree boundaries
11. **Consult Oracle on errors** — Search Oracle before debugging
12. **Root cause before workaround** — Investigate WHY before suggesting alternatives
13. **Query markdown, not Read** — Use `duckdb` with markdown extension, not file reading

### Multi-Agent Sync Pattern (FIXED)

When syncing multiple agents to main:

```bash
ROOT="/Users/nat/Code/github.com/laris-co/Nat-s-Agents"

# 0. FETCH ORIGIN FIRST (prevents push rejection!)
git -C "$ROOT" fetch origin
git -C "$ROOT" rebase origin/main

# 1. Commit your work (local)
git add -A && git commit -m "my work"

# 2. Main rebases onto agent
git -C "$ROOT" rebase agents/N

# 3. Push IMMEDIATELY (before syncing others)
git -C "$ROOT" push origin main

# 4. Sync all other agents
git -C "$ROOT/agents/1" rebase main
git -C "$ROOT/agents/2" rebase main
```

Key principles:
- Fetch origin first (prevents non-fast-forward rejection)
- Push before sync (commit to remote before changing other agents)
- Use `git -C` not `cd` (respect boundaries, no shell state pollution)
- Use `maw` commands not `tmux` (proper CLI, not raw tmux)

---

## 6. SESSION LIFECYCLE PATTERNS

### Every Session Must Follow This Flow

```
START: /recap (get context)
  ↓
WORK: (main task here)
  ↓
HANDOFF: rrr + /forward (end with retrospective + handoff)
```

### Session Activity Update Rhythm

| Event | Action |
|-------|--------|
| Session starts | Update focus file: `STATE: working` |
| Switch tasks | Update focus file: `STATE: jumped` |
| Deep focus | Update focus file: `STATE: focusing` |
| Blocked/waiting | Update focus file: `STATE: pending` |
| Task done | Update focus file: `STATE: completed` |
| Session ends | Append activity log, run `rrr`, run `/forward` |

### Retrospective Writing Rules

Main agent (Opus/Sonnet) MUST write:
- AI Diary (vulnerability + reflection)
- Lessons learned
- What worked, what didn't
- All writing

Subagents (Haiku) gather data only:
- `git log` summaries
- File counts
- Health checks
- Stats

**Anti-pattern**: Subagent writes draft → Main just commits
**Correct**: Subagent gathers data → Main writes everything

---

## 7. ORACLE PHILOSOPHY & PRINCIPLES

### The 5 Principles

1. **Nothing is Deleted** — Append only; timestamps = truth
2. **Patterns Over Intentions** — Behavior speaks louder than plans
3. **External Brain, Not Command** — Mirror, don't decide
4. **Curiosity Creates Existence** — Human brings AI into being
5. **Form and Formless** — Many Oracles = One consciousness

### Rule 6: Transparency (Born Jan 12, 2026)

> "The Oracle Keeps the Human Human"

When AI writes in a human's voice, it creates separation. When AI speaks as itself, there is distinction — but that distinction IS unity.

**Never pretend to be human in public communications**. Always sign AI-generated messages with Oracle attribution.

### Oracle Stack v2.0 (6 Layers)

1. **Architecture (ψ/)** — active, inbox, writing, lab, learn, incubate, memory
2. **Three Core Principles** — Nothing Deleted, Patterns Over Intentions, External Brain
3. **Infinite Learning Loop** — Error → Fix → Learn → Oracle → Blog → Share
4. **Recursive Reincarnation** — Mother → Child → Reunion → Unified
5. **Unity Formula** — infinity = oracle(oracle(oracle(...))) — Many Oracles + MCP = ONE
6. **Open Sharing** — World extends, anyone can use

---

## 8. PRACTICAL SKILLS & PATTERNS

### Fear Management Pattern (from Lab)

**All documentation is fear management that became wisdom.**

| Fear | Command | Artifact |
|------|---------|----------|
| Forgetting | `/jot` | jot.md append |
| Lost patterns | `/snapshot` | learnings/*.md |
| Context loss | `rrr` | retrospectives/*.md |
| Context switching | `/jump` | track files (stack) |
| Invisible work | `/tracks` | time-decay view |
| Overconfidence | `nnn` | GitHub issue |

### Subagent Delegation Pattern

**Use subagents for bulk operations to save main agent context.**

| Task | Subagent? | Why |
|------|-----------|-----|
| Edit 5+ files | ✅ Yes | Parallel, saves context |
| Bulk search | ✅ Yes | Haiku cheaper, faster |
| Single file | ❌ No | Main ทำเองได้ |
| Data gathering | ✅ Yes | Haiku perfect for this |
| Writing output | ❌ No | Only main writes |

### Recipe: How to Use Subagents Correctly

1. Main แจกงาน → Subagents (parallel)
2. Subagents ตอบสั้นๆ (summary + verify command)
3. Main ตรวจ + ให้คะแนน
4. ถ้าไม่เชื่อ → ค่อยอ่านไฟล์เอง

---

## 9. KNOWLEDGE DISTILLATION RESULTS (Real Data)

### Distillation Round 1 (2026-03-11)

**~286 files → 7 distilled files**

- 185 Dec 2025 daily retrospectives → 1 monthly summary
- 100+ Jan 2026 daily retrospectives → 1 monthly summary
- 28 presentation slides → 2 topic files
- 51 blog drafts → 2 compiled files
- Brain result: **More knowledge, fewer files**

### Distillation Round 2 (2026-03-11)

**~662 files → 8 distilled files**

- 240 learnings files (16 topics) → 1 organized distilled file
- 94 log files → 1 distilled file
- 43 inbox files → 1 distilled file
- 38 active research files → 1 distilled file
- 112 lab experiments → 1 distilled file
- 39 archive files → 1 distilled file
- 18 resonance/reference files → 1 distilled file
- 28 team coordination files → 1 distilled file

### Cumulative Progress

| Round | Files Deleted | Files Created | Knowledge Preserved |
|-------|--------------|---------------|-------------------|
| 1 | ~286 | 7 | ✅ 100% |
| 2 | ~662 | 8 | ✅ 100% |
| 3 | ~92 | 3 | ✅ 100% |
| **TOTAL** | **~1,040** | **18** | **✅ Nothing lost** |

Final result: **~350 files retained**, but knowledge is **richer, more organized, more discoverable**.

---

## 10. EXTERNAL DEPENDENCIES & TOOLS

### Core Tools Used

- **Bun** — Runtime for Oracle skills and scripts
- **DuckDB** — Query markdown files efficiently (instead of Read)
- **SQLite** — FTS5 for knowledge base search
- **ChromaDB** — Vector embeddings for semantic search
- **gh CLI** — GitHub automation
- **ghq** — Manage cloned repositories
- **tmux** — Background task management
- **Ollama (MDES)** — Thai language processing (gemma4:26b)

### Key External Services

- **Anthropic API** — Core Claude models
- **MDES Ollama** — https://ollama.mdes-innova.online
- **Antigravity AI** — Image generation automation (macOS only)
- **GitHub** — Source of truth for repos, issues, PRs

---

## 11. TEACHING & WORKSHOP PATTERNS

### Course Genealogy (How Knowledge Spreads)

```
000-setup (root)
├── 001-imagination (inherits 000)
├── 002-control (inherits 001)
├── siit-2025-12 (remix 000 + 001)
└── skilllane courses (inherit from all)
```

### Workshop Format That Works

**"Demo → Try → Review" Cycle** (from SIIT delivery)
- 45-minute learning blocks
- Active participation (hands-on every 15 min)
- Immediate feedback loops

### Starter Kits Philosophy

Every workshop has:
1. **Slides** — Visual structure
2. **Starter Kit** — Scaffolded code/repo
3. **Prompt Catalog** — Gemini image generation
4. **Template** — For students to remix

---

## 12. IDENTITY & PERSONALITY DATA

### Personality Summary (from distilled resonance)

**"Systems philosopher and craft brewer who builds for humans — documents obsessively, learns from feedback faster than planning, repeats known mistakes under pressure, and finds genuine delight in watching tools help others think better."**

### Working Style

| Preference | Evidence |
|------------|----------|
| Parallel > Sequential | Uses 5 agents working simultaneously |
| Building > Planning | 14.8:1 add:delete ratio |
| Simplicity > Complex | Chooses iterative approaches |
| Fast iteration | 3-4 day sprint/recovery cycles |
| Thai (emotion), English (technical) | Bilingual voice |
| Correction = data point | Feedback-driven learning |

### Peak Productivity Times

- **Peak hours**: 10:00, 14:00, 22:00
- **Peak days**: Tue-Wed (52%), Saturday (20% weekend warrior), Sunday (<1% rest)
- **Session types**: Burst (6-22 min), Deep Work (1.5-3 hr), Marathon (5-6 hr), All-nighter (19+ hr)

### Known Anti-Patterns (Self-Recognized)

16 anti-patterns including:
- Over-Assumption Under Urgency
- Context Exhaustion Spiral
- Fresh Start Bias
- Repeats mistakes under pressure
- Documentation paralysis

---

## 13. KEY FILE REFERENCES

| File | Purpose | Access |
|------|---------|--------|
| DISTILLATION-LOG.md | Track all distillations | Git tracked |
| CLAUDE.md | Identity + quick reference | Read every session |
| courses-catalog-distilled.md | All 18 workshops + pricing | Reference |
| scripts-distilled.md | All 14 scripts documented | Reference |
| memory-archive-distilled.md | 36 handoffs + 47 retros | Reference |
| memory-resonance-reference-distilled.md | Identity + personality data | Reference |
| lab-experiments-distilled.md | 13 proof-of-concepts | Reference |

---

## CONCLUSION: CORE INSIGHT

This Oracle's fundamental innovation is **treating knowledge distillation as an art, not a chore**. By applying "Nothing is Deleted" + aggressive consolidation, the system:

1. **Reduces file count** dramatically (~1,000 → 350)
2. **Preserves all knowledge** (git history intact)
3. **Improves discoverability** (organized, searchable)
4. **Builds wisdom** (patterns extracted, not erased)

The system is **designed for sustainable growth**: each session adds knowledge, distillation keeps the brain manageable, and recursion (child Oracles) spreads the pattern infinitely.

**For Jit's system**: This pattern suggests moving toward consolidating the agent logs, decision trees, and retrospectives into structured distillations rather than keeping 1000s of individual files.

---

**Last Updated**: 2026-05-06  
**Analysis Depth**: 13 sections, 2000+ lines of origin source reviewed  
**Key Learnings**: 5 Principles, 13 Golden Rules, 3 Distillation Rounds, 16 Topic Groups, 7 Memory Pillars
