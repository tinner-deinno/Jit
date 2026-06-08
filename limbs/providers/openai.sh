#!/usr/bin/env bash
# limbs/providers/openai.sh — Provider adapter: OpenAI (GPT) / OpenAI-compatible HTTP API
#
# Contract:
#   available                         → exit 0 if key present + endpoint reachable
#   call <model_id> <system> <user>   → print completion to stdout
#
# Injected by gateway (limbs/llm.sh):
#   PROVIDER_API_KEY   — $OPENAI_API_KEY
#   PROVIDER_BASE_URL  — default https://api.openai.com/v1 (override for Azure / local / OpenRouter)
#   PROVIDER_TIMEOUT   — seconds (default 120)
#
# Works with any OpenAI-compatible /chat/completions endpoint (OpenRouter, vLLM,
# LM Studio, Together, etc.) by pointing PROVIDER_BASE_URL at it.

set -uo pipefail

BASE_URL="${PROVIDER_BASE_URL:-https://api.openai.com/v1}"
TIMEOUT="${PROVIDER_TIMEOUT:-120}"
KEY="${PROVIDER_API_KEY:-${OPENAI_API_KEY:-}}"

case "${1:-}" in
  available)
    [ -n "$KEY" ] || { echo "openai: no API key (set OPENAI_API_KEY)" >&2; exit 1; }
    if curl -sf --max-time 6 -H "Authorization: Bearer $KEY" "$BASE_URL/models" >/dev/null 2>&1; then
      exit 0
    fi
    echo "openai: $BASE_URL unreachable or key rejected" >&2
    exit 1
    ;;

  call)
    MODEL="${2:?model required}"
    SYSTEM="${3:-}"
    USER_PROMPT="${4:-}"
    [ -n "$KEY" ] || { echo "openai: no API key" >&2; exit 1; }

    BODY="$(SYSTEM="$SYSTEM" USER_PROMPT="$USER_PROMPT" MODEL="$MODEL" python3 - <<'PY'
import json, os
print(json.dumps({
    "model": os.environ["MODEL"],
    "messages": [
        {"role": "system", "content": os.environ.get("SYSTEM", "")},
        {"role": "user",   "content": os.environ.get("USER_PROMPT", "")},
    ],
}))
PY
)"

    RESP="$(curl -s --max-time "$TIMEOUT" "$BASE_URL/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $KEY" \
      --data "$BODY" 2>/dev/null)"

    [ -n "$RESP" ] || { echo "openai: empty response / timeout" >&2; exit 1; }

    OUT="$(printf '%s' "$RESP" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if "error" in d:
    sys.stderr.write("openai: " + str(d["error"].get("message", d["error"])) + "\n")
    sys.exit(1)
try:
    print(d["choices"][0]["message"]["content"], end="")
except Exception:
    sys.exit(1)
' 2>&1)"
    RC=$?

    if [ $RC -ne 0 ] || [ -z "$OUT" ]; then
      echo "openai: call failed (model=$MODEL) ${OUT:-}" >&2
      exit 1
    fi
    printf '%s' "$OUT"
    ;;

  *)
    echo "Usage: openai.sh {available|call <model> <system> <user>}" >&2
    exit 2
    ;;
esac
