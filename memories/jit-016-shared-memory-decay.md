---
name: jit-016-shared-memory-decay
description: Shared memory decay and cleanup policy implementation
metadata:
  type: learning
  date: 2026-06-08
  ticket: JIT-016
---

# JIT-016: Shared Memory Decay & Cleanup Policy

## Implementation Summary

Added automatic memory management to prevent unbounded growth of shared memory.

### Components Modified

1. **organs/heart.sh**
   - Added `prune_shared_memory()` function
   - Added `archive_entries()` function
   - Added `get_shared_memory_size()` function
   - Auto-prune on each heartbeat (IN beat)
   - New commands: `memory-size`, `memory-prune`

2. **organs/pran.sh**
   - Added `memory-size` command
   - Added `memory-status` command (full dashboard)

3. **organs/vitals.sh**
   - Updated `measure_heart()` to report shared memory size

### Pruning Rules

- **TTL**: Entries older than 24 hours are pruned
- **Max Entries**: Capped at 500 entries (LRU eviction)
- **Archive**: Pruned entries saved to `/tmp/manusat-shared-archive.jsonl`
- **Archive Limit**: Max 10MB (rotates when exceeded, keeps last half)

### File Locations

| File | Purpose |
|------|---------|
| `/tmp/manusat-shared.json` | Active shared memory |
| `/tmp/manusat-shared-archive.jsonl` | Archived entries (JSONL format) |

### Usage

```bash
# Check memory size
bash organs/heart.sh memory-size

# Manually trigger prune
bash organs/heart.sh memory-prune

# Full status dashboard
bash organs/pran.sh memory-status
```

### Testing Results

- ✅ TTL pruning: Removed 10 entries >24h old (15→5)
- ✅ LRU eviction: Evicted 50 oldest entries (550→500)
- ✅ Archive: 50 entries archived to JSONL
- ✅ Heartbeat integration: Auto-prune on each IN beat
- ✅ Vitals reporting: Shows `mem:{count}entries` in heart status
