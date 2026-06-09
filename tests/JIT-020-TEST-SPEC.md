# JIT-020 Test Specification
## Sed Injection in organs/hand.sh

**Test Owner**: chamu (QA Lead)  
**Date**: 2026-06-08  
**Component**: organs/hand.sh, organs/hand-safe.sh  
**Status**: Ready for Execution

---

## Overview

This test plan validates the fix for sed injection vulnerability (JIT-020) in the `hand.sh edit` command. The vulnerability allows injection of sed metacharacters and delimiters through unsanitized user input.

### Vulnerability Summary
- **Location**: organs/hand.sh:46 (edit command)
- **Risk**: Sed command injection via unescaped variables in sed expression
- **Mitigation**: escape_sed_pattern() and escape_sed_replacement() functions
- **Critical**: YES (P0 Security)

---

## Test Case Breakdown

### Phase 1: Security Injection Tests (9 tests)

#### TC-002: Pipe Character Injection
- **Input**: OLD="a|b", NEW="x|y"
- **Risk**: Pipe is sed delimiter; unescaped pipe terminates command
- **Expected**: Both pipes escaped; file shows literal pipes
- **Attack Vector**: `echo "s|a|b|x|y|s//..." ` → multiple sed commands

#### TC-003: Ampersand Backreference
- **Input**: NEW="test & verify"
- **Risk**: `&` in replacement expands to matched text
- **Expected**: `&` escaped in replacement (becomes `\&`)
- **Attack Vector**: `echo "s|foo|test & verify|g"` → "foo test foo verify" duplication

#### TC-004 to TC-010: Regex Metacharacters
- **Covered**: `.` `*` `[` `]` `^` `$` `\`
- **Risk**: Each character has special meaning in regex or sed syntax
- **Expected**: All properly escaped with backslash
- **Combined Test (TC-010)**: Tests all special characters together

### Phase 2: Functional Tests (4 tests)

#### TC-001: Basic Functionality
- Validates normal use case with simple strings
- Ensures fix doesn't break basic edit workflow

#### TC-011: Empty String Replacement
- Tests deletion via replacement with ""
- Validates replacement context can be empty

#### TC-012: Multiline Content
- Tests file with newline characters
- Validates single-line replacements preserve other lines

#### TC-013: Global Flag
- Tests `g` flag in sed replaces all occurrences
- Validates global replacement still works

### Phase 3: Backup & Error Handling (2 tests)

#### TC-014: Backup Creation
- Validates timestamp-based backup file created
- Checks backup contains original content

#### TC-015: Error Handling
- Tests non-existent file error
- Validates appropriate exit codes

### Phase 4: Regression Tests (5 tests)

#### RT-001: Other Commands
- Ensures create, append, delete, copy, call, execute still work
- Validates no side effects from escape functions

#### RT-002: mouth.sh Integration
- Tests hand.sh called via mouth.sh
- Validates inter-organ communication unaffected

#### RT-003: Performance
- 100 sequential edits on normal file
- Threshold: < 5 seconds (acceptable escape overhead)

#### RT-004: Large Files
- 100MB file edit test
- Memory safety validation

#### RT-005: Audit Trail
- Validates log_action() still records edits
- Checks HAND_EDIT log entries

---

## Acceptance Criteria (9 total, 6 critical)

| AC-ID | Description | Critical | Validation Method |
|-------|-------------|----------|-------------------|
| AC-001 | Pipe delimiter escaped | ✅ YES | TC-002 |
| AC-002 | Ampersand escaped in replacement | ✅ YES | TC-003 |
| AC-003 | Regex metacharacters escaped | ✅ YES | TC-004,5,8,9 |
| AC-004 | No sed command injection possible | ✅ YES | TC-007 |
| AC-005 | Backslash escaped first (order critical) | ✅ YES | TC-005 |
| AC-006 | Combined special chars handled | ✅ YES | TC-010 |
| AC-007 | Basic edit functionality preserved | ✅ YES | TC-001,11,12,13 |
| AC-008 | Backup mechanism functional | NO | TC-014 |
| AC-009 | Error handling correct | NO | TC-015 |

---

## Escape Function Details

### escape_sed_pattern() Flow
Applied to the `OLD` string (pattern side of `s|OLD|NEW|g`):

```
Input: "test[a-z]$var|path"
  ↓ sed 's/\\/\\\\/g'    # Backslash first → "test[a-z]$var|path"
  ↓ sed 's/\./\\./g'     # Dot → "test[a-z]$var|path"
  ↓ sed 's/\*/\\*/g'     # Star → "test[a-z]$var|path"
  ↓ sed 's/\[/\\[/g'     # [ → "test\\[a-z\\]$var|path"
  ↓ sed 's/\]/\\]/g'     # ] → "test\\[a-z\\]$var|path"
  ↓ sed 's/\^/\\^/g'     # ^ → "test\\[a-z\\]$var|path"
  ↓ sed 's/\$/\\$/g'     # $ → "test\\[a-z\\]$var\\|path"
  ↓ sed 's/|/\\|/g'      # | → "test\\[a-z\\]$var\\|path"
Output: "test\\[a-z\\]$var\\|path"
```

### escape_sed_replacement() Flow
Applied to the `NEW` string (replacement side of `s|OLD|NEW|g`):

```
Input: "replacement & text | with $var"
  ↓ sed 's/\\/\\\\/g'    # Backslash first
  ↓ sed 's/&/\\&/g'      # & → "replacement \\& text | with $var"
  ↓ sed 's/|/\\|/g'      # | → "replacement \\& text \\| with $var"
Output: "replacement \\& text \\| with $var"
```

---

## Test Execution Steps

### Pre-Test Setup
```bash
cd /workspaces/Jit
mkdir -p /tmp/test_hand_*_cleanup
export TEST_LOG="/tmp/jit-020-test-results-$(date +%s).log"
```

### Test Runner Template
```bash
# For each TC:
1. Create test file with known content
2. Run: bash organs/hand.sh edit <file> <old> <new>
3. Compare output: grep <expected> <file>
4. Cleanup: rm /tmp/test_hand_*.txt*
5. Log result: PASS/FAIL with details
```

### Cleanup
```bash
rm -rf /tmp/test_hand_* /tmp/reg_test* 2>/dev/null
```

---

## Pass/Fail Criteria

### Phase 1 (Security) - BLOCKING
- **PASS**: All 9 injection tests pass (100%)
- **FAIL**: Any injection test fails → Stop, escalate to mue (Hand owner)

### Phase 2 (Functional) - BLOCKING
- **PASS**: All 4 functional tests pass (100%)
- **FAIL**: Any functional test fails → Investigate escape logic

### Phase 3 (Backup/Error) - REQUIRED
- **PASS**: Both tests pass (100%)
- **FAIL**: Non-critical, but should investigate

### Phase 4 (Regression) - BLOCKING
- **PASS**: All 5 regression tests pass (100%)
- **FAIL**: Any failure → Investigate side effects

### Exit Criteria
✅ **PASS**: All phases pass + all critical ACs verified  
❌ **FAIL**: Any blocking phase or critical AC fails

---

## Known Issues & Workarounds

### Issue 1: Escape Functions Are Chained
**Observation**: Each sed escape is a separate pipeline (8 sed commands for pattern, 3 for replacement)  
**Impact**: Performance acceptable for <1000 char strings; larger may degrade  
**Mitigation**: TC-003 validates performance threshold

### Issue 2: Backslash Must Be First
**Observation**: If backslash escaped after other chars, those escapes get re-escaped  
**Example**: Escape `.` first, then `\` would escape the `\` we added  
**Validation**: TC-005 specifically tests this order

### Issue 3: Sed BRE vs ERE
**Observation**: Using Basic Regular Expression (BRE) mode, not Extended  
**Impact**: Some escaping rules differ from ERE (used in -E flag)  
**Validation**: All tests use standard GNU sed BRE

---

## Test Environment

- **OS**: Linux (Tested on Azure Linux 6.8.0)
- **Shell**: Bash (version 4+)
- **Tools**: sed (GNU), bash builtin functions
- **Temp Directory**: /tmp (must be writable)
- **User**: Any non-root user (no special permissions needed)

---

## Sign-Off

**Test Design**: chamu (QA Lead)  
**Approved By**: [Pending]  
**Execution Date**: 2026-06-08+  
**Results Location**: /tmp/jit-020-test-results-*.log

---

## References

- **Ticket**: /workspaces/Jit/tickets/completed/JIT-020-sed-injection-hand.yaml
- **Vulnerable Code**: organs/hand.sh:42-76 (edit function)
- **Fix Mechanism**: escape_sed_pattern() + escape_sed_replacement()
- **Related Skills**: /scrutinize, /code-review
