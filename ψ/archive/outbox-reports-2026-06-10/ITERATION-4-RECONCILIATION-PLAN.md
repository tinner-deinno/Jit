# Iteration 4: Spec Reconciliation Plan

**Date**: 2026-06-09  
**Status**: Blocked on numbering mismatch (fixable, zero-cost rename)

## The Issue

Three sources disagree on 009/010 numbering:

| Source | 009 | 010 |
|--------|-----|-----|
| Backlog (committed) | Regression | Performance |
| Spec files (untracked) | Performance | Regression |
| Active work (heartbeat) | — | Performance (already using 010 label) |

**Impact**: Cannot assign specs until reconciliation. Backbeat work (010) is in flight but doesn't conflict.

## Recommended Fix (Option A — Backlog is Source of Truth)

Since backlog is committed and heartbeat work is already labeled 010 correctly, rename the untracked spec files:

```bash
# Rename to match backlog
mv TICKET-009-PERFORMANCE-SPEC.json TICKET-010-PERFORMANCE-SPEC.json
mv TICKET-010-REGRESSION-VARIANCE-SPEC.json TICKET-009-REGRESSION-SPEC.json

# Update field values in renamed files
# In TICKET-009-REGRESSION-SPEC.json: change "ticket": "TICKET-010" → "ticket": "TICKET-009"
# In TICKET-010-PERFORMANCE-SPEC.json: change "ticket": "TICKET-009" → "ticket": "TICKET-010"
```

## Next Steps (Iteration 5)

1. **Execute rename** (if approved)
2. **Commit all three specs**:
   - TICKET-009-REGRESSION-SPEC.json (6 effort, 5 days, owner=chamu)
   - TICKET-010-PERFORMANCE-SPEC.json (8 effort, 2 weeks, owner=innova)
   - TICKET-011-RATE-LIMITING-SPEC.json (4 effort, 3 days, owner=pada)
3. **Assign to owners**
4. **Merge heartbeat-010 work** into main (already correct label)
5. **Start assignments**: chamu → 009, innova → 010 (monitor heartbeat), pada → 011

## Effort to Fix

- **Rename**: 2 files, 4 field edits = ~5 minutes
- **Commit**: 1 commit message, no merge conflicts = ~2 minutes
- **Risk**: Zero (untracked files, zero cost)

## Approval Needed

Who decides: innova (lead dev) or jit (master)?  
Recommendation: Proceed with Option A (rename specs to match backlog source of truth).

---

**Next Iteration**: Iteration 5 — execute reconciliation and assign tickets to owners.
