---
name: test_limbs_coverage
description: Coverage map for limb utility tests (test_limbs.py) — which functions/paths are tested
type: project
---

# Limb Test Coverage (test_limbs.py)

Created: 2026-06-06
Tests: 106 total, all passing

## lib.sh (28 tests)
- Color output: ok, warn, err, info, step + RESET code
- Logging: log_action timestamp, append, special chars, session marker
- Configuration: ORACLE_URL, OLLAMA_URL, OLLAMA_MODEL, JIT_ROOT, ORACLE_ROOT defaults + overrides
- json_str: plain, quotes, special chars, empty string, Unicode
- oracle_ready: connected, disconnected, curl failure (mocked)
- oracle_search: results formatting, no results (mocked)
- oracle_learn: calls python3 (mocked)
- Sourceability: single source, double source idempotent, function definitions, color constants

## act.sh (22 tests)
- git: commit, push (requires confirmation), status, log, diff
- write: new file, backup existing, empty path error
- append: add to existing, create new, empty path error
- run: successful command, failing command, empty command, logging
- http: missing URL error, GET with mocked curl
- learn: missing pattern error, offline pending log
- help: unknown command, lists all subcommands

## speak.sh (26 tests)
- report: title, content, logging, box drawing
- success: Thai label, green color, logging
- failure: Thai label, red color
- caution: Thai label, yellow color
- insight: Thai label, bold/cyan
- announce: banner, bold, logging
- confirm: yes, no, default no
- summary: date header, empty log (bug documented), missing log file
- status: innova label, time display (mocked curl)
- help: unknown command, lists all subcommands
- Thai language: all Thai labels, Thai text in messages

## index.sh (16 tests)
- status: header, timestamp, log section (mocked curl)
- wake: banner, limb check, awaken alias, logging
- help: unknown command, lists commands
- do: requires intent, logs intent
- reflect: requires topic
- remember: requires pattern
- Module loading: finds lib.sh, sibling scripts, makes executable

## Edge Cases (7 tests)
- write to nonexistent directory
- run with special characters
- git status in non-git dir
- log_action with special chars
- json_str empty string and Unicode
- report with long content wrapping
- success with empty message

## Bug Found
- speak.sh summary: `grep | sed || echo` never triggers the fallback because sed exits 0 on empty input. Documented in test but not fixed (not my job to fix).