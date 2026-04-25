#!/usr/bin/env bash
# organs/pran.sh — หัวใจ/ปราณ: Ollama Load Balancer & Vital Coordinator
#
# บทบาท: ควบคุมการไหลของพลังงาน (Ollama requests) ไปยัง agents ทุกตัว
# ไม่ให้ใช้ทรัพยากรเกิน — แบ่งสรรตามลำดับความสำคัญ
#
# Priority Map (Tier):
#   5 = soma     (strategic brain — สูงสุด)
#   4 = innova, lak (lead devs)
#   3 = neta, chamu (review/QA)
#   2 = vaja, rupa, pada (specialist)
#   1 = karn, netra, sayanprasathan, mue (sensors/executors)
#
# Usage:
#   bash organs/pran.sh status              — สถานะ Ollama ตอนนี้
#   bash organs/pran.sh capacity            — ดู capacity %
#   bash organs/pran.sh request <agent>     — ขอ Ollama slot
#   bash organs/pran.sh release <agent>     — คืน slot
#   bash organs/pran.sh queue               — ดู queue รอ
#   bash organs/pran.sh pulse               — vital signs dashboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-status}"
shift || true

PRAN_STATE="/tmp/manusat-pran-state.json"
PRAN_QUEUE="/tmp/manusat-pran-queue"
MAX_CONCURRENT=3          # Ollama max concurrent requests
CRITICAL_THRESHOLD=80     # % — เกินนี้ต้อง throttle
HIGH_THRESHOLD=60         # % — เกินนี้ boost priority soma

# Priority table
declare -A PRIORITY=(
  ["soma"]=5 ["innova"]=4 ["lak"]=4
  ["neta"]=3 ["chamu"]=3
  ["vaja"]=2 ["rupa"]=2 ["pada"]=2
  ["karn"]=1 ["netra"]=1 ["sayanprasathan"]=1 ["mue"]=1 ["pran"]=1
)

_pran_init() {
  mkdir -p "$PRAN_QUEUE"
  if [ ! -f "$PRAN_STATE" ]; then
    python3 -c "
import json, time
json.dump({
  'active': [],
  'total_requests': 0,
  'throttle_count': 0,
  'last_updated': time.strftime('%Y-%m-%dT%H:%M:%S')
}, open('$PRAN_STATE', 'w'), ensure_ascii=False, indent=2)
" 2>/dev/null
  fi
}

_ollama_check() {
  curl -sf --max-time 5 "$OLLAMA_URL/api/tags" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" > /dev/null 2>&1
}

_ollama_load() {
  # ดึง running processes จาก Ollama
  local RESULT
  RESULT=$(curl -sf --max-time 5 "$OLLAMA_URL/api/ps" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null)
  if [ -z "$RESULT" ]; then echo "0"; return; fi
  echo "$RESULT" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  models = d.get('models', [])
  print(len(models))
except: print(0)
" 2>/dev/null || echo "0"
}

case "$CMD" in

  # ── สถานะ Ollama ──────────────────────────────────────────────────
  status)
    _pran_init
    echo ""
    echo -e "${BOLD}${CYAN}[ ปราณ — Ollama Vital Status ]${RESET}"
    echo ""
    if _ollama_check; then
      LOAD=$(_ollama_load)
      PCT=$(( (LOAD * 100) / MAX_CONCURRENT ))
      [ "$PCT" -gt 100 ] && PCT=100

      if [ "$PCT" -ge "$CRITICAL_THRESHOLD" ]; then
        LABEL="${RED}🚨 CRITICAL${RESET}"
      elif [ "$PCT" -ge "$HIGH_THRESHOLD" ]; then
        LABEL="${YELLOW}⚠️  HIGH${RESET}"
      else
        LABEL="${GREEN}✅ NORMAL${RESET}"
      fi

      BAR_F=$(( PCT / 5 ))
      BAR_E=$(( 20 - BAR_F ))
      BAR="${GREEN}$(printf '█%.0s' $(seq 1 $BAR_F 2>/dev/null))${RESET}$(printf '░%.0s' $(seq 1 $BAR_E 2>/dev/null))"
      echo -e "  Ollama: ${GREEN}online${RESET}  Model: ${CYAN}${OLLAMA_MODEL}${RESET}"
      echo -e "  Load:   $BAR ${PCT}%  [$LOAD/${MAX_CONCURRENT} concurrent]"
      echo -e "  Status: $LABEL"
    else
      echo -e "  Ollama: ${RED}offline / unreachable${RESET}"
      echo -e "  ${YELLOW}⚠️  ไม่สามารถประมวลผลภาษาไทย/creative ได้${RESET}"
    fi

    # ดู active agents จาก state
    if [ -f "$PRAN_STATE" ]; then
      ACTIVE=$(python3 -c "
import json
try:
  d=json.load(open('$PRAN_STATE'))
  a=d.get('active',[])
  print(', '.join(a) if a else 'none')
except: print('?')
" 2>/dev/null)
      echo -e "  Active: ${CYAN}$ACTIVE${RESET}"
    fi
    echo ""
    log_action "PRAN_STATUS" "load=${LOAD:-?}/${MAX_CONCURRENT}"
    ;;

  # ── capacity % ────────────────────────────────────────────────────
  capacity)
    LOAD=$(_ollama_load)
    PCT=$(( (LOAD * 100) / MAX_CONCURRENT ))
    [ "$PCT" -gt 100 ] && PCT=100
    echo "$PCT"
    ;;

  # ── ขอ Ollama slot ────────────────────────────────────────────────
  request)
    AGENT="${1:-unknown}"
    PRIO="${PRIORITY[$AGENT]:-1}"
    _pran_init

    LOAD=$(_ollama_load)
    PCT=$(( (LOAD * 100) / MAX_CONCURRENT ))

    if [ "$PCT" -ge "$CRITICAL_THRESHOLD" ] && [ "$PRIO" -lt 4 ]; then
      echo -e "${RED}THROTTLED${RESET} — Ollama ใกล้เต็ม ($PCT%) agent $AGENT (priority=$PRIO) ต้องรอ"
      echo "$AGENT:$(date +%s)" >> "$PRAN_QUEUE/waiting"
      log_action "PRAN_THROTTLE" "agent=$AGENT prio=$PRIO load=$PCT%"
      exit 1
    fi

    # อนุมัติ
    python3 -c "
import json, time
try:
  d=json.load(open('$PRAN_STATE'))
  if '$AGENT' not in d['active']:
    d['active'].append('$AGENT')
  d['total_requests'] = d.get('total_requests',0)+1
  d['last_updated'] = time.strftime('%Y-%m-%dT%H:%M:%S')
  json.dump(d, open('$PRAN_STATE','w'), ensure_ascii=False, indent=2)
except: pass
" 2>/dev/null
    echo -e "${GREEN}GRANTED${RESET} — $AGENT (priority=$PRIO) รับ Ollama slot"
    log_action "PRAN_GRANT" "agent=$AGENT prio=$PRIO"
    ;;

  # ── คืน slot ──────────────────────────────────────────────────────
  release)
    AGENT="${1:-unknown}"
    python3 -c "
import json, time
try:
  d=json.load(open('$PRAN_STATE'))
  d['active'] = [a for a in d.get('active',[]) if a != '$AGENT']
  d['last_updated'] = time.strftime('%Y-%m-%dT%H:%M:%S')
  json.dump(d, open('$PRAN_STATE','w'), ensure_ascii=False, indent=2)
except: pass
" 2>/dev/null
    log_action "PRAN_RELEASE" "agent=$AGENT"
    ;;

  # ── ดู queue ──────────────────────────────────────────────────────
  queue)
    echo -e "${BOLD}[ Queue รอ Ollama ]${RESET}"
    if [ -f "$PRAN_QUEUE/waiting" ] && [ -s "$PRAN_QUEUE/waiting" ]; then
      cat "$PRAN_QUEUE/waiting" | while IFS=: read AGENT TS; do
        AGE=$(( $(date +%s) - TS ))
        echo -e "  ${YELLOW}⏳${RESET} $AGENT — รอ ${AGE}s"
      done
    else
      echo -e "  ${GREEN}✅ ไม่มี queue${RESET}"
    fi
    ;;

  # ── pulse dashboard (สำหรับ vitals.sh) ───────────────────────────
  pulse)
    if _ollama_check; then
      LOAD=$(_ollama_load)
      PCT=$(( (LOAD * 100) / MAX_CONCURRENT ))
      [ "$PCT" -gt 100 ] && PCT=100
      echo "$PCT"
    else
      echo "0"
    fi
    ;;

  # ── ปรับ allocation อัตโนมัติ ─────────────────────────────────────
  rebalance)
    echo -e "${BOLD}[ ปราณ — Rebalance Ollama Load ]${RESET}"
    PCT=$(bash "$0" capacity 2>/dev/null || echo "0")
    echo -e "  Current load: ${PCT}%"

    if [ "${PCT:-0}" -ge "$CRITICAL_THRESHOLD" ]; then
      echo -e "  ${RED}🚨 โหลดสูงเกิน — throttle tier 1-2${RESET}"
      log_action "PRAN_REBALANCE" "CRITICAL load=$PCT% throttle_low_priority"
    elif [ "${PCT:-0}" -ge "$HIGH_THRESHOLD" ]; then
      echo -e "  ${YELLOW}⚠️  โหลดสูง — เฝ้าระวัง tier 1${RESET}"
      log_action "PRAN_REBALANCE" "HIGH load=$PCT%"
    else
      echo -e "  ${GREEN}✅ โหลดปกติ — ทุก agent ใช้ได้เต็มที่${RESET}"
      log_action "PRAN_REBALANCE" "NORMAL load=$PCT%"
    fi
    ;;

  *)
    echo "Usage: $0 [status|capacity|request <agent>|release <agent>|queue|pulse|rebalance]"
    ;;
esac
