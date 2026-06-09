# Design Review: TICKET-007a Routing Refactor (Syllable-Splitter Keys)

**Reviewer**: lak (Solution Architect)  
**Date**: 2026-06-08  
**Scope**: `hermes-discord/model-router.js`, `limbs/thai-splitter.js`, `config/subagent-routing.json`, `eval/fleet-batch.js`  
**Commits**: c7c9918 (007a refactor), f9cf724 (integration tests), 9cf9107 (007b ollama_cloud symmetry)

---

## Executive Summary

The 007a refactor successfully replaces token-based routing keys with deterministic Thai syllable-splitter canonical forms. The core mechanisms (`thaiCanonicalize`, `routingKey`, `getThaiBackend`) are sound and pass 56+ determinism tests. However, the review identified **5 design issues**, **3 edge-case gaps**, and **2 integration risks** requiring attention.

**Verdict**: Conditionally approved. Apply the fixes in this review before promoting to fleet-wide deployment.

---

## Findings

### 1. Thai Alias Map Gap (Minor) — `model-router.js:87-96`

The `thaiAliasMap` inside `_normalizeModelAlias` is a hardcoded inline dictionary. It covers 7 aliases, but `eval/routing-syllable-keys.test.js` reveals a coverage gap: the alias `ไทย-แอล-แอล-เอ็ม-ไทย-ฟู-น` (Typhoon-S) is not mapped and passes through unchanged. This is acceptable if Typhoon-S is not in active use, but it creates a silent degradation path.

**Fix**: Add the missing alias entry, or emit a `console.warn` when a Thai alias passes through unresolved.

### 2. Cache Key Collision Risk (Moderate) — `model-router.js:272-273`

`_routeCache` uses the canonical string as a Map key. `thaiCanonicalize` joins segments with `' '` (space). Two different mixed Thai/English prompts can theoretically collide if their segment sequences produce the same joined string (e.g., differing only in non-Thai whitespace). In practice this is rare, but the cache is process-local and unbounded.

**Fix**: Bound the cache size (LRU, e.g., 500 entries). Also consider using the raw canonical before the `' '` join, or include a secondary hash in the key.

### 3. DJB2 Hash Bias (Minor) — `model-router.js:262-269`

`routingKey` uses DJB2 over the canonical form. DJB2 is fast but known to have poor avalanche for short strings, and the 32-bit unsigned output modulo `BACKEND_ORDER.length` can skew distribution when the order length is not a power of 2. Test E (`pickBackendByKey distribution`) shows all backends appear in 1000 keys, so this is not a practical problem at current scale, but it could become one if the order length changes to 3, 5, 6, 7, 9, 10, 11.

**Fix**: Replace `key % order.length` with a fair-range reduction (e.g., `key * order.length >>> 32` or a 64-bit FNV). Alternatively, document the known bias and test distribution whenever `BACKEND_ORDER` length changes.

### 4. `fleet-batch.js` `makeRoutingKey` Test Mismatch (Moderate) — `eval/integration-backend-splitter-keys.test.js:D`

Integration test section D checks whether `buildJobs` calls `makeRoutingKey()` (the function from `limbs/thai-splitter.js`). In reality, `fleet-batch.js` imports `{ routingKey }` from `model-router.js` and calls it directly. The test is checking for the wrong import name.

**Fix**: Update the integration test to assert `routingKey` (not `makeRoutingKey`) is referenced and used in `buildJobs`.

### 5. Thai Tonal/Zero-Width Character Normalization Gap (Moderate) — `limbs/thai-splitter.js:81-82`

`splitThaiSyllables` operates on the raw input string without calling `.normalize('NFC')`. While `model-router.js:224` does call `.normalize('NFC')` before processing, `thai-splitter.js` exports `makeRoutingKey` which does not. Any caller that uses `makeRoutingKey` directly (e.g., external tools, future eval scripts) may produce different syllable splits for the same logical Thai text if composed vs. decomposed forms are present.

**Fix**: Add `String(text).normalize('NFC')` at the top of `splitThaiSyllables` (or at the top of `makeRoutingKey`) to guarantee consistency regardless of caller.

### 6. ZWJ / ZWNJ / Punctuation Interactions (Edge Case)

Thai text sometimes contains Zero-Width Joiner (U+200D) or Zero-Width Non-Joiner (U+200C) in social-media or web-scraped content. These characters are not Thai range (U+0E00-U+0E7F) and will be treated as non-Thai segments. This could split a syllable mid-word and change routing unexpectedly.

**Fix**: Strip zero-width joiners/non-joiners before character classification in `thaiCanonicalize` and `splitThaiSyllables`.

### 7. `pickBackendByKey` Preferred Override Short-Circuit (Design)

When `preferred` is provided and present in `order`, `pickBackendByKey` returns it immediately without considering the routing key at all. This means `getThaiBackend` with `options.preferBackend` set will bypass cache lookup and always return the preferred backend. The cache is not populated in this path, so a subsequent call without `preferBackend` will recompute. This is acceptable behavior but should be documented because it breaks the "same prompt -> same backend" guarantee when mixed with `preferBackend`.

**Fix**: Document the override semantics in the JSDoc for `getThaiBackend`.

### 8. `_modelForOllamaBackend` Extracted via Regex `eval` (Risky Pattern)

`eval/routing-symmetry-ollama_cloud.test.js` extracts `_modelForOllamaBackend` from source via regex + `eval`. This is fragile and a security anti-pattern. If the source formatting changes, the test will break with a cryptic error.

**Fix**: Export `_modelForOllamaBackend` from `model-router.js` (e.g., `module.exports._modelForOllamaBackend`) so tests can require it directly.

---

## Integration Risks

1. **Process-local cache**: `_routeCache` is a `Map` in module scope. In a long-running Node process (e.g., fleet-batch with `--count 200`), the cache will grow unbounded. In a short-lived CLI process, the cache is useless. Consider an on-disk or shared-memory cache for multi-process fleet workers.

2. **Backend order length skew**: `BACKEND_ORDER` currently has 8 entries. If a future change adds or removes backends (e.g., removes `openclaude`), the modulo distribution will shift, changing which prompt maps to which backend. This is a breaking change for any persisted routing decisions. If routing affinity is required across deploys, the backend count should be versioned or the hash should use a fixed-size virtual ring.

---

## Recommendations Summary

| # | Issue | Severity | Fix | File |
|---|-------|----------|-----|------|
| 1 | Alias map gap | Minor | Add missing alias or warn | `model-router.js` |
| 2 | Unbounded cache | Moderate | Add LRU (500) | `model-router.js` |
| 3 | DJB2 bias | Minor | Document / test distribution | `docs/` |
| 4 | Test name mismatch | Moderate | Update test assertion | `eval/integration-backend-splitter-keys.test.js` |
| 5 | NFC normalization gap | Moderate | Add `.normalize('NFC')` | `limbs/thai-splitter.js` |
| 6 | ZWJ/ZWNJ edge case | Edge | Strip before classification | `model-router.js`, `limbs/thai-splitter.js` |
| 7 | Preferred override docs | Design | JSDoc update | `model-router.js` |
| 8 | Regex eval anti-pattern | Risk | Export helper directly | `model-router.js`, test |

---

*AI-generated design review. Signed by lak (Solution Architect).*
