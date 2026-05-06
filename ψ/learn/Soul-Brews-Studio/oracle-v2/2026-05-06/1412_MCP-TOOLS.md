# Oracle V2 MCP Tools & Integration Patterns

**Date**: 2026-05-06  
**Source**: `/tmp/learn/Soul-Brews-Studio/oracle-v2`  
**Version**: 26.5.2-alpha.1704  
**Runtime**: Bun 1.2+, TypeScript, MCP SDK 1.29+

---

## Overview

Arra Oracle V2 is a **TypeScript MCP server** that provides semantic knowledge management via the Model Context Protocol. It exposes **22 MCP tools** to Claude Code, enabling agents to search, learn, trace, and manage collective memory across a knowledge graph.

### Stack
- **Bun** runtime (≥1.2.0)
- **SQLite** with FTS5 (full-text search)
- **ChromaDB** or LanceDB (vector/semantic search)
- **Drizzle ORM** (type-safe queries)
- **MCP Protocol** (Model Context Protocol)
- **Hono** (HTTP API server)

---

## MCP Tools Catalog (22 Tools)

### Core Search & Discovery (4 tools)

#### 1. `arra_search` — Hybrid Knowledge Search
**Purpose**: Find relevant principles, patterns, learnings, or retrospectives using keyword + semantic search.

**Input**:
```typescript
interface OracleSearchInput {
  query: string;           // Required: e.g., "force push safety"
  type?: 'principle' | 'pattern' | 'learning' | 'retro' | 'all';  // Default: 'all'
  limit?: number;          // Default: 5
  offset?: number;         // Default: 0 (pagination)
  mode?: 'hybrid' | 'fts' | 'vector';  // Default: 'hybrid'
  project?: string;        // Filter by GitHub project
  cwd?: string;           // Auto-detect project from path
  model?: 'nomic' | 'qwen3' | 'bge-m3';  // Vector model (default: bge-m3, multilingual Thai↔EN)
}
```

**Output**: Search results with:
- Document ID, type, title, content snippet
- Source file path
- Concepts/tags
- Score (hybrid blend of FTS + vector)
- Search metadata (which source matched, time)

**Hybrid Algorithm**:
1. Sanitize query (remove FTS5 special chars: `? * + - ( ) ^ ~ " '`)
2. Run **FTS5 keyword search** on SQLite
3. Run **vector search** on ChromaDB (configurable model)
4. Normalize scores:
   - FTS5: `e^(-0.3 * |rank|)` (exponential decay)
   - Vector: `1 - distance`
5. Merge results: 50% FTS + 50% vector, +10% boost if in both
6. Graceful fallback: FTS5-only if ChromaDB unavailable

---

#### 2. `arra_read` — Fetch Full Document Content
**Purpose**: Read complete file content by path or document ID. Resolves vault paths, ghq repos, and symlinks server-side.

**Input**:
```typescript
interface OracleReadInput {
  file?: string;  // e.g., "ψ/memory/learnings/file.md" or "github.com/org/repo/ψ/..."
  id?: string;    // Document ID from arra_search results
}
```

**Output**:
```json
{
  "content": "full markdown content",
  "source_file": "ψ/memory/learnings/my-learning.md",
  "resolved_path": "/absolute/path/to/file",
  "source": "file" or "fts_cache",
  "project": "github.com/org/repo"  // if multi-project
}
```

**Resolution Strategy**:
1. Try direct from repoRoot (`ψ/memory/...` paths)
2. Try ghq project path (`github.com/org/repo/ψ/...`)
3. Try vault fallback
4. Fallback to FTS indexed cache (if available)

---

#### 3. `arra_list` — Browse All Documents
**Purpose**: List documents without search, with pagination and type filtering.

**Input**:
```typescript
interface OracleListInput {
  type?: 'principle' | 'pattern' | 'learning' | 'retro' | 'all';  // Default: 'all'
  limit?: number;   // 1-100, default: 10
  offset?: number;  // Default: 0
}
```

**Output**: Array of documents (paginated) with previews.

---

#### 4. `arra_concepts` — List Topic Tags
**Purpose**: Discover what topics are covered in the knowledge base.

**Input**:
```typescript
interface OracleConceptsInput {
  limit?: number;   // Default: 50
  type?: 'principle' | 'pattern' | 'learning' | 'retro' | 'all';  // Default: 'all'
}
```

**Output**:
```json
{
  "concepts": [
    { "name": "git", "count": 42 },
    { "name": "safety", "count": 38 }
  ],
  "total_unique": 127,
  "filter_type": "all"
}
```

---

### Learning & Memory (3 tools)

#### 5. `arra_learn` — Add New Pattern/Learning
**Purpose**: Persist new knowledge to the learning base. Creates a markdown file in `ψ/memory/learnings/` and indexes it.

**Input**:
```typescript
interface OracleLearnInput {
  pattern: string;      // Required: the learning content (can be multi-line)
  source?: string;      // Optional: e.g., "rrr: org/repo" or "arra_learn from github.com/org/repo"
  concepts?: string[];  // Optional: ["git", "safety", "trust"]
  project?: string;     // Source project, auto-normalized: "github.com/owner/repo" or "owner/repo"
}
```

**Output**:
```json
{
  "success": true,
  "file": "ψ/memory/learnings/my-learning-20260506.md",
  "id": "learning:uuid",
  "concepts": ["git", "safety"],
  "project": "github.com/org/repo"
}
```

**Features**:
- Auto-generates filename from timestamp + slug
- Normalizes project input (handles `owner/repo`, URLs, paths)
- Extracts project from source attribution field
- Tags with concepts for discovery
- Triggers automatic indexing (FTS5 + vector)

---

#### 6. `arra_handoff` — Session Context Preservation
**Purpose**: Save session context for future sessions. Writes to `ψ/inbox/handoff/` with timestamp.

**Input**:
```typescript
interface OracleHandoffInput {
  content: string;  // Required: markdown content (progress, context, next steps)
  slug?: string;    // Optional: filename slug (auto-generated if omitted)
}
```

**Output**:
```json
{
  "success": true,
  "file": "ψ/inbox/handoff/2026-05-06_14-12_my-slug.md",
  "message": "Handoff written. Next session can read it with arra_inbox()."
}
```

**Vault Support**: If vault is configured, writes to vault repo with project-nested paths:
```
vault_root/github.com/org/repo/ψ/inbox/handoff/YYYY-MM-DD_HH-mm_slug.md
```

---

#### 7. `arra_inbox` — List Pending Handoffs
**Purpose**: Browse handoff files from previous sessions.

**Input**:
```typescript
interface OracleInboxInput {
  limit?: number;   // Default: 10
  offset?: number;  // Default: 0
  type?: 'handoff' | 'all';  // Default: 'all'
}
```

**Output**:
```json
{
  "files": [
    {
      "filename": "2026-05-06_14-12_session-wrap.md",
      "path": "ψ/inbox/handoff/2026-05-06_14-12_session-wrap.md",
      "created": "2026-05-06T14:12:00",
      "preview": "Brief excerpt from content...",
      "type": "handoff"
    }
  ],
  "total": 5,
  "limit": 10,
  "offset": 0
}
```

---

### Statistics & Health (2 tools)

#### 8. `arra_stats` — Database Statistics
**Purpose**: Get knowledge base health and metrics.

**Input**: None (empty object)

**Output**:
```json
{
  "total_documents": 147,
  "by_type": {
    "principle": 42,
    "pattern": 38,
    "learning": 52,
    "retro": 15
  },
  "fts_indexed": 147,
  "unique_concepts": 92,
  "last_indexed": "2026-05-06T14:05:30.000Z",
  "vector_status": "connected",
  "fts_status": "healthy",
  "version": "26.5.2-alpha.1704"
}
```

---

#### 9. `arra_concepts` (alias from above)

---

### Document Lifecycle (2 tools)

#### 10. `arra_supersede` — Mark Documents Outdated
**Purpose**: Implement "Nothing is Deleted" principle. Mark old documents as superseded by newer ones.

**Input**:
```typescript
interface OracleSupersededInput {
  oldId: string;     // Required: ID of outdated document
  newId: string;     // Required: ID of replacement document
  reason?: string;   // Optional: why it's outdated
}
```

**Output**:
```json
{
  "success": true,
  "old_id": "learning:abc123",
  "old_type": "learning",
  "new_id": "learning:def456",
  "new_type": "learning",
  "reason": "Updated with new findings",
  "superseded_at": "2026-05-06T14:12:00Z",
  "message": "Document marked as superseded. It will still appear in search results (P-001 Nothing is Deleted), now flagged with superseded_by, superseded_at, and superseded_reason fields."
}
```

**Database Changes**:
- Sets `superseded_by`, `superseded_at`, `superseded_reason` on old document
- Old document still indexed and searchable
- Query results can follow replacement pointer

---

### Tracing & Discovery (6 tools)

#### 11. `arra_trace` — Log Discovery Session
**Purpose**: Capture exploration/research sessions with "dig points" (files, commits, issues found).

**Input**:
```typescript
interface CreateTraceInput {
  query: string;                    // Required: what was traced
  queryType?: 'general' | 'project' | 'pattern' | 'evolution';  // Default: 'general'
  foundFiles?: Array<{
    path: string;
    type?: 'learning' | 'retro' | 'resonance' | 'other';
    matchReason: string;
    confidence: 'high' | 'medium' | 'low';
  }>;
  foundCommits?: Array<{
    hash: string;
    shortHash: string;
    date: string;
    message: string;
  }>;
  foundIssues?: Array<{
    number: number;
    title: string;
    state: 'open' | 'closed';
    url: string;
  }>;
  foundRetrospectives?: string[];  // File paths
  foundLearnings?: string[];       // File paths
  scope?: 'project' | 'cross-project' | 'human';  // Default: 'project'
  parentTraceId?: string;          // For nested digs
  project?: string;                // ghq format: github.com/org/repo
  agentCount?: number;             // Agents involved
  durationMs?: number;             // How long it took
}
```

**Output**:
```json
{
  "success": true,
  "trace_id": "trace:uuid",
  "depth": 1,
  "summary": {
    "file_count": 3,
    "commit_count": 5,
    "issue_count": 2,
    "total_dig_points": 10
  },
  "message": "Trace logged. Use arra_trace_get with trace_id=\"...\" to explore dig points."
}
```

---

#### 12. `arra_trace_list` — Browse Traces
**Purpose**: Find past trace sessions.

**Input**:
```typescript
interface ListTracesInput {
  query?: string;                          // Filter by query content
  project?: string;                        // Filter by project
  status?: 'raw' | 'reviewed' | 'distilling' | 'distilled';  // Distillation status
  depth?: number;                          // Filter by recursion depth
  limit?: number;                          // Default: 20
  offset?: number;                         // Default: 0
}
```

**Output**: Array of trace summaries with metadata.

---

#### 13. `arra_trace_get` — Fetch Trace Details
**Purpose**: Get complete trace with all dig points.

**Input**:
```typescript
interface GetTraceInput {
  traceId: string;         // Required: trace UUID
  includeChain?: boolean;  // Include parent/child chain, default: false
}
```

**Output**: Full trace object with dig points, file list, commits, issues.

---

#### 14. `arra_trace_link` — Chain Related Traces
**Purpose**: Create bidirectional navigation between related traces.

**Input**:
```typescript
{
  prevTraceId: string;   // Required: trace that comes first
  nextTraceId: string;   // Required: trace that comes after
}
```

**Output**: Confirmation with linked trace IDs.

---

#### 15. `arra_trace_unlink` — Break Trace Chain
**Purpose**: Remove link between traces in specified direction.

**Input**:
```typescript
{
  traceId: string;       // Required: trace to unlink from
  direction: 'prev' | 'next';  // Which direction to break
}
```

---

#### 16. `arra_trace_chain` — View Linked Chain
**Purpose**: Get full linked chain for a trace.

**Input**:
```typescript
{
  traceId: string;  // Required: any trace in the chain
}
```

**Output**: All traces in chain with navigation pointers.

---

### Forum & Consultation (4 tools)

#### 17. `arra_thread` — Send Message / Create Thread
**Purpose**: Multi-turn discussions. Starts new thread or continues existing one. Oracle auto-responds from knowledge base.

**Input**:
```typescript
interface OracleThreadInput {
  message: string;              // Required: your question/message
  threadId?: number;            // Continue existing thread (omit to create)
  title?: string;               // For new threads (defaults to first 50 chars)
  role?: 'human' | 'claude';    // Who is sending, default: 'human'
  model?: string;               // For Oracle's response, e.g., "opus", "sonnet"
}
```

**Output**:
```json
{
  "thread_id": 123,
  "message_id": 456,
  "status": "active",
  "oracle_response": {
    "content": "Guidance based on knowledge base...",
    "principles_found": 5,
    "patterns_found": 3
  },
  "issue_url": "https://github.com/..."  // If created as issue
}
```

---

#### 18. `arra_threads` — List Threads
**Purpose**: Browse discussion threads.

**Input**:
```typescript
interface OracleThreadsInput {
  status?: 'active' | 'answered' | 'pending' | 'closed';
  limit?: number;   // Default: 20
  offset?: number;  // Default: 0
}
```

**Output**: Array of thread summaries.

---

#### 19. `arra_thread_read` — Get Thread History
**Purpose**: Read full message history of a thread.

**Input**:
```typescript
interface OracleThreadReadInput {
  threadId: number;    // Required: thread ID
  limit?: number;      // Max messages to return (default: all)
}
```

**Output**: Array of messages with timestamps.

---

#### 20. `arra_thread_update` — Change Thread Status
**Purpose**: Close, reopen, or mark threads as answered/pending.

**Input**:
```typescript
interface OracleThreadUpdateInput {
  threadId: number;
  status: 'active' | 'closed' | 'answered' | 'pending';
}
```

---

### Special Tools (2 tools)

#### 21. `arra_reflect` — Random Wisdom
**Purpose**: Get random principle or learning for reflection/alignment.

**Input**: None (empty object)

**Output**:
```json
{
  "principle": {
    "id": "principle:uuid",
    "type": "principle",
    "content": "Full principle text...",
    "source_file": "ψ/memory/resonance/5-principles.md",
    "concepts": ["philosophy", "design"]
  }
}
```

---

#### 22. `____IMPORTANT` — Meta Documentation
**Purpose**: Built-in workflow guide (not a tool you call, but listed when querying tools).

Contains quick reference to all 5 tool categories:
1. Search & Discover
2. Learn & Remember
3. Trace & Distill
4. Handoff & Inbox
5. Supersede

---

## Connection Patterns: Oracle V2 ↔ Claude Code

### MCP Protocol Flow

```
Claude Code
    ↓
MCP Client (built into Claude)
    ↓
StdioServerTransport (bun via bin)
    ↓
Arra Oracle MCP Server (src/index.ts)
    ├─ ListToolsRequest → returns all 22 tools
    └─ CallToolRequest → routes to handler (src/tools/*.ts)
    ↓
Tool Handler
    ├─ ToolContext: { db, sqlite, vectorStore, repoRoot, version }
    ├─ Executes query/operation
    └─ Returns ToolResponse (JSON content)
    ↓
Claude receives result
```

### Registration in Claude Code

**CLI**:
```bash
claude mcp add arra-oracle-v2 -- bunx --bun arra-oracle-v2@github:Soul-Brews-Studio/arra-oracle-v3#main
```

**Manual (~/.claude.json)**:
```json
{
  "mcpServers": {
    "arra-oracle-v2": {
      "command": "bunx",
      "args": ["--bun", "arra-oracle-v2@github:Soul-Brews-Studio/arra-oracle-v3#main"]
    }
  }
}
```

### Tool Availability

**Read-Only Mode**:
- Activated via: `ORACLE_READ_ONLY=true` or `--read-only` flag
- Disables: `arra_learn`, `arra_thread`, `arra_thread_update`, `arra_trace`, `arra_supersede`, `arra_handoff`
- Enables: all search/read/stats/reflect tools

**Tool Group Config** (`ψ/config.json` or `arra.config.json`):
```json
{
  "toolGroups": {
    "search": true,
    "learn": true,
    "forum": false,
    "trace": true
  }
}
```

Individual tools can be disabled via config without restarting.

---

## Database Schema (Drizzle ORM)

### Main Tables

**`oracle_documents`**: Metadata index
```
id: string (UUID)
type: 'principle' | 'pattern' | 'learning' | 'retro'
source_file: string
concepts: JSON array
project: string (nullable, ghq format)
created_at: timestamp
updated_at: timestamp
indexed_at: timestamp
superseded_by: string (nullable, document ID)
superseded_at: timestamp (nullable)
superseded_reason: string (nullable)
```

**`oracle_fts`**: Virtual FTS5 table
```
id: string (UNINDEXED)
content: string
concepts: string
```

**`oracle_threads`**: Forum discussions
```
id: integer
title: string
status: 'active' | 'answered' | 'pending' | 'closed'
created_at: timestamp
updated_at: timestamp
```

**`oracle_messages`**: Thread replies
```
id: integer
thread_id: integer FK
role: 'human' | 'claude'
content: string
created_at: timestamp
```

**`oracle_traces`**: Discovery sessions
```
id: string (UUID)
query: string
queryType: string
scope: 'project' | 'cross-project' | 'human'
depth: integer
status: 'raw' | 'reviewed' | 'distilling' | 'distilled'
findings_json: JSON (files, commits, issues, etc.)
created_at: timestamp
parent_trace_id: string (nullable)
prev_trace_id: string (nullable)
next_trace_id: string (nullable)
```

---

## Integration Patterns

### Pattern 1: Search → Read → Learn Loop
**Agent workflow for knowledge discovery**:

```
arra_search("topic")
  → analyze results
  → arra_read(id) for full content
  → arra_learn("my synthesis") to persist insights
  → next iteration
```

---

### Pattern 2: Trace → Handoff → Inbox
**Session preservation**:

```
Start of session:
  arra_inbox() to get context from previous sessions

Mid-session:
  arra_trace(query) to log discoveries as you go

End of session:
  arra_handoff("context for next agent") to save progress

Next session:
  arra_inbox() picks up where you left off
```

---

### Pattern 3: Supersede Chain
**Knowledge evolution**:

```
arra_learn("initial pattern")  → v1
arra_learn("refined pattern")   → v2
arra_supersede(v1_id, v2_id, "found edge cases")

Later:
arra_search("pattern") returns both, with v1 flagged as outdated
arra_read(v1_id) includes pointer to v2
```

---

### Pattern 4: Trace Chains
**Linked discovery sessions**:

```
Session A: arra_trace(query1) → trace_id_A
Session B: arra_trace(query2, parentTraceId: A) → trace_id_B
Later:
arra_trace_link(A, B)        # Link them bidirectionally
arra_trace_chain(A)          # See full A→B→C chain
```

---

### Pattern 5: Forum for Decisions
**Collaborative reasoning**:

```
Agent 1: arra_thread("Should we refactor X?")  → thread_id=123
Agent 2: arra_thread("Yes, because...", threadId=123)
Agent 3: arra_thread_read(123) to get context
        arra_thread("Disagree, here's why...", threadId=123)
Orchestrator: arra_thread_update(123, 'answered') when resolved
```

---

## Tool Handlers Implementation

All handlers in `src/tools/` follow the same pattern:

```typescript
// 1. Define tool schema
export const toolNameToolDef = {
  name: 'arra_tool_name',
  description: '...',
  inputSchema: { type: 'object', properties: { ... } }
};

// 2. Export input type
export interface ToolNameInput { ... }

// 3. Implement handler (async)
export async function handleToolName(
  ctx: ToolContext,    // Database, file system, vector store
  input: ToolNameInput
): Promise<ToolResponse> {
  // Validation
  // Query/operation
  // Return { content: [{ type: 'text', text: JSON.stringify(result) }] }
}

// 4. Register in index.ts (already done)
// 5. Import and export in tools/index.ts barrel
```

---

## Search & Vector Models

### Embedding Models Available

1. **bge-m3** (default):
   - Multilingual (Thai ↔ English)
   - 1024-dimensional
   - Optimized for semantic similarity
   - Via Ollama at MDES-Innova

2. **nomic**:
   - Fast, lightweight
   - 768-dimensional
   - Good for quick searches

3. **qwen3**:
   - Cross-language specialized
   - 4096-dimensional
   - Slower but more precise

### Vector Stores

- **LanceDB** (primary, in `src/vector/factory.ts`)
- **ChromaDB** (fallback)
- Graceful degradation to FTS5-only if unavailable

---

## Special Features

### "Nothing is Deleted" Principle (P-001)
- `arra_supersede` marks documents outdated, doesn't remove them
- Old docs still appear in search with `superseded_by` pointer
- Creates audit trail of knowledge evolution

### Project Context
- Multi-project awareness (ghq-style: `github.com/owner/repo`)
- `arra_learn` normalizes projects: accepts `owner/repo`, URLs, paths
- `arra_read` resolves across vault + ghq + local paths

### Vault Support
- Centralized knowledge vault (separate repo)
- `arra_handoff` writes to vault with project nesting
- `oracle-vault` CLI for sync/pull/migrate

### Tool Groups
- Disable entire categories (search, learn, forum, trace)
- Per-tool granularity for fine-grained control
- Config file: `ψ/config.json` or `arra.config.json`

---

## Workflow Summary (Quick Reference)

| Goal | Tool Sequence |
|------|---|
| Find knowledge | `arra_search()` → `arra_read()` |
| Add learning | `arra_learn()` + optionally `arra_concepts()` |
| Browse | `arra_list()` + `arra_concepts()` |
| Preserve session | `arra_handoff()` at end, `arra_inbox()` at start |
| Log exploration | `arra_trace()` with dig points |
| Update old info | `arra_learn()` new, then `arra_supersede()` old |
| Link traces | `arra_trace_link()` for discovery chains |
| Discuss decision | `arra_thread()` → `arra_thread_read()` → `arra_thread_update()` |
| Get stats | `arra_stats()` or `arra_concepts()` |
| Random wisdom | `arra_reflect()` |

---

## Configuration & Environment

### Environment Variables
- `ORACLE_PORT`: HTTP server port (default: 47778)
- `ORACLE_REPO_ROOT`: Knowledge base location (default: safe config, never `process.cwd()`)
- `ORACLE_READ_ONLY`: Run in read-only mode (disables write tools)
- `ORACLE_VECTOR_READONLY`: Vector server read-only mode

### Files
- **Database**: `sqlite.db` at `ORACLE_DATA_DIR` (default: `./db`)
- **Config**: `ψ/config.json` or `arra.config.json`
- **Knowledge**: `ψ/memory/`, `ψ/inbox/`

---

## Key Design Principles

1. **Hybrid Search**: Keyword + semantic for complementary strength
2. **Graceful Degradation**: FTS5-only if vector DB unavailable
3. **Nothing is Deleted**: Supersede instead of overwrite
4. **Project-Aware**: Multi-repo support via ghq conventions
5. **Tool Granularity**: Independent tools, compose via tools
6. **Type-Safe**: Drizzle ORM, TS interfaces for all inputs/outputs
7. **Server-Side Resolution**: Path/vault resolution happens server-side
8. **Audit Trail**: All traces, handoffs, supersessions logged

---

## Performance Characteristics

- **Search**: 100ms–1s (depending on DB size + vector model)
- **Learn**: ~200ms (disk write + FTS index + vector embed)
- **Read**: <10ms (from file or FTS cache)
- **List/Stats**: <50ms (simple queries)
- **Vector Search**: 100–500ms (depends on model, DB size)

---

## Security

- **Path Traversal Protection**: `fs.realpathSync()` + bounds check in `arra_read`
- **Read-Only Mode**: Disables all write tools
- **Tool Whitelisting**: Config-based tool groups
- **No Auth Required** (by design): runs locally or in trusted network

---

## References

- **Source**: `/tmp/learn/Soul-Brews-Studio/oracle-v2` (cloned from Soul-Brews-Studio/arra-oracle-v3)
- **Entry Point**: `src/index.ts` (MCP server)
- **Tools**: `src/tools/*.ts` (22 individual handlers)
- **Database**: `src/db/schema.ts` (Drizzle schema)
- **HTTP API**: `src/server.ts` (optional REST endpoint)

---

## Related Documentation

- [Architecture](docs/architecture.md) — System design, schema, logging
- [API.md](docs/API.md) — HTTP endpoints reference
- [MCP SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Drizzle ORM](https://orm.drizzle.team/)
