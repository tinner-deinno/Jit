#!/usr/bin/env bash
# INTEGRATION GUIDE — Git Trace System with Jit Agent
#
# This guide shows how to integrate the trace system with Jit and heartbeat
#
# Location: docs/TRACE_INTEGRATION.md
#
# Quick Start:
#   1. Initialize: bash scripts/trace-startup.sh
#   2. Query: bash limbs/trace-query.sh stats
#   3. Enable heartbeat integration (see below)

cat << 'EOF'

# Git Trace System Integration Guide

## Quick Start (< 2 minutes)

### 1. Initialize trace system
```bash
cd /workspaces/Jit
bash scripts/trace-startup.sh
```

Expected output:
```
🔍 Initializing trace system...
  ✓ Trace directory: /workspaces/Jit/ψ/memory/traces/2026-05-12
  ✓ Registry: /workspaces/Jit/ψ/memory/traces/trace-registry.json
  ✓ Total commits: 1473
  ✓ Latest: fffaf3ac... (refactor: Simplify bot...)
  ✓ Initial trace generated
  ✓ Index created
✅ Trace system ready
```

### 2. Test queries
```bash
# View statistics
bash limbs/trace-query.sh stats

# Get latest 10 commits
bash limbs/trace-query.sh latest 10

# Check activity level
bash limbs/trace-query.sh activity

# Read registry (JSON)
bash limbs/trace-query.sh registry | jq .
```

---

## Integration Points

### A. Startup Integration (init-life.sh)

Add this to `scripts/init-life.sh` before starting agents:

```bash
# Initialize trace system
echo "🔍 Setting up trace system..."
bash "$JIT_ROOT/scripts/trace-startup.sh"

# Verify registry exists
if [ -f "$JIT_ROOT/ψ/memory/traces/trace-registry.json" ]; then
  echo "✅ Trace system initialized"
else
  echo "⚠️ Trace system initialization failed"
fi
```

### B. Heartbeat Integration (heartbeat.sh)

Add these lines to `heartbeat.sh` in the main pulse loop (after each commit):

```bash
# After IN or OUT pulse commit:
# ─────────────────────────────────────────
# Update trace on each pulse
bash "$SCRIPT_DIR/heartbeat-hooks.sh" trace "$PULSE_COUNT" "$PULSE_TYPE"
bash "$SCRIPT_DIR/heartbeat-hooks.sh" log "$PULSE_COUNT" "$PULSE_TYPE"
```

### C. Jit Agent Integration

Add to Jit startup code:

```bash
# Read trace registry at startup
TRACE_REGISTRY="ψ/memory/traces/trace-registry.json"
if [ -f "$TRACE_REGISTRY" ]; then
  # Read current stats
  TOTAL_COMMITS=$(jq -r '.git.total_commits' "$TRACE_REGISTRY" 2>/dev/null || echo "unknown")
  LATEST_HASH=$(jq -r '.git.latest_hash' "$TRACE_REGISTRY" 2>/dev/null | cut -c1-7)
  
  echo "📊 Jit starting with $TOTAL_COMMITS commits (latest: $LATEST_HASH)"
fi

# Query activity level periodically
ACTIVITY=$(bash limbs/trace-query.sh activity)
if echo "$ACTIVITY" | grep -q "Active"; then
  echo "🟢 Development activity detected"
fi
```

### D. Discord Bot Integration (hermes-discord/bot.js)

Add status command that includes trace info:

```javascript
// In handleCommand, add:
if (cmd === 'status' || cmd === 'trace') {
  // Query trace system
  const { execSync } = require('child_process');
  try {
    const stats = execSync('bash limbs/trace-query.sh stats').toString();
    const activity = execSync('bash limbs/trace-query.sh activity').toString();
    
    await message.reply('📊 **Development Trace**\n\n' + stats + '\n' + activity);
  } catch (e) {
    await message.reply('❌ Trace system error: ' + e.message);
  }
}
```

---

## Jit Agent Workflow

### 1. On startup
```bash
# Jit reads trace registry
REGISTRY=$(cat ψ/memory/traces/trace-registry.json)

# Extracts current development state
TOTAL=$(echo $REGISTRY | jq '.git.total_commits')
LATEST=$(echo $REGISTRY | jq -r '.git.latest_hash')
```

### 2. Every 15 minutes (on heartbeat)
```bash
# Heartbeat triggers trace update
bash scripts/heartbeat-hooks.sh trace 42 OUT

# Trace system appends to:
# - ψ/memory/traces/2026-05-12/heartbeat-pulses.md
# - ψ/memory/traces/2026-05-12/daily-summary.md
```

### 3. Query during operation
```bash
# Jit checks current activity
ACTIVITY=$(bash limbs/trace-query.sh activity)

# Get latest commits
LATEST=$(bash limbs/trace-query.sh latest 5)

# Check friction score
FRICTION=$(bash limbs/trace-query.sh friction)
```

---

## Directory Structure

After initialization:

```
Jit/
├── scripts/
│   ├── trace-startup.sh              ← Initialize (run once)
│   ├── trace-commits.sh              ← Core engine
│   ├── heartbeat-trace.sh            ← Pulse integration
│   ├── heartbeat-hooks.sh            ← Hook dispatcher
│   ├── heartbeat.sh                  ← (modify to add hooks)
│   └── init-life.sh                  ← (modify to call trace-startup)
│
├── limbs/
│   ├── trace-query.sh                ← Jit query interface
│   └── lib.sh
│
├── ψ/memory/traces/
│   ├── trace-registry.json           ← Jit reads this
│   ├── 2026-05-12/
│   │   ├── index.md
│   │   ├── summary.md
│   │   ├── trace-hourly.md
│   │   ├── trace-daily.md
│   │   ├── commits.index.json
│   │   ├── stats.json
│   │   ├── heartbeat-pulses.md
│   │   └── daily-summary.md
│   └── 2026-05-11/
│       ├── summary.md
│       └── ...
│
└── docs/
    ├── TRACE_SYSTEM.md               ← Full documentation
    └── TRACE_INTEGRATION.md          ← This file
```

---

## Example Usage Scenarios

### Scenario 1: Jit reports development status

```bash
# Jit command: !jit status
# Response includes:
bash limbs/trace-query.sh stats
bash limbs/trace-query.sh activity

# Output:
# ## Development Stats
# | Period | Commits |
# |--------|---------|
# | Total | 1473 |
# | Week | 758 |
# | Today | 326 |
# 
# 🔥 High Activity — 326 commits today
```

### Scenario 2: Check if system is busy

```bash
# During agent decision-making
ACTIVITY=$(bash limbs/trace-query.sh activity)
if echo "$ACTIVITY" | grep -q "🟢 Active"; then
  echo "System is actively being developed"
  # Adjust agent behavior accordingly
fi
```

### Scenario 3: Generate development report

```bash
# Jit periodic report
bash limbs/trace-query.sh today > report.md
bash limbs/trace-query.sh latest 20 >> report.md
bash limbs/trace-query.sh friction >> report.md

# Send to Discord or Oracle
```

### Scenario 4: Detect development patterns

```bash
# Query commits by type
bash limbs/trace-query.sh stats | grep "feat\|fix"

# Extract friction analysis
bash limbs/trace-query.sh friction

# Determine if "help needed" signal
```

---

## Performance Impact

| Operation | Time | Frequency | Total Impact |
|-----------|------|-----------|--------------|
| trace-startup.sh | ~5s | Once | ~5s |
| Full trace-commits.sh | ~10s | Every 90 min | ~2.2 sec/hr |
| heartbeat-trace.sh | ~1s | Every 15 min | ~4 sec/hr |
| trace-query.sh | ~100ms | On-demand | < 0.5 sec/query |

**Total overhead**: ~6 sec/hour = negligible

---

## Troubleshooting

### Registry not found after startup
```bash
# Check directory was created
ls -la ψ/memory/traces/

# Regenerate
bash scripts/trace-startup.sh
```

### Trace queries return empty
```bash
# Verify git history is readable
git log -1 --oneline

# Regenerate trace
bash scripts/trace-commits.sh --daily
```

### Heartbeat not updating traces
```bash
# Check if heartbeat is running
ps aux | grep heartbeat

# Manually run trace update
bash scripts/heartbeat-hooks.sh trace 1 IN

# Check for errors
tail -f /tmp/innova-heartbeat.log
```

### Friction score showing 0.0
```bash
# Reindex commits
bash scripts/trace-commits.sh --daily

# Check git repository
git rev-parse HEAD
```

---

## Files to Modify

### 1. scripts/init-life.sh
**Add after:** Line where agents are being started
**Add:**
```bash
bash "$JIT_ROOT/scripts/trace-startup.sh" || echo "⚠️ Trace initialization skipped"
```

### 2. scripts/heartbeat.sh
**Add after:** Each `git commit` in the main pulse loop
**Add:**
```bash
# Update trace system
bash "$SCRIPT_DIR/heartbeat-hooks.sh" "$PULSE_COUNT" "$PULSE_TYPE" &
```

### 3. hermes-discord/bot.js
**Add in:** `handleCommand()` function
**Add:**
```javascript
if (cmd === 'trace' || cmd === 'status') {
  // Include trace info in status
}
```

---

## Next Steps

1. ✅ Run `bash scripts/trace-startup.sh`
2. ✅ Test `bash limbs/trace-query.sh stats`
3. 📋 Modify `scripts/init-life.sh` to include trace initialization
4. 📋 Modify `scripts/heartbeat.sh` to call `heartbeat-hooks.sh`
5. 📋 Test full integration with heartbeat running
6. 📋 Add trace display to Discord bot status command
7. 📋 Create automated reports for Oracle

---

## Support

- Full system docs: `docs/TRACE_SYSTEM.md`
- Query interface: `bash limbs/trace-query.sh help`
- Scripts: `scripts/trace-*.sh` and `scripts/heartbeat-*.sh`
- Configuration: `ψ/memory/traces/trace-registry.json`

---

**Status**: Ready for integration
**Created**: 2026-05-12
**Version**: 1.0

EOF
