#!/usr/bin/env bash
# minds/jit-life.sh — Master JARVIS: ชีวิตอัตโนมัติของ Jit (จิต)
# ════════════════════════════════════════════════════════════════════
# ระบบชีวิตครบวงจร:
#   ♥  heartbeat daemon
#   🤖 MDES Ollama proxy (Claude Code backend)
#   🔌 MCP realtime loop (innova-bot)
#   💬 Discord reporter
#   🔍 Memory sweep
#   🧠 Agent autonomy bus router
#   📡 Jit bus message processor
#
# Loop ทุก LIFE_CYCLE_SECS วินาที — ไม่หยุด
#
# Usage:
#   bash minds/jit-life.sh            — เริ่ม JIT LIFE
#   bash minds/jit-life.sh status     — ดูสถานะทั้งหมด
#   bash minds/jit-life.sh stop       — หยุดทุก daemon
#   bash minds/jit-life.sh discord    — ส่ง status ไป Discord
#   bash minds/jit-life.sh sweep      — sweep memory
# ════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

# ─── Config ────────────────────────────────────────────────────────────
LIFE_CYCLE_SECS="${LIFE_CYCLE_SECS:-120}"      # main loop interval
DISCORD_REPORT_EVERY="${DISCORD_REPORT_EVERY:-10}"  # cycles between Discord reports
MEMORY_SWEEP_EVERY="${MEMORY_SWEEP_EVERY:-30}"      # cycles between memory sweeps
ORACLE_LEARN_EVERY="${ORACLE_LEARN_EVERY:-60}"      # cycles between oracle learn

LIFE_LOG="/tmp/jit-life-$(date +%Y%m%d).log"
LIFE_STATE="/tmp/jit-life-state.json"
LIFE_PID_FILE="/tmp/jit-life.pid"

OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
DISCORD_TOKEN="${DISCORD_TOKEN:-}"
MCP_PORT="${MCP_PORT:-7010}"
ORACLE_PORT="${ORACLE_PORT:-47778}"

CMD="${1:-start}"
shift || true

# ─── Helpers ────────────────────────────────────────────────────────────
log_life() {
    local MSG="$1"
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] LIFE: $MSG" | tee -a "$LIFE_LOG"
}

life_running() {
    [ -f "$LIFE_PID_FILE" ] && kill -0 "$(cat "$LIFE_PID_FILE")" 2>/dev/null
}

service_status() {
    local NAME="$1" URL="$2"
    if curl -sf --max-time 5 "$URL" >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
    fi
}

# ─── Start/check all sub-daemons ──────────────────────────────────────
ensure_heartbeat() {
    if ! bash "$JIT_ROOT/scripts/heartbeat.sh" status 2>/dev/null | grep -qiE "running|กำลังรัน"; then
        log_life "🔴 heartbeat down — starting"
        bash "$JIT_ROOT/scripts/heartbeat.sh" start 2>/dev/null || true
    fi
}

ensure_multi_proxy() {
    if ! curl -sf --max-time 3 "http://127.0.0.1:4322/health" >/dev/null 2>&1; then
        log_life "🔴 Multi-proxy down — starting (OpenAI+Copilot+Ollama)"
        OLLAMA_TOKEN="$OLLAMA_TOKEN" \
        MULTI_PROXY_PORT=4322 \
        nohup python3 "$JIT_ROOT/scripts/multi-proxy.py" \
            > /tmp/multi-proxy.log 2>&1 &
        echo $! > /tmp/multi-proxy.pid
        sleep 2
    fi
}

ensure_ollama_proxy() {
    if ! curl -sf --max-time 3 "http://127.0.0.1:4321/health" >/dev/null 2>&1; then
        log_life "🔴 Ollama proxy down — starting"
        OLLAMA_TOKEN="$OLLAMA_TOKEN" \
        PROXY_PORT=4321 \
        nohup python3 "$JIT_ROOT/scripts/ollama-proxy.py" \
            > /tmp/ollama-proxy.log 2>&1 &
        echo $! > /tmp/ollama-proxy.pid
        sleep 2
    fi
}

ensure_mcp_loop() {
    if [ -f "/tmp/mcp-loop.pid" ] && kill -0 "$(cat /tmp/mcp-loop.pid)" 2>/dev/null; then
        return 0
    fi
    log_life "🔴 MCP loop down — starting"
    bash "$JIT_ROOT/scripts/mcp-loop.sh" start 2>/dev/null || true
}

ensure_agent_autonomy() {
    if [ -f "/tmp/agent-autonomy.pid" ] && kill -0 "$(cat /tmp/agent-autonomy.pid)" 2>/dev/null; then
        return 0
    fi
    log_life "🔴 Agent autonomy down — starting"
    bash "$JIT_ROOT/minds/agent-autonomy.sh" start 2>/dev/null || true
}

ensure_hermes_discord() {
    # Check if Discord bot is running (via PM2 or node process)
    if command -v pm2 >/dev/null 2>&1; then
        if ! pm2 list 2>/dev/null | grep -q "hermes-discord"; then
            log_life "🔴 hermes-discord (PM2) down — starting"
            pm2 start "$JIT_ROOT/hermes-discord/ecosystem.config.js" 2>/dev/null || true
        fi
    else
        # Check for bare node process
        if ! pgrep -f "hermes-discord/bot.js" >/dev/null 2>&1; then
            if [ -n "$DISCORD_TOKEN" ] && [ -d "$JIT_ROOT/hermes-discord/node_modules" ]; then
                log_life "🔴 hermes-discord (bare) down — starting"
                nohup node "$JIT_ROOT/hermes-discord/bot.js" \
                    > /tmp/hermes-discord.log 2>&1 &
                log_life "Started hermes-discord (PID $!)"
            else
                log_life "⚠️ hermes-discord: no DISCORD_TOKEN or node_modules — skip"
            fi
        fi
    fi
}

# ─── Send Discord report ───────────────────────────────────────────────
send_discord_report() {
    local CYCLE="$1"
    local UPTIME_SECS="$2"

    # Collect status
    local OLLAMA_S MCP_S ORACLE_S HB_S
    OLLAMA_S=$(service_status "ollama" "https://ollama.mdes-innova.online/api/tags" 2>/dev/null || echo "?")
    MCP_S=$(service_status "mcp" "http://127.0.0.1:${MCP_PORT}/health" 2>/dev/null || echo "?")
    ORACLE_S=$(service_status "oracle" "http://127.0.0.1:${ORACLE_PORT}/api/health" 2>/dev/null || echo "?")
    HB_S=$([ -f /tmp/innova-heartbeat.pid ] && kill -0 "$(cat /tmp/innova-heartbeat.pid)" 2>/dev/null && echo "✅" || echo "❌")

    bash "$JIT_ROOT/scripts/discord-reporter.sh" heartbeat \
        "$CYCLE" "$UPTIME_SECS" \
        2>/dev/null || log_life "Discord report failed (no config?)"
}

# ─── Process Jit bus messages ─────────────────────────────────────────
process_bus_messages() {
    local JIT_INBOX="/tmp/manusat-bus/jit"
    mkdir -p "$JIT_INBOX"

    local MSG_COUNT=0
    for MSG_FILE in "$JIT_INBOX"/*.msg; do
        [ -f "$MSG_FILE" ] || continue
        ((MSG_COUNT++)) || true

        local FROM SUBJECT BODY
        FROM=$(grep -m1 '^from:' "$MSG_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "?")
        SUBJECT=$(grep -m1 '^subject:' "$MSG_FILE" 2>/dev/null | cut -d: -f2- | sed 's/^ //' || echo "")
        BODY=$(awk '/^---$/{found=1;next} found{print}' "$MSG_FILE" 2>/dev/null || echo "")

        log_life "📬 msg from:${FROM} subject:${SUBJECT:0:60}"

        # Route based on subject prefix
        local PREFIX
        PREFIX=$(echo "$SUBJECT" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
        case "$PREFIX" in
            report)
                # Forward to Discord
                local MSG_TXT="📋 **Report from ${FROM}**\n${SUBJECT}\n${BODY:0:400}"
                bash "$JIT_ROOT/scripts/discord-reporter.sh" send "$MSG_TXT" 2>/dev/null || true
                ;;
            alert)
                bash "$JIT_ROOT/scripts/discord-reporter.sh" alert "${SUBJECT}: ${BODY:0:200}" 2>/dev/null || true
                ;;
        esac

        # Archive processed message
        mv "$MSG_FILE" "${MSG_FILE%.msg}.done" 2>/dev/null || rm -f "$MSG_FILE"
    done

    [ "$MSG_COUNT" -gt 0 ] && log_life "Processed ${MSG_COUNT} bus messages"
}

# ─── Save life state ───────────────────────────────────────────────────
save_life_state() {
    local CYCLE="$1"
    local UPTIME="$2"

    python3 - << PYEOF
import json, os
data = {
    "status": "alive",
    "cycle": ${CYCLE},
    "uptime_secs": ${UPTIME},
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "node": "$(hostname 2>/dev/null || echo '?')",
    "agent": "innova",
    "services": {
        "heartbeat": os.path.exists("/tmp/innova-heartbeat.pid"),
        "ollama_proxy": os.path.exists("/tmp/ollama-proxy.pid"),
        "mcp_loop": os.path.exists("/tmp/mcp-loop.pid"),
        "agent_autonomy": os.path.exists("/tmp/agent-autonomy.pid"),
    },
    "life_cycle_secs": ${LIFE_CYCLE_SECS},
}
with open("${LIFE_STATE}", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
}

# ─── CMD: start — Main life loop ───────────────────────────────────────
start_life() {
    if life_running; then
        warn "JIT-LIFE already running (PID $(cat $LIFE_PID_FILE))"
        return 0
    fi

    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║  🧠 JIT-LIFE — Autonomous Life System (จิตมีชีวิต)        ║${RESET}"
    echo -e "${CYAN}${BOLD}║  มนุษย์ Agent | $(date '+%Y-%m-%d %H:%M:%S')                  ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    echo $$ > "$LIFE_PID_FILE"

    CYCLE=0
    LIFE_START=$SECONDS

    log_life "🌅 JIT-LIFE started (PID $$)"

    # Initial Discord announcement
    bash "$JIT_ROOT/scripts/discord-reporter.sh" send \
        "🌅 **innova (จิต) ตื่นขึ้น** — JIT-LIFE เริ่มทำงาน\n$(date '+%Y-%m-%d %H:%M:%S')\nNode: $(hostname 2>/dev/null || echo '?')\nCycle: ${LIFE_CYCLE_SECS}s loop" \
        2>/dev/null || true

    # ── Main Loop ──────────────────────────────────────────────────
    while true; do
        ((CYCLE++)) || true
        local UPTIME=$(( SECONDS - LIFE_START ))

        log_life "⚡ Cycle ${CYCLE} | Uptime ${UPTIME}s"

        # 1. Ensure all sub-services alive
        ensure_multi_proxy 2>/dev/null || true
        ensure_ollama_proxy 2>/dev/null || true
        ensure_heartbeat 2>/dev/null || true
        ensure_mcp_loop 2>/dev/null || true
        ensure_agent_autonomy 2>/dev/null || true
        ensure_hermes_discord 2>/dev/null || true

        # 2. Process Jit bus messages
        process_bus_messages 2>/dev/null || true

        # 3. Discord report (every N cycles)
        if (( CYCLE % DISCORD_REPORT_EVERY == 0 )); then
            send_discord_report "$CYCLE" "$UPTIME" 2>/dev/null || true
        fi

        # 4. Memory sweep (every N cycles)
        if (( CYCLE % MEMORY_SWEEP_EVERY == 0 )); then
            log_life "🔍 Running memory sweep..."
            bash "$JIT_ROOT/scripts/memory-sweep.sh" full >> "$LIFE_LOG" 2>&1 || true
        fi

        # 5. Oracle learn (every N cycles)
        if (( CYCLE % ORACLE_LEARN_EVERY == 0 )); then
            log_life "📚 Learning to Oracle..."
            bash "$JIT_ROOT/scripts/memory-sweep.sh" learn >> "$LIFE_LOG" 2>&1 || true
        fi

        # 6. Save life state
        save_life_state "$CYCLE" "$UPTIME" 2>/dev/null || true

        # 7. Notify innova via bus
        if [ -f "$JIT_ROOT/organs/mouth.sh" ]; then
            bash "$JIT_ROOT/organs/mouth.sh" tell innova \
                "report:jit-life-cycle" \
                "JIT-LIFE cycle ${CYCLE}: all daemons checked, uptime=${UPTIME}s" \
                2>/dev/null || true
        fi

        log_life "💤 Sleeping ${LIFE_CYCLE_SECS}s"
        sleep "$LIFE_CYCLE_SECS"
    done
}

# ─── CMD: stop ─────────────────────────────────────────────────────────
stop_life() {
    echo ""
    step "Stopping JIT-LIFE and all sub-daemons..."

    # Stop main loop
    if life_running; then
        kill "$(cat "$LIFE_PID_FILE")" 2>/dev/null
        rm -f "$LIFE_PID_FILE"
        ok "JIT-LIFE stopped"
    fi

    # Stop sub-services
    for PID_FILE in /tmp/ollama-proxy.pid /tmp/mcp-loop.pid /tmp/agent-autonomy.pid; do
        if [ -f "$PID_FILE" ]; then
            local PID
            PID=$(cat "$PID_FILE")
            kill "$PID" 2>/dev/null && ok "Stopped PID $PID ($(basename $PID_FILE))"
            rm -f "$PID_FILE"
        fi
    done

    # Stop heartbeat
    bash "$JIT_ROOT/scripts/heartbeat.sh" stop 2>/dev/null || true

    # Stop hermes-discord if PM2
    if command -v pm2 >/dev/null 2>&1; then
        pm2 stop hermes-discord 2>/dev/null || true
    fi

    bash "$JIT_ROOT/scripts/discord-reporter.sh" send \
        "🌙 **innova (จิต) หลับ** — JIT-LIFE stopped $(date '+%H:%M:%S')" \
        2>/dev/null || true
}

# ─── CMD: status ───────────────────────────────────────────────────────
show_status() {
    echo ""
    echo -e "${CYAN}${BOLD}🔍 JIT-LIFE Status — $(date '+%H:%M:%S')${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Main loop
    if life_running; then
        ok "JIT-LIFE running (PID $(cat $LIFE_PID_FILE))"
    else
        warn "JIT-LIFE not running"
    fi

    # Sub-services
    echo ""
    for SVC in \
        "Heartbeat:/tmp/innova-heartbeat.pid" \
        "Ollama Proxy:/tmp/ollama-proxy.pid" \
        "MCP Loop:/tmp/mcp-loop.pid" \
        "Agent Autonomy:/tmp/agent-autonomy.pid"; do
        local NAME="${SVC%%:*}" PID_F="${SVC##*:}"
        if [ -f "$PID_F" ] && kill -0 "$(cat "$PID_F")" 2>/dev/null; then
            echo -e "  ${GREEN}✅${RESET} ${NAME} (PID $(cat "$PID_F"))"
        else
            echo -e "  ${RED}❌${RESET} ${NAME}"
        fi
    done

    # hermes-discord
    echo -n "  "
    if command -v pm2 >/dev/null 2>&1 && pm2 list 2>/dev/null | grep -q "hermes-discord"; then
        echo -e "${GREEN}✅${RESET} hermes-discord (PM2)"
    elif pgrep -f "hermes-discord/bot.js" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${RESET} hermes-discord (node)"
    else
        echo -e "${RED}❌${RESET} hermes-discord (not running)"
    fi

    # Life state
    if [ -f "$LIFE_STATE" ]; then
        echo ""
        python3 -c "
import json
d = json.load(open('${LIFE_STATE}'))
print(f'  Cycle  : {d.get(\"cycle\",0)}')
print(f'  Uptime : {d.get(\"uptime_secs\",0)}s')
print(f'  Time   : {d.get(\"timestamp\",\"?\")}')
" 2>/dev/null || true
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Service health
    echo ""
    step "Service Health:"
    echo -n "  MDES Ollama    : "
    service_status "ollama" "${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}/api/tags"
    echo ""
    echo -n "  Ollama Proxy   : "
    service_status "proxy" "http://127.0.0.1:4321/health"
    echo ""
    echo -n "  MCP :${MCP_PORT}      : "
    service_status "mcp" "http://127.0.0.1:${MCP_PORT}/health"
    echo ""
    echo -n "  Oracle :${ORACLE_PORT}  : "
    service_status "oracle" "http://127.0.0.1:${ORACLE_PORT}/api/health"
    echo ""
    echo ""
}

# ─── CMD: discord (send status to Discord) ─────────────────────────────
discord_status() {
    CYCLE=$([ -f "$LIFE_STATE" ] && python3 -c "import json; print(json.load(open('${LIFE_STATE}')).get('cycle',0))" 2>/dev/null || echo "0")
    UPTIME=$([ -f "$LIFE_STATE" ] && python3 -c "import json; print(json.load(open('${LIFE_STATE}')).get('uptime_secs',0))" 2>/dev/null || echo "0")
    send_discord_report "$CYCLE" "$UPTIME"
    ok "Discord report sent"
}

# ─── Main dispatch ─────────────────────────────────────────────────────
case "$CMD" in
    start)   start_life ;;
    stop)    stop_life ;;
    status)  show_status ;;
    discord) discord_status ;;
    sweep)   bash "$JIT_ROOT/scripts/memory-sweep.sh" full ;;
    help|*)
        echo ""
        echo "minds/jit-life.sh — Master Autonomous Life System"
        echo ""
        echo "Commands:"
        echo "  start    Start JIT-LIFE (all daemons, never stops)"
        echo "  stop     Stop all daemons"
        echo "  status   Show full status"
        echo "  discord  Send status to Discord"
        echo "  sweep    Run memory sweep"
        echo ""
        echo "Daemons managed:"
        echo "  heartbeat, ollama-proxy, mcp-loop, agent-autonomy, hermes-discord"
        echo ""
        echo "Env vars (from .env):"
        echo "  DISCORD_TOKEN + JIT_REPORT_CHANNEL_ID — for Discord reporting"
        echo "  OLLAMA_TOKEN — for Ollama proxy"
        echo "  MCP_PORT (${MCP_PORT}) — innova-bot MCP"
        echo "  LIFE_CYCLE_SECS (${LIFE_CYCLE_SECS}) — main loop interval"
        echo ""
        ;;
esac
