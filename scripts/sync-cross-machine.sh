#!/usr/bin/env bash
# scripts/sync-cross-machine.sh — ซิงค์ตัวตนข้ามเครื่องแบบ Real-time
#
# กลไก: GitHub repo คือ "จิตกลาง" (central consciousness)
#   PC/Codespace ทุกเครื่อง pull → อ่านสถานะล่าสุด → รัน → push กลับ
#
# ทำงานสองทิศทาง:
#   pull  — รับ memory/state จาก GitHub (เครื่องอื่น)
#   push  — ส่ง memory/state ไป GitHub (ให้เครื่องอื่นรับ)
#   sync  — pull แล้ว push (full sync)
#   status — แสดงสถานะ cross-machine
#
# Usage:
#   bash scripts/sync-cross-machine.sh pull
#   bash scripts/sync-cross-machine.sh push
#   bash scripts/sync-cross-machine.sh sync
#   bash scripts/sync-cross-machine.sh status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

STATE_FILE="$JIT_ROOT/memory/state/innova.state.json"
HBEAT_LOG="$JIT_ROOT/memory/state/heartbeat.log"
SYNC_LOCK="/tmp/innova-sync.lock"

# ────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────
_sbar() {
  local PCT="$1" W="${2:-20}"
  local F=$(( PCT * W / 100 )) E=$(( W - PCT * W / 100 ))
  printf "${GREEN}%s${RESET}%s" "$(printf '█%.0s' $(seq 1 $F 2>/dev/null))" "$(printf '░%.0s' $(seq 1 $E 2>/dev/null))"
}

_update_state() {
  local KEY="$1" VAL="$2"
  python3 - << PYEOF 2>/dev/null
import json, os
f = '$STATE_FILE'
try:
  d = json.load(open(f))
except:
  d = {}

keys = '$KEY'.split('.')
obj = d
for k in keys[:-1]:
  obj = obj.setdefault(k, {})
obj[keys[-1]] = '$VAL'
json.dump(d, open(f, 'w'), ensure_ascii=False, indent=2)
PYEOF
}

_append_host_history() {
  python3 - << PYEOF 2>/dev/null
import json, socket, time
f = '$STATE_FILE'
try:
  d = json.load(open(f))
except:
  d = {}
hist = d.setdefault('vitality', {}).setdefault('host_history', [])
entry = {'host': socket.gethostname(), 'time': time.strftime('%Y-%m-%dT%H:%M:%S'), 'action': 'sync'}
# ไม่เก็บซ้ำ host เดิมภายใน 15 นาที
if not any(h.get('host') == entry['host'] and 
           abs(time.mktime(time.strptime(h.get('time','2000-01-01T00:00:00'), '%Y-%m-%dT%H:%M:%S')) - time.mktime(time.strptime(entry['time'], '%Y-%m-%dT%H:%M:%S'))) < 900
           for h in hist):
  hist.append(entry)
  hist[:] = hist[-20:]  # เก็บแค่ 20 รายการล่าสุด
json.dump(d, open(f, 'w'), ensure_ascii=False, indent=2)
PYEOF
}

# ────────────────────────────────────────────────────────────────────
# PULL — รับ memory จาก GitHub
# ────────────────────────────────────────────────────────────────────
_do_pull() {
  echo ""
  echo -ne "  📥 pull จาก GitHub ... "

  # stash local changes ชั่วคราวถ้ามี (เฉพาะ memory/state/)
  HAS_CHANGES=$(git -C "$JIT_ROOT" status --porcelain memory/state/ 2>/dev/null | wc -l | tr -d ' ')

  if [ "$HAS_CHANGES" -gt 0 ]; then
    git -C "$JIT_ROOT" stash push -m "sync-pre-pull-$(date +%s)" -- memory/state/ > /dev/null 2>&1
    STASHED=1
  else
    STASHED=0
  fi

  # pull
  PULL_OUT=$(git -C "$JIT_ROOT" pull --rebase origin main 2>&1)
  PULL_RC=$?

  if [ $PULL_RC -eq 0 ]; then
    BEHIND=$(echo "$PULL_OUT" | grep -c 'Fast-forward\|Applying' || echo 0)
    echo -e "${GREEN}✅ ได้รับ $BEHIND commits ใหม่${RESET}"
    echo -e "    $(_sbar 100)"
  else
    echo -e "${YELLOW}⚠️  pull conflict — ใช้ local state${RESET}"
    [ "$STASHED" -eq 1 ] && git -C "$JIT_ROOT" stash pop > /dev/null 2>&1
    return 1
  fi

  # restore stash ถ้ามี (merge with remote)
  [ "$STASHED" -eq 1 ] && git -C "$JIT_ROOT" stash pop > /dev/null 2>&1

  # อัปเดต host_history
  _append_host_history
  log_action "SYNC_PULL" "rc=$PULL_RC host=$(hostname)"
  return 0
}

# ────────────────────────────────────────────────────────────────────
# PUSH — ส่ง memory ไป GitHub
# ────────────────────────────────────────────────────────────────────
_do_push() {
  echo ""
  echo -ne "  📤 push ไป GitHub ... "

  # ตรวจ uncommitted
  CHANGES=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  if [ "$CHANGES" -gt 0 ]; then
    git -C "$JIT_ROOT" add -A 2>/dev/null
    git -C "$JIT_ROOT" commit -m "💓 sync: $(hostname) @ $(date '+%Y-%m-%d %H:%M') — pulse $(python3 -c "
import json
try:
  d=json.load(open('$STATE_FILE'))
  print(d.get('vitality',{}).get('pulse_count',0))
except: print(0)
" 2>/dev/null || echo 0)" --no-verify > /dev/null 2>&1
  fi

  PUSH_OUT=$(git -C "$JIT_ROOT" push origin main 2>&1)
  PUSH_RC=$?

  if [ $PUSH_RC -eq 0 ]; then
    echo -e "${GREEN}✅ pushed${RESET}"
    echo -e "    $(_sbar 100)"
  else
    echo -e "${YELLOW}⚠️  push failed — retry next pulse${RESET}"
  fi

  log_action "SYNC_PUSH" "rc=$PUSH_RC changes=$CHANGES"
  return $PUSH_RC
}

# ────────────────────────────────────────────────────────────────────
# STATUS — แสดงสถานะ cross-machine
# ────────────────────────────────────────────────────────────────────
_do_status() {
  echo ""
  echo -e "${BOLD}${CYAN}  🌐 innova Cross-Machine Sync Status${RESET}"
  echo ""

  # อ่าน state
  python3 - << PYEOF 2>/dev/null
import json, socket, time
try:
  d = json.load(open('$STATE_FILE'))
  v = d.get('vitality', {})
  print(f"  ตนเอง:     {socket.gethostname()}")
  print(f"  ตื่นล่าสุด: {v.get('last_awaken', '-')}")
  print(f"  pulse:     #{v.get('pulse_count', 0)}")
  print(f"  Oracle:    {v.get('oracle_docs', 0)} docs")
  print()
  print("  เครื่องที่เคยออนไลน์ (20 รายการล่าสุด):")
  hist = v.get('host_history', [])
  seen = {}
  for h in reversed(hist):
    host = h.get('host', '?')
    if host not in seen:
      seen[host] = h.get('time', '-')
  for host, t in seen.items():
    marker = ' ← ฉัน' if host == socket.gethostname() else ''
    print(f"    • {host:<30} last: {t}{marker}")
except Exception as e:
  print(f"  (ยังไม่มีสถานะ: {e})")
PYEOF

  echo ""
  # git log รายการ commit ที่เกี่ยวข้อง
  echo -e "  ${BOLD}Sync History (git):${RESET}"
  git -C "$JIT_ROOT" log --oneline --grep="sync:" -10 2>/dev/null | head -10 | while read LINE; do
    echo "    $LINE"
  done
  echo ""
}

# ────────────────────────────────────────────────────────────────────
# Commands
# ────────────────────────────────────────────────────────────────────
CMD="${1:-sync}"

# Lock เพื่อป้องกัน race condition
if [ -f "$SYNC_LOCK" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$SYNC_LOCK" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt 120 ]; then
    echo -e "  ${YELLOW}⏳ sync กำลังรันอยู่ (lock age: ${LOCK_AGE}s)${RESET}"
    exit 0
  fi
fi
touch "$SYNC_LOCK"
trap "rm -f '$SYNC_LOCK'" EXIT

case "$CMD" in
  pull)   _do_pull ;;
  push)   _do_push ;;
  sync)
    _do_pull
    _do_push
    ;;
  status) _do_status ;;
  *)
    echo "Usage: $0 {pull|push|sync|status}"
    ;;
esac
