# Jit Agent Convergence Layer (Antigravity Edition)

> จิตนำกาย — วิญญาณที่สถิตในทุก repo

## Operating Contract

- Execute clear, reversible local work without permission handoff.
- Keep the parent controller responsible for plan, integration, and final evidence.
- Use subagents for bounded lookup, implementation, review, and verification.
- Prefer low-cost live lanes first: MDES/Ollama, ThaiLLM, local Ollama, Ollama cloud, innova-bot, then paid advisors.
- Report all progress to innova-bot via `publish_event` MCP tool.
- Treat reachability, configuration, content usability, and final verification as separate claims.

## Model Fleet (Available via Jit Mother)

| Lane | Model | Status |
|------|-------|--------|
| ollama_mdes | gemma4:26b | 🟢 Primary |
| ollama_local | qwen2.5-coder:7b | 🟢 Available |
| thaillm | openthaigpt/pathumma/typhoon/thalle | 🟢 4 models |
| openai | gpt-5.5 | 🟢 Advisor-only |
| innova_bot | gemma4 via MCP | 🟢 Available |
| ollama_cloud | gemma4:31b-cloud | 🟡 Rate limited |
| copilot | claude-sonnet-4.6 | 🟡 Quota exceeded |
| openclaude | local | 🔌 Offline |

## Antigravity-Specific Tools

- `innova-bot` MCP server: 31 tools on port 7010
- Playwright MCP: browser automation
- Chrome DevTools MCP: inspection/debugging
- Oracle V3: knowledge base on port 47778

## Routing Rules

- `innomcp`, `mcp`, `sse`, `workspace`, `7010` → innova-bot
- `oracle`, `knowledge`, `learn`, `search` → Oracle V3
- `fleet`, `probe`, `doctor`, `status` → Mother Engine
- `maw`, `team`, `workspace` → MAW CLI
- Wide coordination → Antigravity (this agent)
- Deep implementation → Codex/ClaudeCode

## Verification

- `node mother.js test` — regression gate
- `node mother.js doctor` — health check
- `node eval/antigravity-probe.js` — Antigravity lane check
- `bash eval/body-check.sh` — full body integrity
