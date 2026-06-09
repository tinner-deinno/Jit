# JIT-020 Quick Reference for Test Runners

## Quick Stats
- **Total Test Cases**: 15 (9 security + 4 functional + 2 backup/error)
- **Regression Tests**: 5
- **Critical Acceptance Criteria**: 6
- **Estimated Time**: 8 hours (full execution)
- **Owner**: chamu (QA/Tester organ)

## One-Liner Test Commands

```bash
# Run single test
cd /workspaces/Jit
bash organs/hand.sh edit /tmp/test_hand_002.txt 'a|b' 'x|y'
grep -q 'x|y' /tmp/test_hand_002.txt && echo "PASS: TC-002" || echo "FAIL: TC-002"

# Cleanup all test files
rm -rf /tmp/test_hand_*.txt* /tmp/reg_test*

# View test plan
cat tests/test-jit-020-hand-sed-injection.json
cat tests/JIT-020-TEST-SPEC.md
```

## Test Map (Quick Lookup)

| Test ID | Name | Type | Files Involved | Status |
|---------|------|------|-----------------|--------|
| TC-001 | Safe literal string | Functional | test_hand_001 | Ready |
| TC-002 | **Pipe character** | Security | test_hand_002 | Ready |
| TC-003 | **Ampersand** | Security | test_hand_003 | Ready |
| TC-004 | **Regex metacharacters** | Security | test_hand_004 | Ready |
| TC-005 | **Backslash escape** | Security | test_hand_005 | Ready |
| TC-006 | Forward slash | Security | test_hand_006 | Ready |
| TC-007 | **Injection attempt** | Security | test_hand_007 | Ready |
| TC-008 | **Square brackets** | Security | test_hand_008 | Ready |
| TC-009 | **Caret/dollar anchors** | Security | test_hand_009 | Ready |
| TC-010 | **Combined specials** | Security | test_hand_010 | Ready |
| TC-011 | Empty replacement | Functional | test_hand_011 | Ready |
| TC-012 | Multiline content | Functional | test_hand_012 | Ready |
| TC-013 | Global flag (multiple) | Functional | test_hand_013 | Ready |
| TC-014 | Backup creation | Backup | test_hand_014 | Ready |
| TC-015 | Error handling | Error | (nonexistent) | Ready |

**Bold** = Critical for security validation

## Acceptance Criteria Checklist

```
AC-001 ✓ Pipe delimiter escaped          [TC-002]
AC-002 ✓ Ampersand escaped               [TC-003]
AC-003 ✓ Regex metacharacters            [TC-004,5,8,9]
AC-004 ✓ No sed injection possible       [TC-007]
AC-005 ✓ Backslash first (order)         [TC-005]
AC-006 ✓ Combined special chars          [TC-010]
AC-007 ✓ Basic functionality preserved   [TC-001,11,12,13]
AC-008   Backup mechanism                [TC-014]
AC-009   Error handling                  [TC-015]
```

## Execution Order (Recommended)

### Phase 1: Security (CRITICAL - Do First)
1. TC-002 (pipe)
2. TC-003 (ampersand)
3. TC-004 (dot, star, brackets)
4. TC-005 (backslash)
5. TC-006 (forward slash)
6. TC-007 (injection attempt)
7. TC-008 (square brackets)
8. TC-009 (caret, dollar)
9. TC-010 (combined)

**Stop if ANY fail** ← Must fix escape logic before proceeding

### Phase 2: Functional (HIGH)
1. TC-001 (basic edit)
2. TC-011 (empty string)
3. TC-012 (multiline)
4. TC-013 (global flag)

### Phase 3: Backup/Error (MEDIUM)
1. TC-014 (backup)
2. TC-015 (error handling)

### Phase 4: Regression (HIGH - Do Last)
1. RT-001 (other commands still work)
2. RT-002 (mouth.sh integration)
3. RT-003 (performance)
4. RT-004 (large files)
5. RT-005 (audit trail)

## Failure Workflow

**If TC-002 fails** (pipe not escaped):
```
→ Check organs/hand.sh:51 escape_sed_pattern()
→ Verify sed 's/|/\\|/g' is present
→ Test: echo "a|b" | sed 's/|/\\|/g'
→ Expected: a\|b
```

**If TC-003 fails** (ampersand not escaped):
```
→ Check organs/hand.sh:62 escape_sed_replacement()
→ Verify sed 's/&/\\&/g' is present
→ Test: echo "test & value" | sed 's/&/\\&/g'
→ Expected: test \& value
```

**If TC-005 fails** (backslash order wrong):
```
→ Backslash MUST be escaped FIRST
→ If escaped after other chars, those escapes get re-escaped
→ Correct order: \ → . → * → [ → ] → ^ → $ → |
```

## One-Pass Validation

```bash
#!/bin/bash
# tests/run-jit-020-quick.sh

cd /workspaces/Jit

# TC-002: Pipe
echo 'a|b c' > /tmp/t002.txt
bash organs/hand.sh edit /tmp/t002.txt 'a|b' 'x|y' 2>/dev/null
grep -q 'x|y c' /tmp/t002.txt && echo "✓ TC-002" || echo "✗ TC-002"

# TC-003: Ampersand
echo 'test & verify' > /tmp/t003.txt
bash organs/hand.sh edit /tmp/t003.txt 'test & verify' 'check & confirm' 2>/dev/null
grep -q 'check & confirm' /tmp/t003.txt && echo "✓ TC-003" || echo "✗ TC-003"

# TC-007: No injection
echo 'original' > /tmp/t007.txt
bash organs/hand.sh edit /tmp/t007.txt 'original' 'safe' 2>/dev/null
grep -q 'safe' /tmp/t007.txt && echo "✓ TC-007" || echo "✗ TC-007"

# Cleanup
rm -f /tmp/t0*.txt*
```

## Key Decision Points

| Q | Answer | Action |
|---|--------|--------|
| All Phase 1 tests pass? | YES → Continue | NO → Stop, fix escape logic |
| All Phase 2 tests pass? | YES → Continue | NO → Investigate, likely side effect |
| All Phase 4 tests pass? | YES → Sign off | NO → Investigate regression |
| All critical ACs verified? | YES → APPROVED | NO → Retest failing AC |

## Sign-Off Template

```
Test Owner: chamu
Execution Date: [DATE]
Result: [PASS/FAIL]
Tests Run: [N]/20
Pass Rate: [%]
Blocking Issues: [NONE/list]
Comments: [...]
Approved By: [mue/neta]
```

## Files Created

- `/workspaces/Jit/tests/test-jit-020-hand-sed-injection.json` ← Full test plan (JSON)
- `/workspaces/Jit/tests/JIT-020-TEST-SPEC.md` ← Detailed spec
- `/workspaces/Jit/tests/JIT-020-QUICK-REFERENCE.md` ← This file

## See Also

- `organs/hand.sh` — Source code (lines 42-76 = edit function)
- `organs/hand-safe.sh` — Safe reference implementation (if provided)
- `tickets/completed/JIT-020-sed-injection-hand.yaml` — Vulnerability ticket
