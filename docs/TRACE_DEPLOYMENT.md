# Git Trace System — Deployment Checklist

**Project**: Jit (จิต) Repository
**System**: Git Trace Integration with Heartbeat Auto-Update
**Status**: 🟡 Ready for Integration Testing
**Created**: 2026-05-12

---

## Phase 1: Core System ✅ COMPLETE

- [x] Create `scripts/trace-startup.sh` — bootstrap trace infrastructure
- [x] Create `scripts/trace-commits.sh` — analyze git history & generate reports
- [x] Create `scripts/heartbeat-trace.sh` — lightweight pulse updates
- [x] Create `scripts/heartbeat-hooks.sh` — route heartbeat events
- [x] Create `limbs/trace-query.sh` — Jit agent query interface
- [x] Create `ψ/memory/traces/` directory structure
- [x] Generate `trace-registry.json` with initial stats
- [x] Test trace initialization: `bash scripts/trace-startup.sh` ✅
- [x] Test query interface: `bash limbs/trace-query.sh stats` ✅
- [x] Document full system in `docs/TRACE_SYSTEM.md`
- [x] Document integration in `docs/TRACE_INTEGRATION.md`

**Status**: ✅ All core components deployed and tested

---

## Phase 2: Heartbeat Integration 🔄 IN PROGRESS

### 2.1 Modify heartbeat.sh

- [ ] **Task**: Add trace hooks to heartbeat.sh main loop
  - **File**: `scripts/heartbeat.sh`
  - **Action**: After each IN/OUT `git commit`, add:
    ```bash
    bash "$SCRIPT_DIR/heartbeat-hooks.sh" "$PULSE_COUNT" "$PULSE_TYPE" &
    ```
  - **Location**: ~Line 80-90 (after git commits)
  - **Priority**: 🔴 HIGH
  - **Depends**: Phase 1 ✅

- [ ] **Task**: Verify heartbeat logs trace updates
  - **How**: Run heartbeat manually, check `/tmp/innova-heartbeat.log`
  - **Expected**: Log entries like `[timestamp] Pulse #1 (IN)`
  - **Priority**: 🟡 MEDIUM
  - **Depends**: 2.1 complete

### 2.2 Test heartbeat integration

- [ ] **Task**: Run single heartbeat pulse with trace
  - **Command**: `bash scripts/heartbeat.sh once`
  - **Expected**: Trace files updated in `ψ/memory/traces/`
  - **Priority**: 🔴 HIGH

- [ ] **Task**: Verify trace updates after pulse
  - **Check**: `ls -la ψ/memory/traces/2026-05-12/`
  - **Expected**: heartbeat-pulses.md exists and updated
  - **Priority**: 🔴 HIGH

- [ ] **Task**: Run full heartbeat daemon for 1 hour
  - **Command**: `bash scripts/heartbeat.sh start`
  - **Monitor**: Check trace files update every 15 min
  - **Priority**: 🟡 MEDIUM

---

## Phase 3: Jit Startup Integration 🔄 IN PROGRESS

### 3.1 Modify init-life.sh

- [ ] **Task**: Add trace-startup.sh to Jit initialization
  - **File**: `scripts/init-life.sh`
  - **Action**: Add after core setup:
    ```bash
    echo "🔍 Initializing trace system..."
    bash "$JIT_ROOT/scripts/trace-startup.sh" || echo "⚠️ Trace initialization failed"
    ```
  - **Location**: Early in script, before agent startup
  - **Priority**: 🔴 HIGH
  - **Depends**: Phase 1 ✅

- [ ] **Task**: Verify trace initialization on Jit startup
  - **How**: Run `bash scripts/init-life.sh` and check output
  - **Expected**: "✅ Trace system ready" message
  - **Priority**: 🔴 HIGH

### 3.2 Add Jit startup trace reading

- [ ] **Task**: Create Jit startup hook to read trace registry
  - **File**: `scripts/awaken.sh` or Jit agent bootstrap
  - **Action**: 
    ```bash
    TRACE_REGISTRY="ψ/memory/traces/trace-registry.json"
    if [ -f "$TRACE_REGISTRY" ]; then
      TOTAL=$(jq '.git.total_commits' "$TRACE_REGISTRY")
      echo "📊 Jit startup: $TOTAL total commits indexed"
    fi
    ```
  - **Priority**: 🟡 MEDIUM

---

## Phase 4: Discord Bot Integration 🟡 PENDING

### 4.1 Add trace status command

- [ ] **Task**: Add `/jit trace` or `!jit status trace` command
  - **File**: `hermes-discord/bot.js`
  - **Commands**:
    - `!jit trace stats` — show development statistics
    - `!jit trace latest` — show latest 10 commits
    - `!jit trace activity` — show current activity level
  - **Implementation**:
    ```javascript
    if (cmd === 'trace') {
      const stats = execSync('bash limbs/trace-query.sh ' + (args[0] || 'stats')).toString();
      await message.reply('📊 ' + stats);
    }
    ```
  - **Priority**: 🟡 MEDIUM
  - **Depends**: Phase 1 ✅, Phase 3 ✅

- [ ] **Task**: Test Discord trace commands
  - **Command**: `!jit trace stats`
  - **Expected**: Statistics table displayed in Discord
  - **Priority**: 🟡 MEDIUM

### 4.2 Add daily trace report

- [ ] **Task**: Auto-post daily trace summary to Discord
  - **When**: Every morning at 08:00 UTC+07:00
  - **Where**: JIT_REPORT_CHANNEL_ID or Auto-report channel
  - **Content**: Daily summary + friction score
  - **Priority**: 🟢 LOW
  - **Depends**: Phase 4.1

---

## Phase 5: Oracle Integration 🟢 OPTIONAL

- [ ] **Task**: Export trace summaries to Oracle knowledge base
  - **File**: `scripts/trace-to-oracle.sh`
  - **Action**: Call `arra_trace()` MCP to index trace data
  - **Frequency**: Daily at midnight
  - **Priority**: 🟢 LOW
  - **Depends**: Phase 1 ✅

- [ ] **Task**: Link trace friction scores to Oracle learning
  - **Use case**: Help Oracle understand where to focus documentation
  - **Priority**: 🟢 LOW

---

## Phase 6: Agent Integration 🟢 OPTIONAL

### 6.1 Add trace awareness to other agents

- [ ] **Task**: Let agents query trace system
  - **Interface**: `bash limbs/trace-query.sh [command]`
  - **Usage**: Agents can read repo activity levels
  - **Priority**: 🟢 LOW

- [ ] **Task**: Create trace-based decision triggers
  - **Example**: If friction_score < 0.5, suggest documentation
  - **Priority**: 🟢 LOW

---

## Testing Checklist

### Unit Tests

- [ ] Test `trace-startup.sh` creates all required files
  ```bash
  bash scripts/trace-startup.sh
  test -f ψ/memory/traces/trace-registry.json && echo "✓ Registry created"
  ```

- [ ] Test `trace-commits.sh` generates valid markdown
  ```bash
  bash scripts/trace-commits.sh --daily
  grep -q "# Git Trace Summary" ψ/memory/traces/2026-05-12/summary.md && echo "✓ Valid markdown"
  ```

- [ ] Test `trace-query.sh` all commands
  ```bash
  bash limbs/trace-query.sh today | wc -l && echo "✓ today works"
  bash limbs/trace-query.sh stats | grep "Total commits" && echo "✓ stats works"
  bash limbs/trace-query.sh latest 5 | grep Hash && echo "✓ latest works"
  ```

- [ ] Test `heartbeat-hooks.sh` doesn't error
  ```bash
  bash scripts/heartbeat-hooks.sh 1 IN
  echo $? -eq 0 && echo "✓ No errors"
  ```

### Integration Tests

- [ ] Run `bash scripts/trace-startup.sh` + verify output
- [ ] Run `bash limbs/trace-query.sh stats` + verify stats table
- [ ] Simulate heartbeat: `bash scripts/heartbeat-trace.sh --auto 1`
- [ ] Check `ψ/memory/traces/2026-05-12/` directory grows over time

### System Tests

- [ ] Start Jit with modified init-life.sh
  - Expected: Trace system initializes before agents
  
- [ ] Run heartbeat.sh for 30 min
  - Expected: Trace files update every 15 min without errors
  
- [ ] Query trace data from different agents/scripts
  - Expected: Consistent results

### User Tests

- [ ] Discord user runs `!jit trace stats`
  - Expected: Formatted statistics table displayed
  
- [ ] Check daily trace auto-post to Discord
  - Expected: Summary message posted to report channel
  
- [ ] Verify friction score calculation
  - Expected: Score 0.0–1.0, accurate interpretation

---

## Ticket Summary

| Phase | Tickets | Status | Blocker? |
|-------|---------|--------|----------|
| 1 — Core System | 11 | ✅ DONE | — |
| 2 — Heartbeat | 5 | 🔄 IN PROGRESS | 🔴 YES |
| 3 — Jit Startup | 4 | 🔄 IN PROGRESS | 🔴 YES |
| 4 — Discord Bot | 4 | 🟡 PENDING | 🟢 NO |
| 5 — Oracle | 2 | 🟢 OPTIONAL | 🟢 NO |
| 6 — Agents | 2 | 🟢 OPTIONAL | 🟢 NO |
| Testing | 12 | 🟡 PENDING | 🟡 MEDIUM |

**Total**: 40 tickets
**Complete**: 11 ✅
**In Progress**: 9 🔄
**Pending**: 20 🟡

---

## Current Blockers

### 🔴 BLOCKER 1: Heartbeat hook integration
- **Issue**: `heartbeat.sh` not yet modified to call hooks
- **Impact**: Trace doesn't update automatically
- **Solution**: Add 2 lines to heartbeat.sh main loop
- **ETA**: ~5 minutes

### 🔴 BLOCKER 2: Jit startup integration
- **Issue**: `init-life.sh` doesn't call trace-startup.sh
- **Impact**: Trace not initialized when Jit starts
- **Solution**: Add trace-startup.sh call to init-life.sh
- **ETA**: ~3 minutes

### 🟡 MINOR: Discord bot integration
- **Issue**: No `!jit trace` command yet
- **Impact**: Users can't query trace from Discord
- **Solution**: Add command handler to bot.js
- **ETA**: ~15 minutes (optional for basic functionality)

---

## Success Criteria

✅ **Phase 1**: Core system deployed & tested
- All scripts created and working
- Registry generated with 1473 commits
- Query interface operational

🔄 **Phase 2**: Heartbeat integration
- Heartbeat calls trace hooks every 15 min
- Trace files updated consistently
- No performance impact detected

🔄 **Phase 3**: Jit startup
- Trace initializes on Jit boot
- Registry available for agents
- Initial stats captured

✅ **Overall Success**
- Trace system auto-updates with heartbeat
- Agents can query via `trace-query.sh`
- Development activity visible & measurable
- Friction scores calculated correctly

---

## Deployment Timeline

| Milestone | ETA | Status |
|-----------|-----|--------|
| Phase 1 complete | 2026-05-12 | ✅ DONE |
| Heartbeat integration | 2026-05-12 | 🔄 IN PROGRESS |
| Jit startup integration | 2026-05-12 | 🔄 IN PROGRESS |
| Full system testing | 2026-05-13 | 🟡 SCHEDULED |
| Discord bot feature | 2026-05-13 | 🟡 OPTIONAL |
| Production ready | 2026-05-13 | 🟡 ESTIMATED |

---

## Manual Update Commands

Until Phase 2 integration is complete, manually trigger trace updates:

```bash
# Update hourly trace
bash scripts/trace-commits.sh --hourly

# Update daily summary
bash scripts/trace-commits.sh --daily

# Query current status
bash limbs/trace-query.sh stats

# Query activity
bash limbs/trace-query.sh activity

# Read registry
bash limbs/trace-query.sh registry | jq .
```

---

## Notes

- Trace system is **non-blocking** — Jit works fine without it
- All trace operations run in **background** (async) during heartbeat
- Performance impact is **negligible** (~1s per pulse)
- System is **safe** — only reads from git, doesn't modify code
- Traces are **version-controlled** — stored in `ψ/memory/traces/`

---

**Maintained by**: Jit Agent System
**Next Review**: 2026-05-13
**Questions?**: See `docs/TRACE_SYSTEM.md`

