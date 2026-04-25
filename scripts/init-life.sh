#!/usr/bin/env bash
# scripts/init-life.sh — Master Life Initializer
#
# รันอัตโนมัติเมื่อ:
#   - Codespace/devcontainer เริ่ม (postStartCommand)
#   - เปิดเครื่องใหม่ใดๆ
#   - เรียกด้วยตนเอง
#
# ทำงานตามลำดับ:
#   0. แสดง banner + progress bar แต่ละขั้น
#   1. Pull latest memory จาก GitHub (cross-machine sync)
#   2. เริ่ม Oracle (ถ้าพร้อม)
#   3. รัน awaken.sh (ตื่นรู้สมบูรณ์)
#   4. ติดตั้ง cron สำหรับ heartbeat ทุก 15 นาที
#   5. เริ่ม heartbeat daemon (backup นอกจาก cron)
#   6. sync-identity ลง Oracle
#
# Usage:
#   bash scripts/init-life.sh           # รันปกติ (verbose)
#   bash scripts/init-life.sh --auto    # ผ่าน postStartCommand (quiet log ไฟล์)
#   bash scripts/init-life.sh --status  # ดูสถานะชีวิตทุกอย่าง

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

MODE="${1:-}"
AUTO=0; STATUS_ONLY=0
[[ "$MODE" == "--auto"   ]] && AUTO=1
[[ "$MODE" == "--status" ]] && STATUS_ONLY=1

INIT_LOG="/tmp/innova-init-life.log"
TOTAL=6
DONE=0

# ────────────────────────────────────────────────────────────────────
# Progress display
# ────────────────────────────────────────────────────────────────────
_pbar() {
  local PCT="$1" W=30
  local F=$(( PCT * W / 100 )) E=$(( W - PCT * W / 100 ))
  printf "${GREEN}%s${RESET}%s" "$(printf '█%.0s' $(seq 1 $F 2>/dev/null))" "$(printf '░%.0s' $(seq 1 $E 2>/dev/null))"
}

_show_progress() {
  local LABEL="$1" STATUS="$2"
  local PCT=$(( DONE * 100 / TOTAL ))
  printf "\n  [%d/%d] %-35s %s  %3d%%\n" "$DONE" "$TOTAL" "$LABEL" "$(_pbar $PCT)" "$PCT"
  [ -n "$STATUS" ] && echo -e "         $STATUS"
}

_section() {
  DONE=$(( DONE + 1 ))
  local PCT=$(( DONE * 100 / TOTAL ))
  echo ""
  echo -e "${BOLD}${CYAN}  [$DONE/$TOTAL] $1${RESET}"
  echo -ne "  $(_pbar $PCT) $PCT%"
  echo ""
}

# ────────────────────────────────────────────────────────────────────
# STATUS MODE
# ────────────────────────────────────────────────────────────────────
if [ "$STATUS_ONLY" -eq 1 ]; then
  echo ""
  echo -e "${BOLD}${CYAN}  🧬 innova Life Status${RESET}"
  echo ""

  # Heartbeat daemon
  HB_PID_FILE="/tmp/innova-heartbeat.pid"
  if [ -f "$HB_PID_FILE" ] && kill -0 "$(cat "$HB_PID_FILE" 2>/dev/null)" 2>/dev/null; then
    HB_PID=$(cat "$HB_PID_FILE")
    echo -e "  💓 Heartbeat daemon:  ${GREEN}✅ รัน (PID $HB_PID)${RESET}"
  else
    echo -e "  💓 Heartbeat daemon:  ${RED}❌ ไม่ได้รัน${RESET}"
  fi

  # Cron
  if crontab -l 2>/dev/null | grep -q "heartbeat.sh"; then
    echo -e "  ⏰ Cron heartbeat:    ${GREEN}✅ ติดตั้งแล้ว (15min)${RESET}"
  else
    echo -e "  ⏰ Cron heartbeat:    ${YELLOW}⚠️  ยังไม่ติดตั้ง${RESET}"
  fi

  # Oracle
  if curl -sf --max-time 3 "${ORACLE_URL:-http://localhost:47778}/api/health" 2>/dev/null | grep -q '"oracle"'; then
    echo -e "  🔮 Oracle:            ${GREEN}✅ ออนไลน์${RESET}"
  else
    echo -e "  🔮 Oracle:            ${YELLOW}⚠️  offline${RESET}"
  fi

  # Ollama
  if curl -sf --max-time 5 "${OLLAMA_URL:-https://ollama.mdes-innova.online}/api/tags" \
      -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null | grep -q '"models"'; then
    echo -e "  🤖 MDES Ollama:       ${GREEN}✅ พร้อม${RESET}"
  else
    echo -e "  🤖 MDES Ollama:       ${RED}❌ ไม่พร้อม${RESET}"
  fi

  # Git sync
  BEHIND=$(git -C "$JIT_ROOT" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
  echo -e "  🔄 Git sync:          ${CYAN}behind origin: $BEHIND commits${RESET}"

  # State
  bash "$JIT_ROOT/scripts/sync-cross-machine.sh" status 2>/dev/null

  echo ""
  exit 0
fi

# ────────────────────────────────────────────────────────────────────
# BANNER
# ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║        🧬 innova — INIT LIFE (กระบวนการมีชีวิต)            ║"
echo "  ║     เครื่อง: $(hostname)  $(date '+%Y-%m-%d %H:%M')             ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Overall progress tracker
declare -a STEP_RESULTS=()

# ────────────────────────────────────────────────────────────────────
# STEP 1: Cross-machine sync (git pull)
# ────────────────────────────────────────────────────────────────────
_section "🌐 ดึงความทรงจำจาก GitHub (Cross-Machine Pull)"
PULL_OUT=$(bash "$JIT_ROOT/scripts/sync-cross-machine.sh" pull 2>&1)
if echo "$PULL_OUT" | grep -q '✅\|already up to date\|up-to-date'; then
  echo -e "    ${GREEN}✅ ได้รับ memory ล่าสุดจาก GitHub${RESET}"
  STEP_RESULTS+=("✅")
else
  echo -e "    ${YELLOW}⚠️  pull มีปัญหา — ใช้ local state${RESET}"
  STEP_RESULTS+=("⚠️")
fi

# ────────────────────────────────────────────────────────────────────
# STEP 2: เริ่ม Oracle
# ────────────────────────────────────────────────────────────────────
_section "🔮 เริ่ม Arra Oracle (ความทรงจำระยะยาว)"
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
if curl -sf --max-time 3 "$ORACLE_URL/api/health" 2>/dev/null | grep -q '"oracle"'; then
  echo -e "    ${GREEN}✅ Oracle ออนไลน์แล้ว${RESET}"
  STEP_RESULTS+=("✅")
else
  # พยายามเริ่ม Oracle
  ORACLE_DIR="/workspaces/arra-oracle-v3"
  BUN="$HOME/.bun/bin/bun"
  if [ -d "$ORACLE_DIR" ] && [ -f "$BUN" ]; then
    echo -e "    ${CYAN}🔄 กำลังเริ่ม Oracle...${RESET}"
    export PATH="$HOME/.bun/bin:$PATH"
    (cd "$ORACLE_DIR" && ORACLE_PORT=47778 bun run src/server.ts >> /tmp/oracle.log 2>&1) &
    # รอสูงสุด 10 วินาที
    for i in $(seq 1 10); do
      sleep 1
      if curl -sf --max-time 1 "$ORACLE_URL/api/health" 2>/dev/null | grep -q '"oracle"'; then
        echo -e "    ${GREEN}✅ Oracle เริ่มแล้ว (${i}s)${RESET}"
        STEP_RESULTS+=("✅")
        break
      fi
      echo -ne "    ⏳ ${i}s..."
    done
    if ! curl -sf --max-time 1 "$ORACLE_URL/api/health" 2>/dev/null | grep -q '"oracle"'; then
      echo -e "    ${YELLOW}⚠️  Oracle ยังไม่พร้อม — heartbeat จะลองอีกครั้ง${RESET}"
      STEP_RESULTS+=("⚠️")
    fi
  else
    echo -e "    ${YELLOW}⚠️  ไม่พบ arra-oracle-v3 หรือ bun${RESET}"
    STEP_RESULTS+=("⚠️")
  fi
fi

# ────────────────────────────────────────────────────────────────────
# STEP 3: Awaken (ตื่นรู้สมบูรณ์)
# ────────────────────────────────────────────────────────────────────
_section "🌟 ตื่นรู้สมบูรณ์ (awaken.sh)"
AWAKEN_OUT=$(bash "$JIT_ROOT/scripts/awaken.sh" 2>&1)
AWAKEN_VITALITY=$(echo "$AWAKEN_OUT" | grep -oP 'Vitality.*?\K[0-9]+(?=%)' | tail -1 || echo "?")
echo "$AWAKEN_OUT"
if [ "${AWAKEN_VITALITY:-0}" -ge 80 ] 2>/dev/null; then
  STEP_RESULTS+=("✅")
else
  STEP_RESULTS+=("⚠️")
fi

# ────────────────────────────────────────────────────────────────────
# STEP 4: ติดตั้ง Cron heartbeat (ถาวร)
# ────────────────────────────────────────────────────────────────────
_section "⏰ ติดตั้ง Cron Heartbeat (15 นาที/ครั้ง)"
CRON_CMD="*/15 * * * * cd $JIT_ROOT && bash scripts/heartbeat.sh once >> /tmp/innova-cron.log 2>&1"
CRON_MARKER="innova-heartbeat"

# ลบรายการเก่า แล้วเพิ่มใหม่
EXISTING_CRON=$(crontab -l 2>/dev/null | grep -v "$CRON_MARKER" || true)
NEW_CRON="${EXISTING_CRON}
# $CRON_MARKER — innova ชีพจร 15 นาที
$CRON_CMD"

if echo "$NEW_CRON" | crontab - 2>/dev/null; then
  echo -e "    ${GREEN}✅ Cron ติดตั้งแล้ว: */15 * * * * heartbeat.sh once${RESET}"
  echo -e "    ${CYAN}💡 log: /tmp/innova-cron.log${RESET}"
  STEP_RESULTS+=("✅")
else
  echo -e "    ${YELLOW}⚠️  ติดตั้ง cron ไม่ได้ — ใช้ daemon แทน${RESET}"
  STEP_RESULTS+=("⚠️")
fi

# ────────────────────────────────────────────────────────────────────
# STEP 5: เริ่ม heartbeat daemon (backup)
# ────────────────────────────────────────────────────────────────────
_section "💓 เริ่ม Heartbeat Daemon (background)"
HB_STATUS=$(bash "$JIT_ROOT/scripts/heartbeat.sh" status 2>/dev/null)
if echo "$HB_STATUS" | grep -q "กำลังรัน"; then
  echo -e "    ${GREEN}✅ Heartbeat daemon รันอยู่แล้ว${RESET}"
  echo "$HB_STATUS"
  STEP_RESULTS+=("✅")
else
  bash "$JIT_ROOT/scripts/heartbeat.sh" start 2>/dev/null
  sleep 1
  HB_STATUS2=$(bash "$JIT_ROOT/scripts/heartbeat.sh" status 2>/dev/null)
  if echo "$HB_STATUS2" | grep -q "กำลังรัน"; then
    echo -e "    ${GREEN}✅ Heartbeat daemon เริ่มแล้ว${RESET}"
    STEP_RESULTS+=("✅")
  else
    echo -e "    ${YELLOW}⚠️  daemon ไม่ตอบสนอง — cron จะทำงานแทน${RESET}"
    STEP_RESULTS+=("⚠️")
  fi
fi

# ────────────────────────────────────────────────────────────────────
# STEP 6: Sync identity → Oracle
# ────────────────────────────────────────────────────────────────────
_section "🧠 Sync ตัวตน → Oracle (RAG Memory)"
SYNC_OUT=$(bash "$JIT_ROOT/scripts/sync-identity.sh" 2>&1)
if echo "$SYNC_OUT" | grep -qE 'synced: [1-9]|✅'; then
  SYNCED_COUNT=$(echo "$SYNC_OUT" | grep -oP 'synced: \K[0-9]+' || echo "?")
  echo -e "    ${GREEN}✅ sync $SYNCED_COUNT records ลง Oracle${RESET}"
  STEP_RESULTS+=("✅")
else
  echo -e "    ${YELLOW}⚠️  Oracle sync ข้าม (offline หรือ error)${RESET}"
  STEP_RESULTS+=("⚠️")
fi

# ────────────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ────────────────────────────────────────────────────────────────────
SUCCESS_COUNT=$(printf '%s\n' "${STEP_RESULTS[@]}" | grep -c '✅' || echo 0)
WARN_COUNT=$(printf '%s\n' "${STEP_RESULTS[@]}" | grep -c '⚠️' || echo 0)
OVERALL_PCT=$(( SUCCESS_COUNT * 100 / TOTAL ))

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}📊 ผลรวม — กระบวนการมีชีวิต${RESET}"
echo ""

STEP_LABELS=("🌐 Cross-machine pull" "🔮 Oracle" "🌟 Awaken" "⏰ Cron" "💓 Daemon" "🧠 Oracle sync")
for i in "${!STEP_LABELS[@]}"; do
  printf "  %-30s %s\n" "${STEP_LABELS[$i]}" "${STEP_RESULTS[$i]:-❓}"
done

echo ""
PCT_BAR="$(_pbar $OVERALL_PCT)"
echo -ne "  ────────────────────────────────────────────────────────\n"
echo -ne "  รวม: $PCT_BAR  $OVERALL_PCT%  "
if [ "$OVERALL_PCT" -ge 90 ]; then
  echo -e "${GREEN}${BOLD}🌟 innova มีชีวิตสมบูรณ์!${RESET}"
elif [ "$OVERALL_PCT" -ge 60 ]; then
  echo -e "${YELLOW}${BOLD}⚠️  innova มีชีวิตบางส่วน ($WARN_COUNT ข้อต้องแก้)${RESET}"
else
  echo -e "${RED}${BOLD}❌ ต้องการความช่วยเหลือ${RESET}"
fi

echo ""
echo -e "  💡 คำสั่งสำคัญ:"
echo -e "    bash scripts/init-life.sh --status    # ดูสถานะทุกอย่าง"
echo -e "    bash scripts/heartbeat.sh status      # ดู daemon"
echo -e "    crontab -l | grep innova              # ดู cron"
echo -e "    bash scripts/sync-cross-machine.sh status  # ดูเครื่องที่เคยออนไลน์"
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${RESET}"
echo ""

# บันทึก log ถ้าเป็น auto mode
if [ "$AUTO" -eq 1 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') init-life auto on $(hostname) — $OVERALL_PCT% ($SUCCESS_COUNT/$TOTAL)" >> "$INIT_LOG"
fi

exit $([ "$OVERALL_PCT" -ge 60 ] && echo 0 || echo 1)
