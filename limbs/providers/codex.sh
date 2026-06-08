#!/usr/bin/env bash
# limbs/providers/codex.sh — Provider adapter: Codex CLI ("codecommand") non-interactive
#
# Contract:
#   available                         → exit 0 if the codex CLI is installed + key present
#   call <model_id> <system> <user>   → print completion to stdout
#
# Injected by gateway (limbs/llm.sh):
#   PROVIDER_API_KEY   — $OPENAI_API_KEY (codex authenticates via OpenAI)
#   PROVIDER_CLI       — CLI binary name (default: codex)
#   PROVIDER_TIMEOUT   — seconds (default 180)
#
# If the codex CLI is not installed, `available` exits non-zero and the gateway
# transparently falls through to the next provider in the agent's fallback chain.
# Install: npm i -g @openai/codex  (see docs/multi-provider-gateway.md)

set -uo pipefail

CLI="${PROVIDER_CLI:-codex}"
TIMEOUT="${PROVIDER_TIMEOUT:-180}"
KEY="${PROVIDER_API_KEY:-${OPENAI_API_KEY:-}}"

case "${1:-}" in
  available)
    command -v "$CLI" >/dev/null 2>&1 || { echo "codex: CLI '$CLI' not installed (npm i -g @openai/codex)" >&2; exit 1; }
    [ -n "$KEY" ] || { echo "codex: no OPENAI_API_KEY" >&2; exit 1; }
    exit 0
    ;;

  call)
    MODEL="${2:?model required}"
    SYSTEM="${3:-}"
    USER_PROMPT="${4:-}"
    command -v "$CLI" >/dev/null 2>&1 || { echo "codex: CLI '$CLI' not installed" >&2; exit 1; }

    FULL_PROMPT="$(printf '%s\n\n---\n\n%s' "$SYSTEM" "$USER_PROMPT")"

    # `codex exec` runs a single non-interactive turn and prints the result.
    RESULT="$(timeout "$TIMEOUT" env "OPENAI_API_KEY=$KEY" \
      "$CLI" exec --model "$MODEL" "$FULL_PROMPT" 2>/dev/null)"
    RC=$?

    if [ $RC -ne 0 ] || [ -z "$RESULT" ]; then
      echo "codex: call failed (exit=$RC model=$MODEL)" >&2
      exit 1
    fi
    printf '%s' "$RESULT"
    ;;

  *)
    echo "Usage: codex.sh {available|call <model> <system> <user>}" >&2
    exit 2
    ;;
esac
