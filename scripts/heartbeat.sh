#!/usr/bin/env bash
# scripts/heartbeat.sh — ชีพจร (หัวใจ / pran) Living Rhythm
#
# หัวใจเต้น 2 ครั้งต่อ 1 รอบ:
#   ครั้ง 1 — IN  (diastole): ดูด blood/signals จากทุก agent → commit IN
#   ครั้ง 2 — OUT (systole) : ฉีด energy/commands ไปทุก agent → commit OUT
#
# ทั้งสองครั้งเกิดทันทีต่อกัน แล้วพักตาม adaptive interval:
#   sprint = 5 นาที  (heavy activity)
#   fast   = 10 นาที (moderate)
#   normal = 15 นาที (default)
#   slow   = 30 นาที (idle)
#   rest   = 1 ชั่วโมง (very quiet)
#
# Commit format:
#   IN : ->💓 heartbeat (IN) ->#N — host @ datetime
#   OUT: ❤️‍🔥-> heartbeat (OUT) #N — host @ datetime
#
# Usage:
#   bash scripts/heartbeat.sh start    — เริ่ม daemon
#   bash scripts/heartbeat.sh stop     — หยุด daemon
#   bash scripts/heartbeat.sh status   — ดูสถานะ
#   bash scripts/heartbeat.sh once     — pulse ครั้งเดียว

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"
LAST_ACTIVITY_FILE="/tmp/heartbeat-last-active.timestamp"
HEART_RATE_REQUEST="/tmp/heart-rate-request.txt"
PID_FILE="/tmp/innova-heartbeat.pid"
LOG_FILE="/tmp/innova-heartbeat.log"
PULSE_INTERVAL=900
PULSE_COUNT=0

# ── Adaptive mode ─────────────────────────────────────────────────────
heartbeat_mode() {
  # ตรวจ rate request จาก agent อื่น (heart.sh rate <mode>)
  if [ -f "$HEART_RATE_REQUEST" ]; then
    local req; req=$(cat "$HEART_RATE_REQUEST" 2>/dev/null | tr -d '[:space:]')
    case "$req" in sprint|fast|normal|slow|rest)
      rm -f "$HEART_RATE_REQUEST"
      echo "$req"; return ;;
    esac
  fi

  # นับเฉพาะ task messages ใหม่ (< 10 นาที, ไม่นับ broadcast ของตัวเอง)
  local pending changes age=0
  pending=$(find "$BUS_ROOT" -name '*.msg' -mmin -10 2>/dev/null \
            | grep -v '_broadcast\.msg$' | wc -l | tr -d ' ')
  changes=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ -f "$LAST_ACTIVITY_FILE" ]; then
    age=$(( $(date +%s) - $(cat "$LAST_ACTIVITY_FILE") ))
  fi

  if   [ "$pending" -ge 10 ] || [ "$changes" -ge 5 ]; then echo "sprint"
  elif [ "$pending" -ge 3  ] || [ "$changes" -ge 1 ]; then echo "fast"
  elif [ "$age" -ge 7200   ];                          then echo "rest"
  elif [ "$age" -ge 3600   ];                          then echo "slow"
  else                                                       echo "normal"
  fi
}

heartbeat_interval() {
  case "$1" in
    sprint) echo 300  ;;   # 5 นาที
    fast)   echo 600  ;;   # 10 นาที
    normal) echo 900  ;;   # 15 นาที (default)
    slow)   echo 1800 ;;   # 30 นาที
    rest)   echo 3600 ;;   # 1 ชั่วโมง
    *)      echo 900  ;;
  esac
}

# ── Progress Bar ──────────────────────────────────────────────────────
_hbar() {
  local PCT="$1" W="${2:-20}"
  local F=$(( PCT * W / 100 )) E=$(( W - PCT * W / 100 ))
  printf "${GREEN}%s${RESET}%s" \
    "$(printf '█%.0s' $(seq 1 $F 2>/dev/null))" \
    "$(printf '░%.0s' $(seq 1 $E 2>/dev/null))"
}

# ── Stale message cleanup ──────────────────────────────────────────────
_cleanup_stale_messages() {
  local deleted
  deleted=$(find "$BUS_ROOT" -name '*.msg' -mmin +30 2>/dev/null | wc -l | tr -d ' ')
  [ "$deleted" -gt 0 ] && find "$BUS_ROOT" -name '*.msg' -mmin +30 -delete 2>/dev/null
  echo "$deleted"
}

# ── git: stage all → commit if changed (excluding innova.state.json) ──
_git_commit_if_changed() {
  local MSG="$1"
  git -C "$JIT_ROOT" add -A 2>/dev/null
  local staged
  staged=$(git -C "$JIT_ROOT" diff --cached --name-only 2>/dev/null \
           | grep -v 'memory/state/innova\.state\.json' | wc -l | tr -d ' ')
  if [ "$staged" -gt 0 ]; then
    git -C "$JIT_ROOT" commit -m "$MSG" --no-verify > /dev/null 2>&1
    echo "committed"
  else
    git -C "$JIT_ROOT" restore --staged . 2>/dev/null || true
    echo "skipped"
  fi
}

# ── git push ──────────────────────────────────────────────────────────
_git_push() {
  if [ -f "$JIT_ROOT/scripts/multi-remote.sh" ]; then
    bash "$JIT_ROOT/scripts/multi-remote.sh" push 2>&1 \
      | grep -E '✅|❌|pushed|failed' | tail -1
  else
    git -C "$JIT_ROOT" push origin main --quiet 2>&1 && echo "✅ pushed" || echo "❌ push failed"
  fi
}

# ══════════════════════════════════════════════════════════════════════
# _do_pulse: หัวใจเต้น 1 รอบ (IN → OUT)
# ══════════════════════════════════════════════════════════════════════
_do_pulse() {
  PULSE_COUNT=$(( PULSE_COUNT + 1 ))

  # ── ตรวจสอบ adaptive mode ──────────────────────────────────────
  local MODE; MODE=$(heartbeat_mode)
  PULSE_INTERVAL=$(heartbeat_interval "$MODE")
  export HEARTBEAT_MODE="$MODE"
  export PULSE_COUNT

  local TS; TS="$(date '+%Y-%m-%d %H:%M')"
  local HOST; HOST="$(hostname)"

  echo ""
  echo -e "${CYAN}  ════════════════════════════════════════════════${RESET}"
  echo -e "${CYAN}  💓 Pulse #$PULSE_COUNT · mode=$MODE · interval=${PULSE_INTERVAL}s${RESET}"
  echo -e "${CYAN}  ════════════════════════════════════════════════${RESET}"
  echo ""

  # ── 0. pull: sync ความทรงจำล่าสุดจาก remote ──────────────────
  echo -ne "  🌐  pull  "
  local pull_ok=0
  if [ -f "$JIT_ROOT/scripts/sync-cross-machine.sh" ]; then
    bash "$JIT_ROOT/scripts/sync-cross-machine.sh" pull 2>&1 \
      | grep -qE '✅|up-to-date|up to date' && pull_ok=1
  else
    git -C "$JIT_ROOT" pull --rebase --quiet 2>/dev/null && pull_ok=1
  fi
  printf " %s %s\n" "$(_hbar $(( pull_ok * 100 )))" \
    "$([ $pull_ok -eq 1 ] && echo 'synced' || echo 'skipped')"

  # ── ล้าง stale messages ────────────────────────────────────────
  local stale; stale=$(_cleanup_stale_messages)
  [ "${stale:-0}" -gt 0 ] && echo "  🧹  purged $stale stale messages"

  # ═══════════════════════════════════════════════════════════════
  # BEAT 1 — IN (diastole): ดูด signals/stats จากทุก agent
  # ═══════════════════════════════════════════════════════════════
  echo ""
  echo -e "  ${RED}->💓 heartbeat (IN) → #$PULSE_COUNT${RESET}"

  echo -ne "  🩸  blood "
  BLOOD=$(bash "$JIT_ROOT/organs/heart.sh" beat in 2>/dev/null)
  local PENDING CHANGES
  PENDING=$(echo "$BLOOD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total_pending',0))" 2>/dev/null || echo 0)
  CHANGES=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$CHANGES" -gt 0 ] || [ "$PENDING" -gt 0 ] && date +%s > "$LAST_ACTIVITY_FILE"
  printf " %s %s task msgs · %s repo changes\n" \
    "$(_hbar $(( PENDING > 0 ? 100 : 30 )))" "$PENDING" "$CHANGES"

  echo -ne "  📝  commit "
  IN_MSG="->💓 heartbeat (IN) ->#$PULSE_COUNT — $HOST @ $TS"
  IN_RESULT=$(_git_commit_if_changed "$IN_MSG")
  printf " %s %s\n" "$(_hbar $([ "$IN_RESULT" = "committed" ] && echo 100 || echo 10))" "$IN_RESULT"

  echo -ne "  🚀  push   "
  PUSH_IN=$(_git_push)
  printf " %s %s\n" "$(_hbar $(echo "$PUSH_IN" | grep -q '✅' && echo 100 || echo 0))" "$PUSH_IN"

  # ═══════════════════════════════════════════════════════════════
  # BEAT 2 — OUT (systole): ฉีด energy/commands ไปทุกอวัยวะ
  # ═══════════════════════════════════════════════════════════════
  echo ""
  echo -e "  ${RED}❤️‍🔥-> heartbeat (OUT) #$PULSE_COUNT${RESET}"

  echo -ne "  ⚡  energy "
  bash "$JIT_ROOT/organs/heart.sh" beat out 2>/dev/null > /dev/null
  printf " %s broadcast to all agents\n" "$(_hbar 100)"

  echo -ne "  📝  commit "
  OUT_MSG="❤️‍🔥-> heartbeat (OUT) #$PULSE_COUNT — $HOST @ $TS"
  OUT_RESULT=$(_git_commit_if_changed "$OUT_MSG")
  printf " %s %s\n" "$(_hbar $([ "$OUT_RESULT" = "committed" ] && echo 100 || echo 10))" "$OUT_RESULT"

  echo -ne "  🚀  push   "
  PUSH_OUT=$(_git_push)
  printf " %s %s\n" "$(_hbar $(echo "$PUSH_OUT" | grep -q '✅' && echo 100 || echo 0))" "$PUSH_OUT"

  # ═══════════════════════════════════════════════════════════════
  # สรุป Pulse
  # ═══════════════════════════════════════════════════════════════
  echo ""
  echo -e "  ────────────────────────────────────────────────"
  echo -e "  ✅ Pulse #$PULSE_COUNT เสร็จ · mode=$MODE · next in ${PULSE_INTERVAL}s · $(date '+%H:%M:%S')"
  echo ""

  log_action "HEARTBEAT_PULSE" \
    "pulse=$PULSE_COUNT mode=$MODE in=$IN_RESULT out=$OUT_RESULT pending=$PENDING changes=$CHANGES"
}

# ══════════════════════════════════════════════════════════════════════
# Commands
# ══════════════════════════════════════════════════════════════════════
CMD="${1:-once}"

case "$CMD" in
  start)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo -e "${YELLOW}⚠️  Heartbeat daemon กำลังรันอยู่แล้ว (PID $(cat "$PID_FILE"))${RESET}"
      exit 0
    fi
    MODE_NOW=$(heartbeat_mode)
    INT_NOW=$(heartbeat_interval "$MODE_NOW")
    echo -e "${GREEN}💓 เริ่ม Pran Heartbeat daemon (mode=$MODE_NOW · interval=${INT_NOW}s)...${RESET}"
    (
      PULSE_COUNT=0
      while true; do
        _do_pulse >> "$LOG_FILE" 2>&1
        sleep "$PULSE_INTERVAL"
      done
    ) &
    DAEMON_PID=$!
    echo "$DAEMON_PID" > "$PID_FILE"
    echo -e "${GREEN}✅ Daemon PID $DAEMON_PID · log: $LOG_FILE${RESET}"
    echo -e "${CYAN}💡 หยุดด้วย: bash scripts/heartbeat.sh stop${RESET}"
    echo -e "${CYAN}💡 เปลี่ยน rate: bash organs/heart.sh rate <sprint|fast|normal|slow|rest>${RESET}"
    ;;

  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      if kill "$PID" 2>/dev/null; then
        echo -e "${GREEN}✅ Heartbeat daemon หยุดแล้ว (PID $PID)${RESET}"
        rm -f "$PID_FILE"
      else
        echo -e "${YELLOW}⚠️  ไม่พบ process PID $PID${RESET}"
        rm -f "$PID_FILE"
      fi
    else
      echo -e "${YELLOW}⚠️  ไม่พบ heartbeat daemon${RESET}"
    fi
    ;;

  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      PID=$(cat "$PID_FILE")
      CUR_MODE=$(heartbeat_mode)
      CUR_INT=$(heartbeat_interval "$CUR_MODE")
      echo -e "${GREEN}💓 Heartbeat daemon กำลังรัน (PID $PID)${RESET}"
      echo -e "  mode: $CUR_MODE · interval: ${CUR_INT}s"
      echo -e "  log: $LOG_FILE"
      echo "  --- last 5 lines ---"
      tail -5 "$LOG_FILE" 2>/dev/null || echo "  (no log)"
    else
      echo -e "${YELLOW}⏸️  Heartbeat ไม่ได้รัน${RESET}"
      echo -e "  รัน: bash scripts/heartbeat.sh start"
    fi
    ;;

  once|pulse)
    _do_pulse
    ;;

  rate)
    RATE="${2:-normal}"
    bash "$JIT_ROOT/organs/heart.sh" rate "$RATE"
    ;;

  *)
    echo "Usage: $0 {start|stop|status|once|pulse|rate}"
    echo "  start          — เริ่ม background daemon"
    echo "  stop           — หยุด daemon"
    echo "  status         — ดูสถานะ"
    echo "  once           — pulse ครั้งเดียว (IN+OUT)"
    echo "  rate <mode>    — เปลี่ยน rate: sprint(5m) fast(10m) normal(15m) slow(30m) rest(1h)"
    ;;
esac
