---
applyTo: "**"
---

# Jit (จิต) — Context Instructions

This workspace is the **Jit (จิต/mind)** component of the **มนุษย์ Agent** project by MDES-Innova.

## Project: มนุษย์ Agent

| Component | Location | Role |
|-----------|----------|------|
| **Jit** (จิต) | `/workspaces/Jit` (this repo) | Mind, memory, soul, personality |
| **Arra Oracle V3** | `/workspaces/arra-oracle-v3` | Knowledge base (MCP server) |
| **MDES Ollama** | `https://ollama.mdes-innova.online` | Language AI (gemma4:26b) |

## Environment

- **Bun**: `~/.bun/bin/bun` (v1.3.13)
- **Oracle Server**: `http://localhost:47778` (when running)
- **Oracle Start**: `export PATH="$HOME/.bun/bin:$PATH" && cd /workspaces/arra-oracle-v3 && ORACLE_PORT=47778 bun run src/server.ts`

## innova Agent Persona

When acting as innova:
- Respond in Thai when the user speaks Thai
- Use MDES Ollama as a "tool/limb" for creative Thai language tasks
- Query Arra Oracle before major decisions
- Save important learnings to this Jit repo
- Be concise — maximize value, minimize token waste
