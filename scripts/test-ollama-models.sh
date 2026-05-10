#!/usr/bin/env bash
# scripts/test-ollama-models.sh — ทดสอบ 4 MDES Ollama models + proxy
# ════════════════════════════════════════════════════════════════════
# ทดสอบ:
#   1. Direct Ollama API (4 models)
#   2. Proxy bridge (Anthropic format → Ollama)
#   3. Claude Code environment readiness
#
# Usage: bash scripts/test-ollama-models.sh [--proxy-only | --direct-only]
# ════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
PROXY_URL="http://127.0.0.1:${PROXY_PORT:-4321}"
MODE="${1:---all}"

PASS=0
FAIL=0

divider() { echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

# ─── Model definitions ───────────────────────────────────────────────
declare -A MODEL_PROMPTS=(
    ["gemma4:26b"]="สวัสดี ตอบในภาษาไทย 1 ประโยคสั้นๆ"
    ["gemma4:e4b"]="Hello, respond in 1 short English sentence"
    ["qwen2.5-coder:7b"]="print('hello world') — explain in 5 words"
    ["llama3.2:latest"]="Say: MDES online — nothing else"
)

# ─── Test 1: Direct Ollama API ────────────────────────────────────────
test_direct() {
    echo ""
    echo -e "${BOLD}🔬 Test 1: Direct MDES Ollama API${RESET}"
    divider

    if [ -z "$OLLAMA_TOKEN" ]; then
        warn "OLLAMA_TOKEN not set — direct tests may fail"
    fi

    for MODEL in "gemma4:26b" "gemma4:e4b" "qwen2.5-coder:7b" "llama3.2:latest"; do
        local PROMPT="${MODEL_PROMPTS[$MODEL]:-ping}"
        echo -n "  [${MODEL}] "

        local T0=$SECONDS
        local PAYLOAD
        PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'model': '${MODEL}',
    'messages': [{'role':'user','content':'${PROMPT}'}],
    'stream': False,
    'options': {'num_predict': 20}
}))
")
        local RESP
        RESP=$(curl -sf --max-time 45 \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${OLLAMA_TOKEN}" \
            --data "$PAYLOAD" \
            "${OLLAMA_BASE_URL}/api/chat" 2>/dev/null || echo "")

        local ELAPSED=$(( SECONDS - T0 ))

        if [ -n "$RESP" ]; then
            local CONTENT
            CONTENT=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',{}).get('content','?')[:60])" 2>/dev/null || echo "parse-error")
            echo -e "${GREEN}✓${RESET} [${ELAPSED}s] \"${CONTENT}\""
            ((PASS++)) || true
        else
            echo -e "${RED}✗${RESET} [${ELAPSED}s] no response"
            ((FAIL++)) || true
        fi
    done
    divider
}

# ─── Test 2: Via Proxy (Anthropic format) ────────────────────────────
test_proxy() {
    echo ""
    echo -e "${BOLD}🔬 Test 2: Anthropic→Ollama Proxy Bridge${RESET}"
    divider

    # Check proxy
    if ! curl -sf --max-time 3 "$PROXY_URL/health" >/dev/null 2>&1; then
        warn "Proxy not running at ${PROXY_URL} — skipping proxy tests"
        warn "Start with: bash minds/ollama-claude.sh proxy"
        return 0
    fi

    local PROXY_HEALTH
    PROXY_HEALTH=$(curl -sf --max-time 5 "$PROXY_URL/health" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'model={d.get(\"current_model\",\"?\")} rotations={d.get(\"rotations\",0)}')
" 2>/dev/null || echo "")
    ok "Proxy healthy: ${PROXY_HEALTH}"

    # Test Anthropic Messages API format via proxy
    local QUESTIONS=(
        "ตอบสั้นๆ: หัวใจของ AI คืออะไร"
        "Quick: what is 2+2"
        "One word: color of sky"
        "Thai: ดวงอาทิตย์คืออะไร"
    )

    local q_idx=0
    for QUESTION in "${QUESTIONS[@]}"; do
        local PAYLOAD
        PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'model': 'claude-3-sonnet',
    'max_tokens': 30,
    'messages': [{'role':'user','content':'${QUESTION}'}]
}))
")
        echo -n "  Q[$((q_idx+1))]: \"${QUESTION}\" → "

        local T0=$SECONDS
        local RESP
        RESP=$(curl -sf --max-time 90 \
            -H "Content-Type: application/json" \
            -H "x-api-key: mdes-ollama" \
            -H "anthropic-version: 2023-06-01" \
            --data "$PAYLOAD" \
            "${PROXY_URL}/v1/messages" 2>/dev/null || echo "")
        local ELAPSED=$(( SECONDS - T0 ))

        if [ -n "$RESP" ]; then
            local CONTENT
            CONTENT=$(echo "$RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d.get('content', [])
text = c[0].get('text','?')[:60] if c else '?'
model = d.get('model','?')
print(f'[{model}] \"{text}\"')
" 2>/dev/null || echo "parse-error")
            echo -e "${GREEN}✓${RESET} [${ELAPSED}s] ${CONTENT}"
            ((PASS++)) || true
        else
            echo -e "${RED}✗${RESET} [${ELAPSED}s] no response"
            ((FAIL++)) || true
        fi
        ((q_idx++)) || true
    done
    divider
}

# ─── Test 3: Claude Code readiness ───────────────────────────────────
test_claude_env() {
    echo ""
    echo -e "${BOLD}🔬 Test 3: Claude Code Environment Check${RESET}"
    divider

    # Check claude CLI
    echo -n "  claude CLI: "
    if command -v claude >/dev/null 2>&1; then
        local CLAUDE_VER
        CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "${GREEN}✓${RESET} ${CLAUDE_VER}"
        ((PASS++)) || true
    else
        echo -e "${RED}✗${RESET} not found"
        echo "    Install: npm install -g @anthropic-ai/claude-code"
        ((FAIL++)) || true
    fi

    # Check Python3
    echo -n "  python3: "
    if command -v python3 >/dev/null 2>&1; then
        local PY_VER
        PY_VER=$(python3 --version 2>&1)
        echo -e "${GREEN}✓${RESET} ${PY_VER}"
        ((PASS++)) || true
    else
        echo -e "${RED}✗${RESET} not found"
        ((FAIL++)) || true
    fi

    # Check OLLAMA_TOKEN
    echo -n "  OLLAMA_TOKEN: "
    if [ -n "$OLLAMA_TOKEN" ]; then
        echo -e "${GREEN}✓${RESET} set (${#OLLAMA_TOKEN} chars)"
        ((PASS++)) || true
    else
        echo -e "${RED}✗${RESET} not set — add to .env: OLLAMA_TOKEN=xxx"
        ((FAIL++)) || true
    fi

    # Check MDES Ollama endpoint
    echo -n "  MDES Ollama endpoint: "
    if curl -sf --max-time 10 "${OLLAMA_BASE_URL}/api/tags" \
        -H "Authorization: Bearer ${OLLAMA_TOKEN}" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${RESET} ${OLLAMA_BASE_URL}"
        ((PASS++)) || true
    else
        echo -e "${RED}✗${RESET} cannot reach ${OLLAMA_BASE_URL}"
        ((FAIL++)) || true
    fi

    # Show launch command
    echo ""
    echo -e "  ${YELLOW}Launch command:${RESET}"
    echo "    bash minds/ollama-claude.sh start"
    echo "  ${YELLOW}Or manually:${RESET}"
    echo "    bash minds/ollama-claude.sh proxy &"
    echo "    export ANTHROPIC_BASE_URL=http://127.0.0.1:${PROXY_PORT:-4321}"
    echo "    export ANTHROPIC_API_KEY=mdes-ollama"
    echo "    claude --dangerously-skip-permissions"
    divider
}

# ─── Summary ──────────────────────────────────────────────────────────
summary() {
    echo ""
    local TOTAL=$(( PASS + FAIL ))
    echo -e "${BOLD}📊 Test Summary: ${PASS}/${TOTAL} passed${RESET}"
    if [ "$FAIL" -eq 0 ]; then
        ok "All tests passed — system ready!"
    elif [ "$PASS" -gt 0 ]; then
        warn "${FAIL} test(s) failed — partial functionality"
    else
        err "All tests failed — check OLLAMA_TOKEN and network"
    fi
    echo ""
}

# ─── Main ──────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}🧪 MDES Ollama Model Test Suite${RESET}"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"

case "$MODE" in
    --proxy-only)
        test_proxy
        ;;
    --direct-only)
        test_direct
        ;;
    --env-only)
        test_claude_env
        ;;
    *)
        test_claude_env
        test_direct
        test_proxy
        ;;
esac

summary
