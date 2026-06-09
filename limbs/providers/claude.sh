#!/usr/bin/env bash
# limbs/providers/claude.sh — Provider adapter: Anthropic Claude (via claude CLI / CommandCode proxy)
#
# Contract (shared by every adapter in limbs/providers/):
#   available                         → exit 0 if this provider can serve a call now
#   call <model_id> <system> <user>   → print completion to stdout; non-zero exit on failure
#
# Config is injected by the gateway (limbs/llm.sh) via environment:
#   PROVIDER_API_KEY   — Anthropic key (here: $COMMANDCODE_API_KEY — burns CommandCode tokens)
#   PROVIDER_CLI       — CLI binary name (default: claude)
#   PROVIDER_BASE_URL  — optional ANTHROPIC_BASE_URL override
#   PROVIDER_TIMEOUT   — seconds (default 120)
#
# Run standalone for debugging:
#   PROVIDER_API_KEY=$COMMANDCODE_API_KEY bash claude.sh call claude-haiku-4-5-20251001 "You are helpful" "Say hi"

set -uo pipefail

CLI="${PROVIDER_CLI:-claude}"
TIMEOUT="${PROVIDER_TIMEOUT:-120}"

case "${1:-}" in
  available)
    command -v "$CLI" >/dev/null 2>&1 || { echo "claude: CLI '$CLI' not found" >&2; exit 1; }
    [ -n "${PROVIDER_API_KEY:-}" ] || { echo "claude: PROVIDER_API_KEY empty (set COMMANDCODE_API_KEY)" >&2; exit 1; }
    exit 0
    ;;

  call)
    MODEL="${2:?model required}"
    SYSTEM="${3:-}"
    USER_PROMPT="${4:-}"

    # When PROVIDER_BASE_URL is set (e.g. CommandCode proxy), use curl directly.
    # Otherwise fall back to the `claude` CLI (uses local subscription).
    if [ -n "${PROVIDER_BASE_URL:-}" ]; then
      [ -n "$PROVIDER_API_KEY" ] || { echo "claude: PROVIDER_API_KEY empty" >&2; exit 1; }

      # Build messages array — skip system if empty
      BODY="$(SYSTEM="$SYSTEM" USER_PROMPT="$USER_PROMPT" MODEL="$MODEL" python3 - <<'PY'
import json, os
msgs = []
sys_p = os.environ.get("SYSTEM", "")
if sys_p:
    msgs.append({"role": "system", "content": sys_p})
msgs.append({"role": "user", "content": os.environ.get("USER_PROMPT", "")})
print(json.dumps({"model": os.environ["MODEL"], "max_tokens": 4096, "messages": msgs}))
PY
)"

      RESP="$(printf '%s\n' "x-api-key: $PROVIDER_API_KEY" "anthropic-version: 2023-06-01" "content-type: application/json" | \
        curl -s --max-time "$TIMEOUT" "$PROVIDER_BASE_URL/messages" \
          -H @- --data "$BODY" 2>/dev/null)"

      [ -n "$RESP" ] || { echo "claude: empty response / timeout" >&2; exit 1; }

      OUT="$(printf '%s' "$RESP" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if "error" in d:
    sys.stderr.write("claude: " + str(d["error"].get("message", d["error"])) + "\n")
    sys.exit(1)
try:
    content = d.get("content", [])
    text = "".join(b.get("text", "") for b in content if b.get("type") == "text")
    print(text, end="")
    usage = d.get("usage", {})
    if usage:
        print("\n__USAGE__:" + json.dumps(usage), end="")
except Exception:
    sys.exit(1)
' 2>&1)"
      RC=$?

      if [ $RC -ne 0 ] || [ -z "$OUT" ]; then
        echo "claude: call failed (model=$MODEL) ${OUT:-}" >&2
        exit 1
      fi
      printf '%s' "$OUT"
      exit 0
    fi

    # Fallback path: use `claude` CLI (subscription mode)
    # claude -p takes a single prompt string; fold the system prompt in as a header.
    FULL_PROMPT="$(printf '%s\n\n---\n\n%s' "$SYSTEM" "$USER_PROMPT")"

    declare -a ENVV=( "ANTHROPIC_API_KEY=$PROVIDER_API_KEY" )
    [ -n "${PROVIDER_BASE_URL:-}" ] && ENVV+=( "ANTHROPIC_BASE_URL=$PROVIDER_BASE_URL" )

    RESULT="$(timeout "$TIMEOUT" env "${ENVV[@]}" \
      "$CLI" -p --model "$MODEL" "$FULL_PROMPT" 2>/dev/null)"
    RC=$?

    if [ $RC -ne 0 ] || [ -z "$RESULT" ]; then
      echo "claude: call failed (exit=$RC model=$MODEL)" >&2
      exit 1
    fi
    printf '%s' "$RESULT"
    ;;

  *)
    echo "Usage: claude.sh {available|call <model> <system> <user>}" >&2
    exit 2
    ;;
esac
