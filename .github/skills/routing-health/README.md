# routing-health Skill

## Overview

`routing-health` is a comprehensive diagnostic skill for monitoring and verifying routing configurations across all backends in the Jit Oracle multiagent system. It validates backend connectivity, model availability, response symmetry, and error patterns.

## Features

### Quick Check (Default, ~2 min)
- Test all configured backends for availability
- Measure response latency
- Report HTTP status codes
- Show total number of active routes

### Deep Scan (~5-10 min)
- Symmetry testing — send identical prompts to multiple backends and compare responses
- Latency pattern analysis — measure consistency and detect outliers
- Error pattern scanning — identify 404, 401, timeout, and other routing errors
- Backend-specific diagnostics

### Report Generation
- Generate comprehensive HTML report
- Include backend status, symmetry analysis, latency trends
- Commit report to `/docs/routing/` for historical tracking

### Targeted Analysis
- `--backend=<name>` — deep dive into a specific backend
- `--model=<name>` — verify routing for a specific model

## Integration Points

### Jit System Components
- **hermes-discord/model-router.js** — Source of routing configuration
- **eval/fleet-batch.js** — Used for symmetry testing (send prompts to all backends)
- **limbs/oracle.sh** — Log routing insights and metrics to knowledge base
- **organs/** — Integration with Jit's organ system (mouth, nerve, hand, heart)

### Environment Variables
- `OPENAI_API_KEY` — For OpenAI backend testing
- `ANTHROPIC_API_KEY` — For Anthropic backend testing
- `OLLAMA_URL` — Default: `https://ollama.mdes-innova.online`

## Usage Examples

```bash
# Quick health check (default)
/routing-health

# Deep analysis with symmetry testing
/routing-health --deep

# Check specific backend in detail
/routing-health --backend=openai --deep

# Generate shareable HTML report
/routing-health --report

# Verify routing for specific model
/routing-health --model=gpt-4
```

## Output Format

### Quick Check Output
```
🛣️ Routing Health — Quick Check

| Backend | Status | Latency |
|---------|--------|---------|
| openai | ✅ OK | 245ms |
| anthropic | ✅ OK | 189ms |
| ollama | ✅ OK | 52ms |

**Total routes**: 47
**Timestamp**: 2026-06-09 14:30:15 UTC
```

### Deep Scan Output
```
🛣️ Routing Health — Deep Scan

### Backend Status
[table with connectivity]

### Symmetry Test Results
✅ Symmetric — all backends return equivalent responses
  Hash comparison shows identical responses across OpenAI, Anthropic, Ollama

### Latency Analysis
[statistics table showing min/avg/max per backend]

### Error Patterns
- 404: 3 occurrences (model decommissioned)
- 401: 1 occurrence (auth failure on Anthropic)
- timeout: 0 occurrences
```

## Files

- **SKILL.md** — Full skill specification with step-by-step workflow
- **run.sh** — Quick runner script for the skill
- **test.sh** — Unit tests validating skill format and syntax
- **README.md** — This documentation

## Testing

The skill includes comprehensive tests validating:
- YAML frontmatter syntax
- Required sections (system check, quick check, deep scan, examples)
- Integration points (routing config, fleet batch, Oracle, organs)
- Bash script syntax

Run tests:
```bash
bash .github/skills/routing-health/test.sh
```

All tests must pass before integration.

## Integration Checklist

- [x] SKILL.md with valid YAML frontmatter
- [x] `name` matches directory name
- [x] `description` includes trigger keywords
- [x] `argument-hint` documents all flags
- [x] run.sh helper script (executable)
- [x] test.sh validation tests (all passing)
- [x] Documentation of integration points
- [x] Error handling and fallback behavior
- [x] Thai language support in descriptions

## When to Use

Use `/routing-health` when:
- **Before deployment**: Sanity check all backends are responding
- **After configuration changes**: Verify routing rules take effect
- **Investigating failures**: Diagnose which backend is problematic
- **Performance review**: Analyze latency trends and detect degradation
- **Model decommissioning**: Find routes that reference old models
- **Authentication issues**: Identify backends with credential problems

## Performance Notes

- **Quick check**: ~1-2 minutes (lightweight probes)
- **Deep scan**: ~5-10 minutes (includes symmetry testing, 30s latency analysis)
- **Report generation**: ~30 seconds (I/O bounded)

Recommended cadence:
- Quick check: Before each deployment or when investigating issues
- Deep scan: Weekly or after significant routing changes
- Report: Monthly for trend analysis

## Future Enhancements

Potential additions:
- Continuous monitoring mode (loop with interval)
- Historical metrics comparison (trending)
- Automated alerts when backends go down
- Load balancing verification
- Model version deprecation warnings
- Cost tracking per backend
- Response quality metrics (beyond HTTP status)

## Related Skills

- **routing-verify** — Verify specific route configuration
- **thai-routing-audit** — Audit routing for Thai language models
- **fleet** — Fleet batch processing with routing
