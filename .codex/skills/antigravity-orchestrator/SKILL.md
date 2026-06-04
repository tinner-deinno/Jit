---
name: antigravity-orchestrator
description: Use Antigravity as a Google-authenticated mission-control lane for wide coordination, MCP browser automation, and parallel verification while Codex/Jit remains the deep executor and evidence owner.
---

# Antigravity Orchestrator

Use this skill when the task mentions Antigravity, Google Pro account auth, Gemini/Google mission control, browser MCP automation, or routing work between Codex, Claude, Gemini, Hermes, and innova-bot.

## Workflow

1. Prove local readiness with `node eval/antigravity-probe.js`.
2. Treat `AGENTS.md` as the convergence layer and this `SKILL.md` as the reusable skill contract.
3. Route wide coordination and parallel verification to Antigravity.
4. Route deep code edits, commits, and final evidence to Codex/Jit.
5. Use `scripts/antigravity-y.sh` or `scripts/antigravity-y.ps1` so launches append `-y`.
6. Use Playwright MCP and Chrome DevTools MCP for browser evidence when Antigravity needs GUI automation.

## Boundaries

- Do not store Google, Gemini, or Antigravity secrets in the repo.
- Do not count Antigravity as a content-usable model lane unless a live task returns usable content.
- If `--exec plan.json` is requested, first confirm the current CLI advertises or accepts it; Antigravity 1.107.0 help does not currently advertise `--exec`.
- Keep Codex as final verifier for innomcp completion claims.

## Evidence

Required evidence for ready state:

- `~/.antigravity/config.yaml` contains `defaults.auto_approve=true` and `defaults.skip_permissions=true`.
- `antigravity --version` succeeds.
- `antigravity chat --help` succeeds.
- Jit routing contains provider `antigravity`, agent `antigravity-mission-control`, and validation command `node eval/antigravity-probe.js`.
