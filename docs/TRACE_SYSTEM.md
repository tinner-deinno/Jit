# Git Trace System Documentation

**Location**: `scripts/trace-*.sh` + `limbs/trace-query.sh`
**Storage**: `ψ/memory/traces/`
**Integration**: Heartbeat-based auto-update every 15 minutes
**Purpose**: Unified discovery, measurement, and analysis of Jit repository development

---

## System Components

### 1. **trace-startup.sh** — Bootstrap (run at Jit startup)
Initializes trace infrastructure:
- Creates `ψ/memory/traces/` directory structure
- Generates `trace-registry.json` for Jit to read
- Creates initial trace snapshot
- Sets up index file

**Called by**: `init-life.sh` before agent startup

```bash
bash scripts/trace-startup.sh
```

---

### 2. **trace-commits.sh** — Core trace engine
Analyzes git history and generates structured summaries:

**Modes**:
- `--hourly` — commits organized by hour (default)
- `--daily` — commits organized by day
- `--stat` — quick statistics only
- `--auto` — full analysis (called by heartbeat)

**Output**:
- `$TRACE_DIR/summary.md` — formatted markdown report
- `$TRACE_DIR/commits.index.json` — machine-readable index
- Tables, lists, friction scores, analysis

**Usage**:
```bash
# Generate hourly trace
bash scripts/trace-commits.sh --hourly

# Generate daily summary
bash scripts/trace-commits.sh --daily

# Full auto analysis (from heartbeat)
bash scripts/trace-commits.sh --auto
```

---

### 3. **heartbeat-trace.sh** — Pulse integration
Lightweight updates on each heartbeat pulse:
- Appends to heartbeat-pulses.md
- Updates daily-summary.md
- Tracks activity deltas
- Minimal overhead (runs in background)

**Called by**: `heartbeat.sh` after each IN/OUT pulse

```bash
bash scripts/heartbeat-trace.sh --auto <pulse_number>
```

---

### 4. **heartbeat-hooks.sh** — Hook dispatcher
Routes heartbeat events to all hooks:
- `trace` hook — calls trace-commits.sh every 6 pulses
- `log` hook — appends to heartbeat log
- `notify` hook — broadcasts to agent bus

**Usage**:
```bash
# Run all hooks on pulse
bash scripts/heartbeat-hooks.sh 42 OUT

# Run specific hook
bash scripts/heartbeat-hooks.sh trace 42 OUT
```

---

### 5. **trace-query.sh** — Jit interface
Query interface for agents to read trace data:

**Queries**:
- `today` — today's full summary
- `latest [n]` — last n commits (default 10)
- `stats` — statistics table
- `activity` — activity level (last 24h)
- `friction` — friction score
- `registry` — machine-readable JSON

**Usage**:
```bash
# Read today's summary
bash limbs/trace-query.sh today

# Get latest 20 commits
bash limbs/trace-query.sh latest 20

# Check activity level
bash limbs/trace-query.sh activity

# Machine-readable data for Jit
bash limbs/trace-query.sh registry | jq .
```

---

## Data Structure

```
ψ/memory/traces/
├── trace-registry.json          # ← Jit reads this at startup
├── 2026-05-12/
│   ├── index.md                 # ← Quick reference
│   ├── trace-hourly.md          # ← Hourly summary (markdown)
│   ├── trace-daily.md           # ← Daily summary (markdown)
│   ├── summary.md               # ← Full analysis with friction score
│   ├── stats.json               # ← Statistics (JSON)
│   ├── commits.index.json       # ← Machine-readable commit index
│   ├── heartbeat-pulses.md      # ← Pulse log (updated every 15 min)
│   └── daily-summary.md         # ← Timeline (appended to)
├── 2026-05-11/
│   ├── summary.md
│   ├── daily-summary.md
│   └── ...
└── ...
```

### trace-registry.json Format

```json
{
  "timestamp": "2026-05-12T14:30:45+07:00",
  "trace_root": "/workspaces/Jit/ψ/memory/traces",
  "today": "2026-05-12",
  "trace_dir": "/workspaces/Jit/ψ/memory/traces/2026-05-12",
  "git": {
    "total_commits": 847,
    "latest_hash": "abc1234...",
    "latest_message": "feat: add trace system",
    "repo": "Jit"
  },
  "traces": {
    "hourly": "..../trace-hourly.md",
    "daily": "..../trace-daily.md",
    "weekly": "..../trace-weekly.md",
    "pulses": "..../heartbeat-pulses.md",
    "summary": "..../summary.md"
  },
  "auto_update": true,
  "update_interval_seconds": 900,
  "next_update": "2026-05-12T14:45:45+07:00"
}
```

### summary.md Format

```markdown
---
timestamp: 2026-05-12T14:30:45+07:00
mode: hourly
friction_score: 0.85
---

# Git Trace Summary — 2026-05-12 14:30:45

**Repository**: Jit
**Mode**: hourly

## Commit History

| Time | Author | Subject | Hash |
|------|--------|---------|------|
| 2026-05-12 14:00 | innova | feat: add trace system | `abc1234` |
| ... | ... | ... | ... |

## Commit Analysis

- **Total commits**: 847
- **Today**: 12 commits
- **Top authors**: innova: 450 | lak: 180 | neta: 100

## Development Activity

| Type | Count |
|------|-------|
| feat | 180 |
| fix | 85 |
| docs | 45 |
| ... | ... |

## Next Steps

- Run `git log --oneline -20` for latest commits
- Use `/trace --deep` for cross-repo analysis
- Check `ψ/memory/traces/` for historical traces
```

---

## Friction Score Calculation

**Formula**: `friction_score = S + C_offset` (clamped to [0.0, 1.0])

| Metric | Score | Meaning |
|--------|-------|---------|
| Oracle | 1.0 | Frictionless — indexed |
| Files | 0.7 | Present but not indexed |
| Git history | 0.5 | Buried — hard to surface |
| Cross-repo | 0.3 | Hidden — elsewhere |
| Not found | 0.0 | Invisible |

**Completeness offset**:
- High confidence: +0.00
- Medium: −0.10
- Low: −0.20

**Examples**:
- Oracle + high confidence = **1.0** 🟢 Excellent
- Oracle + medium = **0.9** 🟢 Near-perfect
- Files + high = **0.7** 🟢 Good
- Git + medium = **0.4** 🟡 Fair
- Not found = **0.0** 🔴 Invisible

---

## Heartbeat Integration

The trace system is automatically triggered on heartbeat pulses:

```
Heartbeat Timeline (15-minute cycle):

00:00 — Pulse #1 (IN)  → lightweight trace append
00:07 — Pulse #2 (OUT) → lightweight trace append
(repeat every 15 min)

Every 6 pulses (≈90 min):
        → Full trace-commits.sh --auto runs in background
        → Complete hourly + daily summaries generated
```

### How to Enable in Heartbeat

Add this to `heartbeat.sh` in the main pulse loop:

```bash
# After each IN/OUT commit:
bash scripts/heartbeat-hooks.sh trace "$PULSE_COUNT" "$PULSE_TYPE"
bash scripts/heartbeat-hooks.sh log "$PULSE_COUNT" "$PULSE_TYPE"
```

---

## Usage by Jit Agent

### Startup: Read registry
```bash
REGISTRY=$(cat ψ/memory/traces/trace-registry.json)
LATEST_COMMITS=$(echo "$REGISTRY" | jq -r '.git.total_commits')
```

### Query current status
```bash
bash limbs/trace-query.sh stats
```

### Check if system is active
```bash
ACTIVITY=$(bash limbs/trace-query.sh activity)
echo "$ACTIVITY" | grep -q "Active" && echo "System is active" || echo "System is idle"
```

### Read today's summary
```bash
bash limbs/trace-query.sh today | head -20
```

### Get machine-readable data
```bash
TRACE_JSON=$(bash limbs/trace-query.sh registry)
FRICTION=$(echo "$TRACE_JSON" | jq -r '.friction_score // "unknown"')
```

---

## Workflow

### 1. Jit startup sequence
```
1. bootstrap.sh or init-life.sh runs
2. → trace-startup.sh initializes system
3. → Creates ψ/memory/traces/ + registry.json
4. → Jit reads trace-registry.json
5. → Jit starts agents
6. → Heartbeat begins (15-min pulses)
```

### 2. On each heartbeat pulse
```
1. heartbeat.sh completes IN/OUT pulse
2. → Calls heartbeat-hooks.sh
3. → hook_trace appends lightweight update
4. → Every 6 pulses: full trace-commits.sh --auto
5. → Trace summaries updated
6. → Jit can query via trace-query.sh
```

### 3. Jit queries trace data
```
1. Jit calls: bash limbs/trace-query.sh [command]
2. Returns formatted markdown or JSON
3. Jit parses and acts on findings
```

---

## Commands Reference

### Initialize
```bash
# First time setup
bash scripts/trace-startup.sh
```

### Manual trace generation
```bash
# Hourly trace
bash scripts/trace-commits.sh --hourly

# Daily summary
bash scripts/trace-commits.sh --daily

# Statistics only
bash scripts/trace-commits.sh --stat
```

### Query trace data
```bash
# Today's summary
bash limbs/trace-query.sh today

# Latest 20 commits
bash limbs/trace-query.sh latest 20

# Statistics
bash limbs/trace-query.sh stats

# Activity level
bash limbs/trace-query.sh activity

# Friction analysis
bash limbs/trace-query.sh friction

# JSON registry (for agents)
bash limbs/trace-query.sh registry
```

---

## Performance

| Operation | Time | Overhead |
|-----------|------|----------|
| trace-startup.sh | ~5s | One-time |
| trace-commits.sh --auto | ~10s | Every 90 min |
| heartbeat-trace.sh --auto | ~1s | Every pulse (15 min) |
| trace-query.sh | ~100ms | On-demand |

**Total heartbeat impact**: ~1s per pulse = negligible

---

## Troubleshooting

### Registry not found
```bash
# Regenerate
bash scripts/trace-startup.sh
```

### No trace data today
```bash
# Generate manually
bash scripts/trace-commits.sh --daily
```

### Friction score showing 0.0
- Run `bash scripts/trace-commits.sh --daily` to reindex
- Check if git history is readable: `cd /workspaces/Jit && git log -1`

### Heartbeat not updating traces
- Verify `heartbeat.sh` calls `heartbeat-hooks.sh`
- Check `/tmp/innova-heartbeat.log` for errors
- Run manually: `bash scripts/heartbeat-trace.sh --auto 1`

---

## Integration Points

| File | Integration |
|------|-----------|
| `init-life.sh` | Call `trace-startup.sh` at Jit boot |
| `heartbeat.sh` | Call `heartbeat-hooks.sh` after each pulse |
| Jit agent | Call `trace-query.sh` to read data |
| hermes-discord bot.js | Could display trace status in status command |
| innova-bot | Could use trace data for session summary |

---

## Next Steps

1. ✅ Initialize: `bash scripts/trace-startup.sh`
2. ✅ Run heartbeat: Enable in `heartbeat.sh`
3. ✅ Query: `bash limbs/trace-query.sh today`
4. 📋 Integrate with Jit startup hooks
5. 📋 Add trace visualization to innova-bot
6. 📋 Export traces to Oracle knowledge base

---

**Created**: 2026-05-12
**System**: Jit (จิต) — Git Trace Integration
**Status**: Ready for deployment
