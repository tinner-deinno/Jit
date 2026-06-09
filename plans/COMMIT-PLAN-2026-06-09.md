# Commit Plan — Jit Calm-Down 2026-06-09

## Context
- 70+ untracked files from cmdteam/Phase 3 work spanning 2 days
- 33 commits ahead of origin, 1760 behind
- System now at 88% vital, 7 loops to be started, Oracle running
- Prior plan `/workspaces/Jit/plans/MASTER-WORK-PLAN-2026-06-07.md` is COMPLETE (49/49 tickets done 2026-06-08) — this plan is the *commit* calm-down, not new work
- Sequence: dependency-aware batches so the repo stays buildable after each push

## Commit Batches (in dependency order)

### Batch 1: Brain artifacts (lowest risk)
- `ψ/` memories: learnings, traces, retrospectives, skills
- `ψ/memory/`, `ψ/inbox/`, `ψ/outbox/`, `ψ/learn/`
- Justification: `ψ/` is git-tracked per project policy, captures work context
- Risk: low — pure additive content, no executable impact

### Batch 2: Validator core (medium risk)
- `src/secure_validator*.js`, `src/json_validator.js`
- `tests/*validator*.{js,sh}`, `tests/security_test_suite_*.{json,py}`
- `src/secure_validator_cli.js`, `src/secure_validator_v8.js`
- **Requires**: `bash tests/run_security_suite_3.sh` + `4.sh` pass before commit
- Risk: medium — touches input parsing on auth/validation paths

### Batch 3: Bus auth + safe variants (medium risk)
- `network/bus-auth.sh`, `network/webhook-safe.sh`, `network/discord-webhook.sh`
- `organs/hand-safe.sh`
- `limbs/validate.sh`, `limbs/validate-task.sh`
- Security-critical, integrates with `bus.sh`; review with `neta` first
- Risk: medium — auth-touching surface

### Batch 4: Infrastructure (low risk)
- `scripts/jit-daemon.env.example`, `scripts/jit-daemon.service`
- `scripts/jit-loops-master.sh`, `scripts/writer-loop.sh`
- `systemd/cmdteam-self-improve.{service,timer}`, `systemd/jit-secure.sh`
- `eval/health-monitor.sh`, `eval/monitor.sh`, `eval/integration-test-*.sh`
- `specs/test-plans/`
- Additive, system-level; verify with `bash scripts/bootstrap.sh --check`

### Batch 5: Documentation (low risk)
- `docs/API.md`, `docs/API_DOCUMENTATION_SECTION.md`, `docs/api/`
- `plans/JIT-011-DEVELOPMENT-PLAN.json`
- `tests/JIT-020-*.md`, `tests/README-JIT-020.md`, `tests/TASK-12-QUICK-REFERENCE.md`
- `agents/cmdteam-interpreter/`
- Markdown, decision trees, plain documentation

### Batch 6: Orphan decisions (review required)
- `logs/`, `reports/`, `jit019_security_analysis.json`
- `tests/security_test_results_*.json`, `tests/run_security_suite_*.sh`
- `mirror/`, `ψ/archive/`
- **Decision per item**: keep (historical signal) vs delete (noise)
- Triage: `neta` (review) + `pran` (vitality) for keep/delete call

## Pre-Commit Checklist
- [ ] Oracle healthy at `:47778` — `curl http://localhost:47778/api/health`
- [ ] All 7 loops alive in `/tmp/cmdteam/` — `pgrep -fa cmdteam`
- [ ] `bash eval/body-check.sh` vitality ≥ 85%
- [ ] `bash eval/soul-check.sh` — all 15 agents respond
- [ ] No secrets in any file — `grep -rE "ANTHROPIC_API_KEY|OPENAI_API_KEY|sk-[A-Za-z0-9]{20,}" --include="*.{sh,js,py,json,md}"`
- [ ] No `.env` files staged (only `.example`) — `git status | grep -v '\.example$'`
- [ ] Tests for Batch 2 pass before each push
- [ ] User (innova/innova) approval received per commit

## Post-Commit Actions
- `git push origin main` (or create PR if branching preferred)
- Update `/workspaces/Jit/plans/MASTER-WORK-PLAN-2026-06-07.md` with actual commit hashes
- Write handoff to `/workspaces/Jit/ψ/inbox/handoff/2026-06-09-calm-down.md`
- `/forward` context for next session
- Notify `vaja` to report calm-down completion to human

## Risk Assessment
- **Low risk**: brain artifacts, docs, infrastructure
- **Medium risk**: validator core (Batch 2) + bus auth (Batch 3) — require tests
- **High risk**: nothing currently (no auth-breaking changes without rollback path)
- **Rollback**: `git revert <sha>` is safe per Rule 1 (Nothing is Deleted) — revert creates a new commit, never rewrites

## Open Questions for Human
1. Batch 6 orphans — keep as historical record or prune? (recommend: keep `reports/`, prune `logs/`)
2. Push directly to `main` or open PR for review? (recommend: PR, given 33 commits ahead)
3. Re-merge `origin` (1760 behind) before or after these batches? (recommend: after — clear local state first)

---
*Prepared by*: innova (จิต/mind)
*Reviewed by*: pending
*Plan type*: Commit-only — no implementation work
