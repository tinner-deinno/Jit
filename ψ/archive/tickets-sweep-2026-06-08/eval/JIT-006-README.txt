================================================================================
JIT-006 TEST PLAN - COMPLETE DELIVERABLE PACKAGE
================================================================================

TICKET:      JIT-006 (P0 Security Fix)
TITLE:       Remove Hardcoded OLLAMA_TOKEN from jit-heartbeat.service
TEST OWNER:  chamu (QA Lead)
CREATED:     2026-06-08
STATUS:      READY FOR EXECUTION

================================================================================
DELIVERABLE FILES (in reading order)
================================================================================

1. JIT-006-DELIVERY-SUMMARY.txt (THIS FILE) [9.1 KB]
   └─ Overview of entire test plan package
   └─ Quick start guide
   └─ File descriptions
   └─ Quality checklist

2. JIT-006-TEST-SUMMARY.md [8.2 KB] ⭐ START HERE
   └─ Executive summary of test strategy
   └─ 10 acceptance criteria explained
   └─ 15 test cases organized by category
   └─ 10 regression tests defined
   └─ 5-phase execution strategy
   └─ Approval gates & success criteria
   └─ Known issues & workarounds
   └─ Test dependencies graph
   └─ Handoff checklist for chamu

3. JIT-006-QUICK-REFERENCE.txt [13 KB] ⭐ USE DURING EXECUTION
   └─ Pre-flight checklist (5 min)
   └─ Phase-by-phase commands
   └─ Exact bash commands to run
   └─ Expected outputs for each test
   └─ Regression test commands
   └─ Common issues & fixes
   └─ Support contact info

4. JIT-006-test-plan.json [37 KB] ⭐ REFERENCE FOR DETAILS
   └─ Machine-readable complete specification
   └─ All 10 acceptance criteria + validation steps
   └─ All 15 test cases with step-by-step procedures
   └─ All 10 regression tests with commands
   └─ 3 performance benchmarks
   └─ Test execution order dependencies
   └─ Test result reporting format
   └─ Approval gates configuration

================================================================================
READING GUIDE (Choose your starting point)
================================================================================

IF YOU ARE...                    START WITH...
─────────────────────────────   ──────────────────────────────────────
chamu (QA Lead)                 → JIT-006-TEST-SUMMARY.md
                                  Then: JIT-006-QUICK-REFERENCE.txt

Andra planning/reviewing        → JIT-006-TEST-SUMMARY.md
                                  Then: JIT-006-test-plan.json

Systems engineer executing      → JIT-006-QUICK-REFERENCE.txt
                                  Reference: JIT-006-test-plan.json

Reviewer (neta)                 → JIT-006-TEST-SUMMARY.md (Approval Gates)
                                  Then: JIT-006-test-plan.json (Security tests)

DevOps (pada)                   → JIT-006-QUICK-REFERENCE.txt (TC-002, TC-003, TC-004)
                                  Reference: JIT-006-test-plan.json

Dev Lead (innova)               → JIT-006-TEST-SUMMARY.md (System Health)
                                  Then: JIT-006-QUICK-REFERENCE.txt (TC-005, TC-011, TC-012)

Master Orchestrator (jit)       → JIT-006-TEST-SUMMARY.md (Approval Gates & Metrics)
                                  Then: JIT-006-test-plan.json (all details)

================================================================================
QUICK START (5 MINUTES)
================================================================================

For chamu - test execution:

1. Read JIT-006-TEST-SUMMARY.md (10 min overview)
2. Review JIT-006-QUICK-REFERENCE.txt (execution checklists)
3. Run pre-flight checks:
   - systemctl --version | head -1
   - curl -s https://ollama.mdes-innova.online/api/health
   - git status

4. Execute Phase 1 (Unit Tests):
   - TC-001: grep OLLAMA_TOKEN in service file
   - TC-002: Check credentials directory permissions
   - TC-003: Check token file permissions
   - TC-004: systemd-analyze verify

5. Report status to jit (Master)

================================================================================
TEST COVERAGE AT A GLANCE
================================================================================

ACCEPTANCE CRITERIA:
  ✓ 10 criteria defined with validation steps
  ✓ All tied to acceptance_criteria in test plan

TEST CASES:
  ✓ 15 total test cases
    - 4 Unit Tests (TC-001 to TC-004)
    - 3 Integration Tests (TC-005, TC-008, TC-011)
    - 3 Security Tests (TC-006, TC-007, TC-013)
    - 3 Functional Tests (TC-009, TC-010, TC-012)
    - 2 Negative Tests (TC-014, TC-015)

REGRESSION TESTS:
  ✓ 10 regression tests
    - Daily: RT-010
    - Weekly: RT-001, RT-003, RT-006, RT-010
    - Monthly: RT-005
    - Quarterly: RT-007
    - On-demand: RT-008, RT-009

PERFORMANCE BENCHMARKS:
  ✓ 3 metrics defined:
    - Service startup time: < 3 seconds
    - First Ollama API call: < 5 seconds
    - Memory overhead: < 10 MB

APPROVAL GATES:
  ✓ 3 approval gates
    - Pre-Merge: neta (Code Reviewer) - P0 tests
    - Staging: pada (DevOps) - P0 + P1 tests
    - Production: jit (Master) - All tests + regression

TIMELINE:
  ✓ Phase 1 (Unit): 1-2 hours
  ✓ Phase 2 (Integration): 1-2 hours
  ✓ Phase 3 (Security): 0.5-1 hour
  ✓ Phase 4 (Functional): 2-3 hours
  ✓ Phase 5 (Negative): 1-2 hours
  ✓ Total (all phases): 6-10 hours

================================================================================
KEY FILES UNDER TEST
================================================================================

1. /workspaces/Jit/jit-heartbeat.service
   - Main systemd unit file
   - Must use LoadCredential, not hardcoded token
   - Must pass systemd-analyze verify

2. /etc/jit-credentials/ollama_token
   - Secure credential storage
   - Must be mode 0600 (root:root only)
   - Must not be world-readable
   - Must contain valid MDES Ollama token

3. /workspaces/Jit/scripts/setup-credentials.sh
   - Setup script for credential initialization
   - Creates /etc/jit-credentials directory
   - Stores token with proper permissions
   - Validates systemd compatibility

4. /workspaces/Jit/scripts/heartbeat-24h-daemon.sh
   - Main heartbeat daemon script
   - Must read OLLAMA_TOKEN from environment
   - Must not hardcode token
   - Must work with LoadCredential mechanism

5. Multi-Agent System Components
   - Oracle API (localhost:47778)
   - Message bus (/tmp/manusat-bus)
   - eval/body-check.sh
   - eval/soul-check.sh

================================================================================
SUCCESS DEFINITION
================================================================================

MINIMAL SUCCESS (Phase 1-3):
  ✓ All unit tests PASS (TC-001 to TC-004)
  ✓ Service starts and runs (TC-005)
  ✓ Ollama connectivity works (TC-008)
  ✓ System health OK (TC-011)
  ✓ No token in process environment (TC-006)
  ✓ No token in git history (TC-007)
  ✓ Credential isolation works (TC-013)

FULL SUCCESS (Phase 1-5):
  ✓ All 15 test cases PASS
  ✓ All 10 regression tests PASS
  ✓ All acceptance criteria met
  ✓ Zero security issues
  ✓ Performance benchmarks met
  ✓ Token rotated at MDES (confirmed)
  ✓ Documentation updated

================================================================================
NEXT STEPS (For chamu)
================================================================================

STEP 1: REVIEW (30 min)
  [ ] Read JIT-006-TEST-SUMMARY.md
  [ ] Review JIT-006-QUICK-REFERENCE.txt
  [ ] Understand 5-phase execution strategy
  [ ] Identify any questions or concerns

STEP 2: PREPARE (15 min)
  [ ] Verify pre-flight requirements (systemd version, sudo access, etc.)
  [ ] Set up test environment
  [ ] Prepare test documentation
  [ ] Schedule regression tests on calendar

STEP 3: EXECUTE (6-10 hours over multiple days)
  [ ] Execute Phase 1 (Unit Tests) - 1-2 hours
  [ ] Report Phase 1 results to jit
  [ ] Execute Phase 2 (Integration) - 1-2 hours
  [ ] Execute Phase 3 (Security) - 0.5-1 hour
  [ ] Report Phase 1-3 results to neta (pre-merge approval)
  [ ] Execute Phase 4 (Functional) - 2-3 hours (if P0 tests pass)
  [ ] Execute Phase 5 (Negative) - 1-2 hours (if P0 tests pass)

STEP 4: DOCUMENT (30 min)
  [ ] Create JIT-006-test-results.json with all results
  [ ] Document any blockers or issues found
  [ ] Attach evidence (logs, screenshots, commands)
  [ ] Update approval gate decision

STEP 5: REPORT (15 min)
  [ ] Send results to jit (Master Orchestrator)
  [ ] Include: phase status, blockers, next steps
  [ ] Request approval if all tests PASS
  [ ] Schedule regression tests

================================================================================
SUPPORT & CONTACTS
================================================================================

QUESTIONS ABOUT TEST PLAN:
  Claude Code (Haiku 4.5)
  Created: 2026-06-08

DURING EXECUTION:
  pada (DevOps)          - Credential setup, systemd, file permissions
  innova (Lead Dev)      - Script issues, environment variables, Ollama
  neta (Code Reviewer)   - Security validation, approval gates
  jit (Master)           - Final merge decisions, production sign-off

MESSAGE BUS:
  /tmp/manusat-bus/<agent-name>/inbox/

================================================================================
IMPORTANT NOTES
================================================================================

1. This test plan is COMPREHENSIVE and SECURITY-FOCUSED
   - Multiple validation methods for each criterion
   - Edge case handling (negative tests)
   - Regression tests for ongoing assurance

2. All tests have EXACT commands documented
   - Copy-paste ready from QUICK-REFERENCE.txt
   - Expected outputs specified
   - Failure modes identified

3. This is a P0 SECURITY fix
   - All P0 tests (TC-001 to TC-007, TC-013) MUST PASS before merge
   - No exceptions or waivers
   - Security review (neta) required

4. Approval gates are MANDATORY
   - Pre-Merge: neta (Code Reviewer)
   - Staging: pada (DevOps)
   - Production: jit (Master Orchestrator)

5. Regression tests are ONGOING
   - Schedule them before closing ticket
   - Daily, weekly, monthly cadences defined
   - Integrated with monitoring/alerting

================================================================================
DOCUMENT VERSIONS
================================================================================

All files created: 2026-06-08
Format: UTF-8 text
Size: ~67 KB total (JSON + markdown + text)

JIT-006-test-plan.json:         37 KB (machine-readable)
JIT-006-TEST-SUMMARY.md:        8.2 KB (human-readable summary)
JIT-006-QUICK-REFERENCE.txt:    13 KB (execution checklist)
JIT-006-DELIVERY-SUMMARY.txt:   9.1 KB (delivery overview)
JIT-006-README.txt (this):       This file

================================================================================
READY FOR EXECUTION
================================================================================

✓ Test plan is COMPLETE
✓ All components documented
✓ Exact commands provided
✓ Approval gates defined
✓ Support contacts listed
✓ Timeline estimated
✓ Quality checklist passed
✓ JSON validation passed

chamu (QA Lead) can begin execution immediately.

Questions? Review the full test plan documents or contact the support team.

================================================================================
Generated by Claude Code (Haiku 4.5)
For: JIT-006 Security Fix - Remove Hardcoded OLLAMA_TOKEN
System: Jit Oracle (จิต)
Date: 2026-06-08
================================================================================
