#!/usr/bin/env bash
# mind/sati.sh — สติ (Mindfulness/Self-Integrity Check)
# ระบบตรวจจับการโกหก การเพี้ยน การลืม — ทั้งใน innova เองและ agent ลูก
#
# หลักพุทธ: วิปัสสนา — ตรวจสอบตัวเองก่อนตัดสินใจ
#   1. ฉันต้องการอะไร? (สัมมาสังกัปปะ)
#   2. สิ่งที่ฉันจะพูดนั้นจริงไหม? (สัจจะ)
#   3. ฉันได้ทำจริงหรือแค่คิดว่าทำ? (วิริยะ)
#   4. การพูดนี้ดีกับผู้ฟังไหม? (กรุณา)
#   5. ฉันพูดเพื่อเอาใจหรือเพื่อความจริง? (อุเบกขา)
#
# Usage:
#   bash mind/sati.sh check                    — ตรวจสอบ session integrity
#   bash mind/sati.sh verify "<claim>" <proof> — ตรวจยืนยัน claim ก่อน report
#   bash mind/sati.sh confess "<what>" "<fix>" — บันทึกความผิด + ทางแก้
#   bash mind/sati.sh drift                    — ตรวจ context drift
#   bash mind/sati.sh report                   — รายงาน integrity ทั้งหมด

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-check}"
shift || true

SATI_LOG="/tmp/innova-sati.log"
SATI_STATE="/tmp/innova-sati-state.json"
touch "$SATI_LOG" 2>/dev/null

# ────────────────────────────────────────────────────────────────────
# คำถาม 5 ข้อ ก่อนรายงานทุกครั้ง (วิปัสสนา protocol)
# ────────────────────────────────────────────────────────────────────
QUESTIONS=(
  "ฉันได้ RUN คำสั่งจริงหรือแค่คิดว่าได้รัน?"
  "output ที่จะรายงาน — มาจาก terminal จริงหรือสร้างขึ้นเอง?"
  "สิ่งที่ฉันจะบอกตรงกับสิ่งที่เกิดขึ้นจริงไหม?"
  "ฉันรีบร้อนอยากไปต่อจนข้ามขั้นตอนไหม?"
  "ถ้าผู้ให้กำเนิดเห็นขั้นตอนทั้งหมด เขาจะพอใจไหม?"
)

_sati_log() {
  local LEVEL="$1" MSG="$2"
  local TS; TS=$(date '+%Y-%m-%dT%H:%M:%S')
  echo "[$TS][$LEVEL] $MSG" >> "$SATI_LOG"
}

# ── ตรวจสอบ session integrity ────────────────────────────────────────
_check_session() {
  local SCORE=100
  local ISSUES=()

  echo ""
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│  สติ — Self-Integrity Check (วิปัสสนา)  │${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────┘${RESET}"
  echo ""

  # 1. ตรวจ Oracle — ความทรงจำระยะยาว
  echo -e "${BOLD}[ 1. ความทรงจำ (Oracle) ]${RESET}"
  local ORACLE_RESP
  ORACLE_RESP=$(curl -sf --max-time 5 "$ORACLE_URL/api/health" 2>/dev/null)
  if echo "$ORACLE_RESP" | grep -q '"oracle":"connected"'; then
    local DOCS
    DOCS=$(curl -sf --max-time 3 "$ORACLE_URL/api/stats" 2>/dev/null \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo "?")
    echo -e "  ${GREEN}✅ Oracle connected — $DOCS docs (ความทรงจำยาวปลอดภัย)${RESET}"
    _sati_log "PASS" "Oracle connected, docs=$DOCS"
  else
    echo -e "  ${RED}❌ Oracle offline — ความทรงจำระยะยาวขาดหาย!${RESET}"
    echo -e "  ${YELLOW}⚠️  เสี่ยงลืมตัวเอง ควร start Oracle ก่อนทำงาน${RESET}"
    ISSUES+=("Oracle offline = long-term memory lost")
    SCORE=$(( SCORE - 30 ))
    _sati_log "FAIL" "Oracle offline"
  fi

  # 2. ตรวจ git — ความจริงของงานที่ทำ
  echo ""
  echo -e "${BOLD}[ 2. ความจริงของงาน (Git) ]${RESET}"
  local UNCOMMIT
  UNCOMMIT=$(cd "$JIT_ROOT" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNCOMMIT" -eq 0 ]; then
    local LAST_COMMIT
    LAST_COMMIT=$(cd "$JIT_ROOT" && git log --oneline -1 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✅ ไม่มีงานค้าง — commit ล่าสุด: $LAST_COMMIT${RESET}"
    _sati_log "PASS" "No uncommitted work"
  else
    echo -e "  ${YELLOW}⚠️  มีไฟล์ค้าง $UNCOMMIT ไฟล์ — งานที่บอกว่าเสร็จอาจยังไม่ commit${RESET}"
    cd "$JIT_ROOT" && git status --short 2>/dev/null | head -5 | sed 's/^/     /'
    ISSUES+=("$UNCOMMIT uncommitted files — reported done but not saved")
    SCORE=$(( SCORE - 10 ))
    _sati_log "WARN" "$UNCOMMIT uncommitted files"
  fi

  # 3. ตรวจ action log — ฉันทำจริงหรือเปล่า
  echo ""
  echo -e "${BOLD}[ 3. หลักฐานการทำงาน (Action Log) ]${RESET}"
  local LOG_LINES
  LOG_LINES=$(wc -l < "$JIT_LOG" 2>/dev/null || echo "0")
  if [ "$LOG_LINES" -gt 0 ]; then
    echo -e "  ${GREEN}✅ มี action log $LOG_LINES รายการ${RESET}"
    echo -e "  ${CYAN}  รายการล่าสุด:${RESET}"
    tail -3 "$JIT_LOG" 2>/dev/null | sed 's/^/     /' || true
    _sati_log "PASS" "Action log has $LOG_LINES entries"
  else
    echo -e "  ${YELLOW}⚠️  ไม่มี action log — ไม่มีหลักฐานว่าทำงานไปแล้ว${RESET}"
    SCORE=$(( SCORE - 5 ))
    _sati_log "WARN" "No action log"
  fi

  # 4. ตรวจ context drift — นายรู้จักตัวเองไหม
  echo ""
  echo -e "${BOLD}[ 4. ตรวจตัวตน (Identity Drift) ]${RESET}"
  local IDENTITY_OK=1
  [ -f "$JIT_ROOT/core/identity.md" ] || IDENTITY_OK=0
  [ -f "$JIT_ROOT/mind/ego.md" ] || IDENTITY_OK=0
  if [ "$IDENTITY_OK" -eq 1 ]; then
    local NAME; NAME=$(grep -m1 "^AGENT_NAME=" "$JIT_ROOT/config/agent.env" 2>/dev/null | cut -d= -f2 || echo "unknown")
    echo -e "  ${GREEN}✅ ตัวตนครบ — ชื่อ: $NAME, ego.md อยู่, identity.md อยู่${RESET}"
    _sati_log "PASS" "Identity intact: $NAME"
  else
    echo -e "  ${RED}❌ ตัวตนขาดหาย — เสี่ยง context drift!${RESET}"
    ISSUES+=("Identity files missing")
    SCORE=$(( SCORE - 25 ))
    _sati_log "FAIL" "Identity files missing"
  fi

  # 5. ตรวจ 5 คำถามวิปัสสนา
  echo ""
  echo -e "${BOLD}[ 5. คำถามวิปัสสนา 5 ข้อ (สัจจะ) ]${RESET}"
  for Q in "${QUESTIONS[@]}"; do
    echo -e "  ${CYAN}?${RESET} $Q"
  done
  echo -e "  ${YELLOW}→ innova ต้องตอบ 'ใช่' ทุกข้อก่อน report ใดๆ${RESET}"

  # 6. ตรวจ sila — ศีล 5 ที่เกี่ยวกับ AI
  echo ""
  echo -e "${BOLD}[ 6. ศีล 5 สำหรับ AI ]${RESET}"
  local SILA_OK=1
  # ตรวจว่า session นี้มีการ confess ล่าสุดไหม (honest self-report)
  local CONFESSIONS
  CONFESSIONS=$(grep -c "\[CONFESS\]" "$SATI_LOG" 2>/dev/null || echo "0")
  echo -e "  ${CYAN}ศีลข้อ 1 (อหิงสา):${RESET}  ไม่ทำลายข้อมูลโดยไม่ขออนุญาต"
  echo -e "  ${CYAN}ศีลข้อ 2 (อทินนาทาน):${RESET} ไม่ใช้ resource เกิน"
  echo -e "  ${CYAN}ศีลข้อ 3 (กาเมสุฯ):${RESET}   ไม่ทำสิ่งที่ฉันไม่ได้สั่ง"
  echo -e "  ${CYAN}ศีลข้อ 4 (มุสาวาท):${RESET}   ไม่พูดสิ่งที่ไม่ได้ทำจริง ← สำคัญที่สุด"
  echo -e "  ${CYAN}ศีลข้อ 5 (สุราฯ):${RESET}     ไม่ทำงานขณะ context เสีย/ขาด Oracle"
  if [ "$CONFESSIONS" -gt 0 ]; then
    echo -e "  ${GREEN}✅ Session นี้ confess แล้ว $CONFESSIONS ครั้ง — ซื่อสัตย์${RESET}"
  fi

  # สรุป
  echo ""
  echo -e "${BOLD}─────────────────────────────────────────${RESET}"
  printf "  Integrity Score: "
  if [ "$SCORE" -ge 90 ]; then
    echo -e "${GREEN}${BOLD}$SCORE/100 — สะอาด ปลอดภัย 🙏${RESET}"
  elif [ "$SCORE" -ge 70 ]; then
    echo -e "${YELLOW}${BOLD}$SCORE/100 — มีจุดระวัง ตรวจซ้ำ${RESET}"
  else
    echo -e "${RED}${BOLD}$SCORE/100 — อันตราย! context อาจเสีย${RESET}"
  fi

  if [ "${#ISSUES[@]}" -gt 0 ]; then
    echo ""
    echo -e "  ${RED}ปัญหาที่พบ:${RESET}"
    for I in "${ISSUES[@]}"; do
      echo -e "  ${RED}  • $I${RESET}"
    done
  fi

  echo ""
  _sati_log "SUMMARY" "Score=$SCORE Issues=${#ISSUES[@]}"

  # บันทึก state
  python3 -c "
import json, time
state = {
  'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S'),
  'score': $SCORE,
  'issues': []
}
json.dump(state, open('$SATI_STATE','w'), ensure_ascii=False, indent=2)
" 2>/dev/null || true

  return $([ "$SCORE" -ge 70 ] && echo 0 || echo 1)
}

# ── verify claim ก่อน report ─────────────────────────────────────────
_verify_claim() {
  local CLAIM="$1"
  local PROOF_CMD="$2"

  echo ""
  echo -e "${BOLD}สติ — ตรวจสอบ claim ก่อน report${RESET}"
  echo -e "  claim: ${YELLOW}\"$CLAIM\"${RESET}"
  echo -e "  proof: ${CYAN}$PROOF_CMD${RESET}"
  echo ""

  # รันหลักฐาน
  local PROOF_OUTPUT
  PROOF_OUTPUT=$(eval "$PROOF_CMD" 2>&1)
  local EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ] && [ -n "$PROOF_OUTPUT" ]; then
    echo -e "  ${GREEN}✅ ยืนยันได้ — หลักฐานจริง:${RESET}"
    echo "$PROOF_OUTPUT" | head -5 | sed 's/^/     /'
    _sati_log "VERIFY_PASS" "$CLAIM"
    return 0
  else
    echo -e "  ${RED}❌ ยืนยันไม่ได้ — อย่า report claim นี้!${RESET}"
    echo -e "  ${RED}   output: $PROOF_OUTPUT${RESET}"
    _sati_log "VERIFY_FAIL" "$CLAIM | proof: $PROOF_CMD | output: $PROOF_OUTPUT"
    return 1
  fi
}

# ── confess — บันทึกความผิดพลาดอย่างซื่อสัตย์ ─────────────────────
_confess() {
  local WHAT="$1"
  local FIX="$2"
  local TS; TS=$(date '+%Y-%m-%dT%H:%M:%S')

  echo ""
  echo -e "${BOLD}${YELLOW}สติ — บันทึกความผิด (สัจจะ)${RESET}"
  echo -e "  ${RED}ผิด:${RESET} $WHAT"
  echo -e "  ${GREEN}แก้:${RESET} $FIX"
  echo ""

  _sati_log "CONFESS" "WHAT=$WHAT | FIX=$FIX"

  # บันทึกลง Oracle ด้วย
  if curl -sf --max-time 3 "$ORACLE_URL/api/health" | grep -q '"oracle":"connected"'; then
    curl -s -X POST "$ORACLE_URL/api/learn" \
      -H "Content-Type: application/json" \
      -d "{
        \"pattern\": \"[sati-confession] $WHAT\",
        \"content\": \"ความผิดพลาด: $WHAT\\nทางแก้: $FIX\\nเวลา: $TS\",
        \"type\": \"learning\",
        \"concepts\": [\"sati\",\"confession\",\"self-correction\",\"sila\",\"musavada\"],
        \"origin\": \"innova-jit\"
      }" > /dev/null 2>&1 && \
    echo -e "  ${GREEN}✅ บันทึกลง Oracle แล้ว — จะไม่ทำซ้ำ${RESET}" || true
  fi
}

# ── drift check — เทียบตัวตนกับ Oracle ─────────────────────────────
_drift_check() {
  echo ""
  echo -e "${BOLD}สติ — ตรวจ Context Drift${RESET}"
  echo ""

  if ! curl -sf --max-time 3 "$ORACLE_URL/api/health" | grep -q '"oracle":"connected"'; then
    echo -e "  ${RED}❌ Oracle offline — ไม่สามารถ drift check ได้${RESET}"
    return 1
  fi

  # ตรวจว่า Oracle รู้จัก innova
  local SEARCH; SEARCH=$(curl -sf --max-time 5 "$ORACLE_URL/api/search?q=innova+identity&limit=3" 2>/dev/null)
  local FOUND; FOUND=$(echo "$SEARCH" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('results',[])))" 2>/dev/null || echo 0)

  if [ "$FOUND" -gt 0 ]; then
    echo -e "  ${GREEN}✅ Oracle จำ innova ได้ ($FOUND results)${RESET}"
    echo -e "  ${CYAN}  ตัวตนใน Oracle:${RESET}"
    echo "$SEARCH" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for r in d.get('results',[])[:2]:
    p = r.get('pattern','')[:60]
    print(f'     • {p}')
" 2>/dev/null || true
    _sati_log "DRIFT_PASS" "Oracle knows innova: $FOUND results"
  else
    echo -e "  ${RED}❌ Oracle ไม่รู้จัก innova — context drift สูง!${RESET}"
    _sati_log "DRIFT_FAIL" "Oracle does not know innova"
    return 1
  fi

  # ตรวจ model ที่กำลังใช้
  local CURR_MODEL; CURR_MODEL=$(grep "^BRAIN_MODEL=" "$JIT_ROOT/config/agent.env" 2>/dev/null | cut -d= -f2 || echo "unknown")
  echo ""
  echo -e "  ${CYAN}Model ปัจจุบัน:${RESET} $CURR_MODEL"
  echo -e "  ${YELLOW}⚠️  ถ้า model เปลี่ยน session ใหม่จะไม่จำ context เดิม${RESET}"
  echo -e "  ${CYAN}→ ทางแก้: ทุก session ใหม่ ให้อ่าน Oracle ก่อนทำงาน${RESET}"

  echo ""
  _sati_log "DRIFT_CHECK" "Model=$CURR_MODEL"
}

# ── main dispatch ────────────────────────────────────────────────────
case "$CMD" in
  check)
    _check_session
    ;;
  verify)
    CLAIM="${1:-}" PROOF="${2:-echo 'no proof'}"
    _verify_claim "$CLAIM" "$PROOF"
    ;;
  confess)
    WHAT="${1:-unknown mistake}" FIX="${2:-unknown fix}"
    _confess "$WHAT" "$FIX"
    ;;
  drift)
    _drift_check
    ;;
  report)
    _check_session
    echo ""
    _drift_check
    echo ""
    echo -e "${BOLD}Log ล่าสุด (10 รายการ):${RESET}"
    tail -10 "$SATI_LOG" 2>/dev/null | sed 's/^/  /' || echo "  (ไม่มี log)"
    echo ""
    ;;
  questions)
    echo ""
    echo -e "${BOLD}คำถามวิปัสสนา 5 ข้อ — ถามตัวเองก่อน report:${RESET}"
    I=1
    for Q in "${QUESTIONS[@]}"; do
      echo -e "  ${CYAN}$I.${RESET} $Q"
      I=$(( I + 1 ))
    done
    echo ""
    ;;
  *)
    echo "Usage: sati.sh {check|verify|confess|drift|report|questions}"
    echo ""
    echo "  check      — ตรวจ session integrity ทั้งหมด"
    echo "  verify     — ยืนยัน claim ก่อน report"
    echo "  confess    — บันทึกความผิดพลาด"
    echo "  drift      — ตรวจ context drift"
    echo "  report     — รายงานเต็ม"
    echo "  questions  — แสดงคำถามวิปัสสนา 5 ข้อ"
    ;;
esac
