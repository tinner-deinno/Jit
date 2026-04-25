#!/usr/bin/env bash
# scripts/multi-remote.sh — Load Balance Push ไปยัง Jit Repos หลายตัว
#
# ทุก GitHub account ที่มี Repo ชื่อ "Jit" จะถูก register ไว้
# เมื่อ push ระบบจะ rotate ไปยัง remote ที่รับได้เร็วที่สุด
# (round-robin + fallback กันไม่ให้ GitHub server คนเดียวหนัก)
#
# Usage:
#   bash scripts/multi-remote.sh list          # แสดง remotes ที่ลงทะเบียน
#   bash scripts/multi-remote.sh add <name> <url>  # เพิ่ม remote ใหม่
#   bash scripts/multi-remote.sh remove <name>    # ลบ remote
#   bash scripts/multi-remote.sh push             # push แบบ load-balanced
#   bash scripts/multi-remote.sh status           # สุขภาพ remotes ทุกตัว

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

REMOTES_CONFIG="$JIT_ROOT/.jit-remotes.json"
PUSH_COUNTER_FILE="/tmp/jit-push-counter"
PUSH_LOG="/tmp/jit-push.log"

# ────────────────────────────────────────────────────────────────────
# Progress Bar
# ────────────────────────────────────────────────────────────────────
_rbar() {
  local PCT="$1" W="${2:-15}"
  local F=$(( PCT * W / 100 )) E=$(( W - PCT * W / 100 ))
  printf "${GREEN}%s${RESET}%s" "$(printf '█%.0s' $(seq 1 $F 2>/dev/null))" "$(printf '░%.0s' $(seq 1 $E 2>/dev/null))"
}

# ────────────────────────────────────────────────────────────────────
# Remote Registry (JSON-backed)
# ────────────────────────────────────────────────────────────────────
_init_remotes() {
  if [ ! -f "$REMOTES_CONFIG" ]; then
    # bootstrap จาก git remotes ที่มีอยู่แล้ว
    python3 - << PYEOF 2>/dev/null
import json, subprocess

remotes = {}
try:
  out = subprocess.check_output(['git', '-C', '$JIT_ROOT', 'remote', '-v'], text=True)
  for line in out.splitlines():
    parts = line.split()
    if len(parts) >= 2 and '(push)' in line:
      name, url = parts[0], parts[1]
      remotes[name] = {"url": url, "push_count": 0, "last_push": None, "enabled": True}
except Exception as e:
  pass

config = {"version": "1.0", "strategy": "round-robin", "remotes": remotes}
json.dump(config, open('$REMOTES_CONFIG', 'w'), indent=2)
print(f"  Initialized {len(remotes)} remote(s)")
PYEOF
  fi
}

_get_remotes() {
  python3 - << PYEOF 2>/dev/null
import json
try:
  c = json.load(open('$REMOTES_CONFIG'))
  for name, r in c.get('remotes', {}).items():
    if r.get('enabled', True):
      print(f"{name} {r['url']}")
except: pass
PYEOF
}

# ────────────────────────────────────────────────────────────────────
# Push Logic (Round-Robin Load Balance)
# ────────────────────────────────────────────────────────────────────
_do_push() {
  local BRANCH; BRANCH=$(git -C "$JIT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  _init_remotes

  # อ่าน counter สำหรับ round-robin
  local COUNTER=0
  [ -f "$PUSH_COUNTER_FILE" ] && COUNTER=$(cat "$PUSH_COUNTER_FILE" 2>/dev/null || echo 0)

  # รับรายชื่อ remotes
  mapfile -t REMOTE_LIST < <(_get_remotes)
  local TOTAL="${#REMOTE_LIST[@]}"

  if [ "$TOTAL" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  ไม่มี remote ที่ลงทะเบียน${RESET}"
    echo -e "  ${CYAN}💡 เพิ่มด้วย: bash scripts/multi-remote.sh add <name> <url>${RESET}"
    return 1
  fi

  echo ""
  echo -e "  ${BOLD}${CYAN}🦵 ขา — กำลัง push แบบ load-balanced${RESET}"
  echo -e "  strategy: round-robin | remotes: $TOTAL | branch: $BRANCH"
  echo ""

  local SUCCESS=0 FAILED=0
  for i in "${!REMOTE_LIST[@]}"; do
    local IDX=$(( (COUNTER + i) % TOTAL ))
    local RNAME; RNAME=$(echo "${REMOTE_LIST[$IDX]}" | awk '{print $1}')
    local RURL;  RURL=$(echo "${REMOTE_LIST[$IDX]}"  | awk '{print $2}')

    echo -ne "  $(_rbar $(( (i+1)*100/TOTAL )))  $RNAME  "

    # Test connectivity terlebih dahulu (ping)
    if git -C "$JIT_ROOT" ls-remote "$RNAME" HEAD > /dev/null 2>&1; then
      # Push
      if git -C "$JIT_ROOT" push "$RNAME" "$BRANCH" --quiet 2>/dev/null; then
        echo -e "${GREEN}✅ pushed${RESET}"
        SUCCESS=$(( SUCCESS + 1 ))
        # หยุดที่ remote แรกที่สำเร็จ (load balance = ไม่ push ซ้ำทุกตัว)
        break
      else
        echo -e "${YELLOW}⚠️  push failed — trying next${RESET}"
        FAILED=$(( FAILED + 1 ))
      fi
    else
      echo -e "${YELLOW}⚠️  unreachable — trying next${RESET}"
      FAILED=$(( FAILED + 1 ))
    fi
  done

  # อัปเดต counter
  echo $(( (COUNTER + 1) % TOTAL )) > "$PUSH_COUNTER_FILE"

  # บันทึก log
  echo "$(date '+%Y-%m-%d %H:%M:%S') push success=$SUCCESS failed=$FAILED branch=$BRANCH" >> "$PUSH_LOG"

  echo ""
  [ "$SUCCESS" -gt 0 ] && echo -e "  ${GREEN}✅ pushed to $SUCCESS remote(s)${RESET}" \
                        || echo -e "  ${RED}❌ push ล้มเหลวทุก remote${RESET}"
  return $([ "$SUCCESS" -gt 0 ] && echo 0 || echo 1)
}

# ────────────────────────────────────────────────────────────────────
# Commands
# ────────────────────────────────────────────────────────────────────
CMD="${1:-list}"
shift || true

case "$CMD" in
  list)
    _init_remotes
    echo ""
    echo -e "  ${BOLD}${CYAN}📡 Jit Multi-Remote Registry${RESET}"
    echo ""
    python3 - << PYEOF 2>/dev/null
import json
try:
  c = json.load(open('$REMOTES_CONFIG'))
  remotes = c.get('remotes', {})
  strategy = c.get('strategy', 'round-robin')
  print(f"  strategy: {strategy}")
  print()
  for name, r in remotes.items():
    status = '✅' if r.get('enabled', True) else '⏸️ '
    pushes = r.get('push_count', 0)
    last   = r.get('last_push', '-')
    print(f"  {status} {name:<20} pushes={pushes:<5} last={last}")
    print(f"     url: {r['url']}")
except Exception as e:
  print(f"  (ยังไม่มี config — รัน 'list' ครั้งแรกเพื่อ init)")
PYEOF
    echo ""
    ;;

  add)
    NAME="${1:?Usage: add <name> <url>}"
    URL="${2:?Usage: add <name> <url>}"
    _init_remotes
    # เพิ่มใน git
    git -C "$JIT_ROOT" remote add "$NAME" "$URL" 2>/dev/null || \
    git -C "$JIT_ROOT" remote set-url "$NAME" "$URL"
    # เพิ่มใน JSON
    python3 - << PYEOF 2>/dev/null
import json
c = json.load(open('$REMOTES_CONFIG'))
c['remotes']['$NAME'] = {"url": "$URL", "push_count": 0, "last_push": None, "enabled": True}
json.dump(c, open('$REMOTES_CONFIG', 'w'), indent=2)
print("  ✅ เพิ่ม remote: $NAME → $URL")
PYEOF
    echo -e "  ${CYAN}💡 tip: เพิ่ม GitHub accounts อื่นที่มี Repo ชื่อ 'Jit' เหมือนกัน${RESET}"
    ;;

  remove)
    NAME="${1:?Usage: remove <name>}"
    _init_remotes
    python3 - << PYEOF 2>/dev/null
import json
c = json.load(open('$REMOTES_CONFIG'))
if '$NAME' in c['remotes']:
  del c['remotes']['$NAME']
  json.dump(c, open('$REMOTES_CONFIG', 'w'), indent=2)
  print("  ✅ ลบ remote: $NAME")
else:
  print("  ⚠️  ไม่พบ remote: $NAME")
PYEOF
    ;;

  push)
    _do_push
    ;;

  status)
    _init_remotes
    echo ""
    echo -e "  ${BOLD}${CYAN}📊 Remote Health Check${RESET}"
    echo ""
    while IFS= read -r LINE; do
      RNAME=$(echo "$LINE" | awk '{print $1}')
      echo -ne "  $RNAME  "
      if git -C "$JIT_ROOT" ls-remote "$RNAME" HEAD > /dev/null 2>&1; then
        echo -e "${GREEN}✅ reachable${RESET}"
      else
        echo -e "${RED}❌ unreachable${RESET}"
      fi
    done < <(_get_remotes)
    echo ""
    ;;

  *)
    echo "Usage: $0 {list|add|remove|push|status}"
    ;;
esac
