---
name: thai-route-audit
description: "Comprehensive Thai language routing audit and verification tool. Use when user says 'route audit', 'verify routing', 'thai routing', 'routing symmetry', 'backend consistency', or wants to test route determinism for Thai input. Do NOT trigger for general route testing without Thai focus, or for non-LLM backends."
argument-hint: "[--fast | --comprehensive] [--backend <name>] [--corpus <file>] [--compare] [--report]"
---

# /thai-route-audit — Thai Language Routing Verification

> "Same Thai input, same Thai backend every time — that is routing symmetry."

Verify that Jit's multi-backend routing system correctly and consistently routes Thai language requests to the same backend. Critical for maintaining deterministic behavior across model inference.

## Usage

```
/thai-route-audit                      # Quick audit (fast mode)
/thai-route-audit --comprehensive      # Full symmetry test (all 9 backends)
/thai-route-audit --backend openai     # Audit specific backend
/thai-route-audit --corpus thai-test-corpus.json    # Use custom test corpus
/thai-route-audit --compare            # Compare all backends side-by-side
/thai-route-audit --report             # Generate markdown audit report
/thai-route-audit --fast --backend anthropic        # Quick Anthropic-only test
```

---

## Core Concept: Routing Symmetry

**Routing Symmetry** = Given the same Thai input (same language, region, character encoding), the routing layer consistently selects the same backend on every call.

This is essential because:
- ✓ Token budgets are backend-specific (some models have higher Thai token counts)
- ✓ Thai character normalization varies by backend
- ✓ Cache-hit rates depend on consistent routing
- ✓ User experience breaks if requests to "same intent" ping different models

**Formula**:
```
Input (Thai) → Routing Key (thai-canonical-form) 
  → Backend Selection (deterministic function)
  → Same Backend Every Time
```

---

## Supported Backends (9 total)

| # | Backend | Model | Thai Support | Notes |
|---|---------|-------|--------------|-------|
| 1 | **anthropic** | claude-opus-4.7 | ✓ Full | Default, reference |
| 2 | **openai** | gpt-4-turbo | ✓ Full | Token count variance |
| 3 | **google** | gemini-pro | ✓ Full | Normalization aware |
| 4 | **aws-bedrock** | Claude 3.5 Sonnet | ✓ Full | Region-dependent |
| 5 | **azure-openai** | GPT-4 | ✓ Full | Endpoint routing |
| 6 | **cohere** | Command R+ | ✓ Limited | Thai coverage gaps |
| 7 | **mistral** | Large | ✓ Limited | European bias |
| 8 | **ollama-local** | gemma4:26b | ✓ Full | MDES on-site |
| 9 | **thaillm** | openthaigpt | ✓ Expert | Thai-native model |

---

## Mode 1: Fast Audit (default)

Quick 5-minute symmetry check with 10 common Thai phrases.

```bash
# Inputs tested
phrases = [
  "สวัสดีชาวโลก",              # Hello world
  "ฉันจำเป็นต้องช่วยเหลือ",      # I need help
  "แสดงรายการสินค้า",           # Show product list
  "ปลายปีวันนี้คืออะไร",         # What is EOY?
  "ระบบขนส่งจราจรกรุงเทพ",      # Bangkok transport
  "คณิตศาสตร์และวิทยาศาสตร์",    # Math and science
  "ปลัดเก็บความลับราชการ",       # State secrets (redacted)
  "อ.ส.ป.ส. และกฎหมาย",         # CICT and law
  "พยาธิสถานศูนย์กลาง",         # Central Hospital
  "ศาสตราจารย์โปรแกรมมิ่ง"      # Professor Programming
]

for phrase in phrases:
  for backend in [anthropic, openai, thaillm]:
    route = routing.select(phrase)
    record(phrase, backend, route.selected_backend)
    assert route.selected_backend == expected_backend
```

**Output**:
```
⚡ Fast Audit: 10 phrases × 3 backends = 30 routing calls

  Phrase 1: สวัสดีชาวโลก
    ✓ Anthropic → anthropic (canonical: สวัสดีชาวโลก)
    ✓ OpenAI   → openai (canonical: สวัสดีชาวโลก)
    ✓ ThaiLLM  → thaillm (canonical: สวัสดีชาวโลก)

  Phrase 2: ฉันจำเป็นต้องช่วยเหลือ
    ✓ Anthropic → anthropic
    ✓ OpenAI   → openai
    ✓ ThaiLLM  → thaillm

  [+8 more phrases]

  Summary: 30/30 routed consistently ✓
  Symmetry Score: 100%
  Audit Duration: 42 seconds
```

---

## Mode 2: Comprehensive Audit

Full symmetry test across all 9 backends with 100+ Thai test cases.

```bash
/thai-route-audit --comprehensive
```

Uses `eval/thai-test-corpus.json` (if present) or generates inline:

```json
{
  "standard_thai": [
    "สวัสดีชาวโลก",
    "บ่ายนี้อากาศดีมาก",
    "ขออภัยที่มาช้า"
  ],
  "thai_with_tones": [
    "ดัง (loud)",
    "หนัก (heavy)",
    "ยาว (long)"
  ],
  "thai_transliteration": [
    "Thai Romanization Test",
    "GPT-3 Tokenization"
  ],
  "thai_canonical_forms": [
    "สวัสดี vs สวส์ฒดี (with vowel marks)",
    "ฯลฯ vs เป็นต้น (abbreviations)"
  ],
  "edge_cases": [
    "Zero-width joiner (‍)",
    "Thai currency symbols",
    "Thai numerals: ๐ ๑ ๒ ๓",
    "Emoji mixed: 😀สวัสดี"
  ]
}
```

**Output**: Detailed per-backend routing matrix + variance report.

```
📊 Comprehensive Audit (9 backends × 100 phrases = 900 routes)

  Backend Consistency:
    anthropic:      100/100 ✓
    openai:         98/100  ⚠ (2 edge cases)
    google:         100/100 ✓
    thaillm:        100/100 ✓
    mistral:        95/100  ⚠ (5 variant phonemes)
    cohere:         92/100  ⚠ (8 rare chars)
    ollama-local:   100/100 ✓
    aws-bedrock:    99/100  ⚠ (1 tone mark)
    azure-openai:   100/100 ✓

  Symmetry Incidents:
    1. Incident [openai-001]: Phrase "ดีจริงๆ"
       - Call 1: openai (canonical: ดีจริงๆ)
       - Call 2: azure-openai (canonical: ดีจริง ๆ ← space injected!)
       - Root: Token boundary at zero-width joiner
       - Fix: Normalize ZWJ before canonicalization

  Global Symmetry: 882/900 (98%)
  Duration: 4min 32s
  Report: /tmp/thai-audit-comprehensive-2026-06-09.md
```

---

## Mode 3: Specific Backend Audit

```bash
/thai-route-audit --backend openai
/thai-route-audit --backend thaillm --comprehensive
```

Focuses on one backend only. Useful for:
- Investigating token count variance
- Testing regional endpoint behavior (Azure, AWS)
- Validating new backend onboarding
- Debugging routing failures

**Output**: Single backend's full routing table + token statistics.

---

## Mode 4: Comparative Analysis (--compare)

```bash
/thai-route-audit --compare
```

Side-by-side comparison of all backends on the same 50-phrase corpus.

**Output format**:
```
🔄 Comparative Routing Analysis (50 phrases × 9 backends = 450 routes)

Phrase: "สวัสดีชาวโลก"
  anthropic:     ✓ anthropic    (25 tokens, +0ms)
  openai:        ✓ openai       (26 tokens, +2ms)
  google:        ✓ google       (24 tokens, +3ms)
  thaillm:       ✓ thaillm      (12 tokens, +1ms) ← Optimal for Thai
  aws-bedrock:   ✓ aws-bedrock  (25 tokens, +8ms)
  azure-openai:  ✓ azure-openai (26 tokens, +7ms)
  mistral:       ✓ mistral      (27 tokens, +2ms)
  cohere:        ✓ cohere       (29 tokens, +5ms)
  ollama-local:  ✓ ollama-local (11 tokens, +0ms) ← Fastest

Token Efficiency: thaillm & ollama-local both win
Latency Efficiency: ollama-local (on-site) fastest
Recommendation: Route Thai → thaillm for quality, ollama-local for speed
```

---

## Mode 5: Report Generation (--report)

```bash
/thai-route-audit --comprehensive --report
```

Generates a markdown audit report with:
- Symmetry findings
- Backend comparison matrix
- Edge case catalog
- Incident log
- Recommendations for routing improvements

Saves to: `docs/reviews/thai-route-audit-[DATE].md`

---

## Implementation Details

### Routing Key Generation

**Function**: `thaiCanonicalize(input) → canonical_form`

Normalizes Thai input to canonical form for consistent routing:

```javascript
function thaiCanonicalize(input) {
  return input
    .normalize('NFC')                    // Unicode canonical decomposition
    .replace(/[​-‍]/g, '')   // Remove zero-width characters
    .replace(/\s+/g, ' ')               // Collapse whitespace
    .toLowerCase()                      // Case normalization (Thai only)
    .trim();
}
```

**Routing Key**: `hash(canonicalize(input))`

```javascript
function routingKey(input) {
  const canonical = thaiCanonicalize(input);
  return hashMD5(canonical);
}
```

### Backend Selection

**Function**: `pickBackendByKey(key) → backend_name`

Deterministic selection based on routing key:

```javascript
function pickBackendByKey(key) {
  const backends = [
    'anthropic', 'openai', 'google', 'aws-bedrock', 'azure-openai',
    'cohere', 'mistral', 'ollama-local', 'thaillm'
  ];
  
  // Map key to backend index (9 backends = modulo 9)
  const index = parseInt(key.substring(0, 8), 16) % backends.length;
  return backends[index];
}
```

**Guarantee**: `pickBackendByKey(routingKey(A)) == pickBackendByKey(routingKey(A'))` when `canonicalize(A) == canonicalize(A')`

---

## Audit Execution Steps

### Step 1: Setup

Check that routing layer is loaded and test corpus is available.

```bash
# Verify routing module
if [ ! -f "hermes-discord/model-router.js" ]; then
  echo "❌ Routing module not found"
  exit 1
fi

# Load test corpus
CORPUS="${CORPUS_FILE:-eval/thai-test-corpus.json}"
if [ ! -f "$CORPUS" ]; then
  echo "⚠ Custom corpus not found, using inline corpus"
  USE_INLINE=true
fi
```

### Step 2: Generate Test Phrases

Load from corpus or generate inline (if --fast).

### Step 3: Execute Routing Calls

For each phrase:
1. Calculate routing key
2. Pick backend
3. Record (phrase, canonical_form, selected_backend)
4. Verify determinism: repeat call 3x, confirm same backend each time

### Step 4: Analyze Symmetry

Count successes/failures per backend and overall.

### Step 5: Generate Output

Format results as markdown table + summary JSON.

---

## Expected Results

**Healthy routing** (target):
- Fast mode: 100% symmetry on 10 phrases × 3 backends
- Comprehensive: 98%+ symmetry across all backends
- All backends route consistently on repeated calls

**Warning signs** (investigate):
- Symmetry < 95% (could indicate unicode normalization issues)
- Repeated calls yield different backends (CRITICAL)
- Token count variance > 15% between equivalent backends
- One backend consistently slower (latency > 100ms)

---

## Integration Points

### Uses
- `hermes-discord/model-router.js` — routing layer
- `eval/thai-test-corpus.json` — test data (if present)
- `limbs/think.sh` — invoke via Oracle for offline verification

### Updates
- `docs/reviews/` — audit reports
- `eval/` — routing statistics

### Related Skills
- `/gsd-audit-fix` — fix routing bugs discovered
- `/innomcp-tool-routing` — overall tool routing audit
- `/deep-research` — research Thai tokenization behavior

---

## Examples

### Quick sanity check (1 minute)
```
/thai-route-audit --fast
```
Output: 30 routing calls, symmetry score, pass/fail.

### Weekly audit (5 minutes)
```
/thai-route-audit --comprehensive
```
Output: 900 routing calls, per-backend matrix, incidents.

### Onboarding new backend
```
/thai-route-audit --backend <name> --comprehensive
```
Verify new backend behaves symmetrically before production routing.

### Debug a reported routing bug
```
/thai-route-audit --compare --report
```
Generate comparative analysis to identify which backend caused the issue.

---

## Notes

- **Thai character handling**: Most issues are zero-width joiners (ZWJ), tone marks, or vowel combining sequences
- **Token variance**: Expected to be 5-10% between backends (some Thai tokenizers are more/less granular)
- **Performance**: Comprehensive audit (900 calls) takes ~4-5 minutes; consider --fast for CI/CD
- **Caching**: Routing keys should be cached to avoid re-computation on high-volume Thai requests

---

## References

- `hermes-discord/model-router.js` — Current routing implementation
- `eval/routing-symmetry-cross-backend-007b.test.js` — Route symmetry tests
- Jit CLAUDE.md § Thai Language Processing
- Unicode NFC/NFD normalization: https://unicode.org/reports/tr15/
