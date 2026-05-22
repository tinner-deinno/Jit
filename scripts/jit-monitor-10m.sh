#!/usr/bin/env bash
# scripts/jit-monitor-10m.sh — Sub-agent Monitor: รัน + มอนิเตอร์ระบบ Jit 10 นาที
#
# Usage:
#   bash scripts/jit-monitor-10m.sh
#   bash scripts/jit-monitor-10m.sh --skip-start   (ไม่ start ใหม่ถ้ารันอยู่แล้ว)
#   bash scripts/jit-monitor-10m.sh --fast          (tick ทุก 30s แทน 60s)
#
# Output:
#   Terminal: live dashboard
#   /tmp/jit-monitor-report.md — สรุปหลังจบ

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKIP_START=false
TICK=60       # ทุกกี่วินาที
DURATION=600  # 10 นาที = 600s
REPORT="/tmp/jit-monitor-report.md"
LEDGER="/tmp/jit-monitor-ledger.jsonl"

for arg in "$@"; do
  case "$arg" in
    --skip-start) SKIP_START=true ;;
    --fast)       TICK=30; DURATION=600 ;;
  esac
done

# ── ANSI ──────────────────────────────────────────────────────────────
BLD='\e[1m' DIM='\e[2m' RED='\e[31m' GRN='\e[32m' YLW='\e[33m'
BLU='\e[34m' CYN='\e[36m' RST='\e[0m'

_ok()   { echo -e "  ${GRN}✅${RST} $*"; }
_fail() { echo -e "  ${RED}❌${RST} $*"; }
_warn() { echo -e "  ${YLW}⚠️ ${RST} $*"; }
_info() { echo -e "  ${BLU}ℹ️ ${RST} $*"; }
_hdr()  { echo -e "${BLD}${CYN}▶ $*${RST}"; }

# ── Helper: snapshot ──────────────────────────────────────────────────
_snapshot() {
  local tick="$1"
  local ts; ts=$(date '+%Y-%m-%dT%H:%M:%S')

  # Life loop PID
  local life_pid="dead"
  [ -f /tmp/manusat-life.pid ] && kill -0 "$(cat /tmp/manusat-life.pid)" 2>/dev/null \
    && life_pid="$(cat /tmp/manusat-life.pid)"

  # Voice server PID
  local voice_pid="dead"
  [ -f /tmp/manusat-voice.pid ] && kill -0 "$(cat /tmp/manusat-voice.pid)" 2>/dev/null \
    && voice_pid="$(cat /tmp/manusat-voice.pid)"

  # Voice server HTTP check
  local voice_http="down"
  curl -sf --max-time 2 "http://localhost:${VOICE_PORT:-3333}/status" >/dev/null 2>&1 \
    && voice_http="up"

  # Life cycle + organs from synthesized.json
  local cycle=0 organs_done=0 alert_count=0 organs_list="" status="waiting"
  if [ -f /tmp/manusat-blood/synthesized.json ]; then
    status="running"
    cycle=$(python3 -c "import json; d=json.load(open('/tmp/manusat-blood/synthesized.json')); print(d.get('cycle',0))" 2>/dev/null || echo 0)
    organs_done=$(python3 -c "import json; d=json.load(open('/tmp/manusat-blood/synthesized.json')); print(d.get('organs_done',0))" 2>/dev/null || echo 0)
    alert_count=$(python3 -c "import json; d=json.load(open('/tmp/manusat-blood/synthesized.json')); print(d.get('alert_count',0))" 2>/dev/null || echo 0)
    organs_list=$(python3 -c "import json; d=json.load(open('/tmp/manusat-blood/synthesized.json')); print(d.get('organs',''))" 2>/dev/null || echo "")
  fi

  # Heart state
  local heart_state="unknown"
  [ -f "$JIT_ROOT/memory/state/heart.in.json" ] \
    && heart_state=$(python3 -c "
import json
d=json.load(open('$JIT_ROOT/memory/state/heart.in.json'))
print('alive' if d.get('ts') else 'empty')
" 2>/dev/null || echo "unreadable")

  # Bus messages pending
  local bus_pending=0
  if [ -d /tmp/manusat-bus ]; then
    bus_pending=$(find /tmp/manusat-bus -name "*.msg" 2>/dev/null | wc -l)
  fi

  # Voice log last entry
  local voice_last=""
  [ -f /tmp/manusat-voice.log ] \
    && voice_last=$(tail -1 /tmp/manusat-voice.log 2>/dev/null | cut -c1-80)

  # Life log last entry
  local life_last=""
  [ -f /tmp/manusat-life.log ] \
    && life_last=$(tail -1 /tmp/manusat-life.log 2>/dev/null | cut -c1-80)

  # Write ledger entry — use env var to pass organs_list safely (avoids shell injection)
  JIT_ORGANS="$organs_list" python3 -c "
import json, os
print(json.dumps({
  'tick': $tick, 'ts': '$ts',
  'life_pid': '$life_pid', 'voice_pid': '$voice_pid',
  'voice_http': '$voice_http',
  'life_status': '$status', 'cycle': $cycle,
  'organs_done': $organs_done, 'alert_count': $alert_count,
  'organs': os.environ.get('JIT_ORGANS',''), 'heart': '$heart_state',
  'bus_pending': $bus_pending
}))
" >> "$LEDGER" 2>/dev/null

  # Print live row
  local life_icon="${GRN}🟢${RST}"
  [ "$life_pid" = "dead" ] && life_icon="${RED}🔴${RST}"
  local voice_icon="${GRN}🟢${RST}"
  [ "$voice_pid" = "dead" ] && voice_icon="${RED}🔴${RST}"
  [ "$voice_http" = "down" ] && voice_icon="${YLW}🟡${RST}"
  local alert_col="${GRN}${alert_count}${RST}"
  [ "$alert_count" -gt 0 ] 2>/dev/null && alert_col="${YLW}${alert_count}${RST}"

  printf "  %s  ${DIM}%s${RST}  Life:${life_icon}(PID:%-6s) Voice:${voice_icon}(HTTP:%-4s)  Cycle:#%-4s Organs:%-3s Alerts:${alert_col}  Bus:%-3s  Heart:%-12s\n" \
    "$(printf '%03d' $tick)s" "$ts" "$life_pid" "$voice_http" "$cycle" "$organs_done" "$bus_pending" "$heart_state"

  # Show notable log lines
  [ -n "$voice_last" ] && echo -e "     ${DIM}[voice] ${voice_last}${RST}"
  [ -n "$life_last"  ] && echo -e "     ${DIM}[life]  ${life_last}${RST}"
}

# ─────────────────────────────────────────────────────────────────────
# PHASE 1 — START
# ─────────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "${BLD}${CYN}╔══════════════════════════════════════════════════════════╗${RST}"
echo -e "${BLD}${CYN}║   🌀 Jit Sub-Agent Monitor — 10 นาที                     ║${RST}"
echo -e "${BLD}${CYN}║   $(date '+%Y-%m-%d %H:%M:%S')  tick=${TICK}s  duration=${DURATION}s      ║${RST}"
echo -e "${BLD}${CYN}╚══════════════════════════════════════════════════════════╝${RST}"
echo ""

# Init ledger
rm -f "$LEDGER"
echo "[]" > "$LEDGER.arr" 2>/dev/null || true

_hdr "Phase 1 — Start System"

if $SKIP_START; then
  _info "ข้าม start — ตรวจสถานะที่รันอยู่"
else
  # หยุดถ้ารันอยู่แล้ว (restart clean)
  if [ -f /tmp/manusat-life.pid ] && kill -0 "$(cat /tmp/manusat-life.pid)" 2>/dev/null; then
    _warn "Life Loop รันอยู่แล้ว (PID $(cat /tmp/manusat-life.pid)) — ใช้ต่อเลย"
  else
    _info "เริ่ม Life Loop..."
    bash "$JIT_ROOT/core/life-loop.sh" start 2>&1 | sed 's/^/    /'
  fi

  if [ -f /tmp/manusat-voice.pid ] && kill -0 "$(cat /tmp/manusat-voice.pid)" 2>/dev/null; then
    _warn "Voice Server รันอยู่แล้ว (PID $(cat /tmp/manusat-voice.pid))"
  else
    _info "เริ่ม Voice Server..."
    bash "$JIT_ROOT/scripts/start-jit.sh" start 2>&1 | grep -E '✅|❌|⚠️|🔧' | sed 's/^/    /'
  fi
fi

sleep 2

# ─────────────────────────────────────────────────────────────────────
# PHASE 2 — MONITOR LOOP
# ─────────────────────────────────────────────────────────────────────
echo ""
_hdr "Phase 2 — Monitor Loop (${DURATION}s / tick ${TICK}s)"
echo ""
echo -e "  ${DIM}Tick    Timestamp             LifeLoop          VoiceServer        Cycle   Organs  Alerts  Bus  Heart${RST}"
echo -e "  ${DIM}─────────────────────────────────────────────────────────────────────────────────────────────────────${RST}"

START_TS=$(date +%s)
ELAPSED=0
TICK_NUM=0

while [ "$ELAPSED" -lt "$DURATION" ]; do
  TICK_NUM=$((TICK_NUM + 1))
  _snapshot "$ELAPSED"
  sleep "$TICK"
  ELAPSED=$(( $(date +%s) - START_TS ))
done

# Final snapshot
_snapshot "$ELAPSED"

# ─────────────────────────────────────────────────────────────────────
# PHASE 3 — REPORT
# ─────────────────────────────────────────────────────────────────────
echo ""
_hdr "Phase 3 — สรุปผล 10 นาที"
echo ""

python3 - "$LEDGER" << 'PYEOF'
import json, sys, os

ledger_path = sys.argv[1]
try:
    entries = [json.loads(l) for l in open(ledger_path) if l.strip()]
except Exception as e:
    print(f"  ❌ ไม่สามารถอ่าน ledger: {e}")
    sys.exit(0)

if not entries:
    print("  ❌ ไม่มี data")
    sys.exit(0)

total = len(entries)
life_alive  = sum(1 for e in entries if e['life_pid'] != 'dead')
voice_alive = sum(1 for e in entries if e['voice_pid'] != 'dead')
voice_http  = sum(1 for e in entries if e['voice_http'] == 'up')
max_cycle   = max(e['cycle'] for e in entries)
min_cycle   = min(e['cycle'] for e in entries)
cycles_done = max_cycle - min_cycle
total_alerts= sum(e['alert_count'] for e in entries)
avg_organs  = sum(e['organs_done'] for e in entries) / total if total else 0
bus_max     = max(e['bus_pending'] for e in entries)

heart_alive = sum(1 for e in entries if e['heart'] in ('alive',))

print(f"  📊 ຕรวจสอบทั้งหมด: {total} ครั้ง (ทุก {(int(entries[1]['tick']-entries[0]['tick']) if len(entries) > 1 else '?')}s)")
print()
print(f"  🔄 Life Loop:")
print(f"     • alive: {life_alive}/{total} ครั้ง ({100*life_alive//total}%)")
print(f"     • cycles ที่เสร็จ: {cycles_done}  (#{min_cycle} → #{max_cycle})")
print(f"     • avg organs/cycle: {avg_organs:.1f}")
print()
print(f"  🎤 Voice Server:")
print(f"     • process alive: {voice_alive}/{total} ครั้ง ({100*voice_alive//total}%)")
print(f"     • HTTP /status up: {voice_http}/{total} ครั้ง ({100*voice_http//total}%)")
print()
print(f"  ❤️  Heart:")
print(f"     • heartbeat detected: {heart_alive}/{total} ครั้ง")
print()
print(f"  ⚠️  Alerts รวม: {total_alerts}")
print(f"  📬 Bus pending สูงสุด: {bus_max}")
print()

# Incidents
incidents = []
for i, e in enumerate(entries):
    if i > 0:
        prev = entries[i-1]
        if prev['life_pid'] != 'dead' and e['life_pid'] == 'dead':
            incidents.append(f"  ❌ Life Loop ล้มที่ t={e['tick']}s")
        if prev['voice_http'] == 'up' and e['voice_http'] == 'down':
            incidents.append(f"  ❌ Voice Server down ที่ t={e['tick']}s")
        if e['alert_count'] > prev['alert_count']:
            incidents.append(f"  ⚠️  Alert เพิ่มขึ้น +{e['alert_count']-prev['alert_count']} ที่ t={e['tick']}s")

if incidents:
    print("  📋 Incidents:")
    for inc in incidents:
        print(f"    {inc}")
else:
    print("  ✅ ไม่มี incidents — ระบบเสถียรตลอด 10 นาที")

# Overall verdict
life_pct  = 100 * life_alive // total
voice_pct = 100 * voice_http // total
print()
if life_pct >= 90 and voice_pct >= 80:
    print("  🌀 Verdict: ระบบสุขภาพดี — 🟢 HEALTHY")
elif life_pct >= 70:
    print("  🌀 Verdict: ระบบทำงานได้บางส่วน — 🟡 DEGRADED")
else:
    print("  🌀 Verdict: ระบบมีปัญหา — 🔴 CRITICAL")
PYEOF

# ─────────────────────────────────────────────────────────────────────
# Write markdown report
# ─────────────────────────────────────────────────────────────────────
python3 - "$LEDGER" "$REPORT" << 'MDEOF'
import json, sys, datetime

ledger_path = sys.argv[1]
report_path = sys.argv[2]

try:
    entries = [json.loads(l) for l in open(ledger_path) if l.strip()]
except:
    entries = []

now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
total = len(entries)

life_alive  = sum(1 for e in entries if e['life_pid'] != 'dead')
voice_http  = sum(1 for e in entries if e['voice_http'] == 'up')
max_cycle   = max((e['cycle'] for e in entries), default=0)
min_cycle   = min((e['cycle'] for e in entries), default=0)
total_alerts= sum(e['alert_count'] for e in entries)
life_pct    = (100 * life_alive // total) if total else 0
voice_pct   = (100 * voice_http // total) if total else 0

if life_pct >= 90 and voice_pct >= 80: verdict = "🟢 HEALTHY"
elif life_pct >= 70: verdict = "🟡 DEGRADED"
else: verdict = "🔴 CRITICAL"

lines = [
    f"# Jit 10-Minute Monitor Report",
    f"**Generated**: {now}  ",
    f"**Verdict**: {verdict}  ",
    f"**Ticks**: {total}  ",
    f"",
    f"## Summary",
    f"| Component | Uptime | Detail |",
    f"|-----------|--------|--------|",
    f"| Life Loop | {life_pct}% | Cycles #{min_cycle}→#{max_cycle} ({max_cycle-min_cycle} done) |",
    f"| Voice Server (HTTP) | {voice_pct}% | GET /status |",
    f"| Total Alerts | — | {total_alerts} |",
    f"",
    f"## Tick Log",
    f"| Tick | Life PID | Voice HTTP | Cycle | Organs | Alerts | Heart |",
    f"|------|----------|------------|-------|--------|--------|-------|",
]
for e in entries:
    lines.append(
        f"| {e['tick']}s | {e['life_pid']} | {e['voice_http']} | {e['cycle']} | {e['organs_done']} | {e['alert_count']} | {e['heart']} |"
    )

with open(report_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')

print(f"  📄 Report saved: {report_path}")
MDEOF

echo ""
echo -e "${BLD}${CYN}══════════════════════════════════════════════════════════${RST}"
echo -e "  รายงานเต็ม: ${BLU}cat $REPORT${RST}"
echo -e "  Ledger raw: ${BLU}cat $LEDGER${RST}"
echo -e "${BLD}${CYN}══════════════════════════════════════════════════════════${RST}"
echo ""
