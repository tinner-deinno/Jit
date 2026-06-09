# JIT-020 Test Plan — Sed Injection in organs/hand.sh

**Status**: Complete and Ready for Execution  
**Test Owner**: chamu (QA/Tester Organ)  
**Priority**: P0 (Critical Security)  
**Date**: 2026-06-08

---

## Quick Start

This directory contains the complete test plan for JIT-020 (sed injection vulnerability in `organs/hand.sh`).

### Three Files, Pick One:

1. **`test-jit-020-hand-sed-injection.json`** ← **Start here for automation**
   - Machine-readable JSON format
   - Complete test cases, acceptance criteria, regression tests
   - Suitable for CI/CD pipeline integration
   - Size: 19 KB

2. **`JIT-020-TEST-SPEC.md`** ← **Start here for understanding**
   - Detailed vulnerability analysis
   - Escape function mechanics
   - Test phases and exit criteria
   - Size: 7.4 KB

3. **`JIT-020-QUICK-REFERENCE.md`** ← **Start here for execution**
   - One-liner commands
   - Test map and checklists
   - Failure workflows and troubleshooting
   - Sign-off template
   - Size: 5.5 KB

---

## The Vulnerability (30-second version)

**What**: `organs/hand.sh` edit command uses unsanitized sed with user input:
```bash
sed -i "s|$OLD|$NEW|g" "$FILE"  # Dangerous: $OLD and $NEW not escaped
```

**How**: Attacker can inject sed metacharacters:
```bash
hand.sh edit myfile.txt "a|b" "c|d"  # Injection: | terminates sed command
```

**Why it matters**: sed can execute arbitrary transformations or be abused via regex patterns.

**The fix**: Two functions properly escape all special characters:
- `escape_sed_pattern()` — escapes pattern side (. * [ ] ^ $ | \)
- `escape_sed_replacement()` — escapes replacement side (& | \)

---

## Test Plan Overview

### 20 Total Tests (4 Phases)

| Phase | Tests | Type | Duration | Blocking? |
|-------|-------|------|----------|-----------|
| **Phase 1** | 9 | Security Injection | 3 hrs | YES ← Run first |
| **Phase 2** | 4 | Functional | 2 hrs | HIGH |
| **Phase 3** | 2 | Backup/Error | 1 hr | MEDIUM |
| **Phase 4** | 5 | Regression | 2 hrs | HIGH |
| **TOTAL** | **20** | — | **8 hrs** | — |

### Test Categories

**Security Tests (9)**: Validate each special character and combinations
- TC-002: Pipe `|`
- TC-003: Ampersand `&`
- TC-004: Regex metacharacters `. * [ ] ^ $`
- TC-005: Backslash `\` (escape order critical)
- TC-006: Forward slash `/`
- TC-007: Combined injection attempt
- TC-008: Square brackets `[` `]`
- TC-009: Caret/dollar anchors `^` `$`
- TC-010: All specials combined

**Functional Tests (4)**: Ensure editing still works normally
- TC-001: Basic string replacement
- TC-011: Empty string (deletion)
- TC-012: Multiline files
- TC-013: Global flag (all occurrences)

**Backup/Error Tests (2)**
- TC-014: Backup file creation
- TC-015: Error handling

**Regression Tests (5)**
- RT-001: Other hand.sh commands
- RT-002: mouth.sh integration
- RT-003: Performance
- RT-004: Large files
- RT-005: Audit logging

---

## Acceptance Criteria (9 total, 6 critical)

### Critical (blocking)
✓ AC-001: Pipe delimiter escaped  
✓ AC-002: Ampersand escaped in replacement  
✓ AC-003: Regex metacharacters escaped  
✓ AC-004: No sed command injection  
✓ AC-005: Backslash escaped first (order matters!)  
✓ AC-006: Combined specials handled

### Supporting
- AC-007: Basic functionality preserved
- AC-008: Backup mechanism works
- AC-009: Error handling correct

---

## How to Run Tests

### Option A: Quick Validation (10 minutes)
```bash
cd /workspaces/Jit
# Run 3 critical tests
bash organs/hand.sh edit /tmp/t002.txt 'a|b' 'x|y' && echo "✓ TC-002"
bash organs/hand.sh edit /tmp/t003.txt 'a&b' 'x&y' && echo "✓ TC-003"
bash organs/hand.sh edit /tmp/t007.txt 'orig' 'safe' && echo "✓ TC-007"
rm /tmp/t*.txt*
```

### Option B: Full Manual Execution (8 hours)
1. Read: `JIT-020-TEST-SPEC.md`
2. Use: `JIT-020-QUICK-REFERENCE.md` for one-liners
3. Follow: Phase 1 → Phase 2 → Phase 3 → Phase 4
4. Sign-off: Template in QUICK-REFERENCE

### Option C: Automated via JSON (CI/CD)
```bash
jq '.test_cases[] | {id: .test_id, name: .name, priority: .priority}' \
  test-jit-020-hand-sed-injection.json
```

---

## Key Decision Points

**Phase 1 (Security Tests)**
- If ALL 9 pass → Continue to Phase 2
- If ANY fail → **STOP** — Fix escape logic, re-run Phase 1

**Phase 2 (Functional)**
- If ALL 4 pass → Continue to Phase 3
- If ANY fail → Investigate side effects

**Phase 4 (Regression)**
- If ALL 5 pass → Ready to sign-off
- If ANY fail → Investigate system-wide impact

**Success Criteria**:
- 100% pass on Phases 1, 2, 4
- All 6 critical ACs verified
- neta (code reviewer) approval

---

## Vulnerability vs. Fix

### Before (Vulnerable)
```bash
edit)
  FILE="$1" OLD="$2" NEW="$3"
  sed -i "s|$OLD|$NEW|g" "$FILE"  # ← Variables not escaped!
```

### After (Fixed)
```bash
edit)
  FILE="$1" OLD="$2" NEW="$3"
  OLD_ESC=$(escape_sed_pattern "$OLD")     # Escape pattern side
  NEW_ESC=$(escape_sed_replacement "$NEW") # Escape replacement side
  sed -i "s|$OLD_ESC|$NEW_ESC|g" "$FILE"
```

### Escape Functions
```bash
escape_sed_pattern() {
  printf '%s\n' "$1" | \
    sed 's/\\/\\\\/g' |  # Backslash FIRST
    sed 's/\./\\./g' |   # Then others
    sed 's/\*/\\*/g' |
    sed 's/\[/\\[/g' |
    sed 's/\]/\\]/g' |
    sed 's/\^/\\^/g' |
    sed 's/\$/\\$/g' |
    sed 's/|/\\|/g'
}

escape_sed_replacement() {
  printf '%s\n' "$1" | \
    sed 's/\\/\\\\/g' |  # Backslash first
    sed 's/&/\\&/g' |    # Ampersand (backreference)
    sed 's/|/\\|/g'      # Pipe (delimiter)
}
```

---

## File Locations

```
/workspaces/Jit/
├── organs/hand.sh                        ← Source code (lines 42-76)
├── tests/
│   ├── test-jit-020-hand-sed-injection.json  ← FULL TEST PLAN (JSON)
│   ├── JIT-020-TEST-SPEC.md                  ← DETAILED SPEC
│   ├── JIT-020-QUICK-REFERENCE.md            ← QUICK REF (one-liners)
│   ├── README-JIT-020.md                     ← This file
│   └── ...
└── tickets/completed/JIT-020-sed-injection-hand.yaml  ← Vulnerability ticket
```

---

## Next Steps

1. **For Test Runners**: Open `JIT-020-QUICK-REFERENCE.md`
2. **For Understanding**: Open `JIT-020-TEST-SPEC.md`
3. **For Automation**: Parse `test-jit-020-hand-sed-injection.json`
4. **For Sign-Off**: Fill template at end of QUICK-REFERENCE

---

## Contact

- **Test Owner**: chamu (QA/Tester Organ)
- **Code Owner**: mue (Hand Organ)
- **Code Reviewer**: neta (Review Organ)
- **Master**: jit (Master Orchestrator)

---

## Timeline

- **Design Completed**: 2026-06-08
- **Execution Target**: 2026-06-08+
- **Sign-Off Target**: 2026-06-09
- **Release Target**: After approval

---

Last Updated: 2026-06-08
Status: **READY FOR EXECUTION**
