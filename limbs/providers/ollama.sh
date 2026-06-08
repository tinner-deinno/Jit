#!/usr/bin/env bash
# limbs/providers/ollama.sh — Provider adapter: MDES Ollama (gemma) over HTTP
#
# Contract:
#   available                         → exit 0 if reachable + token present
#   call <model_id> <system> <user>   → print completion to stdout
#
# Injected by gateway (limbs/llm.sh):
#   PROVIDER_API_KEY   — Bearer token ($OLLAMA_TOKEN)
#   PROVIDER_BASE_URL  — e.g. https://ollama.mdes-innova.online
#   PROVIDER_TIMEOUT   — seconds (default 90)
#
# NOTE: This is the gateway-facing adapter. The human-facing limbs/ollama.sh
#       (ask/think/create/translate) still exists for direct Thai-language use.

set -uo pipefail

BASE_URL="${PROVIDER_BASE_URL:-https://ollama.mdes-innova.online}"
TIMEOUT="${PROVIDER_TIMEOUT:-90}"
TOKEN="${PROVIDER_API_KEY:-${OLLAMA_TOKEN:-}}"

case "${1:-}" in
  available)
    [ -n "$TOKEN" ] || { echo "ollama: no token (set OLLAMA_TOKEN)" >&2; exit 1; }
    # Fast reachability probe — /api/version is cheap and unauthenticated.
    if curl -sf --max-time 6 "$BASE_URL/api/version" >/dev/null 2>&1; then
      exit 0
    fi
    # Some gateways require auth even on version; retry with bearer.
    if curl -sf --max-time 6 -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/version" >/dev/null 2>&1; then
      exit 0
    fi
    echo "ollama: $BASE_URL unreachable" >&2
    exit 1
    ;;

  call)
    MODEL="${2:?model required}"
    SYSTEM="${3:-}"
    USER_PROMPT="${4:-}"
    [ -n "$TOKEN" ] || { echo "ollama: no token" >&2; exit 1; }

    # Use the /api/chat endpoint so system + user roles are preserved.
    BODY="$(SYSTEM="$SYSTEM" USER_PROMPT="$USER_PROMPT" MODEL="$MODEL" python3 - <<'PY'
import json, os
print(json.dumps({
    "model": os.environ["MODEL"],
    "messages": [
        {"role": "system", "content": os.environ.get("SYSTEM", "")},
        {"role": "user",   "content": os.environ.get("USER_PROMPT", "")},
    ],
    "stream": False,
}))
PY
)"

    RESP="$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/chat" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      --data "$BODY" 2>/dev/null)"

    [ -n "$RESP" ] || { echo "ollama: empty response / timeout" >&2; exit 1; }

    OUT="$(printf '%s' "$RESP" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
# /api/chat → {"message":{"content":...}}; /api/generate → {"response":...}
msg = (d.get("message") or {}).get("content") or d.get("response") or ""
if not msg:
    sys.exit(1)
print(msg, end="")
' 2>/dev/null)"
    RC=$?

    if [ $RC -ne 0 ] || [ -z "$OUT" ]; then
      echo "ollama: could not parse response (model=$MODEL)" >&2
      exit 1
    fi
    printf '%s' "$OUT"
    ;;

  *)
    echo "Usage: ollama.sh {available|call <model> <system> <user>}" >&2
    exit 2
    ;;
esac
