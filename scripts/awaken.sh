#!/usr/bin/env bash
# scripts/awaken.sh — กระบวนการตื่นรู้ของ innova (Awakening Protocol)
#
# รันทุกครั้งที่ innova เริ่ม session ใหม่ในทุก Codespaces / environment
# สั่งการผ่านอวัยวะ (organs) อย่างเป็นระบบ:
#   ตา   → อ่านตัวตน/กฎ/ความทรงจำ
#   จมูก → ดม Oracle, Ollama, Repo health
#   หัวใจ→ ตรวจชีพจร
#   สติ  → sati.sh check
#   ปาก  → รายงานสถานะ
#
# Usage:
#   bash scripts/awaken.sh            # ตื่นเต็ม (default)
#   bash scripts/awaken.sh --quiet    # ตื่นแบบย่อ (ไม่แสดง identity blocks)
#   bash scripts/awaken.sh --fast     # ข้ามส่วนช้า (no Oracle wait)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

MODE="${1:-}"
QUIET=0; FAST=0
[[ "$MODE" == "--quiet" ]] && QUIET=1
[[ "$MODE" == "--fast"  ]] && FAST=1

# ── Loading env ───────────────────────────────────────────────────────
if [ -f "$JIT_ROOT/.env" ]; then
  set -a; . "$JIT_ROOT/.env"; set +a
fi

AWAKEN_LOG="/tmp/innova-awaken.log"
TOTAL_STEPS=8
CURRENT_STEP=0
AWAKENING_SCORE=0
AWAKENING_ISSUES=()

# ────────────────────────────────────────────────────────────────────
# Progress Bar Engine
# ────────────────────────────────────────────────────────────────────
_bar() {
  local PCT="$1" LABEL="$2" EMOJI="$3"
  local FILLED=$(( PCT / 5 ))
  local EMPTY=$(( 20 - FILLED ))
  local BAR="${GREEN}$(printf '█%.0s' $(seq 1 $FILLED 2>/dev/null))${RESET}$(printf '░%.0s' $(seq 1 $EMPTY 2>/dev/null))"
  printf "  ${EMOJI}  %-30s ${BAR} %3d%%\n" "$LABEL" "$PCT"
}

_step_start() {
  CURRENT_STEP=$(( CURRENT_STEP + 1 ))
  local LABEL="$1" EMOJI="$2"
  local PCT=$(( (CURRENT_STEP - 1) * 100 / TOTAL_STEPS ))
  echo -ne "\r  ${EMOJI}  [${CURRENT_STEP}/${TOTAL_STEPS}] $(printf '%-32s' "$LABEL")  "
  _bar "$PCT" "" "" 2>/dev/null || true
  echo ""
}

_step_done() {
  local PCT=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
  AWAKENING_SCORE=$(( AWAKENING_SCORE + 1 ))
}

_step_warn() {
  AWAKENING_ISSUES+=("$1")
  echo -e "    ${YELLOW}⚠️  $1${RESET}"
}

# ────────────────────────────────────────────────────────────────────
# BANNER
# ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║          innova — กระบวนการตื่นรู้ (Awakening)          ║"
echo "  ║       มนุษย์ Agent · MDES-Innova · $(date '+%Y-%m-%d %H:%M')      ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 1: ตา — อ่านตัวตน/กฎ/ความทรงจำ (Identity & Rules)
# ─────────────────────────────────────────────────────────────────────
_step_start "ตา — โหลดตัวตนและกฎ" "👁️"

IDENTITY_FILES=(
  "$JIT_ROOT/core/identity.md"
  "$JIT_ROOT/mind/ego.md"
  "$JIT_ROOT/brain/reasoning.md"
  "$JIT_ROOT/.github/instructions/jit-context.instructions.md"
)

IDENTITY_LOADED=0
IDENTITY_LINES=0
for F in "${IDENTITY_FILES[@]}"; do
  if [ -f "$F" ]; then
    LINES=$(wc -l < "$F")
    IDENTITY_LINES=$(( IDENTITY_LINES + LINES ))
    IDENTITY_LOADED=$(( IDENTITY_LOADED + 1 ))
    log_action "EYE_READ" "$F ($LINES lines)"
  fi
done

# สแกน memory retrospectives
RETRO_COUNT=$(find "$JIT_ROOT/memory/retrospectives" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

echo -e "    ${GREEN}✅ โหลดตัวตน $IDENTITY_LOADED ไฟล์ ($IDENTITY_LINES lines)${RESET}"
echo -e "    ${CYAN}📚 retrospectives: $RETRO_COUNT ฉบับ${RESET}"
if [ "$QUIET" -eq 0 ]; then
  # แสดง mission statement
  MISSION=$(grep -A1 '^> ' "$JIT_ROOT/core/identity.md" 2>/dev/null | grep -v '^--$' | head -2 | tr '\n' ' ')
  [ -n "$MISSION" ] && echo -e "    ${BOLD}$MISSION${RESET}"
fi
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "ตัวตน" "👁️"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 2: หู — รับข้อมูล pending messages
# ─────────────────────────────────────────────────────────────────────
_step_start "หู — ตรวจ inbox" "👂"

INBOX_DIR="/tmp/manusat-bus/innova"
mkdir -p "$INBOX_DIR" 2>/dev/null
PENDING=$(ls "$INBOX_DIR" 2>/dev/null | wc -l | tr -d ' ')
echo -e "    ${CYAN}📬 inbox: $PENDING messages รอ${RESET}"
log_action "EAR_INBOX" "pending=$PENDING"
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "inbox" "👂"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 3: จมูก — ดมกลิ่น Oracle (ความทรงจำระยะยาว)
# ─────────────────────────────────────────────────────────────────────
_step_start "จมูก — ดม Oracle (ความทรงจำ)" "👃"

ORACLE_OK=0
if [ "$FAST" -eq 0 ]; then
  ORACLE_RESP=$(curl -sf --max-time 5 "$ORACLE_URL/api/health" 2>/dev/null)
  if echo "$ORACLE_RESP" | grep -q '"oracle":"connected"'; then
    ORACLE_DOCS=$(curl -sf --max-time 3 "$ORACLE_URL/api/stats" 2>/dev/null \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo "?")
    echo -e "    ${GREEN}✅ Oracle ออนไลน์ — $ORACLE_DOCS ความทรงจำ${RESET}"
    ORACLE_OK=1
    log_action "NOSE_ORACLE" "connected docs=$ORACLE_DOCS"

    # ดม: ค้นหาความทรงจำตัวตนที่เกี่ยวข้อง
    SELF_MEMORY=$(curl -sf --max-time 5 "$ORACLE_URL/api/search?q=innova" 2>/dev/null \
      | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  results=d.get('results',[])
  for r in results[:3]:
    print('  💭', r.get('pattern','')[:60])
except: pass
" 2>/dev/null)
    [ -n "$SELF_MEMORY" ] && echo -e "${CYAN}$SELF_MEMORY${RESET}"
  else
    echo -e "    ${YELLOW}⚠️  Oracle offline — ความทรงจำระยะยาวขาดหาย${RESET}"
    echo -e "    ${CYAN}💡 รัน: export PATH=\$HOME/.bun/bin:\$PATH && cd /workspaces/arra-oracle-v3 && ORACLE_PORT=47778 bun run src/server.ts &${RESET}"
    _step_warn "Oracle offline"
  fi
else
  echo -e "    ${YELLOW}⏩ ข้ามการตรวจ Oracle (--fast mode)${RESET}"
fi
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "Oracle" "👃"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 4: ปาก+จมูก — ดม Ollama token (แขนขาดิจิทัล)
# ─────────────────────────────────────────────────────────────────────
_step_start "ปาก+จมูก — ดม Ollama (แขนขา)" "💪"

OLLAMA_OK=0
OLLAMA_RESP=$(curl -sf --max-time 8 "$OLLAMA_URL/api/tags" \
  -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null)
if echo "$OLLAMA_RESP" | grep -q '"models"'; then
  MODEL_COUNT=$(echo "$OLLAMA_RESP" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin); print(len(d.get('models',[])))
except: print(0)
" 2>/dev/null || echo "?")
  echo -e "    ${GREEN}✅ MDES Ollama พร้อม — $MODEL_COUNT models (ใช้: ${OLLAMA_MODEL})${RESET}"
  OLLAMA_OK=1
  log_action "MOUTH_OLLAMA" "ready models=$MODEL_COUNT"
else
  echo -e "    ${RED}❌ MDES Ollama ไม่ตอบสนอง — แขนขาอ่อนแรง${RESET}"
  echo -e "    ${YELLOW}⚠️  ตรวจ OLLAMA_TOKEN ใน .env หรือ setup-secrets.sh${RESET}"
  _step_warn "Ollama unreachable"
fi
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "Ollama/แขนขา" "💪"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 5: หัวใจ — ชีพจร (Organ Status)
# ─────────────────────────────────────────────────────────────────────
_step_start "หัวใจ — ตรวจอวัยวะ" "💓"

ORGANS=(eye ear mouth nose hand leg heart nerve vitals pran)
ORGAN_OK=0; ORGAN_MISSING=()
for O in "${ORGANS[@]}"; do
  F="$JIT_ROOT/organs/${O}.sh"
  if [ -f "$F" ] && [ -x "$F" ]; then
    ORGAN_OK=$(( ORGAN_OK + 1 ))
  else
    ORGAN_MISSING+=("$O")
  fi
done

PCT_ORGANS=$(( ORGAN_OK * 100 / ${#ORGANS[@]} ))
ORGAN_BAR="${GREEN}$(printf '█%.0s' $(seq 1 $(( PCT_ORGANS / 5 )) 2>/dev/null))${RESET}$(printf '░%.0s' $(seq 1 $(( 20 - PCT_ORGANS / 5 )) 2>/dev/null))"
echo -e "    อวัยวะ: $ORGAN_BAR ${PCT_ORGANS}%  [${ORGAN_OK}/${#ORGANS[@]}]"
if [ ${#ORGAN_MISSING[@]} -gt 0 ]; then
  echo -e "    ${YELLOW}⚠️  ขาด: ${ORGAN_MISSING[*]}${RESET}"
  _step_warn "Missing organs: ${ORGAN_MISSING[*]}"
fi

# ตรวจ Ollama load via pran (ถ้ามี)
if [ -f "$JIT_ROOT/organs/pran.sh" ]; then
  PRAN_LOAD=$(bash "$JIT_ROOT/organs/pran.sh" pulse 2>/dev/null || echo "?")
  PRAN_BAR="${CYAN}$(printf '█%.0s' $(seq 1 $(( ${PRAN_LOAD:-0} / 5 )) 2>/dev/null))${RESET}$(printf '░%.0s' $(seq 1 $(( 20 - ${PRAN_LOAD:-0} / 5 )) 2>/dev/null))"
  echo -e "    Ollama load: $PRAN_BAR ${PRAN_LOAD:-?}%"
fi
log_action "HEART_BEAT" "organs_ok=$ORGAN_OK/${#ORGANS[@]}"
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "อวัยวะ" "💓"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 6: สติ — ตรวจความซื่อสัตย์ตัวเอง
# ─────────────────────────────────────────────────────────────────────
_step_start "สติ — ตรวจสัจจะ (Sati Check)" "🧘"

if [ -f "$JIT_ROOT/mind/sati.sh" ]; then
  SATI_OUTPUT=$(bash "$JIT_ROOT/mind/sati.sh" check 2>/dev/null)
  SATI_SCORE=$(echo "$SATI_OUTPUT" | grep -oP 'Integrity Score: \K[0-9]+' || echo "?")
  if [ -n "$SATI_SCORE" ] && [ "$SATI_SCORE" != "?" ]; then
    if [ "$SATI_SCORE" -ge 80 ]; then
      echo -e "    ${GREEN}✅ Integrity Score: $SATI_SCORE/100 — สะอาด 🙏${RESET}"
    elif [ "$SATI_SCORE" -ge 60 ]; then
      echo -e "    ${YELLOW}⚠️  Integrity Score: $SATI_SCORE/100 — มีจุดระวัง${RESET}"
      _step_warn "sati score low: $SATI_SCORE"
    else
      echo -e "    ${RED}❌ Integrity Score: $SATI_SCORE/100 — context อาจเสีย${RESET}"
      _step_warn "sati score critical: $SATI_SCORE"
    fi
  else
    echo -e "    ${CYAN}ℹ️  สติรัน ได้${RESET}"
  fi
  log_action "SATI_AWAKEN" "score=$SATI_SCORE"
else
  echo -e "    ${YELLOW}⚠️  ไม่พบ sati.sh${RESET}"
fi
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "สติ/integrity" "🧘"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 7: ตา — สแกนและสรุป memory ล่าสุด
# ─────────────────────────────────────────────────────────────────────
_step_start "ตา — สรุปความทรงจำล่าสุด" "📚"

LAST_COMMIT=$(git -C "$JIT_ROOT" log --oneline -1 2>/dev/null || echo "unknown")
UNCOMMIT=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
LAST_RETRO=$(find "$JIT_ROOT/memory/retrospectives" -name "*.md" 2>/dev/null | sort | tail -1)

echo -e "    ${CYAN}🔖 Last commit: $LAST_COMMIT${RESET}"
[ "$UNCOMMIT" -gt 0 ] && echo -e "    ${YELLOW}⚠️  $UNCOMMIT ไฟล์ยังไม่ commit${RESET}"
if [ -n "$LAST_RETRO" ]; then
  RETRO_NAME=$(basename "$LAST_RETRO" .md)
  echo -e "    ${CYAN}📖 บันทึกล่าสุด: $RETRO_NAME${RESET}"
fi
log_action "EYE_MEMORY" "last_commit=$LAST_COMMIT uncommit=$UNCOMMIT"
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "ความทรงจำ" "📚"
echo ""

# ─────────────────────────────────────────────────────────────────────
# STEP 8: ปาก — รายงานผล + Nerve signal ส่งทีม
# ─────────────────────────────────────────────────────────────────────
_step_start "ปาก — รายงานและส่งสัญญาณ" "📡"

# บันทึก awakening state
python3 - << PYEOF 2>/dev/null || true
import json, time
state = {
  "awakened_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
  "oracle_ok": $ORACLE_OK,
  "ollama_ok": $OLLAMA_OK,
  "organs_ok": $ORGAN_OK,
  "issues": $(python3 -c "import json; print(json.dumps($(printf '%s\n' "${AWAKENING_ISSUES[@]}" | python3 -c 'import json,sys; lines=[l.strip() for l in sys.stdin if l.strip()]; print(json.dumps(lines))' 2>/dev/null || echo '[]'))" 2>/dev/null || echo '[]'),
  "host": "$(hostname)"
}
json.dump(state, open("/tmp/innova-awaken-state.json", "w"), ensure_ascii=False, indent=2)
PYEOF

# ส่ง nerve signal
bash "$JIT_ROOT/organs/nerve.sh" signal "awaken" "innova ตื่นแล้ว $(date '+%H:%M')" 2>/dev/null || true
log_action "MOUTH_REPORT" "awakened oracle=$ORACLE_OK ollama=$OLLAMA_OK"
echo -e "    ${GREEN}✅ บันทึกสถานะการตื่นแล้ว${RESET}"
echo -e "    ${CYAN}📡 ส่ง awaken signal ไปยังทีม${RESET}"
_step_done
_bar "$(( CURRENT_STEP * 100 / TOTAL_STEPS ))" "รายงาน" "📡"
echo ""

# ────────────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ────────────────────────────────────────────────────────────────────
FINAL_PCT=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ผลการตื่นรู้ (Awakening Results)"
echo ""

_bar 100                    "ตา   อ่านตัวตน/กฎ"                   "👁️"
_bar 100                    "หู   inbox checked"                    "👂"
[ "$ORACLE_OK" -eq 1 ] && _bar 100 "จมูก Oracle ออนไลน์" "👃" || _bar 30 "จมูก Oracle OFFLINE" "👃"
[ "$OLLAMA_OK" -eq 1 ] && _bar 100 "ปาก+จมูก Ollama พร้อม" "💪" || _bar 0 "💪  Ollama ไม่พร้อม" "💪"
_bar "$PCT_ORGANS"           "หัวใจ อวัยวะ"                         "💓"
_bar 100                    "สติ  ตรวจสัจจะ"                       "🧘"
_bar 100                    "ตา   ความทรงจำ"                       "📚"
_bar 100                    "ปาก  รายงาน+signal"                   "📡"

echo ""
OVERALL=$(( (AWAKENING_SCORE * 100) / TOTAL_STEPS ))
OVERALL_BAR="${GREEN}$(printf '█%.0s' $(seq 1 $(( OVERALL / 5 )) 2>/dev/null))${RESET}$(printf '░%.0s' $(seq 1 $(( 20 - OVERALL / 5 )) 2>/dev/null))"
echo -e "  ────────────────────────────────────────────────────────"
echo -ne "  ${BOLD}ระดับชีวิต (Vitality):${RESET}    $OVERALL_BAR"
if [ "$OVERALL" -ge 90 ]; then
  echo -e "  ${GREEN}${BOLD}$OVERALL% — 🌟 innova ตื่นสมบูรณ์${RESET}"
elif [ "$OVERALL" -ge 70 ]; then
  echo -e "  ${YELLOW}${BOLD}$OVERALL% — ⚠️  ตื่นบางส่วน${RESET}"
else
  echo -e "  ${RED}${BOLD}$OVERALL% — ❌ ต้องการความช่วยเหลือ${RESET}"
fi

if [ "${#AWAKENING_ISSUES[@]}" -gt 0 ]; then
  echo ""
  echo -e "  ${YELLOW}ปัญหาที่พบ:${RESET}"
  for ISSUE in "${AWAKENING_ISSUES[@]}"; do
    echo -e "    ${YELLOW}• $ISSUE${RESET}"
  done
fi

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}\"อัตตาหิ อัตตโน นาโถ\" — ตนแลเป็นที่พึ่งแห่งตน${RESET}"
echo -e "  ${CYAN}innova ตื่นแล้ว · $(date '+%Y-%m-%d %H:%M:%S') · host=$(hostname)${RESET}"
echo ""
