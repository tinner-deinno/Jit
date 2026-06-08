---
name: health_check_false_positives_fixed
description: Updated eval/body-check.sh and soul-check.sh to eliminate false positives via timestamp validation and strict JSON parsing
metadata:
  type: feedback
  date: 2026-06-08
---

# Health Check Script Improvements

## Problem Identified
Both health check scripts were reporting PASS on stale/broken systems because they checked for file existence rather than actual health signals.

## False Positives Found

### body-check.sh
- heart.out.json existence ≠ fresh heartbeat (could be 1hr old)
- No message queue monitoring (backlog accumulation invisible)
- Redundant Oracle health file check that always passed

### soul-check.sh
- Loose grep patterns (grep -q "status":"ok" matches partial strings)
- No explicit Oracle API connectivity test
- No validation that search results actually exist (empty results pass)
- Fragile ls command patterns

## Fixes Applied

### body-check.sh Changes
1. **Timestamp validation**: Check heart.out.json timestamp < 5 minutes old (300s threshold)
   - Actively measures heartbeat freshness
   - Alerts if pulse stale (e.g., 150s = PASS, 400s = WARN)

2. **Message queue monitoring**: Check inbox depth via `bus.sh queue`
   - Threshold: warn if > 50 messages (backlog accumulation)
   - Currently seeing healthy drain (25 messages)

3. **Stricter Oracle validation**: Explicit JSON parse `d.get('status')=='ok'`
   - Removed the always-passing Oracle health file check

### soul-check.sh Changes
1. **Strict JSON parsing**: All HTTP responses validated via `python3 -c "json.load(...); exit(0 if CONDITION else 1)"`
   - Oracle health: `status == 'ok'` (not substring grep)
   - Oracle search: `len(results) > 0` (not just presence of 'innova' string)
   - Ollama: `'models' in response` (not substring match)

2. **Explicit API timeout**: `--max-time 3` flags on Oracle calls
   - Prevents hanging on unresponsive endpoints

3. **Better file checks**: `-f` tests instead of ls output patterns
   - More reliable on different shells

## Test Results (2026-06-08)

**body-check.sh**: 41 PASS, 0 FAIL, 1 WARN (97% vitality)
- Heart pulse: 150s fresh ✅
- Message queue: 25 messages healthy ✅
- Oracle API: status=ok ✅
- All infrastructure checks ✅

**soul-check.sh**: 8 PASS, 0 FAIL
- Oracle API responding ✅
- innova→Oracle connectivity ✅
- Oracle search indexed ✅
- Ollama models present ✅
- Repo structure complete ✅

## Detection Improvement
- **Stale heartbeat**: Now detectable (was: always "fresh" if file existed)
- **Queue backlog**: Now monitorable (was: invisible)
- **Oracle connectivity**: Now validated (was: loose grep match)
- **Search results**: Now verified (was: substring match on empty results)

**Why:** chamu's nose detects actual system problems, not just file existence. Real health checks measure behavior and timing, not just presence. Timestamp validation catches silent failures; strict JSON parsing catches response corruption.

**How to apply:** Run `bash eval/body-check.sh` and `bash eval/soul-check.sh` regularly. Watch for WARN on heart pulse age or queue depth as early indicators of problems before they cascade.
