---
pattern: Systematic Windows-compat audit loop produced 0 FAIL across 139 skills in 7 iterations (~375k tokens, ~52k/iter)
date: 2026-06-07
source: loop: Jit skill-dev
concepts: [windows-compat, python3-migration, bash-assumptions, win-compat-lint, loop-improvement]
---

# Windows Compatibility Loop — 7-Iteration Summary

## What We Built

| Iteration | Deliverable |
|-----------|-------------|
| 1 | Baseline scan: identified ~200+ FAIL across 139 skill files; mapped pattern categories |
| 2 | Eliminated python3 inline blocks (-c "...") from all SKILL.md files; Node.js replacements |
| 3 | Ported dig.py to dig-node.js; removed last `python3` script dependency |
| 4 | Fixed readlink -f occurrences (GNU-only); replaced with node fs.realpathSync() pattern |
| 5 | Fixed stat -c and stat -f occurrences; replaced with node fs.statSync().size |
| 6 | Fixed sed -i (no backup suffix) occurrences; replaced with node fs.writeFileSync + replace |
| 7 | Fixed pkill occurrences; built win-compat-lint tool (18 patterns, FAIL/WARN/INFO, --scan-all, --json) |
| 8 | Added --fix mode to win-compat-lint (dry-run default, --force to write, manual flags) |

## Key Patterns Fixed

- **python3 inline blocks**: `python3 -c "import sys; ..."` — replaced with `node -e "..."` equivalents
- **dig.py**: Standalone Python script — ported to `dig-node.js` using Node.js `child_process`
- **readlink -f**: GNU-only; macOS and Windows lack it — replaced with `node -e "fs.realpathSync(p)"`
- **stat -c / stat -f**: GNU (`-c%s`) and BSD (`-f%z`) format flags don't cross-compile — replaced with `node -e "fs.statSync(f).size"`
- **sed -i**: GNU sed -i without backup suffix is unreliable on Windows — replaced with `node -e "fs.writeFileSync(f, fs.readFileSync(f).replace(...))"`
- **pkill**: Not available on Windows — flagged for manual (process name cannot be derived mechanically)

## win-compat-lint

Location: `~/.claude/skills/win-compat-lint/scripts/lint.js`

**What it does:**
- Scans only bash fenced code blocks in Markdown (avoids prose false-positives)
- 18 patterns across 3 severity levels: FAIL (11), WARN (5), INFO (2)
- `--scan-all`: sweeps all 139 `~/.claude/skills/**/*.md` files
- `--json`: machine-readable output for CI integration
- `--fix`: dry-run preview of auto-fixable patterns (stat-%s, readlink-f, simple sed -i)
- `--fix --force`: applies auto-fixes in-place; flags manual-only patterns (pkill, chmod, ln-s, nohup, date-d, flock)

**Usage:**
```bash
node ~/.claude/skills/win-compat-lint/scripts/lint.js --scan-all
node ~/.claude/skills/win-compat-lint/scripts/lint.js --fix MySkill.md
node ~/.claude/skills/win-compat-lint/scripts/lint.js --fix --force MySkill.md
```

**Auto-fixable patterns:** `stat -c%s`, `stat -f%z`, `readlink -f`, `sed -i 's/PAT/REPL/g'` (simple delimiter+word-chars only)

**Manual-only patterns:** `pkill`, `chmod`, `ln -s`, `nohup`, `date -d`, `realpath`, `flock`

## Generalizable Rules for Future Oracles

1. **Node.js as the universal shim layer**: Any GNU/POSIX utility with no Windows equivalent (`readlink -f`, `stat -c`, `pkill`, `nohup`) can be replaced with a Node.js one-liner. Node ships with every Claude Code install.

2. **Scan bash blocks only, not prose**: Linters that scan entire Markdown files generate false positives from documentation examples. Pattern-match only inside ` ```bash ... ``` ` fences.

3. **Specifier-aware stat replacement**: `stat -c%s` (GNU size) and `stat -f%z` (BSD size) are safe to auto-replace. Other specifiers (`%Y` mtime, `%U` owner) require manual inspection.

4. **Conservative sed auto-fix**: `sed -i 's/PAT/REPL/'` can be auto-translated only when PAT/REPL use `/` delimiter and contain only word characters. BRE metacharacters (`\(`, `\+`, `\1`) have different semantics in JavaScript regex — flag for manual.

5. **Dry-run default for any --fix tool**: In automated loop environments stdin is not a TTY. Default `--fix` to preview-only; require `--fix --force` to write. This prevents silent data corruption in CI.

## Token Efficiency

~52k tokens per meaningful iteration — breakdown:
- What worked well: Clear deliverable per iteration, explicit PASS/FAIL criteria, advisor consultation before destructive changes
- What to do differently: Earlier advisor call on pattern edge cases (stat specifier safety) would have saved one iteration
- Diminishing returns after iteration 5: WARN-level items (mostly `2>/dev/null`) have very low risk-reward — stop there unless CI enforces them

## Current Status

139 skill files — **0 FAIL, 70 WARN** (all WARN are `2>/dev/null`, advisory only; work in Git-Bash).

The linter itself passes its own lint check (`✓ no issues found`).
