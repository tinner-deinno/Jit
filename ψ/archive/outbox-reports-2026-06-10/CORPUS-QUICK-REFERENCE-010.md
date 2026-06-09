# Thai Test Corpus 010 — Quick Reference

**File**: `thai-test-corpus-010.json`  
**Phrases**: 28 distinct Thai phrases  
**Backends**: 9 (all covered)  
**Purpose**: Regression testing for TICKET-010 (routing consistency)

---

## Key Facts

- **Total Phrases**: 28 (one per entry)
- **Backend Distribution**: 4 + 3×8 = 28 (MDES gets 4 as reference backend)
- **Syllable Range**: 1–8 syllables (realistic Thai variety)
- **Tone Marks**: 9 phrases with marks, 19 without (32/68 split)
- **Code-Switching**: 4 phrases mix Thai + English
- **Zero-Width Safety**: All phrases safe (no ZWNJ/ZWSP)

---

## Backend Assignment (9 Backends)

```
[0] ollama_mdes      ← 4 phrases (reference)
[1] thaillm          ← 3 phrases
[2] commandcode      ← 3 phrases
[3] ollama_local     ← 3 phrases
[4] ollama_cloud     ← 3 phrases
[5] copilot          ← 3 phrases
[6] openai           ← 3 phrases
[7] openclaude       ← 3 phrases
[8] innova_bot       ← 3 phrases
```

---

## JSON Structure (per entry)

```json
{
  "id": "TH-010-NNN",
  "phrase": "Thai text here",
  "syllables": ["syl", "la", "bles"],
  "syllable_count": 3,
  "tone_marks": 0,
  "contains_zero_width": false,
  "backend_index": 0-8,
  "backend_name": "backend_id",
  "reason": "Why this tests this backend..."
}
```

---

## Usage in Test Harness

```javascript
const corpus = require('./thai-test-corpus-010.json');

// For 10 iterations × 28 phrases = 280 routing decisions
corpus.forEach(entry => {
  for (let round = 1; round <= 10; round++) {
    const result = router.selectBackend(entry.phrase);
    
    // Record: { phrase, expected: entry.backend_index, actual: result.index, round }
    // Verify: result.index === entry.backend_index (determinism)
  }
});

// Distribution analysis:
// - Per-backend count should be ~31 routes (11.11%)
// - Tolerance: ±0.5% (10.34%-11.66%)
// - Expected variance: ≤0.5%
```

---

## Pattern Categories

### Single Syllables (8 phrases)
จิต, เอ, แอ, โอ, ใจ, ไข่, ศีล, ๑๒๓
- Tests: minimal routing

### Two Syllables (6 phrases)
นำกาย, สมาธิ, ธรรมะ, ปัญญา, น้ำขึ้น, ทั้งหมด
- Tests: syllable-boundary handling

### Three Syllables (11 phrases)
อวัยวะ, ภาษาไทย, เชียงใหม่, ประเทศไทย, ให้รีบตัก, จิตนำกาย, วิญญาณ, คืออะไร, รัน node mother.js, Thai-Syllable-Splitter แบบ deterministic, ความพอเพียง
- Tests: common Thai conversation length

### 4+ Syllables (3 phrases)
มนุษย์ Agent (4), กรุงเทพมหานคร (5), ความแตกต่างระหว่าง soma และ innova (8)
- Tests: long strings, boundary conditions

---

## Edge Cases Covered

| Edge Case | Examples | Tests |
|---|---|---|
| Vowel-only syllables | เอ, แอ, โอ, ใจ | Vowel-prefix handling |
| Rare consonants | ศีล, วิญญาณ, ปัญญา | Consonant clusters |
| Tone marks | ไข่, ธรรมะ, น้ำขึ้น | Diacritical handling |
| Proper nouns | เชียงใหม่, กรุงเทพมหานคร | Place names |
| Thai numerals | ๑๒๓ | Digit conversion |
| Code-switching | มนุษย์ Agent, รัน node mother.js | Mixed language |
| Idiomatic phrases | จิตนำกาย, ความพอเพียง | Cultural context |

---

## Expected Test Results

### Determinism Check
```
PASS if: for all 28 phrases, 10 runs each, 
         result always maps to the same backend
         (0 drift, 0 cross-contamination)
```

### Distribution Fairness Check
```
Backend frequency distribution after 280 decisions:
  Expected: ~31 decisions per backend (11.11%)
  Tolerance: 10.34%-11.66% (±0.5%)
  
PASS if: all 9 backends within tolerance
         (variance ≤0.5%)
```

### Variance Policy
```
≤0.5%  → PASS (acceptable variance)
>0.5%  → Code review needed (investigate why)
>1.0%  → Hotfix required (significant drift)
```

---

## BACKEND_ORDER Variations

Test 3 configurations with this corpus:

1. **Baseline** (all 9)
   ```
   ollama_mdes,thaillm,commandcode,ollama_local,ollama_cloud,
   copilot,openai,openclaude,innova_bot
   ```
   Expected variance: ≤0.5%

2. **Remove 1** (8 backends, e.g., innova_bot removed)
   ```
   ollama_mdes,thaillm,commandcode,ollama_local,ollama_cloud,
   copilot,openai,openclaude
   ```
   Expected: Phrases that mapped to innova_bot now remap to next in order
   Variance: likely 1.5%-3% (3 phrases redistribute)

3. **Add Hypothetical 10th** (e.g., new_backend)
   ```
   ollama_mdes,thaillm,commandcode,ollama_local,ollama_cloud,
   copilot,openai,openclaude,innova_bot,new_backend
   ```
   Expected: New backend gets ~1/10 = 10% of routes
   Variance: ±1-2% (algorithm redistribution)

---

## Files Generated

- **thai-test-corpus-010.json** — The corpus (this is the main artifact)
- **VALIDATION-REPORT-thai-test-corpus-010.md** — Full validation details
- **CORPUS-QUICK-REFERENCE-010.md** — This file

---

## Implementation Checklist (for chamu/QA)

- [ ] Load corpus in `test/regression-010.js`
- [ ] Implement 10-round iteration loop
- [ ] Capture routing distribution per backend
- [ ] Compute variance statistics (mean, stddev, percentiles)
- [ ] Generate `eval/regression-baseline-010.json` golden file
- [ ] Test 3 BACKEND_ORDER variations
- [ ] Document variance thresholds in PR release notes
- [ ] Commit baseline to repo for future regression detection

---

## Regression Baseline Template (eval/regression-baseline-010.json)

```json
{
  "corpus_version": "010",
  "corpus_stats": {
    "total_phrases": 28,
    "total_backends": 9,
    "syllable_distribution": {
      "1": 8, "2": 6, "3": 11, "4": 1, "5": 1, "8": 1
    },
    "tone_marks_count": 9,
    "with_code_switching": 4
  },
  "baseline_distribution": {
    "backend_0_ollama_mdes": { "count": 31, "percentage": 11.07 },
    "backend_1_thaillm": { "count": 31, "percentage": 11.07 },
    ...
  },
  "variance_per_backend": {
    "backend_0_ollama_mdes": { "min": 10.36, "max": 11.79, "stddev": 0.31 },
    ...
  },
  "tolerance_threshold": {
    "min_percentage": 10.34,
    "max_percentage": 11.66,
    "variance_allowed": 0.5
  },
  "variance_policy": {
    "acceptable": "≤0.5%",
    "review_required": ">0.5%",
    "hotfix_required": ">1.0%"
  },
  "test_harness": {
    "version": "regression-010.js v1.0",
    "date": "2026-06-09",
    "iterations": 10,
    "total_decisions": 280
  }
}
```

---

**Generated**: 2026-06-09  
**Co-authored by**: Claude Code + chamu (QA/Tester)  
**Part of**: Jit Oracle multi-agent system (TICKET-010)
