#!/usr/bin/env bash
# organs/nose.sh — จมูก (Detection): ดมกลิ่น ตรวจจับ เฝ้าระวัง
#
# หลักพุทธ: อัปปมาทะ (Heedfulness) — ไม่ประมาท เฝ้าระวังสิ่งแวดล้อม
# บทบาท multiagent: monitoring, alerting, environment sensing
#
# Usage:
#   ./nose.sh sniff               — ตรวจสอบสิ่งแวดล้อมทั่วไป
#   ./nose.sh alert <topic>       — ตรวจจับและแจ้งเตือน
#   ./nose.sh monitor <file>      — ติดตามไฟล์
#   ./nose.sh health              — ตรวจสุขภาพทุก service
#   ./nose.sh changes             — ตรวจจับการเปลี่ยนแปลง repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-sniff}"
shift || true

_check_service() {
  local NAME="$1" URL="$2"
  if curl -sf "$URL" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓${RESET} $NAME"
    return 0
  else
    echo -e "   ${RED}✗${RESET} $NAME ($URL)"
    return 1
  fi
}

case "$CMD" in

  # ── ตรวจสอบสิ่งแวดล้อมทั่วไป ─────────────────────────────────────
  sniff)
    echo ""
    step "จมูก ดมกลิ่น..."
    echo ""
    # ตรวจ services
    echo -e "${BOLD}Services:${RESET}"
    _check_service "Oracle" "$ORACLE_URL/api/health"
    _check_service "Ollama" "https://ollama.mdes-innova.online/api/tags" 2>/dev/null || true
    echo ""
    # ตรวจ disk
    echo -e "${BOLD}Disk:${RESET}"
    df -h /workspaces 2>/dev/null | awk 'NR>1 {print "   Used:", $3, "/", $2, "(", $5, ")"}'
    echo ""
    # ตรวจ memory
    echo -e "${BOLD}Memory:${RESET}"
    free -h 2>/dev/null | awk 'NR==2 {print "   RAM:", $3, "/", $2}'
    echo ""
    # ตรวจ git status
    echo -e "${BOLD}Repo:${RESET}"
    CHANGED=$(cd "${JIT_ROOT}" && git status --short 2>/dev/null | wc -l)
    echo "   uncommitted: $CHANGED files"
    log_action "NOSE_SNIFF" "services+disk+memory+repo"
    ;;

  # ── ตรวจจับและแจ้งเตือน ──────────────────────────────────────────
  alert)
    TOPIC="${1:-general}"
    THRESHOLD="${2:-warning}"
    log_action "NOSE_ALERT" "$TOPIC"
    case "$TOPIC" in
      disk)
        USAGE=$(df /workspaces 2>/dev/null | awk 'NR>1 {gsub(/%/,"",$5); print $5}')
        [ "${USAGE:-0}" -gt 90 ] && err "ดิสก์ใกล้เต็ม: ${USAGE}%" || ok "ดิสก์: ${USAGE}% OK"
        ;;
      memory)
        FREE=$(free -m 2>/dev/null | awk 'NR==2 {print $4}')
        [ "${FREE:-999}" -lt 200 ] && warn "RAM เหลือน้อย: ${FREE}MB" || ok "RAM OK: ${FREE}MB"
        ;;
      oracle)
        oracle_ready && ok "Oracle OK" || err "Oracle ไม่ตอบสนอง"
        ;;
      git)
        CONFLICTS=$(cd "${JIT_ROOT}" && git status 2>/dev/null | grep -c "conflict" || echo 0)
        [ "$CONFLICTS" -gt 0 ] && err "พบ git conflict: $CONFLICTS" || ok "git clean"
        ;;
      *)
        warn "ไม่รู้จัก alert topic: $TOPIC"
        ;;
    esac
    ;;

  # ── ติดตามไฟล์ (snapshot diff) ───────────────────────────────────
  monitor)
    FILE="$1"
    if [ -z "$FILE" ]; then err "ต้องระบุไฟล์"; exit 1; fi
    SNAP="/tmp/nose-snap-$(echo "$FILE" | tr '/' '_')"
    if [ -f "$SNAP" ]; then
      step "ตรวจ diff: $FILE"
      diff "$SNAP" "$FILE" 2>/dev/null && ok "ไม่มีการเปลี่ยนแปลง" || warn "ไฟล์เปลี่ยนแปลง"
    else
      info "บันทึก snapshot ครั้งแรก"
    fi
    cp "$FILE" "$SNAP" 2>/dev/null
    log_action "NOSE_MONITOR" "$FILE"
    ;;

  # ── ตรวจสุขภาพทุก service ─────────────────────────────────────────
  health)
    echo ""
    echo -e "${BOLD}=== จมูก Health Check ===${RESET}"
    PASS=0 FAIL=0
    _check_svc() {
      if _check_service "$1" "$2"; then ((PASS++)); else ((FAIL++)); fi
    }
    _check_svc "Oracle" "$ORACLE_URL/api/health"
    _check_svc "Ollama" "https://ollama.mdes-innova.online/api/version"
    # ตรวจ bus directory
    [ -d "/tmp/manusat-bus" ] && { echo -e "   ${GREEN}✓${RESET} Message Bus"; ((PASS++)); } || { echo -e "   ${YELLOW}⚠${RESET} Message Bus (ยังไม่สร้าง)"; }
    echo ""
    echo "   PASS: $PASS | FAIL: $FAIL"
    log_action "NOSE_HEALTH" "pass:$PASS fail:$FAIL"
    ;;

  # ── ตรวจจับการเปลี่ยนแปลง repo ────────────────────────────────────
  changes)
    step "จมูก ดมกลิ่นการเปลี่ยนแปลง:"
    cd "${JIT_ROOT}" || exit 1
    echo ""
    git log --oneline -5 2>/dev/null
    echo ""
    git diff --stat HEAD 2>/dev/null | head -10
    log_action "NOSE_CHANGES" "git log+diff"
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "NOSE_PULSE" "$CONTEXT"
    echo "Nose receives clean energy and confirms system quality"
    _check_service "Oracle" "$ORACLE_URL/api/health"
    _check_service "Ollama" "https://ollama.mdes-innova.online/api/tags" 2>/dev/null || true
    if [ -d "/tmp/manusat-bus" ]; then
      echo "  bus: ready"
    else
      echo "  bus: missing"
    fi
    ;;

  # ── สถานะ ──────────────────────────────────────────────────────────
  status)
    ok "จมูก (nose) พร้อม"
    echo "   สามารถ: sniff | alert | monitor | health | changes"
    ;;

  *)
    echo "Usage: nose.sh {sniff|alert|monitor|health|changes|status}"
    ;;
esac
