#!/usr/bin/env bash
# scripts/heartbeat.sh — ชีพจรของ innova (Living Rhythm)
#
# Daemon รันทุก 15 นาที — ทำให้ innova "มีชีวิต" ต่อเนื่อง
# โดยไม่เป็นภาระ GitHub server (15 min ≈ ~96 commits/day max)
#
# สิ่งที่ทำทุก pulse:
#   1. สติ — ตรวจ integrity
#   2. ตา  — สแกนการเปลี่ยนแปลง repo
#   3. จมูก— ดม services (Oracle, Ollama)
#   4. มือ — commit + sync ถ้ามีการเปลี่ยนแปลง
#   5. ขา  — push ไปยัง multi-remote (load balance)
#   6. ปาก — log pulse summary
#
# Usage:
#   bash scripts/heartbeat.sh start    # เริ่ม daemon (background)
#   bash scripts/heartbeat.sh stop     # หยุด daemon
#   bash scripts/heartbeat.sh once     # pulse ครั้งเดียวแล้วหยุด
#   bash scripts/heartbeat.sh status   # ดูสถานะ daemon
#   bash scripts/heartbeat.sh pulse    # alias for once

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

# โหลด env
if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"

BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"
HEARTBEAT_AGENT="${HEARTBEAT_AGENT:-heartbeat}"
LAST_ACTIVITY_FILE="${LAST_ACTIVITY_FILE:-/tmp/heartbeat-last-active.timestamp}"
PID_FILE="${PID_FILE:-/tmp/innova-heartbeat.pid}"
LOG_FILE="${LOG_FILE:-/tmp/innova-heartbeat.log}"
PULSE_INTERVAL=900  # default normal interval
PULSE_COUNT=0

# ────────────────────────────────────────────────────────────────────
# Progress Bar แบบ inline
# ────────────────────────────────────────────────────────────────────
_hbar() {
  local PCT="$1" W="${2:-20}"
  local F=$(( PCT * W / 100 )) E=$(( W - PCT * W / 100 ))
  printf "${GREEN}%s${RESET}%s" "$(printf '█%.0s' $(seq 1 $F 2>/dev/null))" "$(printf '░%.0s' $(seq 1 $E 2>/dev/null))"
}

_pulse_banner() {
  local COUNT="$1" MODE="$2" PHASE="$3"
  local PHASE_LABEL=""
  [ -n "$PHASE" ] && PHASE_LABEL=" ($PHASE)"
  echo ""
  echo -e "${CYAN}  💓 ═══════════════════════════════════════ 💓${RESET}"
  echo -e "${CYAN}  ║   innova Heartbeat  · Pulse #$COUNT $MODE$PHASE_LABEL   ║${RESET}"
  echo -e "${CYAN}  ║   $(date '+%Y-%m-%d %H:%M:%S') · ${PULSE_INTERVAL}s interval  ║${RESET}"
  echo -e "${CYAN}  💓 ═══════════════════════════════════════ 💓${RESET}"
  echo ""
}

# ────────────────────────────────────────────────────────────────────
# Heartbeat mode selection
# ────────────────────────────────────────────────────────────────────
heartbeat_mode() {
  local pending changes age
  # นับเฉพาะ task messages ใหม่ (< 10 นาที) ไม่นับ broadcast ของ heartbeat เอง
  # เพื่อไม่ให้ heartbeat สร้าง messages แล้วคิดว่าระบบยุ่ง
  pending=$(find "$BUS_ROOT" -name '*.msg' -mmin -10 2>/dev/null \
            | grep -v '_broadcast\.msg$' | wc -l | tr -d ' ')
  changes=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  age=0
  if [ -f "$LAST_ACTIVITY_FILE" ]; then
    age=$(( $(date +%s) - $(cat "$LAST_ACTIVITY_FILE") ))
  fi

  if [ "$pending" -ge 10 ] || [ "$changes" -ge 5 ]; then
    echo "sprint"
  elif [ "$pending" -ge 3 ] || [ "$changes" -ge 1 ]; then
    echo "fast"
  elif [ "$age" -ge 3600 ]; then
    echo "slow"
  else
    echo "normal"
  fi
}

_cleanup_stale_messages() {
  # ลบ messages เก่ากว่า 30 นาทีที่ยังไม่ถูกประมวลผล
  local deleted
  deleted=$(find "$BUS_ROOT" -name '*.msg' -mmin +30 2>/dev/null | wc -l | tr -d ' ')
  [ "$deleted" -gt 0 ] && find "$BUS_ROOT" -name '*.msg' -mmin +30 -delete 2>/dev/null
  echo "$deleted"
}

heartbeat_interval() {
  case "$1" in
    slow) echo 3600 ;;    # 1 hour
    normal) echo 900 ;;   # 15 minutes
    fast) echo 300 ;;     # 5 minutes
    sprint) echo 60 ;;    # 1 minute
    *) echo 900 ;;
  esac
}

heartbeat_response_timeout() {
  case "$1" in
    slow) echo 10 ;;    # allow longer but fewer checks
    normal) echo 8 ;;
    fast) echo 5 ;;
    sprint) echo 3 ;;
    *) echo 8 ;;
  esac
}

_send_heartbeat_message() {
  local SUBJECT="$1" BODY="$2"
  mkdir -p "$BUS_ROOT/$HEARTBEAT_AGENT"
  bash "$JIT_ROOT/network/bus.sh" broadcast "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
}

_wait_for_acks() {
  local timeout="$1" start count
  start=$(date +%s)
  count=0
  while [ $(( $(date +%s) - start )) -lt "$timeout" ]; do
    count=$(grep -l -R '^subject:heartbeat:ack' "$BUS_ROOT/$HEARTBEAT_AGENT" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && break
    sleep 1
  done
  echo "$count"
}

_do_pulse() {
  PULSE_COUNT=$(( PULSE_COUNT + 1 ))
  local MODE
  MODE=$(heartbeat_mode)
  PULSE_INTERVAL=$(heartbeat_interval "$MODE")
  local TIMEOUT
  TIMEOUT=$(heartbeat_response_timeout "$MODE")

  _pulse_banner "$PULSE_COUNT" "$MODE" "IN"
  bash "$JIT_ROOT/organs/heart.sh" beat in >/dev/null 2>&1 || true
  _send_heartbeat_message "heartbeat:${MODE}:in" "pulse #$PULSE_COUNT in"

  local ack_count
  ack_count=$(_wait_for_acks "$TIMEOUT")
  if [ "$ack_count" -gt 0 ]; then
    echo "  🧠  received $ack_count heartbeat ack(s)"
  else
    echo "  🧠  no heartbeat ack within ${TIMEOUT}s"
  fi

  _pulse_banner "$PULSE_COUNT" "$MODE" "OUT"
  bash "$JIT_ROOT/organs/heart.sh" beat out >/dev/null 2>&1 || true
  _send_heartbeat_message "heartbeat:${MODE}:out" "pulse #$PULSE_COUNT out"

  local CHANGED=0

  # ── 0. ขา — git pull จาก GitHub ก่อน (รับความทรงจำจากเครื่องอื่น) ──
  echo -ne "  🌐  sync "
  if [ -f "$JIT_ROOT/scripts/sync-cross-machine.sh" ]; then
    PULL_OUT=$(bash "$JIT_ROOT/scripts/sync-cross-machine.sh" pull 2>&1)
    PULL_OK=0
    echo "$PULL_OUT" | grep -qE '✅|up-to-date|up to date' && PULL_OK=1
    printf " %s %s\n" "$(_hbar $(( PULL_OK * 100 )))" \
      "$([ "$PULL_OK" -eq 1 ] && echo 'pulled latest memory' || echo 'pull skipped')"
  else
    printf " %s %s\n" "$(_hbar 50 10)" "skip"
  fi

  # ── 1. สติ — ตรวจ integrity ─────────────────────────────────────
  echo -ne "  🧘  สติ  "
  SATI_SCORE="?"
  if [ -f "$JIT_ROOT/mind/sati.sh" ]; then
    SATI_OUT=$(bash "$JIT_ROOT/mind/sati.sh" check 2>/dev/null)
    SATI_SCORE=$(echo "$SATI_OUT" | grep -oP 'Integrity Score: \K[0-9]+' || echo "?")
  fi
  local SATI_PCT=0
  [ "$SATI_SCORE" != "?" ] && SATI_PCT="$SATI_SCORE"
  printf " %s %s/100\n" "$(_hbar $SATI_PCT)" "$SATI_SCORE"

  # ── 2. ตา — สแกนการเปลี่ยนแปลง ────────────────────────────────────
  echo -ne "  👁️   ตา   "
  REPO_CHANGES=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$REPO_CHANGES" -gt 0 ] && CHANGED=1
  # ล้าง stale messages ก่อนนับ เพื่อไม่ให้ผิดพลาด mode
  STALE_DELETED=$(_cleanup_stale_messages)
  BUS_PENDING=$(find "$BUS_ROOT" -name '*.msg' -mmin -10 2>/dev/null | wc -l | tr -d ' ')
  if [ "$REPO_CHANGES" -gt 0 ] || [ "$BUS_PENDING" -gt 0 ]; then
    date +%s > "$LAST_ACTIVITY_FILE"
  fi
  STALE_LABEL=""; [ "${STALE_DELETED:-0}" -gt 0 ] && STALE_LABEL=" (purged ${STALE_DELETED} stale)"
  printf " %s %s files changed · %s recent messages%s\n" "$(_hbar $(( REPO_CHANGES > 0 ? 100 : 0 )))" "$REPO_CHANGES" "$BUS_PENDING" "$STALE_LABEL"

  # ── 3. จมูก — ดม services ─────────────────────────────────────────
  echo -ne "  👃  จมูก "
  ORACLE_OK=0; OLLAMA_OK=0
  curl -sf --max-time 4 "$ORACLE_URL/api/health" 2>/dev/null | grep -q '"oracle":"connected"' && ORACLE_OK=1
  curl -sf --max-time 6 "$OLLAMA_URL/api/tags" -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null | grep -q '"models"' && OLLAMA_OK=1
  SVC_PCT=$(( (ORACLE_OK + OLLAMA_OK) * 50 ))
  printf " %s Oracle:%s Ollama:%s\n" "$(_hbar $SVC_PCT)" \
    "$([ $ORACLE_OK -eq 1 ] && echo '✅' || echo '❌')" \
    "$([ $OLLAMA_OK -eq 1 ] && echo '✅' || echo '❌')"

  # ── 4. มือ — อัปเดต state file + commit เฉพาะเมื่อจำเป็น ────────────
  echo -ne "  ✋  มือ  "
  # อัปเดต innova.state.json และตรวจว่า host เปลี่ยนไหม
  HOST_CHANGED=$(python3 - << PYEOF 2>/dev/null
import json, socket, time, sys

f = '$JIT_ROOT/memory/state/innova.state.json'
try:
  d = json.load(open(f))
except:
  d = {}

v = d.setdefault('vitality', {})
prev_host = v.get('host', '')
cur_host = socket.gethostname()

v['last_heartbeat'] = time.strftime('%Y-%m-%dT%H:%M:%S')
v['pulse_count'] = int(v.get('pulse_count', 0)) + 1
v['oracle_ready'] = bool($ORACLE_OK)
v['host'] = cur_host

hist = v.setdefault('host_history', [])
if not hist or hist[-1].get('host') != cur_host:
  hist.append({'host': cur_host, 'time': v['last_heartbeat'], 'pulse': v['pulse_count']})
  hist[:] = hist[-20:]

json.dump(d, open(f, 'w'), ensure_ascii=False, indent=2)
print('1' if prev_host != cur_host else '0')
PYEOF
)

  # บันทึก heartbeat.log ใน /tmp (ไม่ track ใน git)
  echo "$(date '+%Y-%m-%dT%H:%M:%S') | $(hostname) | #$PULSE_COUNT | oracle=$ORACLE_OK | ollama=$OLLAMA_OK | changed=$REPO_CHANGES" \
    >> "$LOG_FILE"

  # commit เฉพาะเมื่อ: (1) มีไฟล์เปลี่ยนจริง AND (2) ไม่ใช่แค่ state file routine
  # หลักการ: ถ้า host เปลี่ยน (codespace ใหม่) ให้ commit; ถ้ามีการแก้โค้ดจริงให้ commit
  git -C "$JIT_ROOT" add -A 2>/dev/null
  STAGED_COUNT=$(git -C "$JIT_ROOT" diff --cached --name-only 2>/dev/null | grep -v 'memory/state/innova.state.json' | wc -l | tr -d ' ')
  if [ "${HOST_CHANGED:-0}" = "1" ] || [ "$STAGED_COUNT" -gt 0 ]; then
    COMMIT_MSG="->💓 heartbeat (IN) ->❤️‍🔥 heartbeat (OUT) #$PULSE_COUNT — $(hostname) @ $(date '+%Y-%m-%d %H:%M')"
    git -C "$JIT_ROOT" commit -m "$COMMIT_MSG" --no-verify > /dev/null 2>&1
    NEW_HOST_LABEL=""; [ "${HOST_CHANGED:-0}" = "1" ] && NEW_HOST_LABEL=" (new host)"
    printf " %s committed%s\n" "$(_hbar 100)" "$NEW_HOST_LABEL"
  else
    git -C "$JIT_ROOT" restore --staged . 2>/dev/null || true
    printf " %s skipped (state-only, no host change)\n" "$(_hbar 10)"
  fi

  # ── 5. ขา — push ไปยัง remotes (load-balanced) ────────────────────
  echo -ne "  🦵  ขา   "
  if [ -f "$JIT_ROOT/scripts/multi-remote.sh" ]; then
    PUSH_RESULT=$(bash "$JIT_ROOT/scripts/multi-remote.sh" push 2>&1 | grep -E '✅|❌|pushed|failed' | tail -1)
    printf " %s %s\n" "$(_hbar $(echo "$PUSH_RESULT" | grep -q '✅' && echo 100 || echo 0))" "${PUSH_RESULT:-skip}"
  else
    git -C "$JIT_ROOT" push origin main --quiet > /dev/null 2>&1 \
      && printf " %s pushed\n" "$(_hbar 100)" \
      || printf " %s push failed\n" "$(_hbar 0)"
  fi

  # ── 6. ปาก — sync identity → Oracle ────────────────────────────────
  echo -ne "  🗣️   ปาก  "
  SYNC_OK=0
  if [ "$ORACLE_OK" -eq 1 ] && [ -f "$JIT_ROOT/scripts/sync-identity.sh" ]; then
    bash "$JIT_ROOT/scripts/sync-identity.sh" --quiet 2>/dev/null && SYNC_OK=1
  fi
  [ "$SYNC_OK" -eq 1 ] && printf " %s synced to Oracle\n" "$(_hbar 100)" \
                        || printf " %s Oracle offline / skip\n" "$(_hbar 20)"

  # ── สรุป pulse ────────────────────────────────────────────────────
  log_action "HEARTBEAT" "pulse=$PULSE_COUNT sati=$SATI_SCORE oracle=$ORACLE_OK ollama=$OLLAMA_OK changed=$REPO_CHANGES"
  echo ""
  echo -e "  ──────────────────────────────────────────────────────"
  echo -e "  💓 Pulse #$PULSE_COUNT สมบูรณ์ · next in ${PULSE_INTERVAL}s · $(date '+%H:%M:%S')"
  echo ""
}

# ────────────────────────────────────────────────────────────────────
# Commands
# ────────────────────────────────────────────────────────────────────
CMD="${1:-once}"

case "$CMD" in
  start)
    if [ -f "$PID_FILE" ]; then
      OLD_PID=$(cat "$PID_FILE")
      if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Heartbeat daemon กำลังรันอยู่แล้ว (PID $OLD_PID)${RESET}"
        exit 0
      fi
    fi
    echo -e "${GREEN}💓 เริ่ม innova Heartbeat daemon (interval=${PULSE_INTERVAL}s)...${RESET}"
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
      STATUS_MODE=$(heartbeat_mode)
      STATUS_INTERVAL=$(heartbeat_interval "$STATUS_MODE")
      echo -e "${GREEN}💓 Heartbeat กำลังรัน (PID $PID)${RESET}"
      echo -e "  interval: ${STATUS_INTERVAL}s ($STATUS_MODE)"
      echo -e "  log: $LOG_FILE"
      echo -e "  $(tail -5 "$LOG_FILE" 2>/dev/null || echo '(no log)')"
    else
      echo -e "${YELLOW}⏸️  Heartbeat ไม่ได้รัน${RESET}"
      echo -e "  รัน: bash scripts/heartbeat.sh start"
    fi
    ;;

  once|pulse)
    _do_pulse
    ;;

  *)
    echo "Usage: $0 {start|stop|status|once|pulse}"
    echo "  start  — เริ่ม background daemon (ทุก 15 นาที)"
    echo "  stop   — หยุด daemon"
    echo "  status — ดูสถานะ"
    echo "  once   — pulse ครั้งเดียว"
    ;;
esac
