---
pattern: Read memory for Oracle/ψ location before running environment detection scripts — detection scripts assume ψ is co-located with pwd, which fails on Windows multi-repo setups
date: 2026-05-20
source: rrr: Jit Oracle
concepts: [windows, oracle-root-detection, ψ-path, memory-first, environment]
---

# Read Memory Before Running Detection Scripts

When an Oracle's ψ vault is not co-located with the current working directory (common in Windows setups where `C:\Users\admin` is the shell home but `C:\Users\admin\Jit` is the oracle repo), the standard bash detection logic (`git rev-parse` + CLAUDE.md + ψ/ check) will silently fall through to "use pwd" — and then create files in the wrong place.

**Rule**: Before running any Oracle root detection bash script, check stored memory (e.g., `ecc_integration.md` or `user_setup_jit.md`) for a stored ψ path. If found, use it directly and skip the detection script.

**Evidence**: Session b4fc5d38 — detection failed, created `~/.claude/projects/C--Users-admin/memory/retrospectives/` before cross-referencing memory revealed the real ψ at `C:\Users\admin\Jit\ψ`.

**Applies to**: Any skill that writes to ψ/ — /rrr, /trace, /learn, /vault, etc. — whenever running on a Windows Oracle where home dir ≠ Oracle repo dir.
