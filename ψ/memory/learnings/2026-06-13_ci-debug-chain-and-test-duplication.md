---
pattern: When fixing a CI test failure, read the entire test file — tests often duplicate source functions locally
date: 2026-06-13
source: rrr: innomcp
concepts: [ci, testing, debugging, rebase, avoidance-pattern]
---

# CI Debug Chain + Test File Duplication (2026-06-13)

## Rules

**Rule 1**: When a test fails, read the ENTIRE test file before touching source code. Tests may
duplicate source functions locally with a comment like "must stay in sync with X". Fixing only
the source leaves the duplicate test copy broken.

**Why**: innomcp `files-safePath.test.ts` had a local copy of `safePath()` with the comment
"must stay in sync with files.ts". I fixed `files.ts` first. CI still failed. Took 45 minutes
to realize the test had its own copy.

**Rule 2**: Map the full CI failure chain before fixing the first error.
Chain: pnpm lockfile mismatch → pnpm version (9→11) → Node version (20→22) → test expectations.
Each fix revealed the next. Mapping upfront is faster than iterating.

**Rule 3**: Rebase on 20+ commits with active conflicts → create a fresh branch instead.
`git checkout origin/main -b fix/name && git checkout <source-branch> -- <specific-files>`
is faster and safer than `git rebase origin/main` on a long diverged branch.

**Rule 4**: Tactical clarity (CI green) can crowd out strategic goals (architecture, monitoring).
Notice when you're choosing work with clear signals over work with ambiguous signals.
Explicitly timebox the strategic work first.

**Rule 5**: Goal conditions need concrete verification criteria at goal-setting time.
">100 CC sub-agents" is ambiguous. Before accepting a goal, ask: how will I know when this
specific condition is met? (task-count in a plan file? actual concurrent API calls? throughput?)
