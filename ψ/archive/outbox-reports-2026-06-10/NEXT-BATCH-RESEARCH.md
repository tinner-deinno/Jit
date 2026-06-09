# Next Batch Research & Planning (Post TICKET-011/012/013)

**Date**: 2026-06-09  
**Status**: Planning (awaiting TICKET-011/012/013 completion)

---

## Immediate Actions (After TICKET-011/012/013 Committed)

### 1. Resolve GitHub PAT Scope Issue
**Blocker**: `pending-commits` branch has 742 unit tests + 11/11 E2E chat PASS but cannot push.

**Action**:
```bash
# From C:\Users\USER-NT\DEV\innomcp repo:
# 1. Regenerate GitHub PAT with scopes: `repo` + `workflow`
# 2. Update .git/config or environment token
# 3. git push origin pending-commits
# 4. If successful: 11 E2E chat tests + 742 unit tests will land in main
```

**Owner**: TBD  
**Effort**: 0.5 points (credential refresh + push)  
**Blocker Impact**: HIGH (11/11 E2E chat tests unblocked)

---

## TICKET-014 Candidates (To Be Defined)

### Option A: innomcp E2E Chat Integration (from pending-commits)
If `pending-commits` branch push succeeds:
- **Status**: 11/11 E2E chat tests PASS
- **Scope**: Full end-to-end chat flow validation
- **Effort**: 2 points (integration testing only, dev already done)
- **Owner**: chamu (QA lead)

### Option B: innova-bot Health Monitoring
From SA Design Review (Finding #1):
- **Issue**: `status().backends` missing `innova_bot` entry (monitoring gap)
- **Scope**: Add innova_bot to backend health reporting
- **Effort**: 2 points
- **Owner**: pada (infrastructure)

### Option C: preferBackend Parameter Support
From SA Design Review (Find #2):
- **Issue**: preferBackend silently ignored in proxy (decision needed)
- **Scope**: Either (a) add parameter support, or (b) document limitation
- **Effort**: 3 points (if implementation) or 1 point (if documentation)
- **Owner**: lak (architecture decision) + innova (implementation)

### Option D: Zero-Width Character Handling
From SA Design Review (Edge Case):
- **Issue**: ZWJ/ZWNJ not stripped from Thai text (edge case)
- **Scope**: Add stripping logic or document limitation
- **Effort**: 2 points
- **Owner**: chamu (Thai language specialist)

### Option E: NFC Normalization Audit
From TICKET-011 follow-up:
- **Issue**: Verify .normalize('NFC') doesn't have Thai-specific edge cases
- **Scope**: Comprehensive normalization audit across all Thai test corpus
- **Effort**: 1.5 points
- **Owner**: innova (implementation audit)

---

## CODEX Report Findings

**Reference**: Mentioned in TICKET-013 description ("from CODEX report").

**Potential findings**:
- Health monitoring degradation (addressed by TICKET-013)
- Thai routing variance (addressed by TICKET-011)
- Cache performance (addressed by TICKET-011 LRU)
- E2E chat integration gaps (in pending-commits)

**Action**: Retrieve CODEX report after TICKET-013 complete to identify remaining issues.

---

## Post-Batch Sequencing

### Phase 1: Immediate (T+0 to T+30min)
- [x] Commit TICKET-011/012/013 changes
- [x] Push to github main
- [ ] Update innomcp_dev_backlog.md (mark 011/012/013 DONE)
- [ ] Resolve GitHub PAT scope and push pending-commits

### Phase 2: Next Batch (T+30min to T+2h)
- [ ] Assess pending-commits push status
- [ ] If PASS: Integrate 11/11 E2E chat tests into main
- [ ] If FAIL: Debug GitHub PAT/credentials
- [ ] Pick TICKET-014 from candidates (A/B/C/D/E)
- [ ] Launch orchestration workflow for TICKET-014

### Phase 3: Continuous (Every 5 min)
- [ ] Monitor workflows (loop cycle)
- [ ] Commit each batch atomically
- [ ] Push to github after every 3-5 tickets
- [ ] Update backlog continuously

---

## Decision Points

### 1. GitHub PAT Regeneration
- **Responsible**: System admin or innova (if self-service credentials)
- **Timeline**: ASAP (blocks pending-commits)
- **Fallback**: Manual cherry-pick of 11 E2E tests if push fails

### 2. TICKET-014 Priority
**Recommendation**: Option A (pending-commits push) > Option B (innova_bot) > Option C (preferBackend)
- Option A unblocks 11 real E2E tests
- Option B improves observability
- Option C is a design question (can defer)

### 3. CODEX Report Access
- **Action**: After TICKET-013 committed, search for CODEX report in:
  - `/reports/` directory
  - Archive files
  - Upstream branches
- **Expected findings**: Next batch of issues + priorities

---

## Resource Allocation

**Available Agents** (for TICKET-014+):
- Tier 1: soma (strategic), innova (operational)
- Tier 2: lak (architecture), neta (review)
- Tier 3: pada (infrastructure), chamu (QA), karn (listening), mue (execution), netra (observation), pran (vital), sayanprasathan (network)
- **Capacity**: >10 agents in parallel per workflow

**Model Allocation**:
- **Sonnet** (hard tasks): architecture decisions, E2E integration, compliance
- **Haiku** (light tasks): documentation, credential management, reporting
- **Providers**: ThaiLLM/Ollama for Thai language tasks, MDES for provider-specific work

---

## Estimated Burn Rate

**Current**: 3 workflows in flight (011, 012, 013) = 12 tickets/day capacity
**Post-batch**: 1 workflow per 5 min = 288 tickets/day theoretical max (realistic: 20-30/day)

**Backlog Consumption**:
- TICKET-011/012/013: 3 tickets (complete)
- TICKET-014 (pending decision): 1 ticket (~2-3 hours)
- Future (014+): Estimate 10-15 tickets queued (TBD)

**Timeline to Empty Backlog**: ~1-2 weeks at current burn rate

---

## Success Metrics

- [ ] All TICKET-011/012/013 tests PASS (>95% success rate)
- [ ] All commits pushed to github (zero stale branches)
- [ ] No regressions vs baseline (zero test failures)
- [ ] Loop uptime: 100% (no crashes, 5-min cycle maintained)
- [ ] Velocity: 3+ tickets/day average (target: 5+)
