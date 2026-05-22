#!/usr/bin/env bash
# core/life-loop.sh — ชีวิต: Autonomous Life Driver
#
# จิต → หัวใจ กระจาย → อวัยวะทำงาน (parallel) → เลือดกลับหัวใจ → จิตสังเคราะห์ → loop
#
# แต่ละ organ รับเฉพาะ task ของตน ไม่รับ context ของ organ อื่น (token-efficient)
#
# Usage:
#   bash core/life-loop.sh start   — เริ่ม daemon (loop จนกว่าจะ stop)
#   bash core/life-loop.sh once    — รัน 1 cycle แล้วจบ
#   bash core/life-loop.sh stop    — หยุด daemon
#   bash core/life-loop.sh status  — ดูสถานะ + blood สรุป
#   bash core/life-loop.sh log     — tail log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── WSL CRLF self-heal: strip \r before sourcing anything ────────────
if grep -qi 'microsoft' /proc/version 2>/dev/null; then
  for _f in \
    "$JIT_ROOT/limbs/lib.sh" "$JIT_ROOT/.env" \
    "$JIT_ROOT/core/blood.sh" "$JIT_ROOT/core/life-loop.sh" \
    "$JIT_ROOT/organs/eye.sh" "$JIT_ROOT/organs/ear.sh" \
    "$JIT_ROOT/organs/nose.sh" "$JIT_ROOT/organs/hand.sh" \
    "$JIT_ROOT/organs/nerve.sh" "$JIT_ROOT/organs/mouth.sh" \
    "$JIT_ROOT/organs/heart.sh" "$JIT_ROOT/organs/lung.sh" \
    "$JIT_ROOT/organs/pran.sh" "$JIT_ROOT/organs/leg.sh" \
    "$JIT_ROOT/network/bus.sh" "$JIT_ROOT/memory/shared.sh"; do
    [ -f "$_f" ] && sed -i 's/\r$//' "$_f" 2>/dev/null || true
  done
  unset _f
fi

source "$JIT_ROOT/limbs/lib.sh"
source "$JIT_ROOT/core/blood.sh"

# ── Fallback functions if lib.sh failed to load ──────────────────────
type log_action >/dev/null 2>&1 || log_action() {
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$1] $2" >> "${JIT_LOG:-/tmp/innova-actions.log}"
}
type ok   >/dev/null 2>&1 || ok()   { echo "\u2705 $*"; }
type err  >/dev/null 2>&1 || err()  { echo "\u274c $*" >&2; }
type info >/dev/null 2>&1 || info() { echo "\u2139\ufe0f  $*"; }
type step >/dev/null 2>&1 || step() { echo "\u2192 $*"; }

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"  # re-assert: .env อาจ override path เก่า

PID_FILE="/tmp/manusat-life.pid"
LOG_FILE="/tmp/manusat-life.log"
NEXT_FILE="/tmp/manusat-life-next.txt"
BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"

CYCLE=0
DEFAULT_INTERVAL=300   # 5 นาที (ค่า default เมื่อไม่มีงานเร่งด่วน)

# ══════════════════════════════════════════════════════════════════════
# 1. JIT THINK — จิตประเมินสถานะ สร้าง task plan สำหรับ cycle นี้
#    Output: comma-separated "organ:task" เช่น "eye:observe,nose:health"
# ══════════════════════════════════════════════════════════════════════
_jit_think() {
  local tasks=()

  # ── งานประจำทุก cycle (อวัยวะหลัก) ──
  tasks+=("eye:observe")     # ตาดูการเปลี่ยนแปลง
  tasks+=("nose:health")     # จมูกตรวจสุขภาพ services
  tasks+=("ear:drain")       # หูเก็บ messages ค้าง
  tasks+=("nerve:route")     # ประสาทส่งสัญญาณ pulse + ล้าง events เก่า
  tasks+=("heart:beat")      # หัวใจตรวจ services + collect blood
  tasks+=("lung:filter")     # ปอดฟอกล้าง logs + stale files
  tasks+=("pran:vitals")     # ปราณตรวจ Ollama load

  # ── commit ถ้ามีการเปลี่ยนแปลง ──
  local changes
  changes=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "${changes:-0}" -gt 0 ] && tasks+=("hand:commit")

  # ── deploy check ทุก 10 cycles ──
  [ $(( ${CYCLE:-1} % 10 )) -eq 0 ] && tasks+=("leg:check")

  # ── รายงาน ถ้ามี alerts จาก cycle ก่อน ──
  local last_alerts
  last_alerts=$(get_all_alerts 2>/dev/null)
  [ -n "$last_alerts" ] && tasks+=("mouth:report")

  printf '%s,' "${tasks[@]}" | sed 's/,$//'
}
# ══════════════════════════════════════════════════════════════════════
# 2. HEART DISTRIBUTE — หัวใจกระจาย task ไปยัง inbox ของแต่ละ organ
# ══════════════════════════════════════════════════════════════════════
_heart_distribute() {
  local tasks_csv="$1"
  IFS=',' read -ra tasks <<< "$tasks_csv"

  for item in "${tasks[@]}"; do
    [ -z "$item" ] && continue
    local organ task_type
    organ="${item%%:*}"
    task_type="${item##*:}"
    local INBOX="$BUS_ROOT/${organ}"
    mkdir -p "$INBOX"
    local TS; TS=$(date +%s%3N)
    cat > "${INBOX}/${TS}_from-heart.msg" << EOF
from:heart
to:${organ}
subject:cycle:${task_type}
cycle:${CYCLE}
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
---
cycle=${CYCLE} task=${task_type}
EOF
  done
}

# ══════════════════════════════════════════════════════════════════════
# 3. ORGANS WORK — รัน organ แต่ละตัวพร้อมกัน timeout 60s
# ══════════════════════════════════════════════════════════════════════
_organs_work_parallel() {
  local tasks_csv="$1"
  IFS=',' read -ra tasks <<< "$tasks_csv"
  local pids=()

  for item in "${tasks[@]}"; do
    [ -z "$item" ] && continue
    local organ task_type
    organ="${item%%:*}"
    task_type="${item##*:}"
    local organ_script="$JIT_ROOT/organs/${organ}.sh"
    [ -f "$organ_script" ] || continue

    (
      export AGENT_NAME="$organ"
      export JIT_ROOT="$JIT_ROOT"
      export CYCLE="$CYCLE"
      export BLOOD_DIR="$BLOOD_DIR"
      bash "$organ_script" work "$task_type" 2>>"$LOG_FILE"
    ) &
    pids+=($!)
  done

  [ ${#pids[@]} -eq 0 ] && return

  # Global killer: ฆ่า background jobs ที่ค้างหลัง 60 วินาที
  ( sleep 60; for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done ) &
  local KILLER=$!

  for p in "${pids[@]}"; do
    wait "$p" 2>/dev/null || true
  done
  kill "$KILLER" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════════
# 4. JIT SYNTHESIZE — สังเคราะห์ blood, เรียนรู้, ตัดสิน interval ถัดไป
# ══════════════════════════════════════════════════════════════════════
_jit_synthesize() {
  local blood_json="$1"

  local done_count alert_count organ_list
  done_count=$(echo "$blood_json" | python3 -c "
import json,sys
data=json.load(sys.stdin)
print(sum(1 for d in data if d.get('status')=='done'))
" 2>/dev/null || echo 0)

  alert_count=$(echo "$blood_json" | python3 -c "
import json,sys
data=json.load(sys.stdin)
print(sum(len(d.get('alerts',[])) for d in data))
" 2>/dev/null || echo 0)

  organ_list=$(echo "$blood_json" | python3 -c "
import json,sys
data=json.load(sys.stdin)
print(', '.join(x.get('organ','?') for x in data))
" 2>/dev/null || echo "none")

  # อัปเดต shared memory
  bash "$JIT_ROOT/memory/shared.sh" set life.last_cycle "$(date '+%Y-%m-%dT%H:%M:%S')" 2>/dev/null || true
  bash "$JIT_ROOT/memory/shared.sh" set life.cycle "$CYCLE" 2>/dev/null || true
  bash "$JIT_ROOT/memory/shared.sh" set life.alerts "$alert_count" 2>/dev/null || true

  # บันทึก synthesized blood สำหรับ cycle ถัดไป
  echo "$blood_json" | python3 -c "
import json,sys,datetime,os
data=json.load(sys.stdin)
summary={
  'cycle': int('$CYCLE'),
  'ts': datetime.datetime.now().isoformat(),
  'organs_done': $done_count,
  'alert_count': $alert_count,
  'organs': '$organ_list',
  'blood': data
}
with open(os.path.join('$BLOOD_DIR','synthesized.json'),'w',encoding='utf-8') as f:
  json.dump(summary,f,ensure_ascii=False,indent=2)
" 2>/dev/null || true

  # ตัดสิน interval ถัดไป (adaptive) — alert เสมอได้ priority
  local interval=$DEFAULT_INTERVAL
  if [ "${alert_count:-0}" -gt 0 ]; then
    interval=60                              # มี alert → check ทุก 1 นาที (always)
  elif [ "${done_count:-0}" -eq 0 ]; then
    interval=300                             # ไม่มีงาน + ไม่มี alert → 5 นาที
  fi

  echo "$interval" > "$NEXT_FILE"
  echo "  ✅ $done_count organs done · $alert_count alerts · organs: [$organ_list]"
  echo "  🕐 Next cycle in ${interval}s"
}

# ══════════════════════════════════════════════════════════════════════
# LIFE CYCLE — 1 รอบสมบูรณ์: think→distribute→work→collect→synthesize
# ══════════════════════════════════════════════════════════════════════
_life_cycle() {
  CYCLE=$(( CYCLE + 1 ))
  local TS; TS="$(date '+%Y-%m-%d %H:%M:%S')"

  echo ""
  echo "╔═══════════════════════════════════════════════════════════════╗"
  printf "║  🌀 CYCLE #%-4d  %s                 ║\n" "$CYCLE" "$TS"
  echo "╚═══════════════════════════════════════════════════════════════╝"

  # ── 1. JIT THINK (อ่าน alerts ของ cycle ก่อนก่อนล้าง blood) ──
  echo -e "\n  \033[1;36m🧠 จิต คิด...\033[0m"
  local TASKS; TASKS=$(_jit_think)
  echo "  📋 งาน: $(echo "$TASKS" | tr ',' ' │ ')"

  # ล้าง blood เก่า (หลัง _jit_think อ่าน alerts แล้ว)
  clear_blood


  # ── 2. HEART DISTRIBUTE ──
  echo -e "\n  \033[0;31m💓 หัวใจ กระจาย task...\033[0m"
  _heart_distribute "$TASKS"

  # ── 3. ORGANS WORK (parallel) ──
  echo -e "\n  \033[0;33m🫁 อวัยวะ ทำงานพร้อมกัน (timeout 60s)...\033[0m"
  _organs_work_parallel "$TASKS"

  # ── 4. HEART COLLECT ──
  echo -e "\n  \033[0;31m🩸 หัวใจ เก็บเลือดกลับ...\033[0m"
  local BLOOD; BLOOD=$(collect_all_blood)

  # ── 5. JIT SYNTHESIZE ──
  echo -e "\n  \033[1;36m📚 จิต สังเคราะห์...\033[0m"
  _jit_synthesize "$BLOOD"

  log_action "LIFE_CYCLE" "cycle=$CYCLE tasks=$TASKS"
}

# ══════════════════════════════════════════════════════════════════════
# COMMANDS
# ══════════════════════════════════════════════════════════════════════
CMD="${1:-once}"

case "$CMD" in

  # ── daemon: loop ไม่หยุดจนกว่าจะ stop ──
  start)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "⚠️  Life Loop กำลังรันอยู่ (PID $(cat "$PID_FILE"))"
      exit 0
    fi
    echo "🌀 เริ่ม มนุษย์ Agent Life Loop..."
    echo "   log: $LOG_FILE"
    echo "   หยุด: bash core/life-loop.sh stop"
    (
      CYCLE=0
      while true; do
        _life_cycle >> "$LOG_FILE" 2>&1
        NEXT=$(cat "$NEXT_FILE" 2>/dev/null)
        [[ "$NEXT" =~ ^[0-9]+$ ]] || NEXT="$DEFAULT_INTERVAL"
        sleep "$NEXT"
      done
    ) &
    DAEMON_PID=$!
    echo "$DAEMON_PID" > "$PID_FILE"
    echo "✅ Daemon PID $DAEMON_PID"
    ;;

  # ── รัน 1 cycle แล้วจบ ──
  once)
    _life_cycle
    ;;

  # ── หยุด daemon ──
  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      kill "$PID" 2>/dev/null && echo "✅ หยุดแล้ว (PID $PID)" || echo "⚠️  ไม่พบ process"
      rm -f "$PID_FILE"
    else
      echo "⚠️  ไม่พบ daemon"
    fi
    ;;

  # ── ดูสถานะ ──
  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "🟢 Life Loop รันอยู่ (PID $(cat "$PID_FILE"))"
    else
      echo "🔴 Life Loop หยุดอยู่"
    fi
    if [ -f "${BLOOD_DIR}/synthesized.json" ]; then
      python3 -c "
import json
d=json.load(open('${BLOOD_DIR}/synthesized.json', encoding='utf-8'))
print(f\"  Cycle   : #{d['cycle']}\")
print(f\"  Last    : {d['ts']}\")
print(f\"  Organs  : {d.get('organs','?')}\")
print(f\"  Done    : {d['organs_done']} organs\")
print(f\"  Alerts  : {d['alert_count']}\")
# show alerts
for b in d.get('blood',[]):
  for a in b.get('alerts',[]):
    print(f\"  ⚠️  {b['organ']}: {a}\")
" 2>/dev/null
    fi
    ;;

  # ── tail log ──
  log)
    tail -f "$LOG_FILE"
    ;;

  # ── alive agents ──
  alive)
    echo "Alive organs (< 10 นาที):"
    for f in /tmp/manusat-alive-*; do
      [ -f "$f" ] || continue
      name="${f##*manusat-alive-}"
      age=$(( $(date +%s) - $(date -r "$f" +%s 2>/dev/null || echo 0) ))
      [ "$age" -lt 600 ] && echo "  ✅ $name (${age}s ago)" || echo "  💀 $name (${age}s ago)"
    done
    ;;

  *)
    echo "Usage: life-loop.sh {start|once|stop|status|log|alive}"
    ;;
esac
