#!/usr/bin/env bash
# scripts/start-jit.sh — เริ่มต้น มนุษย์ Agent ทั้งระบบ (Life Loop + Voice Server)
#
# Usage:
#   bash scripts/start-jit.sh          — start everything
#   bash scripts/start-jit.sh stop     — stop everything
#   bash scripts/start-jit.sh status   — check status
#   bash scripts/start-jit.sh restart  — stop + start

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# WSL CRLF self-heal
if grep -qi 'microsoft' /proc/version 2>/dev/null; then
  for _f in "$JIT_ROOT/limbs/lib.sh" "$JIT_ROOT/.env" "$JIT_ROOT/core/life-loop.sh" \
            "$JIT_ROOT/minds/jit-voice.sh" "$SCRIPT_DIR/start-jit.sh" \
            "$JIT_ROOT/voice/server.ts" "$JIT_ROOT/voice/voice.sh"; do
    [ -f "$_f" ] && sed -i 's/\r$//' "$_f" 2>/dev/null || true
  done; unset _f
fi

[ -f "$JIT_ROOT/.env" ] && { set -a; . "$JIT_ROOT/.env"; set +a; }
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export JIT_ROOT

VOICE_PID_FILE="/tmp/manusat-voice.pid"
VOICE_LOG="/tmp/manusat-voice-server.log"
VOICE_PORT="${VOICE_PORT:-3333}"

# ── Helper: is process alive? ────────────────────────────────────────────
_is_alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }

# ── Start voice server ───────────────────────────────────────────────────
_start_voice() {
  if _is_alive "$VOICE_PID_FILE"; then
    echo "   ⚠️  Voice Server กำลังรันอยู่ (PID $(cat "$VOICE_PID_FILE"))"
    return 0
  fi

  # Prefer native WSL/Linux bun over Windows bun-in-PATH (Windows bun can't resolve /mnt/c paths)
  local BUN_CMD
  _resolve_bun() {
    # 1. WSL native bun (best)
    [ -x "$HOME/.bun/bin/bun" ] && { BUN_CMD="$HOME/.bun/bin/bun"; return 0; }
    # 2. npm-installed bun (from npm install -g bun)
    local _npm_bun
    _npm_bun="$(npm prefix -g 2>/dev/null)/bin/bun"
    [ -x "$_npm_bun" ] && { BUN_CMD="$_npm_bun"; return 0; }
    # 3. bun somewhere in PATH — reject Windows paths
    if command -v bun >/dev/null 2>&1; then
      local _b; _b=$(command -v bun)
      case "$_b" in /mnt/c/*|/mnt/d/*) ;; *) BUN_CMD="$_b"; return 0 ;; esac
    fi
    return 1
  }

  if ! _resolve_bun; then
    # Auto-heal: try npm install -g bun (no unzip needed, user already has npm)
    if command -v npm >/dev/null 2>&1; then
      echo "   🔧 WSL bun not found — installing via npm (no unzip needed)..."
      npm install -g bun --loglevel=error 2>&1 | grep -v '^npm warn' || true
      # npm installs into $(npm prefix -g)/bin — add to PATH and re-check
      local NPM_BIN; NPM_BIN="$(npm prefix -g 2>/dev/null)/bin"
      export PATH="$HOME/.bun/bin:$NPM_BIN:$PATH"
      if ! _resolve_bun; then
        echo "   ❌ bun install via npm failed. Manual fix:"
        echo "      sudo apt-get install -y unzip && curl -fsSL https://bun.sh/install | bash"
        return 1
      fi
      echo "   ✅ bun installed via npm: $BUN_CMD"
    else
      echo "   ❌ WSL bun not found and npm not available."
      echo "      Fix: sudo apt-get install -y unzip && curl -fsSL https://bun.sh/install | bash"
      return 1
    fi
  fi

  # Pre-flight: verify server.ts is readable
  local SERVER_TS="$JIT_ROOT/voice/server.ts"
  if [ ! -f "$SERVER_TS" ]; then
    echo "   ❌ $SERVER_TS not found"
    return 1
  fi

  "$BUN_CMD" run "$SERVER_TS" > "$VOICE_LOG" 2>&1 &
  local VPID=$!
  echo "$VPID" > "$VOICE_PID_FILE"
  sleep 1

  if _is_alive "$VOICE_PID_FILE"; then
    echo "   ✅ Voice Server PID $VPID → http://localhost:${VOICE_PORT}  (bun: $BUN_CMD)"
  else
    echo "   ❌ Voice Server failed — ดู log: cat $VOICE_LOG"
    cat "$VOICE_LOG" | tail -8
    return 1
  fi
}

case "${1:-start}" in

  # ── Start all ──────────────────────────────────────────────────────────
  start)
    echo ""
    echo "🌀 ============================================"
    echo "   มนุษย์ Agent — จิต เริ่มชีวิต"
    echo "   $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""

    echo "→ [1/2] Life Loop..."
    bash "$JIT_ROOT/core/life-loop.sh" start
    sleep 1

    echo ""
    echo "→ [2/2] Voice Server (port $VOICE_PORT)..."
    _start_voice

    echo ""
    echo "=============================================="
    echo "✅ จิต ตื่นแล้ว! 🌀"
    echo ""
    echo "  🌐 Voice UI  : http://localhost:${VOICE_PORT}"
    echo "  📋 Life Log  : bash core/life-loop.sh log"
    echo "  📊 Status    : bash scripts/start-jit.sh status"
    echo "  🎤 Voice Log : bash minds/jit-voice.sh log"
    echo "  🛑 Stop all  : bash scripts/start-jit.sh stop"
    echo "=============================================="
    echo ""
    ;;

  # ── Stop all ───────────────────────────────────────────────────────────
  stop)
    echo "🛑 หยุด มนุษย์ Agent..."
    bash "$JIT_ROOT/core/life-loop.sh" stop 2>/dev/null || true

    if _is_alive "$VOICE_PID_FILE"; then
      PID=$(cat "$VOICE_PID_FILE")
      kill "$PID" 2>/dev/null && echo "✅ Voice Server หยุดแล้ว (PID $PID)"
    fi
    rm -f "$VOICE_PID_FILE"
    echo "✅ หยุดทั้งหมดแล้ว"
    ;;

  # ── Restart ────────────────────────────────────────────────────────────
  restart)
    bash "$0" stop
    sleep 2
    bash "$0" start
    ;;

  # ── Status ─────────────────────────────────────────────────────────────
  status)
    echo "=== มนุษย์ Agent Status ==="
    echo ""
    # Life Loop
    bash "$JIT_ROOT/core/life-loop.sh" status
    echo ""
    # Voice Server
    if _is_alive "$VOICE_PID_FILE"; then
      echo "🟢 Voice Server รันอยู่ (PID $(cat "$VOICE_PID_FILE")) → http://localhost:${VOICE_PORT}"
    else
      echo "🔴 Voice Server หยุดอยู่"
    fi
    # Voice Log recent
    if [ -f "$VOICE_LOG" ]; then
      echo ""
      echo "Voice Server log (5 บรรทัดล่าสุด):"
      tail -5 "$VOICE_LOG"
    fi
    ;;

  *)
    echo "Usage: start-jit.sh {start|stop|restart|status}"
    ;;
esac
