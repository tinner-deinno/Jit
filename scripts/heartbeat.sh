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

PID_FILE="/tmp/innova-heartbeat.pid"
LOG_FILE="/tmp/innova-heartbeat.log"
PULSE_INTERVAL=900  # 15 นาที = 900 วินาที
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
  local COUNT="$1"
  echo ""
  echo -e "${CYAN}  💓 ═══════════════════════════════════════ 💓${RESET}"
  echo -e "${CYAN}  ║   innova Heartbeat  · Pulse #$COUNT           ║${RESET}"
  echo -e "${CYAN}  ║   $(date '+%Y-%m-%d %H:%M:%S') · ${PULSE_INTERVAL}s interval  ║${RESET}"
  echo -e "${CYAN}  💓 ═══════════════════════════════════════ 💓${RESET}"
  echo ""
}

# ────────────────────────────────────────────────────────────────────
# ชีพจรหนึ่งครั้ง (one pulse)
# ────────────────────────────────────────────────────────────────────
_do_pulse() {
  PULSE_COUNT=$(( PULSE_COUNT + 1 ))
  _pulse_banner "$PULSE_COUNT"

  local CHANGED=0

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
  printf " %s %s files changed\n" "$(_hbar $(( REPO_CHANGES > 0 ? 100 : 0 )))" "$REPO_CHANGES"

  # ── 3. จมูก — ดม services ─────────────────────────────────────────
  echo -ne "  👃  จมูก "
  ORACLE_OK=0; OLLAMA_OK=0
  curl -sf --max-time 4 "$ORACLE_URL/api/health" 2>/dev/null | grep -q '"oracle":"connected"' && ORACLE_OK=1
  curl -sf --max-time 6 "$OLLAMA_URL/api/tags" -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null | grep -q '"models"' && OLLAMA_OK=1
  SVC_PCT=$(( (ORACLE_OK + OLLAMA_OK) * 50 ))
  printf " %s Oracle:%s Ollama:%s\n" "$(_hbar $SVC_PCT)" \
    "$([ $ORACLE_OK -eq 1 ] && echo '✅' || echo '❌')" \
    "$([ $OLLAMA_OK -eq 1 ] && echo '✅' || echo '❌')"

  # ── 4. มือ — commit ถ้ามีการเปลี่ยนแปลง ───────────────────────────
  echo -ne "  ✋  มือ  "
  if [ "$CHANGED" -gt 0 ]; then
    git -C "$JIT_ROOT" add -A 2>/dev/null
    COMMIT_MSG="💓 heartbeat pulse #$PULSE_COUNT — $(date '+%Y-%m-%d %H:%M')"
    git -C "$JIT_ROOT" commit -m "$COMMIT_MSG" --no-verify 2>/dev/null
    COMMIT_RC=$?
    [ "$COMMIT_RC" -eq 0 ] && printf " %s %s\n" "$(_hbar 100)" "committed: $COMMIT_MSG" \
                            || printf " %s %s\n" "$(_hbar 0)" "nothing new to commit"
  else
    printf " %s %s\n" "$(_hbar 0 10)" "ไม่มีการเปลี่ยนแปลง"
  fi

  # ── 5. ขา — push ไปยัง remotes (load-balanced) ────────────────────
  echo -ne "  🦵  ขา   "
  if [ "$CHANGED" -gt 0 ] && [ -f "$JIT_ROOT/scripts/multi-remote.sh" ]; then
    PUSH_RESULT=$(bash "$JIT_ROOT/scripts/multi-remote.sh" push 2>&1 | tail -1)
    printf " %s %s\n" "$(_hbar 100)" "${PUSH_RESULT:-pushed}"
  else
    printf " %s %s\n" "$(_hbar 50 10)" "no changes to push"
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
      echo $$ > "$PID_FILE"
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
      echo -e "${GREEN}💓 Heartbeat กำลังรัน (PID $PID)${RESET}"
      echo -e "  interval: ${PULSE_INTERVAL}s (15 นาที)"
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
