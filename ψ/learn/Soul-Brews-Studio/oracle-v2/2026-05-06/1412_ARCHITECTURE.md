# Oracle V2 Technical Architecture

**Date**: 2026-05-06  
**Source**: Soul-Brews-Studio/arra-oracle-v3 (rebranded from oracle-v2)  
**Status**: Nightly Release (CalVer: v26.5.2-alpha.1704)

---

## Executive Summary

Oracle V2 is a **Model Context Protocol (MCP) semantic knowledge base system** that enables AI agents to query, learn from, and reason about philosophy and patterns. It uses **hybrid search** combining SQLite FTS5 (full-text search) with vector embeddings (ChromaDB/LanceDB) to deliver both keyword accuracy and semantic understanding. The system is designed as a **shared memory layer** for multi-agent systems and local-first knowledge management.

**Core Purpose**: "The Oracle Keeps the Human Human" — a persistent, searchable knowledge base for principles, learnings, retrospectives, and patterns that survives across sessions.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                   ORACLE V2 ECOSYSTEM                   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐   ┌──────────────┐   ┌────────────┐    │
│  │   Claude    │   │   HTTP API   │   │ Dashboard  │    │
│  │  (via MCP)  │   │  (Elysia)    │   │ (Web UI)   │    │
│  └──────┬──────┘   └──────┬───────┘   └─────┬──────┘    │
│         │                 │                 │           │
│         └─────────────────┼─────────────────┘           │
│                           │                             │
│                   ┌───────▼───────┐                     │
│                   │  Oracle Core  │                     │
│                   │  (MCP Server) │                     │
│                   └───────┬───────┘                     │
│                           │                             │
│      ┌────────────────────┼────────────────────┐        │
│      │                    │                    │        │
│  ┌───▼────┐   ┌──────────▼──────┐   ┌─────────▼──┐    │
│  │ SQLite │   │   Vector Store  │   │  Markdown  │    │
│  │ (FTS5) │   │ (ChromaDB/Lance)│   │   Files    │    │
│  └────────┘   └─────────────────┘   └────────────┘    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Three-Layer Stack**:
1. **MCP Transport** (stdio) — Claude integration
2. **HTTP API** (Elysia on :47778) — REST endpoints
3. **Data Layer** (SQLite + Vector DB) — Persistent storage

---

## Core Components

### 1. MCP Server (`src/index.ts`)

**Entry point for Claude Code integration via Model Context Protocol.**

- **Transport**: stdio (Model Context Protocol)
- **Tools**: 22 MCP tools exported to Claude
- **Lifecycle**: Lazy initialization, graceful shutdown
- **State**: Database, vector store, configuration

**Architecture**:
```typescript
class OracleMCPServer {
  server: Server                    // MCP server instance
  sqlite: Database                  // SQLite connection
  db: BunSQLiteDatabase             // Drizzle ORM wrapper
  vectorStore: VectorStoreAdapter   // Pluggable vector backend
  disabledTools: Set<string>        // Feature flags
  readOnly: boolean                 // Mode flag
}
```

**Initialization Flow**:
1. Load tool group configuration (which features enabled)
2. Create SQLite database + apply schema
3. Create vector store (LanceDB by default, fallback graceful)
4. Verify vector health → log connection status
5. Register MCP tool handlers
6. Start listening on stdio

**Tool Registration**: Each tool has two parts:
- `*ToolDef`: JSON schema (inputs, description, type)
- `handle*`: Async handler function (logic + side effects)

---

### 2. HTTP Server (`src/server.ts`)

**REST API for web UI and external integrations.**

**Framework**: Elysia (bun-native, TypeBox schemas)  
**Port**: 47778 (ORACLE_PORT env var)  
**Status**: 55 endpoints across 14 modules

**Core Modules** (`src/routes/`):
- `auth/` — Login, logout, status
- `search/` — Hybrid search, reflection, similar docs
- `knowledge/` — Learn, handoff, inbox
- `forum/` — Threads, messages, Q&A
- `traces/` — Trace discovery, chaining, dig points
- `health/` — Server status, stats, active Oracles
- `dashboard/` — Activity, growth, session stats
- `schedule/` — Appointments, calendar events
- `supersede/` — Document versioning chains
- `vector/` — Embedding operations, 3D map projection
- `oraclenet/` — Oracle family registry, heartbeats
- `plugins/` — Plugin discovery and metadata
- `indexer/` — Reindexing triggers
- `vault/` — Vault sync and pull

**Middleware Stack**:
- Private Network Access (Chrome PNA) preflight
- CORS (configurable origins)
- Security headers (X-Frame-Options, CSP, XSS protection)
- Error handling (database locks → 503, validation → 400)
- Swagger documentation at `/swagger`

**Key Features**:
- Auto-seed menu items from route modules
- Graceful shutdown with process manager
- Database busy handling (returns 503 during indexing)

---

### 3. Database Schema (`src/db/schema.ts`)

**Drizzle ORM on SQLite3 with FTS5 virtual table.**

**Core Tables**:

#### `oracle_documents` (Metadata Index)
```sql
id TEXT PRIMARY KEY
type TEXT NOT NULL (principle|pattern|learning|retro)
source_file TEXT NOT NULL
concepts TEXT JSON []
created_at INTEGER
updated_at INTEGER
indexed_at INTEGER
superseded_by TEXT (null if current)
superseded_at INTEGER
superseded_reason TEXT
origin TEXT (mother|arthur|volt|human|legacy)
project TEXT (ghq format)
created_by TEXT (indexer|arra_learn|manual)

idx_source, idx_type, idx_superseded, idx_origin, idx_project
```

#### `indexing_jobs` (Per-Model Embedding Queue)
```sql
id TEXT PRIMARY KEY ("idx-{ts}-{model}-{rand}")
doc_id TEXT FK→oracle_documents
model_key TEXT (bge-m3|qwen3|nomic)
collection TEXT
status TEXT (pending|claimed|done|error)
attempts INTEGER
created_at, claimed_at, finished_at, error TEXT
```

Enables **async embedding**: Document written to FTS5 synchronously, then one row per embedding model queued for daemon worker.

#### `forumThreads` & `forumMessages` (Q&A)
```sql
threads: id, title, created_by, status, issue_url, project, created_at
messages: id, thread_id, role, content, author, principles_found, created_at
```

#### `traceLog` (Discovery Traces)
```sql
trace_id TEXT UNIQUE
query TEXT
queryType TEXT (general|project|pattern|evolution)
foundFiles TEXT JSON [{path, type, matchReason, confidence}]
foundCommits TEXT JSON [{hash, date, message}]
foundIssues TEXT JSON [{number, title, state, url}]
scope TEXT (project|cross-project|human)
depth INTEGER (0=initial, 1+=dig from parent)
status TEXT (raw|reviewed|distilling|distilled)
prevTraceId, nextTraceId (linked list chain)
created_at, updated_at
```

#### `supersedeLog` (Audit Trail)
```sql
old_path, old_id, old_title, old_type
new_path, new_id, new_title
reason TEXT
superseded_at, superseded_by
```

Implements **"Nothing is Deleted"** principle.

#### `schedule` (Per-Human Shared Calendar)
```sql
date TEXT YYYY-MM-DD
time TEXT HH:MM|TBD
event TEXT
recurring TEXT (daily|weekly|monthly)
status TEXT (pending|done|cancelled)
```

#### `searchLog`, `learnLog`, `documentAccess` (Activity Logs)
Track queries, learning events, and document reads with project filtering.

#### `indexingStatus` (Progress Tracking)
```sql
is_indexing INTEGER
progress_current, progress_total INTEGER
started_at, completed_at INTEGER
error TEXT
repo_root TEXT
```

**FTS5 Virtual Table** (managed via raw SQL, Drizzle doesn't support):
```sql
CREATE VIRTUAL TABLE oracle_fts USING fts5(
  id UNINDEXED,
  content TEXT,
  concepts TEXT
)
```

---

### 4. Vector Store Layer (`src/vector/`)

**Pluggable interface for semantic search via embeddings.**

**Factory Pattern** (`factory.ts`):
```typescript
interface VectorStoreAdapter {
  readonly name: string
  connect(): Promise<void>
  close(): Promise<void>
  ensureCollection(): Promise<void>
  addDocuments(docs: VectorDocument[]): Promise<void>
  query(text: string, limit?: number, where?: Record): Promise<VectorQueryResult>
  queryById(id: string, nResults?: number): Promise<VectorQueryResult>
  getStats(): Promise<{ count: number }>
}
```

**Supported Backends** (`src/vector/adapters/`):
- **LanceDB** (default) — Local vector DB, auto-managed
- **ChromaDB** — Legacy, external server
- **SQLite-vec** — In-process, native SQLite extension
- **Qdrant** — Distributed vector DB
- **Cloudflare Vectorize** — Edge-first embeddings

**Embedding Providers**:
- **Ollama** (default) — Local, no API key
  - Model: `bge-m3` (multilingual, 1024-dim)
  - Alternatives: `qwen3` (4096-dim), `nomic` (768-dim)
- **OpenAI** — `text-embedding-3-small` (1536-dim)
- **Cloudflare AI** — Edge embeddings via Workers
- **ChromaDB internal** — Bundled with ChromaDB

**Graceful Degradation**:
- If vector store unavailable → FTS5-only with warning
- Precomputed embeddings optional (reduce round-trips)
- Connection timeout: 30s, then mark unavailable

---

### 5. Hybrid Search Algorithm (`src/tools/search.ts`)

**Combines FTS5 keyword + vector semantic search.**

**Flow**:
```
1. Sanitize query
   └─ Remove FTS5 special chars: ? * + - ( ) ^ ~ " ' : .
   
2. Parallel searches
   ├─ FTS5: SELECT ... FROM oracle_fts WHERE content MATCH 'query'
   │        Score: e^(-0.3 * |rank|) → [0, 1]
   │
   └─ Vector: vectorStore.query(text) → distances
             Score: 1 - distance (cosine similarity)
   
3. Normalize scores
   ├─ FTS: exponential decay curve
   ├─ Vector: 1 - L2 distance
   └─ Cap at [0, 1]
   
4. Merge results by document ID
   
5. Hybrid scoring
   score = (0.5 * fts_score) + (0.5 * vector_score)
   + 0.1 (boost if document in both results)
   
6. Rank by score, return top N
```

**Graceful Degradation**:
- If vector unavailable → use FTS5 only with warning
- If query becomes empty after sanitization → return original (will error, logged)

**Search Modes**:
- `hybrid` (default) — Both FTS5 + vector
- `fts` — Keywords only (faster, no embedding overhead)
- `vector` — Semantic only (more context-aware)

---

## MCP Tools (22 Total)

### Knowledge Retrieval (6 tools)
| Tool | Input | Output | Read-Only | Notes |
|------|-------|--------|-----------|-------|
| `arra_search` | query, type, limit, offset, mode, project, cwd | results[] + total | ✓ | Hybrid search with model selection |
| `arra_list` | type, limit, offset | documents[] + total | ✓ | Browse without search |
| `arra_reflect` | (none) | random_document | ✓ | Wisdom picker |
| `arra_read` | file or id | full_content | ✓ | Fetch complete document |
| `arra_concepts` | (optional filter) | concept_tags[] | ✓ | List all concept tags |
| `arra_stats` | (none) | db_stats + health | ✓ | Database statistics |

### Learning & Memory (4 tools)
| Tool | Input | Output | Notes |
|------|-------|--------|-------|
| `arra_learn` | pattern, concepts, project, source | document_id | Write new knowledge |
| `arra_handoff` | content, slug | handoff_id | Session context for next session |
| `arra_inbox` | (optional limit, type) | handoff_files[] | Retrieve pending handoffs |
| `arra_supersede` | old_id, new_id, reason | success | Mark document as outdated |

### Forum & Discussion (4 tools)
| Tool | Input | Output | Notes |
|------|-------|--------|-------|
| `arra_thread` | title, message, project | thread_id | Create or add to thread |
| `arra_threads` | status, limit | threads[] | List discussion threads |
| `arra_thread_read` | thread_id, limit | messages[] | Read thread conversation |
| `arra_thread_update` | thread_id, status | success | Close/reopen/answer thread |

### Trace Discovery (6 tools)
| Tool | Input | Output | Notes |
|------|-------|--------|-------|
| `arra_trace` | query, dig_points, scope, parent | trace_id | Log discovery session |
| `arra_trace_list` | query, project, status | traces[] | Browse traces |
| `arra_trace_get` | trace_id, includeChain | full_trace | Fetch trace + context |
| `arra_trace_link` | prev_id, next_id | success | Chain traces horizontally |
| `arra_trace_unlink` | trace_id, direction | success | Break trace chain |
| `arra_trace_chain` | trace_id | chain[] | Get full linked chain |

### Schedule (1 tool in MCP, 2 in HTTP)
| Tool | Input | Output | Notes |
|------|-------|--------|-------|
| `arra_schedule_add` | date, event, time, recurring, notes | event_id | Add appointment |
| `arra_schedule_list` | date_range, filter | events[] | List schedule entries |

### Verify (1 tool)
| Tool | Input | Output | Notes |
|------|-------|--------|-------|
| `arra_verify` | check, type | missing[], orphaned[] | Compare disk vs DB |

**Write-Protected Tools** (disabled in read-only mode):
- `arra_learn`, `arra_thread`, `arra_thread_update`, `arra_trace`, `arra_supersede`, `arra_handoff`

---

## API Endpoints (55 Total)

Organized by module. See README.md for full list.

**High-Frequency Endpoints**:
- `GET /api/search` — Hybrid search
- `GET /api/list` — Document listing
- `GET /api/reflect` — Random wisdom
- `POST /api/learn` — Add knowledge
- `GET /api/stats` — System statistics
- `GET /api/health` — Server status

**Vector Operations**:
- `GET /api/similar` — Vector nearest neighbors
- `GET /api/map` — 2D knowledge graph (via t-SNE)
- `GET /api/map3d` — 3D projection (PCA from LanceDB embeddings)

**Advanced**:
- `GET /api/traces/:id/chain` — Trace linked lists
- `POST /api/traces/:prevId/link` — Link traces
- `GET /api/oraclenet/presence` — Oracle family heartbeats
- `GET /api/plugins` — Discover plugins

---

## Data Flow Examples

### Example 1: Hybrid Search Query
```
Claude: "oracle_search" with query="nothing deleted"
  ↓
MCP Server receives call
  ↓
Tool Handler (src/tools/search.ts):
  1. Detect project from cwd
  2. Sanitize query → "nothing deleted"
  3. FTS5 query: SELECT * FROM oracle_fts WHERE content MATCH 'nothing deleted'
  4. Vector query: vectorStore.query("nothing deleted")
  5. Merge + score
  6. Log to search_log table
  7. Return results[] + metadata
  ↓
Claude receives search results with scores + source (fts|vector|hybrid)
```

### Example 2: Learn a New Pattern
```
Claude: "arra_learn" with pattern="...", concepts=["safety", "git"]
  ↓
Tool Handler (src/tools/learn.ts):
  1. Generate document ID
  2. Write to ψ/memory/learnings/{timestamp}_slug.md
  3. Insert into oracle_documents table
  4. Queue indexing jobs (one per embedding model)
  5. Return document_id + file path
  ↓
Indexer daemon (separate process):
  1. Pick up pending indexing_jobs
  2. Embed text via Ollama
  3. Write to LanceDB collection
  4. Mark job status="done"
  ↓
Next search includes newly learned pattern
```

### Example 3: Trace Discovery
```
Claude: "arra_trace" with query="multiagent patterns", foundFiles=[...], foundCommits=[...]
  ↓
Tool Handler (src/trace/handler.ts):
  1. Generate trace_id (UUID)
  2. Serialize dig_points to JSON
  3. Insert into trace_log table
  4. Calculate depth (0 if no parent)
  5. Return trace_id + summary
  ↓
Later: Claude: "arra_trace_get" with trace_id
  ↓
Returns full trace record with all dig points
  ↓
Later: Claude can link traces: "arra_trace_link" prev=trace1, next=trace2
  ↓
Creates bidirectional navigation (prev_trace_id, next_trace_id)
```

---

## Key Design Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **FTS5 + Vector Hybrid** | Fast keyword + semantic understanding | Two indexes to maintain |
| **Pluggable Vector Stores** | Support multiple backends (LanceDB, ChromaDB, Qdrant) | Abstraction layer overhead |
| **Async Embedding Queue** | Non-blocking, daemon worker pattern | Eventual consistency |
| **Drizzle ORM** | Type-safe, introspection, migration support | Another abstraction layer |
| **Elysia HTTP** | Bun-native, fast, TypeBox validation | Smaller ecosystem than Express |
| **Bun Runtime** | Fast, native TypeScript, single tool | Ecosystem smaller than Node |
| **Supersede Pattern** | "Nothing is Deleted" — audit trail | Extra table, query complexity |
| **Linked Trace Chains** | Horizontal + vertical hierarchy | More complex queries |
| **Per-Human Schedule** | Shared across all Oracles | Denormalized design |
| **Project-Aware Filtering** | Multi-org support via ghq paths | Extra column per table |

---

## Security Model

### Path Traversal Protection
- `/file` endpoint uses `fs.realpathSync()` to resolve symlinks
- Validates final path stays within `REPO_ROOT`
- Blocks `../` escapes

### Query Sanitization
- FTS5 special chars stripped before execution
- Prevents FTS5 syntax errors (which act like injection)
- Whitespace normalized

### CORS
- Default: `studio.buildwithoracle.com`, `neo.buildwithoracle.com`
- Localhost allowed (http://localhost:*)
- Configurable via `ORACLE_CORS_ORIGIN` env var
- Private Network Access preflight supported (Chrome 117+)

### MCP Write Protection
- Tools like `arra_learn`, `arra_thread` disabled if `readOnly=true`
- Enforced at server initialization

### Database
- SQLite (local, file-based, no network exposure)
- Drizzle ORM escapes all user input
- Schema-first migrations (no `CREATE TABLE` in app code)

---

## Configuration

### Environment Variables
| Variable | Default | Purpose |
|----------|---------|---------|
| `ORACLE_PORT` | 47778 | HTTP server port |
| `ORACLE_REPO_ROOT` | (must be set) | Knowledge base root |
| `ORACLE_DATA_DIR` | `~/.oracle-v3` | Database directory |
| `DB_PATH` | `{DATA_DIR}/oracle.db` | SQLite file |
| `ORACLE_CORS_ORIGIN` | (empty) | Extra allowed origins |
| `ORACLE_VECTOR_READONLY` | (unset) | Read-only vector mode |
| `VECTOR_URL` | (unset) | Proxy to external vector service |

### Tool Groups (`oracle-tools.json`)
```json
{
  "search": true,
  "learn": true,
  "forum": false,
  "traces": true,
  "schedule": true
}
```

---

## Versioning & Release Process

**CalVer Format**: `v{YY}.{M}.{D}-alpha.{HOUR}`

Example: `v26.5.2-alpha.1704` (May 2, 2026, 5 PM UTC)

**Always Nightly** by default:
- `--stable` flag only for rare intentional milestones
- Bumps via dedicated `bump/alpha.N` PR
- Auto-tag + release workflows fire on PR merge

---

## Testing

**Test Suites**:
- Unit tests: `src/**/__tests__/*.ts`
- Integration tests: `src/integration/`
- E2E tests: Playwright

**Coverage**:
- MCP tool handlers
- Search algorithms (FTS5 + vector)
- Database migrations
- Vector store adapters
- HTTP endpoints

**Run**:
```bash
bun test                    # All
bun test:unit               # Unit only
bun test:integration        # Integration only
bun test:coverage           # With coverage report
```

---

## Evolution & Roadmap

### Completed (v26.5.2)
- ✓ Hybrid FTS5 + vector search
- ✓ Forum threads (Q&A)
- ✓ Trace discovery system
- ✓ "Nothing is Deleted" supersede pattern
- ✓ Dashboard with 3D knowledge graph
- ✓ Plugin ecosystem
- ✓ Vault sync (GitHub-backed)
- ✓ OracleNet (family registry + heartbeats)
- ✓ Schedule/calendar (per-human shared)

### Planned
- Canvas plugin system (Three.js 2D/3D widgets)
- Enhanced distillation (auto-promote traces → learnings)
- Multi-model embeddings (dynamically select best model per query)
- GraphQL API (alongside REST)

---

## References

**Key Files**:
- MCP entry: `src/index.ts` (244 lines)
- HTTP server: `src/server.ts` (240 lines)
- Database schema: `src/db/schema.ts` (400+ lines)
- Search handler: `src/tools/search.ts` (300+ lines)
- Trace system: `src/trace/handler.ts` + `src/tools/trace.ts`
- Vector layer: `src/vector/factory.ts` + `src/vector/adapters/`

**Documents**:
- README.md — Installation, quick start, tool list
- TIMELINE.md — Evolution from May 2025 → present
- CLAUDE.md — Project conventions, development workflow
- docs/architecture.md — Higher-level system design
- docs/API.md — Endpoint documentation (auto-generated)

**Related Projects**:
- arra-oracle-v3 repo — This is it (rebranded from oracle-v2)
- oracle-studio — Separate React dashboard repo
- Soul-Brews-Studio — GitHub org housing Oracle ecosystem

---

## Summary

Oracle V2 is a **production-ready knowledge system** combining:
- **MCP transport** for AI integration
- **Hybrid search** (FTS5 keyword + vector semantic)
- **Forum discussions** for Q&A
- **Trace discovery** with dig points
- **"Nothing is Deleted" auditing** via supersede pattern
- **Multi-backend vector stores** (pluggable)
- **REST API** for web UI
- **Bun runtime** for speed
- **Drizzle ORM** for type safety
- **55 HTTP endpoints** + 22 MCP tools

Designed to be **local-first, multi-agent-ready, and philosophy-preserving**.
