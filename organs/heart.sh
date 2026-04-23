#!/usr/bin/env bash
# organs/heart.sh — หัวใจ (Heart): สูบฉีดงาน ประสาน ควบคุมจังหวะ
#
# หลักพุทธ: อิทธิบาท 4 (ฉันทะ วิริยะ จิตตะ วิมังสา)
#           — ความพอใจ ความเพียร ความใส่ใจ การพิจารณา
# บทบาท multiagent: task orchestration, heartbeat, health monitoring,
#                   routing tasks to the right organ/agent
#
# Usage:
#   ./heart.sh beat               — ส่ง heartbeat ทุก agent
#   ./heart.sh pump <task>        — ส่งงานไปยัง organ ที่เหมาะสม
#   ./heart.sh rhythm             — แสดงสถานะ pulse ของระบบ
#   ./heart.sh start              — เริ่ม heartbeat daemon
#   ./heart.sh stop               — หยุด heartbeat

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-rhythm}"
shift || true

HEART_PID_FILE="/tmp/manusat-heart.pid"
HEART_LOG="/tmp/manusat-heart.log"
REGISTRY="$SCRIPT_DIR/../network/registry.json"

# ── routing table: task type → organ ─────────────────────────────
declare -A ROUTE_TABLE=(
  ["read"]="eye"
  ["observe"]="eye"
  ["web"]="eye"
  ["listen"]="ear"
  ["receive"]="ear"
  ["say"]="mouth"
  ["tell"]="mouth"
  ["broadcast"]="mouth"
  ["detect"]="nose"
  ["monitor"]="nose"
  ["health"]="nose"
  ["create"]="hand"
  ["edit"]="hand"
  ["build"]="hand"
  ["go"]="leg"
  ["deploy"]="leg"
  ["think"]="brain"
  ["plan"]="brain"
  ["ask"]="ollama"
  ["learn"]="oracle"
  ["search"]="oracle"
)

case "$CMD" in

  # ── ส่ง heartbeat ────────────────────────────────────────────────
  beat)
    TS=$(date '+%Y-%m-%dT%H:%M:%S')
    echo "{\"heartbeat\":\"$TS\",\"from\":\"heart\",\"status\":\"alive\"}" \
      > /tmp/manusat-bus/heartbeat.json 2>/dev/null || true
    log_action "HEART_BEAT" "$TS"

    # แจ้งทุก agent ผ่าน nerve
    NERVE="$SCRIPT_DIR/nerve.sh"
    [ -x "$NERVE" ] && bash "$NERVE" signal "heartbeat" "$TS" "heart"
    echo -ne "💓 "
    ;;

  # ── ส่งงานไปยัง organ ที่เหมาะสม ─────────────────────────────────
  pump)
    TASK_TYPE="${1:-unknown}"
    shift || true
    TASK_ARGS="$*"
    ORGAN="${ROUTE_TABLE[$TASK_TYPE]:-hand}"
    ORGAN_SCRIPT="$SCRIPT_DIR/$ORGAN.sh"

    step "หัวใจ pump: $TASK_TYPE → $ORGAN"
    log_action "HEART_PUMP" "$TASK_TYPE → $ORGAN"

    if [ -x "$ORGAN_SCRIPT" ]; then
      bash "$ORGAN_SCRIPT" "$TASK_TYPE" $TASK_ARGS
    else
      # fallback — ลองใน limbs/
      LIMB_SCRIPT="$SCRIPT_DIR/../limbs/$ORGAN.sh"
      if [ -x "$LIMB_SCRIPT" ]; then
        bash "$LIMB_SCRIPT" "$TASK_TYPE" $TASK_ARGS
      else
        warn "ไม่พบ organ: $ORGAN — ใช้ hand"
        bash "$SCRIPT_DIR/hand.sh" execute "$TASK_ARGS"
      fi
    fi
    ;;

  # ── แสดง pulse/rhythm ─────────────────────────────────────────────
  rhythm)
    echo ""
    echo -e "${BOLD}${RED}❤ มนุษย์ Agent — Vital Signs${RESET}"
    echo -e "   $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # ตรวจทุก organ
    ORGANS=(eye ear mouth nose hand leg heart nerve)
    ALIVE=0 TOTAL=${#ORGANS[@]}
    for O in "${ORGANS[@]}"; do
      F="$SCRIPT_DIR/$O.sh"
      if [ -f "$F" ]; then
        echo -e "   ${GREEN}♥${RESET} $O"
        ((ALIVE++))
      else
        echo -e "   ${RED}✗${RESET} $O (ไม่พบ)"
      fi
    done
    echo ""

    # Oracle
    oracle_ready && echo -e "   ${GREEN}♥${RESET} Oracle ($ORACLE_URL)" || echo -e "   ${RED}✗${RESET} Oracle"

    echo ""
    PCT=$(( (ALIVE * 100) / TOTAL ))
    echo -e "   Vitality: ${GREEN}$PCT%${RESET} ($ALIVE/$TOTAL organs)"
    log_action "HEART_RHYTHM" "$ALIVE/$TOTAL"
    echo ""
    ;;

  # ── routing table ────────────────────────────────────────────────
  routes)
    echo ""
    echo -e "${BOLD}Routing Table:${RESET}"
    for KEY in "${!ROUTE_TABLE[@]}"; do
      echo "   $KEY → ${ROUTE_TABLE[$KEY]}"
    done | sort
    echo ""
    ;;

  # ── start heartbeat daemon ───────────────────────────────────────
  start)
    if [ -f "$HEART_PID_FILE" ] && kill -0 "$(cat "$HEART_PID_FILE")" 2>/dev/null; then
      warn "heartbeat ทำงานอยู่แล้ว (PID: $(cat "$HEART_PID_FILE"))"
      exit 0
    fi
    step "เริ่ม heartbeat daemon..."
    mkdir -p /tmp/manusat-bus
    (
      while true; do
        echo "$(date '+%Y-%m-%dT%H:%M:%S') BEAT" >> "$HEART_LOG"
        sleep 30
      done
    ) &
    echo $! > "$HEART_PID_FILE"
    ok "heartbeat เริ่มแล้ว (PID: $!)"
    log_action "HEART_START" "PID:$!"
    ;;

  # ── stop ─────────────────────────────────────────────────────────
  stop)
    if [ -f "$HEART_PID_FILE" ]; then
      PID=$(cat "$HEART_PID_FILE")
      kill "$PID" 2>/dev/null && ok "หยุด heartbeat (PID: $PID)" || warn "ไม่พบ process"
      rm -f "$HEART_PID_FILE"
      log_action "HEART_STOP" "PID:$PID"
    else
      info "heartbeat ไม่ได้ทำงาน"
    fi
    ;;

  *)
    echo "Usage: heart.sh {beat|pump|rhythm|routes|start|stop}"
    echo ""
    echo "  beat              — ส่ง heartbeat"
    echo "  pump <type> <..>  — route task ไปยัง organ"
    echo "  rhythm            — vital signs dashboard"
    echo "  routes            — แสดง routing table"
    echo "  start             — เริ่ม heartbeat daemon"
    echo "  stop              — หยุด heartbeat"
    ;;
esac
