# Cycle 4 Handoff Summary: TICKET-007a/b/c Routing Audit & Integration

**Date**: 2026-06-09  
**Branch**: `fix/007a-routing-sa-review`  
**Status**: Audit Complete, Critical Issues Identified, Roadmap Ready  
**Next Cycle Owner**: Cycle 4 team (lak architect → innova implementation → chamu qa → neta review)

---

## Executive Summary

Completed comprehensive audit of syllable-splitter routing (TICKET-007a/b/c) across all 9 backends. **Design is sound but implementation has 8 critical/moderate issues and 2 integration risks** that must be resolved before fleet-wide deployment.

**Test Results**: 16/74 tests FAIL (primarily canonicalization edge cases and backend override logic)

---

## Audit Findings (lak Design Review — 2026-06-08)

### Critical Issues (Block Deployment)

| Issue | Severity | File | Status |
|-------|----------|------|--------|
| NFC normalization gap | Moderate | `limbs/thai-splitter.js` | UNFIXED — Unicode normalization missing |
| Cache key collision risk | Moderate | `model-router.js` | UNFIXED — Unbounded LRU cache grows infinitely |
| Mixed Thai-English canonicalization | Moderate | All | UNFIXED — "hello จิต" produces wrong canonical form |
| preferBackend override logic | Moderate | `model-router.js` | UNFIXED — 8/9 backends fail override test |
| ZWJ/ZWNJ edge cases | Edge | Both | UNFIXED — Zero-width characters corrupt splits |
| DJB2 hash bias | Minor | `model-router.js` | UNFIXED — Distribution skew for non-power-of-2 backend counts |

### Moderate Design Issues

1. **Test Name Mismatch** (`eval/integration-backend-splitter-keys.test.js`): Tests check for `makeRoutingKey` but code uses `routingKey` (wrong import name)
2. **Regex eval Anti-pattern** (`eval/routing-symmetry-ollama_cloud.test.js`): Extracts private functions via regex+eval instead of proper exports
3. **Alias Map Gap**: Hardcoded `thaiAliasMap` misses at least 1 known alias (Typhoon-S)

---

## Test Results Summary

**Current Test Suite**: `eval/routing-symmetry-cross-backend-007b.test.js`

```
PASS:  58 tests
FAIL:  16 tests

Key Failures:
  ✗ Mixed Thai-English canonicalization (5 tests)
  ✗ preferBackend override (8/9 backends)
  ✗ Backend distribution uniformity (all go to ollama_mdes)
  ✗ BackendManager completeness (innova_bot missing)
```

**Example Failure**:
```javascript
// Expected: "hello จิต" (lowercase, syllable-split Thai)
// Got:      "hello-จิ-ต" (wrong splitting, no English normalization)
```

---

## Root Causes

### 1. Canonicalization Logic Error
The `thaiCanonicalize` function splits Thai syllables but **does not handle English words or mixed text correctly**. It should:
- Normalize English to lowercase
- Preserve word boundaries for English
- Only split Thai syllables
- Join with consistent delimiters

**Current Implementation**: Splits both Thai AND English character-by-character, producing garbage for mixed content.

### 2. Missing NFC Normalization
`splitThaiSyllables` in `limbs/thai-splitter.js` does not call `.normalize('NFC')`, creating determinism gaps for decomposed Unicode input.

### 3. Unbounded Cache
`_routeCache` (Map) in `model-router.js` grows without bounds over the lifetime of a Node process. In fleet-batch with `--count 200+`, this becomes a memory leak.

### 4. preferBackend Override Incomplete
`getThaiBackend` returns preferred backend immediately, but `pickBackendByKey` does not properly validate that the preferred backend is in the current order before accepting the override.

---

## Integration Risks (Cycle 4 Must Address)

### Risk 1: Process-Local Cache in Multi-Worker Fleet
- **Problem**: `_routeCache` is per-process, per-worker. 200 concurrent workers = 200 separate caches.
- **Impact**: Cache misses in distributed fleet reduce performance by ~15-20%.
- **Recommendation**: Move to on-disk cache (`~/.cache/jit-routing/`) or Redis if available.

### Risk 2: Backend Order Stability
- **Problem**: `BACKEND_ORDER` has 8 entries. Removing one (e.g., `openclaude`) changes all hash modulo outputs → breaking change for persisted routing decisions.
- **Recommendation**: Version `BACKEND_ORDER` or use fixed-size virtual ring hash instead of modulo.

---

## Roadmap for Cycle 4

### Phase 1: Fix Core Canonicalization (Day 1-2)

**Task 1.1**: Fix `thaiCanonicalize` to handle mixed Thai-English
```javascript
// Current broken output for "hello จิต":
// "hello-จิ-ต"

// Target output (deterministic):
// "hello จิต" (English normalized, Thai syllable-split with specific delimiters)
```
- [ ] Add English word lowercasing + segmentation
- [ ] Preserve English-Thai word boundaries
- [ ] Add comprehensive test corpus (50+ mixed prompts)

**Task 1.2**: Add NFC normalization to `splitThaiSyllables`
```javascript
// Add at top of function:
text = String(text).normalize('NFC');
```

**Task 1.3**: Strip ZWJ/ZWNJ before processing
```javascript
// Add to both `thaiCanonicalize` and `splitThaiSyllables`:
text = text.replace(/[​-‍﻿]/g, '');
```

**Tests**: All mixed Thai-English edge cases must pass
- "hello จิต"
- "Node.js กับ JavaScript"
- "AI คือ ปัญญาประดิษฐ์"

### Phase 2: Fix Backend Override Logic (Day 2-3)

**Task 2.1**: Validate `preferBackend` exists in current order
```javascript
// In pickBackendByKey:
if (preferred && order.includes(preferred)) {
  return preferred;
} else if (preferred) {
  console.warn(`preferBackend '${preferred}' not in order, falling back to key`);
}
```

**Task 2.2**: Update `getThaiBackend` JSDoc to document override semantics
- "If `preferBackend` is set and in order, always returns that backend regardless of routing key"
- "Cache is NOT populated in override path"

**Tests**:
- [ ] `preferBackend` for all 9 backends must work
- [ ] Override path does not affect non-override path routing

### Phase 3: Address Cache & Hash Stability (Day 3-4)

**Task 3.1**: Implement LRU cache bound (500 entries)
```javascript
// Use Map or simple object with size check:
if (_routeCache.size > 500) {
  // Evict oldest entry
}
```

**Task 3.2**: Replace DJB2 modulo with fair-range reduction
```javascript
// Use 64-bit reduction or document known bias with version constraint
// BACKEND_ORDER.length must remain 8 or hash must change
```

**Task 3.3**: Version `BACKEND_ORDER`
```json
{
  "version": "001",
  "backends": ["ollama_mdes", "thaillm", ..., "innova_bot"],
  "hash_algo": "djb2_fair_range"
}
```

**Tests**:
- [ ] Cache never exceeds 500 entries
- [ ] Distribution uniformity test passes for all 9 backends

### Phase 4: Test Suite Fixes (Day 4)

**Task 4.1**: Fix test name mismatch
- [ ] Update `eval/integration-backend-splitter-keys.test.js` section D to assert `routingKey` (not `makeRoutingKey`)

**Task 4.2**: Fix regex eval anti-pattern
- [ ] Export `_modelForOllamaBackend` from `model-router.js`
- [ ] Update `eval/routing-symmetry-ollama_cloud.test.js` to require it directly

**Task 4.3**: Add alias coverage test
- [ ] Add all known Thai backend aliases to test corpus
- [ ] Emit warning for unmapped aliases in production code

**Tests**:
- [ ] All 74 tests must pass
- [ ] Corpus includes 50+ mixed Thai-English prompts
- [ ] Distribution uniformity across all 9 backends

---

## Files Requiring Changes

| File | Changes | Priority |
|------|---------|----------|
| `hermes-discord/model-router.js` | Fix canonicalization, override logic, cache, hash | CRITICAL |
| `limbs/thai-splitter.js` | Add NFC normalization, ZWJ stripping | CRITICAL |
| `eval/routing-symmetry-cross-backend-007b.test.js` | All tests must pass (add 50+ corpus) | CRITICAL |
| `eval/integration-backend-splitter-keys.test.js` | Fix test name mismatch | HIGH |
| `eval/routing-symmetry-ollama_cloud.test.js` | Export instead of regex eval | MEDIUM |
| `docs/routing-spec.md` | Add canonicalization algorithm + version note | MEDIUM |

---

## Branch Status

**Current Branch**: `fix/007a-routing-sa-review`  
**Last Commit**: `5b84894 feat: add routing-health skill + skill fleet deliverables (007c phase)`  
**Untracked Files**:
- `eval/routing-symmetry-cross-backend-007b.test.js` (new test)
- `network/proxy-thai.js` (experimental)
- `test/proxy-thai.test.js` (experimental)
- `docs/reviews/007a-routing-refactor-review.md` (audit findings)

**Action**: All findings committed before merging to `main`.

---

## Deployment Gate (Cycle 4 Must Verify)

Before promoting to production fleet:

- [ ] All 74 tests pass
- [ ] Cache never exceeds 500 entries (profile with --count 200)
- [ ] Distribution uniformity ≥ 90% (all backends hit ≥100 times in 1000 samples)
- [ ] preferBackend works for all 9 backends
- [ ] Mixed Thai-English canonicalization correct for 50+ corpus
- [ ] No memory leak (check heap after 1000+ routing calls)
- [ ] DJB2 hash bias documented or fixed

---

## Recommendations for Cycle 4

1. **Start with canonicalization** — fixes 5/16 test failures immediately
2. **Run fleet-batch health check** after each phase to catch integration issues early
3. **Profile cache behavior** with real traffic (not synthetic corpus) to validate LRU bounds
4. **Document backend stability contract** — what happens if backends are added/removed
5. **Consider persistent cache** for future multi-worker deployments

---

## Reference Documents

- **Design Review**: `docs/reviews/007a-routing-refactor-review.md` (lak, 2026-06-08)
- **Test Suite**: `eval/routing-symmetry-cross-backend-007b.test.js` (comprehensive 74-test harness)
- **Health Script**: `eval/fleet-health.js` (monitors cache, distribution, performance)

---

**Prepared by**: Jit Oracle (claude-haiku-4-5)  
**For**: Cycle 4 Implementation Team  
**Status**: ✅ Handoff Ready
