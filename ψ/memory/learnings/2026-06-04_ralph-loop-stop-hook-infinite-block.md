---
pattern: ralph-loop stop-hook blocked turn-end forever because it never honored stop_hook_active; fix = exit 0 when the raw input contains "stop_hook_active":true.
date: 2026-06-04
source: "user-directed fix: Jit"
concepts: [claude-code, hooks, ralph-loop, infinite-loop, stop-hook]
---

# Ralph-loop stop hook: infinite block loop (root cause + fix)

## Symptom
Every `Stop` re-blocked the turn and fed the same prompt back, with no exit
condition reachable — an unbreakable continuation loop.

## Root cause
`ralph-loop/hooks/stop-hook.sh` never checked `stop_hook_active`. Claude Code
sets `stop_hook_active: true` in the hook input when a stop is ITSELF a
continuation triggered by this hook. Without honoring it, the hook blocks
unconditionally whenever `.claude/ralph-loop.local.md` exists.

## Fix
Early in the hook (right after `HOOK_INPUT=$(cat)`), before the state-file check:

```bash
if [[ "$HOOK_INPUT" == *'"stop_hook_active":true'* ]] || [[ "$HOOK_INPUT" == *'"stop_hook_active": true'* ]]; then
  exit 0
fi
```

Applied to BOTH copies: the executing cache copy
(`~/.claude/plugins/cache/claude-plugins-official/ralph-loop/1.0.0/hooks/`) and
the marketplace source.

## Gotcha (why the first attempt failed)
First tried `jq_extract '.stop_hook_active'`. On a box without `jq`, the hook's
Node fallback does `process.stdout.write(v||'')` — and `process.stdout.write(true)`
THROWS on a boolean, so it returned `""` and the guard never fired. Matching the
raw JSON string is robust regardless of jq/node availability.

## To escape such a loop without editing the hook
Delete `.claude/ralph-loop.local.md` — the hook exits 0 when the state file is absent.
