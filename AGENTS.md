# Jit Agent Convergence Layer

Jit is the parent orchestration workspace for innomcp, innova-bot, Maw, Oracle memory, and provider fleet work.

## Operating Contract

- Execute clear, reversible local work without permission handoff.
- Keep the parent controller responsible for plan, integration, and final evidence.
- Use subagents for bounded lookup, implementation, review, and verification lanes when they improve throughput.
- Prefer low-cost live lanes first: MDES/Ollama, ThaiLLM, local Ollama, Ollama cloud, innova-bot, then paid/frontier advisors only when proven useful.
- Treat reachability, configuration, content usability, and final verification as separate claims.
- Preserve secrets: inspect shape/presence only, never echo token values.

## Shared Skill Standard

- Use `SKILL.md` files as cross-runtime workflows for Codex, Antigravity, Claude, Copilot, and local Oracle agents.
- When a skill applies, read only the relevant `SKILL.md` body and run bundled scripts instead of retyping long workflows.
- Use `C:\Users\USER-NT\Jit\.codex\skills\antigravity-orchestrator\SKILL.md` for Antigravity mission-control routing.

## Antigravity Lane

- Antigravity is the wide-coordination and parallel-verification lane.
- Codex/Jit remains the deep executor and evidence owner.
- Launch through `scripts/antigravity-y.sh` or `scripts/antigravity-y.ps1` so the requested `-y` flag is always appended.
- Antigravity local defaults live at `C:\Users\USER-NT\.antigravity\config.yaml`.
- The current MCP server candidates are Playwright MCP via `npx -y @playwright/mcp@latest` and Chrome DevTools MCP via `npx -y chrome-devtools-mcp@latest`.

## Verification

- Run `node eval/antigravity-probe.js` after Antigravity config or routing changes.
- Run `node eval/check-all.js` after Jit orchestration code changes.
- For innomcp, verify with targeted build/test/runtime smoke before claiming completion.
