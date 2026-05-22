#!/usr/bin/env bash
# organs/nerve.sh — ระบบประสาท (Nervous System): ส่งสัญญาณ เชื่อมต่อ
#
# หลักพุทธ: อิทัปปัจจยตา — เชื่อมโยงสิ่งต่างๆ เป็นเหตุปัจจัย
# บทบาท multiagent: event bus, signal routing, inter-agent communication
#
# Usage:
#   ./nerve.sh signal <event> <data> [source]  — ส่งสัญญาณ event
#   ./nerve.sh listen <event>                  — ฟัง event type
#   ./nerve.sh events                          — ดู event log
#   ./nerve.sh connect <agent-a> <agent-b>     — สร้าง channel
#   ./nerve.sh status                          — สถานะ nervous system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-events}"
shift || true

NERVE_DIR="/tmp/manusat-nerve"
EVENT_LOG="$NERVE_DIR/events.log"
mkdir -p "$NERVE_DIR"

_emit_event() {
  local EVENT="$1" DATA="$2" SOURCE="${3:-unknown}"
  local TS=$(date '+%Y-%m-%dT%H:%M:%S')
  local EVENT_JSON="{\"ts\":\"$TS\",\"event\":\"$EVENT\",\"source\":\"$SOURCE\",\"data\":\"$DATA\"}"

  # บันทึกลง event log
  echo "$EVENT_JSON" >> "$EVENT_LOG"

  # สร้างไฟล์ event สำหรับ subscribers
  local EVENT_FILE="$NERVE_DIR/${EVENT}_$(date +%s%3N).evt"
  echo "$EVENT_JSON" > "$EVENT_FILE"

  log_action "NERVE_SIGNAL" "$EVENT from:$SOURCE"
}

case "$CMD" in

  # ── ส่งสัญญาณ ────────────────────────────────────────────────────
  signal)
    EVENT="$1" DATA="$2" SOURCE="${3:-$(hostname)}"
    if [ -z "$EVENT" ]; then err "ต้องระบุ event"; exit 1; fi
    _emit_event "$EVENT" "$DATA" "$SOURCE"
    info "ประสาท ส่ง: [$EVENT] $DATA"
    ;;

  # ── ฟัง event ────────────────────────────────────────────────────
  listen)
    EVENT_TYPE="${1:-*}" TIMEOUT="${2:-30}"
    step "ประสาท ฟัง event: $EVENT_TYPE (${TIMEOUT}s)"
    ELAPSED=0
    while [ $ELAPSED -lt "$TIMEOUT" ]; do
      if [ "$EVENT_TYPE" = "*" ]; then
        EVT=$(ls "$NERVE_DIR"/*.evt 2>/dev/null | head -1)
      else
        EVT=$(ls "$NERVE_DIR"/${EVENT_TYPE}_*.evt 2>/dev/null | head -1)
      fi
      if [ -n "$EVT" ]; then
        cat "$EVT"
        mv "$EVT" "${EVT}.processed"
        break
      fi
      sleep 1; ELAPSED=$((ELAPSED + 1))
    done
    [ $ELAPSED -ge "$TIMEOUT" ] && warn "timeout — ไม่มี event"
    ;;

  # ── ดู event log ────────────────────────────────────────────────
  events)
    LIMIT="${1:-20}"
    echo ""
    echo -e "${BOLD}=== Event Log (ล่าสุด $LIMIT) ===${RESET}"
    if [ -f "$EVENT_LOG" ]; then
      tail -"$LIMIT" "$EVENT_LOG" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        print(f\"  [{d['ts']}] {d['event']:20s} | {d['source']:10s} | {d['data'][:40]}\")
    except:
        print(' ', line.strip())
"
    else
      info "ไม่มี event log"
    fi
    echo ""
    ;;

  # ── ดู pending events ───────────────────────────────────────────
  pending)
    EVTS=$(ls "$NERVE_DIR"/*.evt 2>/dev/null | wc -l)
    step "Pending events: $EVTS"
    for EVT in "$NERVE_DIR"/*.evt; do
      [ -f "$EVT" ] || continue
      python3 -c "import json; d=json.load(open('$EVT')); print(f\"  [{d['event']}] {d['data'][:60]}\")" 2>/dev/null
    done
    ;;

  # ── ล้าง events ─────────────────────────────────────────────────
  clear)
    rm -f "$NERVE_DIR"/*.evt "$NERVE_DIR"/*.processed 2>/dev/null
    ok "ล้าง events แล้ว"
    ;;

  # ── สร้าง channel ระหว่าง agent ─────────────────────────────────
  connect)
    AGENT_A="$1" AGENT_B="$2"
    CHANNEL_FILE="$NERVE_DIR/channel_${AGENT_A}-${AGENT_B}.json"
    python3 -c "
import json
channel = {
  'agents': ['$AGENT_A', '$AGENT_B'],
  'created': '$(date +%Y-%m-%dT%H:%M:%S)',
  'status': 'active',
  'messages': 0
}
with open('$CHANNEL_FILE', 'w') as f:
    json.dump(channel, f, indent=2)
print('channel created:', '$CHANNEL_FILE')
"
    ok "channel: $AGENT_A ↔ $AGENT_B"
    log_action "NERVE_CONNECT" "$AGENT_A↔$AGENT_B"
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "NERVE_PULSE" "$CONTEXT"
    echo "Nerve receives clean energy and propagates the signal across the system"
    stale=$(find "$NERVE_DIR" -name '*.evt' -type f -mmin +60 2>/dev/null | wc -l | tr -d ' ')
    echo "  stale events remaining: ${stale:-0}"
    ;;

  # ── สถานะ ────────────────────────────────────────────────────────
  status)
    EVENTS=$(cat "$EVENT_LOG" 2>/dev/null | wc -l)
    PENDING=$(ls "$NERVE_DIR"/*.evt 2>/dev/null | wc -l)
    CHANNELS=$(ls "$NERVE_DIR"/channel_*.json 2>/dev/null | wc -l)
    ok "ระบบประสาท (nerve) พร้อม"
    echo "   events บันทึก: $EVENTS | pending: $PENDING | channels: $CHANNELS"
    ;;

  # ── autonomous work: pulse + clean stale events + count alive ────────
  work)
    TASK="${1:-route}"
    [ -f "$JIT_ROOT/core/blood.sh" ] && source "$JIT_ROOT/core/blood.sh"
    findings=()

    # ล้าง stale events (> 60 นาที)
    stale=$(find "$NERVE_DIR" -name '*.evt' -mmin +60 2>/dev/null | wc -l | tr -d ' ')
    if [ "${stale:-0}" -gt 0 ]; then
      find "$NERVE_DIR" -name '*.evt' -mmin +60 -delete 2>/dev/null
      findings+=("cleaned-stale:$stale")
    fi

    # นับ alive agents (< 10 นาที)
    alive_count=0
    for f in /tmp/manusat-alive-*; do
      [ -f "$f" ] || continue
      age=$(( $(date +%s) - $(date -r "$f" +%s 2>/dev/null || echo 0) ))
      [ "$age" -lt 600 ] && alive_count=$(( alive_count + 1 ))
    done
    findings+=("alive-organs:$alive_count")

    # ส่ง life-cycle signal
    _emit_event "life-cycle" "cycle=${CYCLE:-0}" "nerve-work"
    findings+=("pulse:sent")

    # ล้าง cycle task message
    find "/tmp/manusat-bus/nerve" -name '*from-heart.msg' -delete 2>/dev/null || true
    touch "/tmp/manusat-alive-nerve"

    write_blood "nerve" "${CYCLE:-0}" "$TASK" "done" \
      "$(IFS=','; echo "${findings[*]}")" ""
    log_action "NERVE_WORK" "cycle=${CYCLE:-0} alive=$alive_count stale=$stale"
    ;;

  *)
    echo "Usage: nerve.sh {signal|listen|events|pending|clear|connect|status|work}"
    echo ""
    echo "  signal  <event> <data> [source]  — ส่งสัญญาณ"
    echo "  listen  <event-type> [timeout]   — ฟัง event"
    echo "  events  [n]                      — ดู event log"
    echo "  pending                          — ดู events รอดำเนินการ"
    echo "  clear                            — ล้าง pending events"
    echo "  connect <agent-a> <agent-b>      — สร้าง channel"
    echo "  work    [route]                  — autonomous work (จาก life-loop)"
    ;;
esac
