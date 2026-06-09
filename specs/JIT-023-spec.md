# JIT-023: Vector Embeddings & Semantic Memory

**Status**: In Progress  
**Owner**: innova (Lead Developer)  
**Priority**: P2  
**Created**: 2026-06-07

## Objective

เพิ่ม semantic search capabilities ให้ memory system โดยเก็บ vector embeddings ใน `memory/` alongside knowledge entries และใช้ Oracle V3 เป็น backing store สำหรับ embeddings

## Acceptance Criteria

1. ✅ Embeddings stored in `memory/embeddings/` alongside knowledge entries
2. ✅ `memory/shared.sh recall` returns exact + semantically similar matches
3. ✅ Embeddings refreshed on heartbeat
4. ✅ `similarity_score` included in responses
5. ✅ Cross-session memory recovery works

## Architecture

```
Memory System v2 (with Embeddings)
├── /tmp/manusat-shared.json      ← Real-time shared state (ephemeral)
├── memory/
│   ├── index.json                ← Memory index with metadata
│   ├── knowledge/                ← Knowledge entries (flat files)
│   ├── embeddings/               ← NEW: Vector embeddings cache
│   │   ├── <key>.embedding.json  ← { vector, model, timestamp, source }
│   │   └── index.embeddings.json ← Embedding index for fast lookup
│   ├── heartbeats/               ← Heartbeat snapshots
│   └── archive/                  ← Archived memories
└── Arra Oracle V3                ← Persistent storage with LanceDB vectors
    ├── FTS5 SQLite               ← Keyword search
    └── LanceDB                   ← Semantic/vector search
```

## Embedding Generation Flow

```
1. New memory entry created → trigger embedding generation
2. limbs/embed.sh generate <key> → MDES Ollama (gemma4:e4b) or local model
3. Store embedding in memory/embeddings/<key>.embedding.json
4. Sync to Oracle LanceDB (optional, for cross-repo sharing)
5. On recall: compute query embedding → cosine similarity → rank results
```

## API Changes

### shared.sh recall

**Before:**
```bash
./shared.sh recall "query"
# Returns: exact keyword matches only
```

**After:**
```bash
./shared.sh recall "query" [--semantic] [--limit N]
# Returns: hybrid results with similarity_score
# Output format:
#   [{
#     "key": "...",
#     "value": "...",
#     "similarity_score": 0.85,
#     "decay_score": 0.72,
#     "combined_score": 0.79,
#     "source": "semantic|exact|hybrid"
#   }]
```

### New Commands

```bash
# Generate embeddings for all memories
./limbs/embed.sh build-all

# Generate embedding for specific key
./limbs/embed.sh generate <key>

# Query with semantic search
./shared.sh recall "query" --semantic --limit 10

# Refresh embeddings (heartbeat hook)
./limbs/embed.sh refresh
```

## Implementation Plan

### Phase 1: Core Embedding Infrastructure
- [x] Create `limbs/embed.sh` — embedding generation script
- [x] Create `memory/embeddings/` directory
- [x] Implement embedding generation via MDES Ollama
- [x] Store embeddings in JSON format

### Phase 2: Semantic Search Integration
- [x] Update `shared.sh recall` to support `--semantic` flag
- [x] Implement cosine similarity calculation
- [x] Combine decay score + similarity score
- [x] Format output with similarity_score

### Phase 3: Heartbeat Integration
- [ ] Add embedding refresh to heartbeat script
- [ ] Batch embedding generation for new memories
- [ ] Error handling for embedding failures

### Phase 4: Cross-Session Recovery
- [ ] Implement context-based memory retrieval
- [ ] Test across multiple sessions
- [ ] Document recovery patterns

## Similarity Scoring Formula

```
combined_score = (SEMANTIC_WEIGHT × similarity_score) + 
                 (DECAY_WEIGHT × decay_score) + 
                 (ACCESS_WEIGHT × access_score)

Where:
- similarity_score: cosine similarity between query and memory embedding [0-1]
- decay_score: recency-based score [0-1]
- access_score: log10(access_count) normalized [0-1]
- Default weights: SEMANTIC=0.4, DECAY=0.35, ACCESS=0.25
```

## Dependencies

- MDES Ollama API (`https://ollama.mdes-innova.online`)
- Python3 with numpy (for cosine similarity)
- Arra Oracle V3 (LanceDB backing store)
