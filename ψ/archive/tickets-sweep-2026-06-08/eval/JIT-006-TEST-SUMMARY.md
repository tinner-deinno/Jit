# JIT-006 Test Plan Summary
## Remove Hardcoded OLLAMA_TOKEN from jit-heartbeat.service

**Test Owner**: chamu (QA Lead)  
**Generated**: 2026-06-08  
**Target Components**:
- `/workspaces/Jit/jit-heartbeat.service`
- `/etc/jit-credentials/ollama_token`
- `scripts/setup-credentials.sh`
- `scripts/heartbeat-24h-daemon.sh`

---

## Test Coverage Overview

### Acceptance Criteria (10 total)
- **AC-001**: No hardcoded OLLAMA_TOKEN in service file
- **AC-002**: Credentials stored with 0600 permissions (root:root)
- **AC-003**: LoadCredential mechanism properly configured
- **AC-004**: Service starts and runs successfully
- **AC-005**: Token not visible in process environment
- **AC-006**: Token removed from git history
- **AC-007**: Ollama API connectivity verified
- **AC-008**: Token rotated and old token disabled at MDES
- **AC-009**: Setup script creates valid configuration
- **AC-010**: System health check passes (full multi-agent system)

### Test Cases (15 total)

#### Category: Unit Tests (4 tests)
| Test ID | Title | Time |
|---------|-------|------|
| TC-001 | Service file has no hardcoded token | 0.25h |
| TC-002 | Credentials directory exists with 0700 permissions | 0.25h |
| TC-003 | Token file has 0600 permissions, not world-readable | 0.25h |
| TC-004 | Service file passes systemd validation | 0.5h |

#### Category: Integration Tests (3 tests)
| Test ID | Title | Time |
|---------|-------|------|
| TC-005 | Service starts and runs without errors | 0.5h |
| TC-008 | Ollama API connectivity verified | 0.5h |
| TC-011 | Full multi-agent system health check | 1.0h |

#### Category: Security Tests (3 tests)
| Test ID | Title | Time |
|---------|-------|------|
| TC-006 | Running process doesn't expose token in environment | 0.5h |
| TC-007 | Token removed from all git history | 0.5h |
| TC-013 | Non-root user cannot read credential | 0.5h |

#### Category: Functional Tests (3 tests)
| Test ID | Title | Time |
|---------|-------|------|
| TC-009 | Setup script creates valid configuration | 0.5h |
| TC-010 | Service restarts cleanly | 0.5h |
| TC-012 | Heartbeat pulses continue at expected interval | 1.5h |

#### Category: Negative Tests (2 tests)
| Test ID | Title | Time |
|---------|-------|------|
| TC-014 | Invalid/expired token handled gracefully | 0.75h |
| TC-015 | Missing credentials directory handled gracefully | 0.75h |

**Total Test Case Execution Time**: ~8.5 hours

### Regression Tests (10 total)

Continuous/periodic validation tests:
1. **RT-001**: No credential leakage via systemd-show
2. **RT-002**: systemd-analyze security audit clean
3. **RT-003**: Heartbeat pulse continues after restart (weekly)
4. **RT-004**: Credential persistence across reboot (post-upgrade)
5. **RT-005**: No regressions in other services (monthly)
6. **RT-006**: Audit trail captures credential access (weekly)
7. **RT-007**: Documentation stays in sync (quarterly)
8. **RT-008**: Compatibility with heartbeat-24h-daemon.sh
9. **RT-009**: LoadCredential fallback graceful failure
10. **RT-010**: No secrets in journalctl output (weekly)

---

## Test Execution Strategy

### Pre-Test Requirements
- [ ] systemd version >= 247 (`systemctl --version`)
- [ ] sudo access for credential setup
- [ ] Git repository accessible
- [ ] Ollama API reachable (https://ollama.mdes-innova.online)
- [ ] Oracle running on localhost:47778
- [ ] Valid MDES Ollama token available

### Phase 1: Unit Tests (Mandatory)
Execute TC-001 through TC-004 first. Must all PASS.
- Validates file structure and systemd syntax
- No runtime dependencies
- **Duration**: ~1.25 hours

### Phase 2: Integration Tests (Mandatory)
Execute TC-005, TC-008, TC-011 after Phase 1 passing.
- Validates runtime behavior
- Requires systemd running, Ollama accessible
- **Duration**: ~2 hours

### Phase 3: Security Tests (Mandatory)
Execute TC-006, TC-007, TC-013 in parallel with Phase 2.
- Validates security posture
- **Duration**: ~1.5 hours

### Phase 4: Functional Tests (Recommended)
Execute TC-009, TC-010, TC-012 for comprehensive coverage.
- Validates operational readiness
- **Duration**: ~2.5 hours

### Phase 5: Negative Tests (Recommended)
Execute TC-014, TC-015 for edge case validation.
- Validates error handling
- **Duration**: ~1.5 hours

### Regression Tests (Ongoing)
RT-001 through RT-010 run per-deployment and on schedule.
- **Daily**: RT-010 (no secrets in logs)
- **Weekly**: RT-001, RT-003, RT-006, RT-010
- **Monthly**: RT-005
- **Quarterly**: RT-007
- **On-demand**: RT-008, RT-009

---

## Approval Gates

| Gate | Tests | Owner | Decision |
|------|-------|-------|----------|
| Pre-Merge | All P0 tests (TC-001 to TC-007, TC-013) | neta (Code Reviewer) | APPROVED / BLOCKED |
| Staging Deploy | All P0 + P1 tests | pada (DevOps) | APPROVED / BLOCKED |
| Production Deploy | All P0 + P1 + regression passing | jit (Master) | APPROVED / BLOCKED |

---

## Success Criteria

**Minimal Success** (Phase 1 + Phase 2):
- All unit tests PASS (TC-001 to TC-004)
- Service starts and runs (TC-005)
- Ollama connectivity works (TC-008)
- System health OK (TC-011)

**Full Success** (All Phases):
- All 15 test cases PASS
- All 10 regression tests PASS
- No security issues found
- Token confirmed rotated at MDES
- All acceptance criteria (AC-001 to AC-010) met

---

## Known Issues & Workarounds

### Issue: systemd version < 247
**Impact**: LoadCredential not available  
**Workaround**: Fall back to EnvironmentFile with mode 0600  
**Test**: TC-004 will fail; implement fallback and re-run

### Issue: Ollama API unreachable
**Impact**: TC-008 fails  
**Workaround**: Verify MDES connectivity, check token rotation status  
**Test**: Skip TC-008, run manual verification with curl

### Issue: Git history scrub incomplete
**Impact**: TC-007 fails  
**Workaround**: Re-run BFG or git-filter-repo, verify token absent  
**Test**: Re-run TC-007 after cleanup

---

## Test Evidence & Artifacts

### Output Files Generated
- `/workspaces/Jit/eval/JIT-006-test-results.json` — Test execution results
- `/workspaces/Jit/reports/JIT-006-validation.txt` — Final validation checklist
- `/workspaces/Jit/eval/JIT-006-test-plan.json` — This test plan (machine-readable)

### Log Files Preserved
- `journalctl -u jit-heartbeat` — Service logs
- `systemctl show jit-heartbeat.service` — Service configuration
- `git log --all -S '9e34679'` — Git history verification

---

## Test Case Dependencies Graph

```
TC-001 (File integrity)
  ↓
TC-002 (Credentials directory)
  ↓
TC-003 (Token file security)
  ↓
TC-004 (systemd validation)
  ↓
TC-005 (Service startup) ← TC-007 (Git history - parallel)
  ↓
TC-006 (Process environment)
  ↓
TC-008 (Ollama connectivity)
  ↓
TC-009 (Setup script)
  ↓
TC-010 (Service restart)
  ↓
TC-011 (System health)
  ↓
TC-012 (Heartbeat pulse)
  ↓
TC-013 (Credential isolation)
  ↓
TC-014 (Invalid token) ← TC-015 (Missing credentials)
  ↓
✓ All tests complete → Regression tests (RT-001 to RT-010)
```

---

## Metrics & KPIs

### Quality Metrics
- **Test Pass Rate Target**: 100%
- **Code Coverage**: All credential paths tested
- **Security Issues Found**: 0 (target)

### Performance Metrics
- **Service Startup Time**: < 3 seconds
- **First API Call**: < 5 seconds after startup
- **Memory Overhead**: < 10 MB additional

### Reliability Metrics
- **Uptime After Fix**: 100% over 30-day period
- **Restart Recovery**: < 30 seconds
- **Auth Failure Recovery**: Automatic with valid token

---

## Test Handoff to chamu (QA)

**Ready to Execute**: Yes  
**Prerequisites Met**: Verify (see Pre-Test Requirements above)  
**Estimated Time**: 8.5 hours (Phase 1-4) + ongoing (RT tests)  
**Support Contacts**:
- **pada** (DevOps) — Credential setup, systemd issues
- **innova** (Lead Dev) — Heartbeat script issues
- **neta** (Code Reviewer) — Security concerns

**Execution Checklist**:
- [ ] Review test plan (this document)
- [ ] Verify all pre-test requirements
- [ ] Execute Phase 1 (Unit tests)
- [ ] Document results in JIT-006-test-results.json
- [ ] Report blockers to jit (Master Orchestrator)
- [ ] Execute Phase 2-5 once Phase 1 PASS
- [ ] Schedule regression tests (weekly/monthly)
- [ ] Sign off on completion

---

**Generated By**: Claude Code (Haiku 4.5)  
**For Ticket**: JIT-006 (Security Fix - Remove Hardcoded OLLAMA_TOKEN)  
**Date**: 2026-06-08  
