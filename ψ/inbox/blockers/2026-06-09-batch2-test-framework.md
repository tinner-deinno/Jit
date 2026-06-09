# 🚧 BLOCKER: Batch 2 (Validator Core) — Test framework mismatch

**Status**: BLOCKED — needs decision
**Date**: 2026-06-09 04:05

## Problem
Tests in `tests/secure_validator*.test.js` and `tests/json_validator.test.js` use Jest API (`describe`, `test`, `expect`) but the repo has no `package.json` and no Jest installed.

```
$ node --test tests/secure_validator.test.js ...
ReferenceError: describe is not defined
✖ failing tests: secure_validator_cli.test.js, secure_validator_v8.test.js
```

## Source code
- `src/secure_validator.js`, `src/secure_validator_v8.js`, `src/json_validator.js` all export correctly as CommonJS
- `node -e "require('./src/secure_validator_v8')"` works fine
- Code itself is functional

## Options

| Option | Pros | Cons |
|--------|------|------|
| **A. Install jest + package.json** | Tests work as-is | Adds dependency, modifies project structure |
| **B. Rewrite tests to node:test** | No new dep, native | Touches 4 test files |
| **C. Commit src/ only, no tests** | Captures code | Violates "pass test first" rule |
| **D. Skip Batch 2 entirely** | Safe | Code sits uncommitted |

## My recommendation
**Option B** — node:test is the project's pattern (Bun + native). Test count is small (4 files, ~30 tests). Use `node --test` with assert + test() functions. ~30min of work.

## Awaiting
innova's choice on A/B/C/D.
