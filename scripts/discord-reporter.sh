#!/usr/bin/env bash
# scripts/discord-reporter.sh — ส่งรายงานไป Discord ผ่าน Bot Token
# ════════════════════════════════════════════════════════════════════
# ใช้ Discord REST API กับ Bot Token (ไม่ต้องใช้ webhook URL)
# รองรับทั้ง webhook URL และ Bot Token + Channel ID
#
# Usage:
#   bash scripts/discord-reporter.sh send "ข้อความ"
#   bash scripts/discord-reporter.sh heartbeat      — ส่ง vitals report
#   bash scripts/discord-reporter.sh mcp-status     — รายงาน MCP status
#   bash scripts/discord-reporter.sh alert "msg"    — ส่ง alert (urgent)
#   bash scripts/discord-reporter.sh cycle N        — รายงาน JARVIS cycle
# ════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

# ─── Config ────────────────────────────────────────────────────────────
DISCORD_TOKEN="${DISCORD_TOKEN:-}"
DISCORD_CHANNEL_ID="${JIT_REPORT_CHANNEL_ID:-${DISCORD_CHANNEL_ID:-}}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
DISCORD_API="https://discord.com/api/v10"
REPORTER_LOG="/tmp/discord-reporter.log"
AGENT_NAME="${AGENT_NAME:-innova}"
SYSTEM_NAME="${SYSTEM_NAME:-มนุษย์ Agent}"

CMD="${1:-help}"
shift || true

# ─── Send via Bot Token ────────────────────────────────────────────
_send_bot() {
    local CHANNEL_ID="$1"
    local CONTENT="$2"
    local TOKEN="$3"

    python3 - << PYEOF
import urllib.request, urllib.error, json, sys

channel_id = "${CHANNEL_ID}"
token = "${TOKEN}"
content = sys.argv[1]
api = "${DISCORD_API}"

url = f"{api}/channels/{channel_id}/messages"
headers = {
    "Authorization": f"Bot {token}",
    "Content-Type": "application/json",
    "User-Agent": "JitDiscordReporter/1.0"
}
payload = json.dumps({"content": content}).encode()
req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read())
        print(f"OK: message_id={data.get('id','?')}")
except urllib.error.HTTPError as e:
    err = e.read().decode(errors='ignore')
    print(f"ERR {e.code}: {err[:200]}", file=sys.stderr)
    sys.exit(1)
except Exception as ex:
    print(f"EX: {ex}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# ─── Send via Webhook ──────────────────────────────────────────────
_send_webhook() {
    local WEBHOOK_URL="$1"
    local CONTENT="$2"

    python3 - << PYEOF
import urllib.request, urllib.error, json, sys

url = "${WEBHOOK_URL}"
content = sys.argv[1]
payload = json.dumps({"content": content, "username": "innova (จิต)"}).encode()
req = urllib.request.Request(url, data=payload,
    headers={"Content-Type": "application/json", "User-Agent": "JitDiscordReporter/1.0"},
    method="POST")
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        print(f"OK: status={resp.status}")
except urllib.error.HTTPError as e:
    print(f"ERR {e.code}: {e.read().decode()[:200]}", file=sys.stderr)
    sys.exit(1)
except Exception as ex:
    print(f"EX: {ex}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# ─── Main send dispatcher ──────────────────────────────────────────
send_discord() {
    local MSG="$1"
    local TS
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TS] DISCORD: ${MSG:0:120}" >> "$REPORTER_LOG"

    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        _send_webhook "$DISCORD_WEBHOOK_URL" "$MSG" 2>/dev/null \
            && { log_action "DISCORD_WEBHOOK" "OK"; return 0; }
    fi

    if [ -n "$DISCORD_TOKEN" ] && [ -n "$DISCORD_CHANNEL_ID" ]; then
        _send_bot "$DISCORD_CHANNEL_ID" "$MSG" "$DISCORD_TOKEN" 2>/dev/null \
            && { log_action "DISCORD_BOT" "OK"; return 0; }
    fi

    warn "Discord not configured — DISCORD_TOKEN+DISCORD_CHANNEL_ID or DISCORD_WEBHOOK_URL required"
    return 1
}

# ─── Message builders ──────────────────────────────────────────────
build_heartbeat_msg() {
    local UPTIME_SECS="${1:-0}"
    local CYCLE="${2:-0}"
    local OLLAMA_STATUS="${3:-unknown}"
    local MCP_STATUS="${4:-unknown}"
    local ORACLE_STATUS="${5:-unknown}"

    local UPTIME_MIN=$(( UPTIME_SECS / 60 ))
    local TS
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    cat << MSG
🤖 **innova (จิต) — Heartbeat Report**
━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏰ Time     : ${TS}
🔄 JARVIS   : Cycle #${CYCLE} | Uptime ${UPTIME_MIN}m
🧠 Ollama   : ${OLLAMA_STATUS}
🔌 MCP:7010 : ${MCP_STATUS}
📚 Oracle   : ${ORACLE_STATUS}
━━━━━━━━━━━━━━━━━━━━━━━━━━━
*${SYSTEM_NAME} • PC Node: $(hostname 2>/dev/null || echo '?')*
MSG
}

build_cycle_msg() {
    local CYCLE="$1"
    local DETAIL="${2:-}"

    cat << MSG
⚡ **JARVIS Cycle #${CYCLE}** — $(date '+%H:%M:%S')
${DETAIL}
MSG
}

build_alert_msg() {
    local ALERT_TEXT="$1"
    echo "🚨 **innova ALERT** — $(date '+%H:%M:%S')\n${ALERT_TEXT}"
}

# ─── Check services ────────────────────────────────────────────────
check_mcp() {
    local PORT="${MCP_PORT:-7010}"
    if curl -sf --max-time 5 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        echo "✅ online:${PORT}"
    else
        echo "❌ offline:${PORT}"
    fi
}

check_oracle() {
    local PORT="${ORACLE_PORT:-47778}"
    if curl -sf --max-time 5 "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
        echo "✅ online:${PORT}"
    else
        echo "❌ offline:${PORT}"
    fi
}

check_ollama() {
    if curl -sf --max-time 10 \
        -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
        "${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}/api/tags" \
        >/dev/null 2>&1; then
        echo "✅ online"
    else
        echo "❌ offline"
    fi
}

# ─── CMD dispatch ──────────────────────────────────────────────────
case "$CMD" in

    send)
        MSG="$*"
        [ -z "$MSG" ] && { err "Usage: discord-reporter.sh send <message>"; exit 1; }
        send_discord "$MSG"
        ;;

    heartbeat)
        CYCLE="${1:-0}"
        UPTIME_SECS="${2:-0}"
        OLLAMA_S=$(check_ollama)
        MCP_S=$(check_mcp)
        ORACLE_S=$(check_oracle)
        MSG=$(build_heartbeat_msg "$UPTIME_SECS" "$CYCLE" "$OLLAMA_S" "$MCP_S" "$ORACLE_S")
        send_discord "$MSG"
        ;;

    mcp-status)
        MCP_S=$(check_mcp)
        MSG="🔌 **MCP Status** — $(date '+%H:%M:%S')\ninnova-bot MCP: ${MCP_S}\nPort: ${MCP_PORT:-7010}"
        send_discord "$MSG"
        ;;

    alert)
        MSG=$(build_alert_msg "$*")
        send_discord "$MSG"
        ;;

    cycle)
        CYCLE="${1:-?}"
        shift || true
        DETAIL="$*"
        MSG=$(build_cycle_msg "$CYCLE" "$DETAIL")
        send_discord "$MSG"
        ;;

    status)
        echo ""
        step "Discord Reporter Status"
        echo "  Token   : $([ -n "$DISCORD_TOKEN" ] && echo "✅ set" || echo "❌ not set")"
        echo "  Channel : $([ -n "$DISCORD_CHANNEL_ID" ] && echo "✅ ${DISCORD_CHANNEL_ID}" || echo "❌ not set")"
        echo "  Webhook : $([ -n "$DISCORD_WEBHOOK_URL" ] && echo "✅ set" || echo "❌ not set")"
        echo "  Log     : $REPORTER_LOG"
        echo ""
        ;;

    test)
        step "Sending test message to Discord..."
        send_discord "🧪 **innova Test** — Discord reporter works! $(date '+%H:%M:%S')"
        ;;

    help|*)
        echo ""
        echo "scripts/discord-reporter.sh — Send reports to Discord"
        echo ""
        echo "Commands:"
        echo "  send <msg>        — Send raw message"
        echo "  heartbeat [cycle] [uptime_secs] — Send vitals"
        echo "  mcp-status        — Report MCP status"
        echo "  alert <msg>       — Send urgent alert"
        echo "  cycle <N> [msg]   — Report JARVIS cycle"
        echo "  test              — Send test message"
        echo "  status            — Show config"
        echo ""
        echo "Env vars required:"
        echo "  DISCORD_TOKEN + JIT_REPORT_CHANNEL_ID"
        echo "  OR DISCORD_WEBHOOK_URL"
        echo ""
        ;;
esac
