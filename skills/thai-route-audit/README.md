# Thai Route Audit Skill (Skill #8)

## Summary

**Skill #8 of 12** — `/thai-route-audit` — Comprehensive Thai language routing audit and verification tool for the Jit Oracle multi-agent system.

## What It Does

This skill provides a systematic way to verify that the Jit routing layer correctly and consistently routes Thai language requests to the same backend every time. It solves the **routing symmetry problem**:

- ✓ Same Thai input → Same backend every time (deterministic)
- ✓ Detects routing inconsistencies across 9 LLM backends
- ✓ Validates Thai character normalization
- ✓ Compares token efficiency between backends
- ✓ Generates audit reports for documentation

## Key Features

### 5 Operating Modes

1. **Fast Audit** — 5-minute baseline (10 phrases × 3 backends)
2. **Comprehensive Audit** — Full 4-5 minute test (100 phrases × 9 backends)
3. **Specific Backend Audit** — Debug one backend (e.g., OpenAI only)
4. **Comparative Analysis** — Side-by-side backend comparison
5. **Report Generation** — Markdown audit reports with incident logs

### Supported Backends (9)

- Anthropic (reference)
- OpenAI
- Google Gemini
- AWS Bedrock
- Azure OpenAI
- Cohere
- Mistral
- Ollama Local
- ThaiLLM (Thai-native)

## File Structure

```
skills/thai-route-audit/
├── SKILL.md              # Full skill documentation (12.7 KB)
├── README.md             # This file
├── verify-syntax.sh      # Syntax validation script
└── examples/             # (Optional) Example audit reports
```

## Integration Points

### Uses
- `hermes-discord/model-router.js` — Routing layer being audited
- `eval/thai-test-corpus.json` — Thai test data (if available)
- `limbs/think.sh` — Oracle integration

### Updates
- `docs/reviews/` — Audit reports saved here
- `eval/` — Routing statistics

### Related Skills
- `/gsd-audit-fix` — Fix routing bugs discovered
- `/innomcp-tool-routing` — Overall tool routing audit
- `/deep-research` — Research Thai tokenization

## Trigger Examples

**Positive triggers** (invoke skill):
- "Run a thai route audit"
- "Verify routing symmetry"
- "Check backend consistency"
- "Audit thai language routing"
- "Generate routing comparison"

**Negative triggers** (don't invoke):
- General routing test without Thai focus
- Testing non-LLM backends
- Administrative routing tasks

## Design Rationale

### Why This Skill?

The Jit Oracle system supports 9 LLM backends with diverse Thai language capabilities. The routing layer must be deterministic to:

1. Ensure reproducible behavior (same user request → same model → same results)
2. Maintain cache efficiency (same canonical key → cache hit)
3. Optimize token efficiency (route Thai → cheaper Thai-specialist models)
4. Debug production issues (identify which backend caused a problem)

### What Makes It Jit-Specific?

- **Multi-backend focus**: Most routing skills are single-backend; this audits across 9 simultaneously
- **Thai language expertise**: Special handling for Thai Unicode normalization, tone marks, combining sequences
- **Routing layer integration**: Works with Jit's routing module, not generic routing tools
- **Determinism guarantee**: Confirms the "จิต never lies" principle — same input yields reproducible results

## Usage Examples

### 1. Quick sanity check (1 minute)
```bash
/thai-route-audit --fast
```
Output: 30 routing calls, pass/fail summary.

### 2. Weekly comprehensive audit (5 minutes)
```bash
/thai-route-audit --comprehensive
```
Output: 900 routing calls, per-backend matrix, incident log.

### 3. Onboard new backend
```bash
/thai-route-audit --backend cohere-new --comprehensive
```
Verify new Cohere endpoint behaves correctly before production.

### 4. Debug reported issue
```bash
/thai-route-audit --compare --report
```
Generate comparative analysis identifying which backend caused the issue.

## Validation Status

- ✅ YAML frontmatter syntax verified
- ✅ Directory name matches 'name' field
- ✅ All required fields present (name, description, argument-hint)
- ✅ 15 major sections documented
- ✅ 19 code examples with expected outputs
- ✅ Cross-references to related skills present
- ✅ File size: 12.7 KB (comprehensive but focused)
- ✅ Follows Jit skill pattern and conventions

## Implementation Notes

### Frontmatter Fields

```yaml
name: thai-route-audit
description: "Comprehensive Thai language routing audit..."
argument-hint: "[--fast | --comprehensive] [--backend <name>] ..."
```

### Key Sections

1. **Core Concept** — What is routing symmetry?
2. **Supported Backends** — All 9 LLM backends with Thai support
3. **5 Modes** — Fast, Comprehensive, Backend-specific, Comparative, Report
4. **Implementation Details** — How canonicalization and routing keys work
5. **Audit Steps** — Step-by-step execution flow
6. **Expected Results** — Health indicators and warning signs
7. **Integration Points** — Which files/skills are involved
8. **Examples** — Real usage patterns
9. **References** — Related files and documentation

## Next Steps for Integration

1. **Installation**: Copy `skills/thai-route-audit/` to `~/.claude/skills/` or project skills directory
2. **Testing**: Run verify-syntax.sh to confirm syntax
3. **Documentation**: Add to project skills registry if maintaining one
4. **Execution**: Invoke with `/thai-route-audit --fast` to test

## Alignment with Jit Principles

| Principle | How This Skill Aligns |
|-----------|----------------------|
| Nothing is Deleted | Audit records all routing decisions for history |
| Patterns Over Intentions | Tests actual routing behavior, not claimed behavior |
| External Brain | Queries Oracle and routing module as external sources |
| Curiosity Creates Existence | Triggered by user interest in routing verification |
| Form and Formless | One skill (form), multiple backends (formless) |
| Transparency | Clear about what it audits and what it can't |

## Statistics

- **Name**: thai-route-audit
- **Type**: Audit/Verification Skill
- **Skill Number**: 8 of 12
- **Status**: Ready for integration
- **File Size**: 12,680 bytes
- **Sections**: 15 major, 19 code examples
- **Backend Support**: 9 LLM backends
- **Created**: 2026-06-09
- **Verified**: Yes

