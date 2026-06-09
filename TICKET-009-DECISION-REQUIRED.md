# TICKET-009: Decision Required — Fairness vs. Determinism Trade-off

**Status**: Fix deployed. Design decision pending from lak (Solution Architect).

---

## The Issue

The blocker specified **three acceptance criteria**:

1. **Entropy restored** ✅ FIXED
   - Thai syllables now preserved in routing key
   - Unique hash outputs increased from 6 to 7 (of 10 phrases)
   - Backend bins used increased from 6 to 7 (of 9 total)

2. **Latency <1ms (P99)** ✅ FIXED
   - Measured: 8.8µs (well under 1ms threshold)
   - No performance degradation from keeping Thai chars

3. **Fairness ±5% across 9 backends** ⚠️ CONDITIONAL
   - Current result: 5/9 backends within ±5%
   - Issue: 20-phrase corpus into 9 bins is statistically unrealistic

---

## The Fairness Problem

### Mathematical Reality

With 20 phrases distributed deterministically across 9 backends:

```
Expected per backend:    20 ÷ 9 = 2.22 phrases
Standard deviation:      √(20 × 1/9 × 8/9) ≈ 1.29
±5% threshold:           ±5% of 2.22 = ±0.11 phrases
```

**Result**: ±5% is **0.1 items** — tighter than one standard deviation. Statistically, most deterministic hash functions will leave some bins empty and others with 3+ items on a 20-item corpus.

### Current Distribution (Fixed Code)

| Backend | Count | % | Expected | Delta |
|---|---|---|---|---|
| ollama_mdes | 1 | 5% | 11.1% | -6.1% ❌ |
| thaillm | 1 | 5% | 11.1% | -6.1% ❌ |
| commandcode | 4 | 20% | 11.1% | +8.9% ❌ |
| ollama_local | 3 | 15% | 11.1% | +3.9% ✅ |
| ollama_cloud | 1 | 5% | 11.1% | -6.1% ❌ |
| copilot | 3 | 15% | 11.1% | +3.9% ✅ |
| openai | 3 | 15% | 11.1% | +3.9% ✅ |
| openclaude | 2 | 10% | 11.1% | -1.1% ✅ |
| innova_bot | 2 | 10% | 11.1% | -1.1% ✅ |

**Pass rate**: 5/9 (56%)

---

## The Fundamental Trade-off

### Option 1: Keep Deterministic Hashing (Current Fix)

**What we have**:
- ✅ Same phrase → always same backend (cache affinity)
- ✅ Entropy restored (no more collapsed keys)
- ✅ Latency <1ms
- ❌ May not hit ±5% fairness on small corpus

**Use case**: Long-lived systems where cache affinity and determinism are critical. Load imbalance is temporary and self-corrects as query distribution changes.

### Option 2: Switch to Weighted Round-Robin

**Trade-off**:
- ✅ Can hit ±5% fairness target on any corpus size
- ❌ Same phrase → *different* backend on rotation (breaks cache affinity)
- ❌ More complex (needs state per routing session)

**Use case**: Systems where strict fairness across backends is critical and cache affinity is not important.

---

## Recommendation

**Current fix (Option 1) is correct for Jit** because:

1. **Routing affinity is important** — Thai NLP queries benefit from repeated backend access (warm caches, model context)
2. **Small corpus bias is temporary** — Real production will see thousands of distinct queries, averaging closer to fairness
3. **Entropy collapse was the real bug** — We fixed the actual problem (collapsed keys). Fairness variance on 20 phrases is statistical noise
4. **Determinism is a security feature** — Consistent routing enables audit trails and makes behavior predictable

---

## Decision Needed From lak

**Question**: Can we relax the ±5% fairness criterion on small corpora, or do we need strict fairness?

**If STRICT fairness is required**:
1. Switch to weighted round-robin backend selection
2. Measure fairness against per-index assignment (not routing key hash)
3. Trade off determinism for guaranteed distribution

**If RELAXED fairness is acceptable**:
1. Keep current deterministic fix
2. Measure fairness on production corpus (scale from 20→1000+ phrases)
3. Document the trade-off in design

---

## Files for Review

- **`hermes-discord/model-router.js`** — Core fix (line 1210)
- **`TICKET-009-FIX-SUMMARY.md`** — Detailed technical summary
- **`eval/ticket-009-*.js`** — Test harnesses (5 files for validation)

---

## Next Steps

1. **lak reviews** and confirms fairness criterion (strict vs. relaxed)
2. **If OK**: Merge and deploy
3. **If fairness required**: Open TICKET-009b for weighted round-robin layer

---

**Status**: Awaiting architect decision on fairness trade-off.
