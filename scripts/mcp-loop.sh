#!/usr/bin/env bash
# scripts/mcp-loop.sh — MCP Realtime Connection Keeper
# ════════════════════════════════════════════════════════════════════
# รักษา innova-bot MCP ให้ online ตลอดเวลา
# ส่ง heartbeat ผ่าน MCP SSE endpoint
# รับ task จาก MCP และ route ผ่าน Jit bus
#
# Usage:
#   bash scripts/mcp-loop.sh start     — เริ่ม loop
#   bash scripts/mcp-loop.sh stop      — หยุด
#   bash scripts/mcp-loop.sh status    — ดูสถานะ
#   bash scripts/mcp-loop.sh ping      — test MCP connection
#   bash scripts/mcp-loop.sh tools     — list MCP tools
# ════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

# ─── Config ────────────────────────────────────────────────────────────
MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-7010}"
MCP_BASE="http://${MCP_HOST}:${MCP_PORT}"
MCP_SSE_URL="${MCP_BASE}/sse"
MCP_HEALTH_URL="${MCP_BASE}/health"
MCP_TOOLS_URL="${MCP_BASE}/tools"

INNOVA_BOT_PATH="${INNOVA_BOT_PATH:-/mnt/c/Users/USER-NT/DEV/innova-bot-template}"
MCP_LOG="/tmp/mcp-loop.log"
MCP_PID_FILE="/tmp/mcp-loop.pid"
MCP_STATE_FILE="/tmp/mcp-loop-state.json"
POLL_INTERVAL="${MCP_POLL_INTERVAL:-30}"  # seconds between polls

CMD="${1:-help}"
shift || true

mcp_running() {
    [ -f "$MCP_PID_FILE" ] && kill -0 "$(cat "$MCP_PID_FILE")" 2>/dev/null
}

mcp_online() {
    curl -sf --max-time 5 "$MCP_HEALTH_URL" >/dev/null 2>&1
}

log_mcp() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] MCP: $1" | tee -a "$MCP_LOG"
}

# ─── Call MCP tool ────────────────────────────────────────────────
call_mcp_tool() {
    local TOOL_NAME="$1"
    shift || true
    local PARAMS="${1:-{}}"

    python3 - << PYEOF
import urllib.request, json, sys

url = "${MCP_BASE}/tools/${TOOL_NAME}"
payload = json.dumps({"params": ${PARAMS}}).encode()
req = urllib.request.Request(url, data=payload,
    headers={"Content-Type": "application/json"},
    method="POST")
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read())
        print(json.dumps(data, ensure_ascii=False, indent=2))
except Exception as ex:
    print(f"MCP call failed: {ex}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# ─── Get MCP tool list ─────────────────────────────────────────────
get_mcp_tools() {
    curl -sf --max-time 10 "$MCP_TOOLS_URL" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  {t.get(\"name\",\"?\")}') for t in d.get('tools', d.get('result',[]))]" 2>/dev/null \
    || echo "  (cannot list tools)"
}

# ─── Save state ────────────────────────────────────────────────────
save_mcp_state() {
    local STATUS="$1"
    local CYCLE="$2"
    local LAST_TOOL="${3:-none}"

    python3 - << PYEOF
import json
data = {
    "status": "${STATUS}",
    "cycle": ${CYCLE},
    "mcp_url": "${MCP_BASE}",
    "mcp_port": ${MCP_PORT},
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "last_tool_call": "${LAST_TOOL}",
    "poll_interval_secs": ${POLL_INTERVAL},
    "innova_bot_path": "${INNOVA_BOT_PATH}",
}
with open("${MCP_STATE_FILE}", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
}

# ─── Try start innova-bot ─────────────────────────────────────────
try_start_innova_bot() {
    log_mcp "Attempting to start innova-bot..."

    # Normalize Windows path to WSL
    local BOT_PATH
    BOT_PATH=$(python3 -c "
import re, sys
p = '${INNOVA_BOT_PATH}'
if re.match(r'^[A-Za-z]:\\\\', p):
    drive = p[0].lower()
    rest = p[2:].replace('\\\\', '/')
    print(f'/mnt/{drive}/{rest.lstrip(\"/\")}')
else:
    print(p)
" 2>/dev/null || echo "${INNOVA_BOT_PATH}")

    if [ -d "$BOT_PATH" ]; then
        local VENV_PY="$BOT_PATH/.venv/Scripts/python.exe"
        local VENV_PY_LINUX="$BOT_PATH/.venv/bin/python"

        if [ -f "$VENV_PY" ]; then
            cd "$BOT_PATH" && nohup "$VENV_PY" -m innova_bot.main > /tmp/innova-bot.log 2>&1 &
            log_mcp "Started innova-bot (Windows venv)"
            return 0
        elif [ -f "$VENV_PY_LINUX" ]; then
            cd "$BOT_PATH" && nohup "$VENV_PY_LINUX" -m innova_bot.main > /tmp/innova-bot.log 2>&1 &
            log_mcp "Started innova-bot (Linux venv)"
            return 0
        fi
    fi

    log_mcp "Cannot start innova-bot — path: $BOT_PATH"
    return 1
}

# ─── Process tasks from MCP (poll-based) ──────────────────────────
process_mcp_tasks() {
    local CYCLE="$1"

    # Use mcp_innovabot_job_status to check pending jobs
    local RESULT
    RESULT=$(python3 - << PYEOF 2>/dev/null
import urllib.request, json, sys

# Try /tasks endpoint first
for endpoint in ["/api/tasks", "/tasks", "/queue"]:
    try:
        req = urllib.request.Request(
            "${MCP_BASE}" + endpoint,
            headers={"Content-Type": "application/json"},
            method="GET"
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            tasks = data.get("tasks", data.get("queue", data.get("items", [])))
            if isinstance(tasks, list) and len(tasks) > 0:
                print(f"found:{len(tasks)}")
                break
    except:
        pass
else:
    print("empty")
PYEOF
)
    echo "$RESULT"
}

# ─── CMD: ping ────────────────────────────────────────────────────
do_ping() {
    echo ""
    step "Pinging MCP at ${MCP_BASE}..."
    if mcp_online; then
        ok "MCP online: ${MCP_BASE}"
        local HEALTH
        HEALTH=$(curl -sf --max-time 5 "$MCP_HEALTH_URL" 2>/dev/null || echo "{}")
        echo "$HEALTH" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  status  : {d.get(\"status\",\"?\")}')
print(f'  version : {d.get(\"version\",\"?\")}')
print(f'  name    : {d.get(\"name\",\"?\")}')
" 2>/dev/null || echo "  (raw: $HEALTH)"
    else
        warn "MCP offline: ${MCP_BASE}"
    fi
}

# ─── CMD: tools ──────────────────────────────────────────────────
do_tools() {
    echo ""
    step "MCP Tools at ${MCP_BASE}:"
    get_mcp_tools
}

# ─── CMD: start (loop) ────────────────────────────────────────────
start_loop() {
    if mcp_running; then
        warn "MCP loop already running (PID $(cat $MCP_PID_FILE))"
        return 0
    fi

    echo ""
    echo -e "${CYAN}${BOLD}🔌 Starting MCP Realtime Loop${RESET}"
    echo "   URL: ${MCP_BASE}"
    echo "   Poll: every ${POLL_INTERVAL}s"
    echo ""

    # Background loop
    (
        echo $$ > "$MCP_PID_FILE"
        CYCLE=0
        START=$SECONDS

        while true; do
            ((CYCLE++)) || true

            # 1. Check MCP health
            if mcp_online; then
                save_mcp_state "online" "$CYCLE"
                log_mcp "✅ MCP online (cycle $CYCLE)"

                # 2. Process any pending tasks
                TASK_STATUS=$(process_mcp_tasks "$CYCLE")
                if echo "$TASK_STATUS" | grep -q "^found:"; then
                    TASK_COUNT=$(echo "$TASK_STATUS" | grep -o '[0-9]*$')
                    log_mcp "📋 ${TASK_COUNT} pending tasks found"
                    # Route to innova via bus
                    if [ -f "$JIT_ROOT/organs/mouth.sh" ]; then
                        bash "$JIT_ROOT/organs/mouth.sh" tell innova \
                            "task:mcp-tasks-pending" \
                            "MCP cycle ${CYCLE}: ${TASK_COUNT} tasks waiting at ${MCP_BASE}" \
                            2>/dev/null || true
                    fi
                fi

                # 3. Send keepalive heartbeat to MCP
                python3 - << HBEOF 2>/dev/null || true
import urllib.request, json
try:
    payload = json.dumps({"agent": "innova", "cycle": ${CYCLE}, "status": "alive"}).encode()
    req = urllib.request.Request(
        "${MCP_BASE}/heartbeat",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    urllib.request.urlopen(req, timeout=5)
except:
    pass
HBEOF

            else
                save_mcp_state "offline" "$CYCLE"
                log_mcp "❌ MCP offline (cycle $CYCLE) — attempting restart"
                try_start_innova_bot 2>/dev/null || true
                sleep 10  # Wait for startup
            fi

            sleep "$POLL_INTERVAL"
        done
    ) &

    echo $! > "$MCP_PID_FILE"
    ok "MCP loop started (PID $(cat $MCP_PID_FILE))"
}

# ─── CMD: stop ────────────────────────────────────────────────────
stop_loop() {
    if mcp_running; then
        kill "$(cat "$MCP_PID_FILE")" 2>/dev/null
        rm -f "$MCP_PID_FILE"
        ok "MCP loop stopped"
    else
        warn "MCP loop not running"
    fi
}

# ─── CMD: status ─────────────────────────────────────────────────
show_status() {
    echo ""
    step "MCP Loop Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if mcp_running; then
        ok "Loop running (PID $(cat $MCP_PID_FILE))"
    else
        warn "Loop not running"
    fi

    if [ -f "$MCP_STATE_FILE" ]; then
        python3 -c "
import json
d = json.load(open('${MCP_STATE_FILE}'))
print(f'  MCP status : {d.get(\"status\",\"?\")}')
print(f'  Cycle      : {d.get(\"cycle\",0)}')
print(f'  Timestamp  : {d.get(\"timestamp\",\"?\")}')
" 2>/dev/null || true
    fi

    echo ""
    do_ping
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─── Main dispatch ────────────────────────────────────────────────
case "$CMD" in
    start)   start_loop ;;
    stop)    stop_loop ;;
    status)  show_status ;;
    ping)    do_ping ;;
    tools)   do_tools ;;
    help|*)
        echo ""
        echo "scripts/mcp-loop.sh — MCP Realtime Connection Keeper"
        echo ""
        echo "Commands:"
        echo "  start    Start MCP polling loop (background)"
        echo "  stop     Stop loop"
        echo "  status   Show loop + MCP status"
        echo "  ping     Test MCP connection"
        echo "  tools    List available MCP tools"
        echo ""
        echo "MCP: ${MCP_BASE}"
        echo ""
        ;;
esac
