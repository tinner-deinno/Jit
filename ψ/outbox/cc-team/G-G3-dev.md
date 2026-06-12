<!-- cc-team deliverable
 group: G (Antigravity (agy) bridge: Node wrapper, bash limb, Claude Code skill, fusion patterns doc)
 member: G3 role=dev model=zai-org/GLM-5.1
 finish_reason: stop | tokens: {"prompt_tokens":419,"completion_tokens":2015,"total_tokens":2434,"prompt_tokens_details":{"cached_tokens":3,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1163,"reasoning_tokens_estimated":true,"image_tokens":0},"cache_creation_input_tokens":0} | 41s
 generated: 2026-06-12T17:53:18.120Z -->
---
name: antigravity
description: Dispatch tasks to Google Antigravity CLI (agy) — Gemini 3 models via Google AI Pro. Use when user says antigravity, agy, gemini, ask google, second opinion from gemini, or wants long-context/multimodal analysis or parallel heavy execution outside Claude. Do NOT trigger for CommandCode tasks (use cc-team) or Ollama Thai tasks (use limbs/ollama.sh).
---

# Antigravity

## Quick Reference

| Invocation | Purpose |
|---|---|
| `node scripts/agy-bridge.js --prompt "..."` | Basic prompt |
| `node scripts/agy-bridge.js --prompt "..." --json` | Structured JSON output |
| `node scripts/agy-bridge.js --model gemini-3-flash --prompt "..."` | Explicit model selection |
| `node scripts/agy-bridge.js --skip-permissions --cwd <repo>` | Unattended execution in repo |
| `node scripts/agy-bridge.js --models` | List available models |
| `bash limbs/antigravity.sh ask "..."` | Quick one-shot question |
| `bash limbs/antigravity.sh think "..."` | Deep reasoning request |
| `bash limbs/antigravity.sh code "..."` | Code generation task |
| `bash limbs/antigravity.sh models` | List models via wrapper |
| `bash limbs/antigravity.sh status` | Check auth & quota status |

## Model Selection

| Model | Use When | Notes |
|---|---|---|
| `gemini-3-flash` | Fast/cheap tasks — **default choice** | Lowest cost, highest speed |
| `gemini-3-pro` | Deep reasoning, complex analysis | Slower, higher quality |
| `gemini-3.1-pro` | Most demanding reasoning tasks | Premium tier, use sparingly |

> **Quota: 1,500 req/day** shared across Google AI Pro pool. Prefer `gemini-3-flash` by default to conserve quota for when you truly need pro.

## Patterns

### Second Opinion
**When:** Verify a Claude claim or get an independent take on a conclusion.
```bash
bash limbs/antigravity.sh ask "Is this assertion correct: <claim>? Cite sources."
```

### Long-Context Reader
**When:** Summarize or analyze a large file/diff that exceeds Claude's context window.
```bash
cat bigfile.py | node scripts/agy-bridge.js --model gemini-3-flash --prompt "Summarize this file"
# or with directory context:
node scripts/agy-bridge.js --add-dir ./src --prompt "Review the architecture"
```

### Parallel Specialist
**When:** Offload heavy work to a separate git worktree while Claude orchestrates the main tree.
```bash
cd $(git worktree add ../antigravity-wt HEAD 2>&1 | awk '{print $NF}') && \
node scripts/agy-bridge.js --skip-permissions --cwd . --prompt "Refactor module X"
```

### CC-Fusion
**When:** CommandCode generates code cheaply, agy reviews with fresh eyes, Claude arbitrates disagreements.
```bash
bash limbs/antigravity.sh code "Review this generated code for correctness and style: <code>"
```

## Safety Rules

1. **Never use `--skip-permissions` outside an isolated git worktree.** It grants unrestricted file-system write access — always sandbox first.
2. **Quota burn warning.** Background chatter and repeated calls count against the 1,500 req/day pool. Batch prompts when possible; avoid idle polling loops.
3. **First run requires browser auth by a human.** If agy is unauthenticated, suggest the user type: `! agy auth` in their terminal.
4. **Windows-safe paths.** Use `%TEMP%` or project-relative paths instead of `/tmp`. Never assume POSIX-only absolute paths exist.
