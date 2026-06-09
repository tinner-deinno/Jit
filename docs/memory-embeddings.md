# Memory Embeddings

> **JIT-023** — Vector embeddings and semantic indexing for the memory system

## Overview

The memory system now supports **semantic search** alongside exact matching. Using vector embeddings, agents can find contextually relevant memories across sessions, even when keywords don't match exactly.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Memory Query                              │
│                  "recall <topic>"                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐
│  Exact Match    │       │  Semantic Match │
│  (FTS5)         │       │  (Vector)       │
└────────┬────────┘       └────────┬────────┘
         │                         │
         └────────────┬────────────┘
                      │
                      ▼
         ┌─────────────────────────┐
         │   Ranked Results with   │
         │   Similarity Scores     │
         └─────────────────────────┘
```

## Embedding Storage

Embeddings are stored alongside knowledge entries in two locations:

### 1. Oracle Knowledge Base (Primary)

The Arra Oracle V3 stores embeddings in LanceDB:
- **Location**: `~/.arra-oracle-v3/ψ/memory/`
- **Index**: ChromaDB/LanceDB vector index
- **Dimensions**: 1024 (bge-m3 model) or 768 (nomic-embed)

### 2. Local Cache (Secondary)

For fast access, recent embeddings are cached locally:
- **Location**: `/workspaces/Jit/memory/embeddings/`
- **Format**: JSON with embedded vectors
- **Refresh**: Updated on each heartbeat

## Usage

### Recall with Semantic Search

```bash
# Basic recall (exact + semantic)
bash memory/shared.sh recall "decision-making"

# Search archived memories
bash memory/shared.sh recall --archived "old-patterns"

# Oracle search with embeddings
bash limbs/oracle.sh search "multi-agent coordination" 10
```

### Example Output

```
=== Recall Results: 'decision-making' ===

[0.92] architecture-decisions: When choosing between options, 
  always document rationale. Use ADR format for significant... [innova@15x]

[0.87] oracle-first-pattern: Query Oracle before major decisions
  to avoid duplicating stored knowledge... [soma@23x]

[0.75] reversible-actions: Design rollback paths; signal before
  destructive operations... [lak@8x]

[0.68] team-structure: Decision hierarchy follows soma→lak→innova
  for technical choices... [vaja@5x]
```

## Configuration

### Embedding Model

Select the embedding model via environment or oracle.sh:

```bash
# Models available:
# - bge-m3 (default): 1024-dim, multilingual (Thai↔EN)
# - nomic: 764-dim, fast English
# - qwen3: 4096-dim, cross-language

bash limbs/oracle.sh search "query" 10 --model bge-m3
```

### Similarity Threshold

Results below this threshold are filtered out:

```bash
# In limbs/lib.sh or environment
EMBEDDING_THRESHOLD=0.6  # Default: 0.6 (60% similarity)
```

### Decay Scoring

Memory relevance decays over time using this formula:

```python
relevance = (RECENCY_WEIGHT * recency_score) + 
            (ACCESS_WEIGHT * access_score) + 
            (SEMANTIC_WEIGHT * semantic_score)

# Default weights:
RECENCY_WEIGHT = 0.4   # Freshness matters
ACCESS_WEIGHT = 0.3    # Frequently accessed = important
SEMANTIC_WEIGHT = 0.3  # Semantic match strength
```

## Memory Index Structure

The memory index (`memory/index.json`) tracks each entry with metadata:

```json
{
  "entries": {
    "architecture-decisions": {
      "value": "When choosing between options...",
      "set_by": "innova",
      "created_date": "2026-06-01T10:00:00",
      "last_accessed": "2026-06-08T04:30:00",
      "access_count": 15,
      "expiry_date": null,
      "archived": false,
      "decay_score": 0.92,
      "embedding_id": "emb_abc123"
    }
  },
  "archived": []
}
```

## Cross-Session Recovery

Given a context, find relevant prior decisions:

```bash
# Context: "We're designing a new API endpoint"
bash memory/shared.sh recall "API design"

# This returns:
# - Exact matches for "API" and "design"
# - Semantic matches like "endpoint patterns", "REST conventions"
# - Related decisions from previous sessions
```

### Example Recovery Flow

```bash
# Step 1: Capture current context
CONTEXT="Implementing health tracking for agent registry"

# Step 2: Recall relevant memories
bash memory/shared.sh recall "$CONTEXT"

# Step 3: Review returned memories for patterns
# - Previous registry changes
# - Health monitoring patterns
# - Similar implementations

# Step 4: Apply learned patterns to current task
```

## Heartbeat Refresh

Embeddings are refreshed periodically:

```bash
# Heartbeat batch job updates embeddings
bash organs/heart.sh refresh-embeddings
```

This:
1. Scans new/changed memory entries
2. Generates embeddings via Oracle API
3. Updates local cache
4. Syncs to Oracle DB

## Oracle Integration

### Search with Embeddings

```bash
# Search Oracle with semantic matching
bash limbs/oracle.sh search "agent health" 5

# Returns results ranked by:
# - Keyword match (FTS5)
# - Vector similarity (ChromaDB/LanceDB)
# - Recency boost
```

### Learn with Auto-Embedding

```bash
# New knowledge is automatically embedded
bash limbs/oracle.sh learn "new-pattern" "Content here" "pattern,health"

# Oracle generates embedding and stores in vector index
```

## Performance Considerations

| Operation | Latency | Notes |
|-----------|---------|-------|
| Exact match recall | < 50ms | FTS5 index lookup |
| Semantic search | 100-300ms | Vector similarity calculation |
| Embedding generation | 500-1000ms | One-time per new entry |
| Batch refresh | 5-10s | Heartbeat background job |

## Files and Paths

| Path | Purpose |
|------|---------|
| `memory/index.json` | Memory index with metadata |
| `memory/archive/` | Archived memories (>60 days) |
| `memory/embeddings/` | Local embedding cache |
| `/tmp/manusat-shared.json` | Real-time shared state |
| `~/.arra-oracle-v3/ψ/memory/` | Oracle knowledge base |

## Query Examples

### Find Related Decisions

```bash
# "What decisions did we make about caching?"
bash memory/shared.sh recall "caching strategy"
```

### Recover Context After Restart

```bash
# "What was I working on related to message tracing?"
bash memory/shared.sh recall "message tracing correlation"
```

### Discover Patterns

```bash
# "Show me all architecture patterns"
bash memory/shared.sh recall "architecture pattern"
```

### Cross-Language Search

Thai query for English content (with bge-m3):

```bash
# Thai query returns English memories
bash memory/shared.sh recall "การตัดสินใจ"  # Returns "decision-making" entries
```

## Best Practices

1. **Query before deciding** — Always recall relevant memories first
2. **Use specific terms** — More specific queries yield better semantic matches
3. **Review decay scores** — High scores indicate fresh, frequently-used memories
4. **Archive proactively** — Move old memories to archive to keep recall fast
5. **Cross-reference with CoT logs** — Combine semantic search with decision traces

## Troubleshooting

### No Results Returned

```bash
# Check if memory index exists
cat memory/index.json

# Verify Oracle is running
curl http://localhost:47778/api/health

# Try broader search terms
bash memory/shared.sh recall "general-term"
```

### Slow Queries

```bash
# Check index size
cat memory/index.json | jq '.entries | keys | length'

# Archive old entries
bash memory/shared.sh archive

# Reduce result limit
bash memory/shared.sh recall "query" --limit 5
```

## Related Documentation

- [[cot-logging]] — Decision traces that complement memory entries
- [[registry-health]] — Track memory system health
- [[oracle]] — Arra Oracle knowledge base integration

---

*Document version: 1.0 | Created: 2026-06-08 | Owner: innova*
