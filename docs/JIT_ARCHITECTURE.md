# Jit System Architecture — Mind / Body / Memory / Limbs

## Core Principle

The มนุษย์ Agent system separates **mind** from **body**. A Jit repository is
the mind/soul of one agent. The innova-bot repository is the shared body/runtime.
They are bound at startup but remain independently versioned.

---

## Component Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     มนุษย์ Agent System                         │
│                                                                  │
│  ┌──────────────────────┐    ┌──────────────────────────────┐   │
│  │   Jit Repository     │    │   innova-bot Repository      │   │
│  │   (Mind / Soul)      │    │   (Body / Runtime)           │   │
│  │                      │    │                              │   │
│  │  • Identity          │    │  • Backend API (port 7010)   │   │
│  │  • Memory            │◄──►│  • GUI  /gui                 │   │
│  │  • Values            │    │  • TUI  rpg_tui              │   │
│  │  • Role              │    │  • MCP server                │   │
│  │  • Relationships     │    │  • Federation endpoints      │   │
│  │  • Checkpoints       │    │  • Agent message routing     │   │
│  │  • Source docs       │    │  • Process control           │   │
│  └──────────────────────┘    └──────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────┐   ┌─────────────────┐  ┌──────────────┐  │
│  │  Arra Oracle V3  │   │  MDES Ollama     │  │   Message    │  │
│  │  (Long-term      │   │  (Cognitive /    │  │   Bus / MCP  │  │
│  │   Memory Organ)  │   │   Language Limb) │  │  (Nervous    │  │
│  │  port 47778      │   │  gemma4:26b      │  │   System)    │  │
│  └──────────────────┘   └─────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components Explained

### Jit Repository — Mind / Soul

- **What it is**: A git repository per agent identity. Many may exist across GitHub accounts.
- **Contains**: Identity (`core/identity.md`), memory (`memory/`), values, role, relationships, docs
- **Does NOT contain**: Backend server code, GUI, TUI, MCP implementation
- **Git policy**: Checkpoint commits only — source, docs, identity, stable state. Never realtime.
- **Each Jit is unique**: different identity, role, memory scope, duties, remotes, node bindings

### innova-bot Repository — Body / Runtime

- **What it is**: One shared body implementation. Many Jit minds can bind to it.
- **Contains**: `python -m innova_bot.main` (backend), `/gui` endpoint, `rpg_tui`, MCP server, federation
- **Does NOT contain**: Any specific agent's private memory or identity
- **Binding**: A Jit repo declares its body via `config/jit-topology.json` (`body_repo_path`)
- **Rule**: innova-bot must never overwrite a Jit mind's private memory

### Arra Oracle V3 — Long-term Memory Organ

- **What it is**: Knowledge base with FTS5 + LanceDB vector search (runs on Bun)
- **Port**: 47778 (default)
- **Role**: Stores learned knowledge across sessions; queried before major decisions
- **Not realtime**: Writes are intentional learning events, not heartbeat state dumps

### MDES Ollama — Cognitive / Language Limb

- **What it is**: Remote LLM endpoint (`gemma4:26b`) for Thai language tasks
- **URL**: `https://ollama.mdes-innova.online`
- **Role**: Creative reasoning, Thai language processing, generative output
- **Not the primary brain**: The Claude model (via Copilot/API) is the primary thinker

### MCP / Federation — Nervous System

- **What it is**: Message Control Protocol server in innova-bot; connects agents
- **Port**: 7010 (SSE transport default)
- **Role**: Routes messages between agents, exposes tool endpoints, federates across nodes
- **Not the message bus**: The file-based bus (`/tmp/manusat-bus/`) handles local inter-agent I/O

### Git — Checkpoint / Source Sync

- **What it IS for**: Source code, documentation, identity files, stable state checkpoints
- **What it is NOT for**: Realtime heartbeat state, runtime logs, process signals, tmp files
- **Correct cadence**: Human or agent milestone commands trigger commits. Cron/heartbeat do not.
- **What heartbeat does**: Writes to `/tmp/` and `memory/state/` locally. Never `git add -A`.

---

## Boundary Rules

| Rule | Reason |
|------|--------|
| Jit repo does not pretend to be innova-bot | Mind ≠ body — different version control, different duties |
| innova-bot does not write to Jit's private memory | Body is shared; each Jit's soul is private |
| Heartbeat does not commit to git | Git is not a message bus; high-frequency commits corrupt history |
| `git add -A` is forbidden in heartbeat | Picks up runtime junk (.pyc, logs, tmp) into source history |
| `.env` is never committed | Contains tokens; use `.env.example` + `.secrets/` encrypted blobs |
| Runtime state stays in `/tmp/` | `heart.in.json`, `heart.out.json`, cron logs are session-local |

---

## Multi-Jit Topology

```
GitHub Account A              GitHub Account B
  tinner-deinno/Jit            other-org/Jit-soma
  (innova mind/soul)           (soma mind/soul)
         │                            │
         └─────────┬──────────────────┘
                   │
            innova-bot body
         (shared runtime, port 7010)
                   │
              Oracle V3
            (shared memory)
```

Each Jit repo has its own:
- `jit_id`
- `role`
- `memory_scope`
- `git_account`
- `allowed_sync_modes`

They share:
- innova-bot body (one running process per node)
- Oracle (one DB per deployment)
- Ollama endpoint
