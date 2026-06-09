# JIT-028: Knowledge Decay & Archival Policy — Implementation Report

## Overview

Implemented a complete knowledge decay and archival system for the Jit memory architecture, enabling automatic management of memory relevance over time.

## Changes Made

### 1. Memory Metadata Structure (`memory/shared.sh`)

Added metadata fields to all memory entries:

| Field | Type | Description |
|-------|------|-------------|
| `access_count` | integer | Number of times accessed |
| `last_accessed` | timestamp | Last access time |
| `created_date` | timestamp | Creation date |
| `expiry_date` | timestamp/null | Expiration date (if set) |
| `archived` | boolean | Archive status |
| `decay_score` | float | Relevance score (0-1) |

**Location**: `/workspaces/Jit/memory/shared.sh`

### 2. Decay Scoring Formula

```python
relevance = (0.4 * recency_score) + (0.3 * access_score) + (0.3 * semantic_score)

where:
  recency_score  = 1 / (1 + days_since_access / 30)
  access_score   = min(1, log10(access_count + 1) / 3)
  semantic_score = keyword match (0 or 1, future: vector similarity)
```

**Weights**: recency=0.4, access=0.3, semantic=0.3

### 3. `learn-expires` Command (`limbs/oracle.sh`)

New command for expiring knowledge:

```bash
./limbs/oracle.sh learn-expires "pattern" "content" "concepts" <days>
# Example:
./limbs/oracle.sh learn-expires "temp-api-key" "abc123" "security,temp" 7
```

Stores expiry date in memory index and Oracle concepts.

### 4. Archive System (`memory/shared.sh`, `mind/memory-decay.sh`)

- **Threshold**: 60 days of no access
- **Archive location**: `/workspaces/Jit/memory/archive/`
- **Archive command**: `./memory/shared.sh archive`
- **Decay check**: `./mind/memory-decay.sh check`

Archived entries:
- Moved to `/workspaces/Jit/memory/archive/*.json`
- Marked with `archived: true` in index
- Still searchable via `recall --archived`

### 5. Recall Prioritization (`memory/shared.sh`)

New `recall` command returns results sorted by decay score (high→low):

```bash
./memory/shared.sh recall "query"           # Active memories only
./memory/shared.sh recall --archived "query" # Archived memories only
```

Results include:
- Decay score
- Access count
- Days since access
- Expired/archived markers

### 6. Heartbeat Integration (`scripts/heartbeat.sh`)

Memory decay check runs every 10 pulses (~2.5 hours at normal mode):

```bash
# In _do_pulse():
if [ $(( PULSE_COUNT % 10 )) -eq 0 ]; then
  bash "$JIT_ROOT/mind/memory-decay.sh" archive
fi
```

## Files Modified/Created

| File | Type | Purpose |
|------|------|---------|
| `memory/shared.sh` | Modified | Added recall, archive commands + metadata |
| `limbs/oracle.sh` | Modified | Added learn-expires command |
| `mind/memory-decay.sh` | Created | Decay check/archive/report tool |
| `scripts/heartbeat.sh` | Modified | Integrated archive task |
| `memory/decay-policy.md` | Created | Policy documentation |
| `tests/test_memory_decay.py` | Created | Test suite (5 tests) |
| `docs/JIT-028-implementation.md` | Created | This document |

## Acceptance Criteria Status

| Criteria | Status | Notes |
|----------|--------|-------|
| ✅ Metadata on memory entries | PASS | All fields implemented |
| ✅ learn-expires command | PASS | Working with expiry tracking |
| ✅ Archive after 60 days | PASS | Tested and verified |
| ✅ Decay scoring implemented | PASS | Formula matches spec |
| ✅ recall prioritizes recent+high-access | PASS | Sorted by decay score |
| ✅ --archived flag for archive search | PASS | Filters correctly |

## Test Results

```
============================================================
TEST SUMMARY
============================================================
  ✅ PASS: Decay Scoring Formula
  ✅ PASS: Archive Threshold Logic
  ✅ PASS: Recall Prioritization
  ✅ PASS: Expiry Handling
  ✅ PASS: Archived Flag Filtering

Total: 5/5 tests passed
```

## Usage Examples

### Set memory with expiry
```bash
./memory/shared.sh set temp_key "some value" 7  # expires in 7 days
```

### Search memories
```bash
./memory/shared.sh recall "api"           # Find active memories
./memory/shared.sh recall --archived "api" # Find archived memories
```

### Check decay status
```bash
./mind/memory-decay.sh check    # Show all entries with scores
./mind/memory-decay.sh archive  # Manual archive run
./mind/memory-decay.sh report   # Generate markdown report
```

### Learn with expiry
```bash
./limbs/oracle.sh learn-expires "pattern" "content" "concepts" 30
```

## Future Enhancements

1. **Vector-based semantic scoring**: Replace keyword match with LanceDB vector similarity
2. **Configurable weights**: Allow tuning recency/access/semantic weights via environment
3. **Auto-restore**: Restore archived entries when accessed frequently
4. **Discord notifications**: Alert when important memories are about to expire
5. **Oracle schema update**: Add access_count, last_accessed columns to oracle_documents table

## Architecture Alignment

This implementation follows Buddhist principles:
- **อนิจจัง (Impermanence)**: Memories naturally decay over time
- **อนัตตา (Non-self)**: No central controller; decay emerges from usage patterns
- **มัชฌิมาปฏิปทา (Middle Way)**: Balance between retention and forgetting
