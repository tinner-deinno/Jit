# TICKET-012 & TICKET-013 Orchestration Plan

**Date**: 2026-06-09  
**Status**: Ready for Workflow (awaiting TICKET-011 completion)  
**Orchestration Model**: Parallel execution (>10 agents), plan→dev→test per task

---

## TICKET-012: Team Charter YAML

**Objective**: Create normalized team charter in YAML format for mnu-agent (มนุษย์ Agent) system.

**Dependency**: TICKET-011 (rate-limiting) must be complete before pushing.

### Acceptance Criteria
1. YAML structure with sections: name, vision, team_members (14), organs, org_chart
2. All 14 agents assigned to organs (soma, innova, lak, neta, vaja, chamu, rupa, pada, netra, karn, mue, pran, sayanprasathan, jit)
3. Agent tier structure (Tier 0: jit, Tier 1: soma, Tier 2: innova/lak/neta, Tier 3: 9 specialists)
4. RACI matrix for all workflows (standard flow, bug flow, health flow)
5. CLAUDE.md references updated to point to team-charter.yaml
6. All existing specs (body-map.md, identity.md, etc.) reconciled with charter

### Implementation Breakdown
- **Lead**: innova (orchestrate), soma (architect)
- **Tasks**:
  - Extract/normalize from CLAUDE.md + /core/*.md
  - Create teams/team-charter.yaml (450-550 lines)
  - Generate RACI matrix JSON (agents × workflows)
  - Validate schema (22 required fields)
  - Update docs cross-references

### Test Plan
- Parse YAML (valid syntax)
- Verify all 14 agents registered
- Verify all organs assigned (no duplicates)
- Verify RACI coverage (all workflows have owners)
- Compare against CLAUDE.md for consistency

### Expected Output
- `teams/team-charter.yaml` (normalized team structure)
- `teams/raci-matrix.json` (workflows × agents responsibility map)
- `docs/TEAM_CHARTER_VALIDATION.md` (consistency report)

---

## TICKET-013: innomcp Redis/DB Health Monitoring

**Objective**: Implement graceful degradation in health endpoint (liveness vs readiness).

**Problem**: innomcp health endpoint returns `degraded` when Redis/DB readiness check blocks, even if chat and MCP are fully functional.

**Solution**: Separate health checks:
- **Liveness** (fast, required): Chat API + MCP providers responding
- **Readiness** (optional, gated): Redis + PostgreSQL connected and responsive

### Acceptance Criteria
1. New health endpoint: GET `/health?detailed=true` returns `{ status, liveness, readiness }`
2. Liveness check (<50ms total): test chat API + MCP provider connectivity
3. Readiness check (<500ms): test Redis + PostgreSQL + LLM cache stores
4. Status logic:
   - `healthy` if liveness=green AND readiness=green
   - `degraded` if liveness=green AND readiness=yellow/red
   - `unhealthy` if liveness=red
5. Metrics per check: response_time, last_success, last_error
6. No breaking changes to existing `/health` endpoint (backward compat)
7. CI gate: health=green when chat+MCP work (even if stores are slow)

### Implementation Breakdown
- **Lead**: pada (health monitoring), innova (MCP integration)
- **Tasks**:
  - Audit current health check code (innomcp/src/health.js or similar)
  - Extract liveness checks: chat API, MCP provider roster
  - Extract readiness checks: Redis, PostgreSQL, cache stores
  - Implement dual-check architecture (parallel, timeout-gated)
  - Add /health?detailed=true endpoint + response schema
  - Backward compatibility: existing /health returns status based on liveness
  - Add metrics collection (response times, error tracking)

### Test Plan
- Unit: Each check runs independently, returns correct status
- Integration: Full dual-check chain with mocked backends
- Spike: Redis/PostgreSQL offline → health=degraded (not unhealthy)
- Backward compat: /health endpoint matches old behavior
- Performance: liveness <50ms, readiness <500ms
- CI gate: health passes when chat+MCP green (ignoring stores)

### Expected Output
- `innomcp/src/health.js` (refactored with liveness/readiness split)
- `innomcp/test/health.test.js` (24+ unit + integration tests)
- `innomcp/docs/HEALTH_MONITORING.md` (architecture + metric descriptions)
- `eval/health-metrics-report.json` (baseline response times + variance)

---

## Orchestration Timeline

### Phase 1: TICKET-011 Completion (Background Workflow)
- Status: **In Progress** (workflow ID: `wf_8f986c9e-ffe`)
- Expected completion: ~10-15 min from launch
- Action on completion: Auto-commit, auto-push

### Phase 2: TICKET-012 Development (Parallel, 2-3h)
- Agents: innova (lead), soma, lak, neta
- Deliverables: team-charter.yaml, raci-matrix.json, validation report
- Blocker resolution: TICKET-011 must be pushed first

### Phase 3: TICKET-013 Development (Parallel, 3-4h)
- Agents: pada (lead), innova, chamu, karn
- Deliverables: health.js refactor, tests, metrics report
- No blockers (independent of 011/012)

### Phase 4: Integration & Push
- Merge both 012 + 013 PRs
- Update innomcp_dev_backlog.md (mark 012/013 complete)
- Prepare next batch (TICKET-014+)

---

## Execution Strategy

**Immediate Actions** (while TICKET-011 workflow completes):
1. ✅ Monitor workflow completion
2. ✅ Prepare Sonnet-led orchestration for TICKET-012 + 013
3. ✅ Spawn >10 agents (innova, soma, lak, neta, pada, chamu, innova, karn, netra, mue, pran)
4. ✅ Parallel execution: 012 and 013 can run independently
5. ✅ Plan→Dev→Test per sub-task
6. ✅ Auto-commit/push on completion

**Loop Integration**:
- Every 5 min: Check for workflow completion → trigger 012+013 orchestration
- Workflow runs in parallel with loop
- Each iteration validates: git status, test PASS/FAIL, commit readiness

---

## Success Criteria

### TICKET-012
- [ ] team-charter.yaml valid YAML, contains all 14 agents
- [ ] RACI matrix complete (all workflows covered)
- [ ] Consistency report: 100% references reconciled
- [ ] Test: All YAML validations PASS

### TICKET-013
- [ ] Health endpoint split into liveness/readiness
- [ ] Liveness <50ms, readiness <500ms (benchmark verified)
- [ ] Redis offline → degraded (not unhealthy)
- [ ] CI gate: health=green when chat+MCP work
- [ ] All 24+ tests PASS
- [ ] Backward compatibility: old /health API unaffected

### Overall
- [ ] Both 012 + 013 committed and pushed
- [ ] All tests PASS (342+ unit + integration)
- [ ] No regressions vs TICKET-011 changes
- [ ] Loop state: ready for TICKET-014
