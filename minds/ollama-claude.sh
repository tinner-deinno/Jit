#!/usr/bin/env bash
# minds/ollama-claude.sh — JARVIS: Claude Code + MDES Ollama Autonomous Engine
# ═══════════════════════════════════════════════════════════════════════
#
# เรียกใช้ Claude Code ด้วย MDES Ollama เป็น custom AI backend
# มี 4 models หมุนเวียน + JARVIS loop ทำงานตลอดไม่หยุด
#
# Usage:
#   bash minds/ollama-claude.sh start           — เริ่ม proxy + claude
#   bash minds/ollama-claude.sh proxy           — แค่ start proxy
#   bash minds/ollama-claude.sh test-models     — ทดสอบ 4 models
#   bash minds/ollama-claude.sh jarvis          — JARVIS loop (ไม่หยุด)
#   bash minds/ollama-claude.sh status          — ดูสถานะ
#   bash minds/ollama-claude.sh stop            — หยุด proxy
# ═══════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

# Load env
if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

# ─── Config ────────────────────────────────────────────────────────────
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
PROXY_PORT="${PROXY_PORT:-4321}"
PROXY_URL="http://127.0.0.1:${PROXY_PORT}"
PROXY_PID_FILE="/tmp/ollama-proxy.pid"
PROXY_LOG="/tmp/ollama-proxy.log"
JARVIS_LOG="/tmp/jarvis-claude.log"
JARVIS_STATE="/tmp/jarvis-claude-state.json"

# 4 Models in rotation
MODEL_POOL=(
    "gemma4:26b"
    "gemma4:e4b"
    "qwen2.5-coder:7b"
    "llama3.2:latest"
)

CMD="${1:-help}"
shift || true

# ─── Helpers ────────────────────────────────────────────────────────────
proxy_running() {
    [ -f "$PROXY_PID_FILE" ] && kill -0 "$(cat "$PROXY_PID_FILE")" 2>/dev/null
}

proxy_health() {
    curl -sf --max-time 5 "$PROXY_URL/health" 2>/dev/null
}

ollama_ping() {
    local MODEL="${1:-gemma4:e4b}"
    local PAYLOAD
    PAYLOAD=$(python3 -c "import json; print(json.dumps({'model':'${MODEL}','messages':[{'role':'user','content':'ping — ตอบสั้นมาก 1 คำ'}],'stream':False,'options':{'num_predict':8}}))")
    local RESP
    RESP=$(curl -sf --max-time 30 \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${OLLAMA_TOKEN}" \
        --data "$PAYLOAD" \
        "${OLLAMA_BASE_URL}/api/chat" 2>/dev/null)
    [ -n "$RESP" ] && echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',{}).get('content','?'))" 2>/dev/null
}

# ─── CMD: proxy ────────────────────────────────────────────────────────
start_proxy() {
    if proxy_running; then
        warn "Proxy already running (PID $(cat $PROXY_PID_FILE))"
        return 0
    fi
    step "Starting MDES Ollama proxy on port ${PROXY_PORT}..."
    OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
    OLLAMA_TOKEN="$OLLAMA_TOKEN" \
    PROXY_PORT="$PROXY_PORT" \
    nohup python3 "$JIT_ROOT/scripts/ollama-proxy.py" > "$PROXY_LOG" 2>&1 &
    echo $! > "$PROXY_PID_FILE"
    sleep 2
    if proxy_health >/dev/null 2>&1; then
        ok "Proxy started (PID $(cat $PROXY_PID_FILE)) — $PROXY_URL"
    else
        err "Proxy failed to start — check $PROXY_LOG"
        return 1
    fi
}

stop_proxy() {
    if proxy_running; then
        kill "$(cat "$PROXY_PID_FILE")" 2>/dev/null
        rm -f "$PROXY_PID_FILE"
        ok "Proxy stopped"
    else
        warn "Proxy not running"
    fi
}

# ─── CMD: test-models ──────────────────────────────────────────────────
test_models() {
    echo ""
    step "🧪 Testing 4 MDES Ollama models..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local PASSED=0
    local FAILED=0

    for MODEL in "${MODEL_POOL[@]}"; do
        echo -n "  Testing ${MODEL}... "
        local T0=$SECONDS
        local RESP
        RESP=$(ollama_ping "$MODEL" 2>/dev/null || echo "")
        local ELAPSED=$(( SECONDS - T0 ))

        if [ -n "$RESP" ]; then
            echo -e "${GREEN}✓${RESET} [${ELAPSED}s] → \"${RESP}\""
            ((PASSED++)) || true
        else
            echo -e "${RED}✗${RESET} [${ELAPSED}s] timeout/error"
            ((FAILED++)) || true
        fi
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ "$PASSED" -gt 0 ]; then
        ok "$PASSED/${#MODEL_POOL[@]} models responding"
    else
        err "No models responding — check OLLAMA_TOKEN and network"
        return 1
    fi
}

# ─── CMD: start (proxy + claude) ───────────────────────────────────────
start_claude_with_ollama() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║  🤖 Claude Code + MDES Ollama               ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
    echo ""

    # 1. Start proxy
    start_proxy || return 1

    # 2. Quick model health check
    step "Verifying MDES Ollama reachability..."
    RESP=$(ollama_ping "gemma4:e4b" 2>/dev/null || echo "")
    if [ -z "$RESP" ]; then
        warn "gemma4:e4b not responding — will try others via proxy rotation"
    else
        ok "MDES Ollama online: \"${RESP}\""
    fi

    echo ""
    echo -e "${YELLOW}${BOLD}🚀 Launching Claude Code with MDES Ollama backend...${RESET}"
    echo "   ANTHROPIC_BASE_URL=${PROXY_URL}"
    echo "   Command: claude --dangerously-skip-permissions $*"
    echo ""

    # 3. Run claude with proxy
    export ANTHROPIC_BASE_URL="$PROXY_URL"
    export ANTHROPIC_API_KEY="mdes-ollama"

    if command -v claude >/dev/null 2>&1; then
        claude --dangerously-skip-permissions "$@"
    else
        warn "claude CLI not found — showing env for manual launch:"
        echo ""
        echo "  export ANTHROPIC_BASE_URL=${PROXY_URL}"
        echo "  export ANTHROPIC_API_KEY=mdes-ollama"
        echo "  claude --dangerously-skip-permissions"
        echo ""
    fi
}

# ─── CMD: jarvis — Autonomous JARVIS loop ──────────────────────────────
jarvis_loop() {
    local TASK="${1:-dev}"   # default task type
    local CYCLE=0
    local JARVIS_START=$SECONDS

    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║  🤖 JARVIS — Claude Code + MDES Ollama Daemon        ║${RESET}"
    echo -e "${CYAN}${BOLD}║  Mode: autonomous | Never stops                       ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Ensure proxy is running
    start_proxy || { err "Cannot start proxy — abort"; return 1; }

    # Export env
    export ANTHROPIC_BASE_URL="$PROXY_URL"
    export ANTHROPIC_API_KEY="mdes-ollama"

    log_jarvis() {
        local MSG="$1"
        echo "[$(date '+%Y-%m-%dT%H:%M:%S')] JARVIS #${CYCLE}: ${MSG}" | tee -a "$JARVIS_LOG"
    }

    save_state() {
        python3 - << PYEOF
import json, time
data = {
  "status": "running",
  "cycle": ${CYCLE},
  "uptime_secs": $((SECONDS - JARVIS_START)),
  "proxy_url": "${PROXY_URL}",
  "proxy_port": ${PROXY_PORT},
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "models": ["gemma4:26b","gemma4:e4b","qwen2.5-coder:7b","llama3.2:latest"],
  "task_mode": "${TASK}",
}
with open("${JARVIS_STATE}", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
    }

    # ── JARVIS Main Loop ────────────────────────────────────────────
    while true; do
        ((CYCLE++)) || true
        log_jarvis "⚡ Cycle ${CYCLE} — checking system"

        # 1. Keep proxy alive
        if ! proxy_running; then
            log_jarvis "🔴 Proxy died — restarting"
            start_proxy
        fi

        # 2. Check MDES Ollama
        OLLAMA_OK=false
        for MODEL in "${MODEL_POOL[@]}"; do
            RESP=$(ollama_ping "$MODEL" 2>/dev/null || echo "")
            if [ -n "$RESP" ]; then
                log_jarvis "✅ Ollama online: ${MODEL} → \"${RESP}\""
                OLLAMA_OK=true
                break
            fi
        done

        # 3. Send work via bus if Ollama is online
        if [ "$OLLAMA_OK" = "true" ]; then
            # Notify agents that Ollama backend is available
            if [ -d "$JIT_ROOT/organs" ]; then
                bash "$JIT_ROOT/organs/mouth.sh" tell innova \
                    "task:ollama-backend-ready" \
                    "JARVIS cycle ${CYCLE}: MDES Ollama online. ANTHROPIC_BASE_URL=${PROXY_URL}. Ready for autonomous dev work." \
                    2>/dev/null || true
            fi

            log_jarvis "📬 Notified innova: Ollama backend ready (cycle ${CYCLE})"
        else
            log_jarvis "⚠️  All Ollama models offline — waiting 60s before retry"
            sleep 60
            continue
        fi

        # 4. Save state
        save_state 2>/dev/null || true

        # 5. Send heartbeat pulse
        if [ -f "$JIT_ROOT/scripts/heartbeat.sh" ]; then
            bash "$JIT_ROOT/scripts/heartbeat.sh" once 2>/dev/null || true
        fi

        log_jarvis "💤 Sleeping 120s before next cycle"
        sleep 120
    done
}

# ─── CMD: status ────────────────────────────────────────────────────────
show_status() {
    echo ""
    step "🔍 JARVIS / Ollama Bridge Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Proxy status
    if proxy_running; then
        ok "Proxy running (PID $(cat $PROXY_PID_FILE)) → ${PROXY_URL}"
        HEALTH=$(proxy_health 2>/dev/null || echo "{}")
        if [ -n "$HEALTH" ]; then
            echo "$HEALTH" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  model: {d.get(\"current_model\",\"?\")}')
print(f'  requests: {d.get(\"requests\",0)} | errors: {d.get(\"errors\",0)} | rotations: {d.get(\"rotations\",0)}')
print(f'  uptime: {d.get(\"uptime_secs\",0)}s')
" 2>/dev/null || true
        fi
    else
        warn "Proxy not running"
    fi

    # JARVIS state
    if [ -f "$JARVIS_STATE" ]; then
        echo ""
        step "JARVIS state:"
        python3 -c "import json; d=json.load(open('${JARVIS_STATE}')); print(json.dumps(d, indent=2, ensure_ascii=False))" 2>/dev/null || true
    fi

    # MDES Ollama
    echo ""
    step "MDES Ollama reachability:"
    for MODEL in "${MODEL_POOL[@]}"; do
        echo -n "  ${MODEL}: "
        RESP=$(ollama_ping "$MODEL" 2>/dev/null || echo "")
        if [ -n "$RESP" ]; then
            echo -e "${GREEN}✓${RESET} online"
        else
            echo -e "${RED}✗${RESET} offline"
        fi
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  export ANTHROPIC_BASE_URL=${PROXY_URL}"
    echo "  export ANTHROPIC_API_KEY=mdes-ollama"
    echo "  claude --dangerously-skip-permissions"
    echo ""
}

# ─── Main dispatch ────────────────────────────────────────────────────
case "$CMD" in
    proxy)         start_proxy ;;
    stop)          stop_proxy ;;
    test-models)   test_models ;;
    start)         start_claude_with_ollama "$@" ;;
    jarvis)        jarvis_loop "${1:-dev}" ;;
    status)        show_status ;;
    help|*)
        echo ""
        echo "minds/ollama-claude.sh — Claude Code + MDES Ollama"
        echo ""
        echo "Commands:"
        echo "  proxy          Start Anthropic↔Ollama proxy (port ${PROXY_PORT})"
        echo "  stop           Stop proxy"
        echo "  test-models    Test all 4 models"
        echo "  start [args]   Start proxy + claude --dangerously-skip-permissions [args]"
        echo "  jarvis         JARVIS autonomous loop (never stops)"
        echo "  status         Show proxy + model health"
        echo ""
        echo "Models: ${MODEL_POOL[*]}"
        echo "Proxy:  ${PROXY_URL}"
        echo ""
        ;;
esac
