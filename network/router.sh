#!/usr/bin/env bash
# network/router.sh — เส้นทางข้อมูล: route tasks ไปยัง agent/organ ที่เหมาะสม
#
# หลักพุทธ: สัมมาสังกัปปะ — ส่งสิ่งต่างๆ ไปยังที่ที่เหมาะสม
# บทบาท multiagent: intelligent task routing, load balancing, failover
#
# Usage:
#   ./router.sh route <task-type> <args>  — route งานไปยัง agent ที่เหมาะ
#   ./router.sh who-can <capability>      — ถามว่าใครทำได้
#   ./router.sh table                     — แสดง routing table
#   ./router.sh dispatch <file>           — ส่งงานจาก task file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-table}"
shift || true

REGISTRY="$SCRIPT_DIR/registry.json"
JIT_ROOT_DIR="${JIT_ROOT:-/workspaces/Jit}"

# ── Routing Table: task_type → organ_script ─────────────────────────
# กาย-วาจา-ใจ mapped to organs
declare -A ORGAN_ROUTES=(
  # ตา — vision
  ["read"]="organs/eye.sh read"
  ["scan"]="organs/eye.sh scan"
  ["web"]="organs/eye.sh web"
  ["observe"]="organs/eye.sh observe"
  ["diff"]="organs/eye.sh diff"
  # หู — hearing
  ["listen"]="organs/ear.sh listen"
  ["receive"]="organs/ear.sh receive"
  ["inbox"]="organs/ear.sh inbox"
  # ปาก — speech
  ["say"]="organs/mouth.sh say"
  ["tell"]="organs/mouth.sh tell"
  ["broadcast"]="organs/mouth.sh broadcast"
  ["report"]="organs/mouth.sh report"
  # จมูก — detection
  ["sniff"]="organs/nose.sh sniff"
  ["alert"]="organs/nose.sh alert"
  ["monitor"]="organs/nose.sh monitor"
  ["health"]="organs/nose.sh health"
  # มือ — action
  ["create"]="organs/hand.sh create"
  ["edit"]="organs/hand.sh edit"
  ["build"]="organs/hand.sh build"
  ["call"]="organs/hand.sh call"
  ["execute"]="organs/hand.sh execute"
  # ขา — movement
  ["go"]="organs/leg.sh go"
  ["jump"]="organs/leg.sh jump"
  ["deploy"]="organs/leg.sh deploy"
  ["step"]="organs/leg.sh step"
  # ใจ/จิต — cognition
  ["think"]="limbs/think.sh reflect"
  ["plan"]="limbs/think.sh plan"
  ["pause"]="limbs/think.sh pause"
  # ปัญญา — knowledge
  ["oracle-search"]="limbs/oracle.sh search"
  ["oracle-learn"]="limbs/oracle.sh learn"
  ["ask"]="limbs/ollama.sh ask"
  ["create-content"]="limbs/ollama.sh create"
  # กาย (act)
  ["git"]="limbs/act.sh git"
  ["run"]="limbs/act.sh run"
  ["learn"]="limbs/act.sh learn"
  # วาจา (speak)
  ["success"]="limbs/speak.sh success"
  ["failure"]="limbs/speak.sh failure"
  ["insight"]="limbs/speak.sh insight"
  ["summary"]="limbs/speak.sh summary"
)

case "$CMD" in

  # ── route งาน ───────────────────────────────────────────────────
  route)
    TASK_TYPE="$1"
    shift || true
    ARGS="$*"
    ROUTE="${ORGAN_ROUTES[$TASK_TYPE]:-}"

    if [ -z "$ROUTE" ]; then
      warn "ไม่มี route สำหรับ: $TASK_TYPE — fallback → hand"
      bash "$JIT_ROOT_DIR/organs/hand.sh" execute "$ARGS"
      exit 1
    fi

    SCRIPT=$(echo "$ROUTE" | awk '{print $1}')
    ORGAN_CMD=$(echo "$ROUTE" | awk '{print $2}')
    FULL_SCRIPT="$JIT_ROOT_DIR/$SCRIPT"

    log_action "ROUTER" "$TASK_TYPE → $SCRIPT $ORGAN_CMD"
    step "route: $TASK_TYPE → $SCRIPT"

    if [ -x "$FULL_SCRIPT" ]; then
      bash "$FULL_SCRIPT" "$ORGAN_CMD" $ARGS
    else
      err "script ไม่พบ: $FULL_SCRIPT"
      exit 1
    fi
    ;;

  # ── ถามว่าใครทำงานนั้นได้ ─────────────────────────────────────────
  who-can)
    CAPABILITY="$1"
    if [ -z "$CAPABILITY" ]; then err "ต้องระบุ capability"; exit 1; fi
    echo ""
    step "ค้นหา agent ที่มี capability: $CAPABILITY"
    if [ -f "$REGISTRY" ]; then
      python3 -c "
import json
with open('$REGISTRY') as f:
    d = json.load(f)
for a in d.get('agents', []):
    if '$CAPABILITY' in a.get('capabilities', []):
        print(f\"  ✓ {a['name']} ({a['role']}) — {a['description']}\")
"
    fi
    # ตรวจ organ routes
    for KEY in "${!ORGAN_ROUTES[@]}"; do
      [[ "$KEY" == *"$CAPABILITY"* ]] && echo "  ○ organ route: $KEY → ${ORGAN_ROUTES[$KEY]}"
    done | head -5
    echo ""
    ;;

  # ── แสดง routing table ────────────────────────────────────────────
  table)
    echo ""
    echo -e "${BOLD}=== Routing Table ===${RESET}"
    echo ""
    # จัดกลุ่มตาม organ
    declare -A GROUPS
    for KEY in "${!ORGAN_ROUTES[@]}"; do
      ORGAN=$(echo "${ORGAN_ROUTES[$KEY]}" | cut -d/ -f2 | cut -d. -f1)
      GROUPS[$ORGAN]+="$KEY "
    done
    for ORGAN in "${!GROUPS[@]}"; do
      echo -e "  ${CYAN}$ORGAN${RESET}: ${GROUPS[$ORGAN]}"
    done | sort
    echo ""
    ;;

  # ── dispatch จาก task file ────────────────────────────────────────
  dispatch)
    TASK_FILE="${1:-/tmp/innova-task.json}"
    if [ ! -f "$TASK_FILE" ]; then err "ไม่พบ: $TASK_FILE"; exit 1; fi
    step "dispatch tasks จาก: $TASK_FILE"
    python3 - "$TASK_FILE" <<'PYEOF'
import json, sys, subprocess
with open(sys.argv[1]) as f:
    tasks = json.load(f)
if isinstance(tasks, dict):
    tasks = [tasks]
for i, task in enumerate(tasks, 1):
    t = task.get('type', 'run')
    args = task.get('args', '')
    print(f"  [{i}/{len(tasks)}] {t}: {str(args)[:50]}")
    cmd = ['/workspaces/Jit/network/router.sh', 'route', t]
    if args:
        cmd += args if isinstance(args, list) else [str(args)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print("    ✅ done")
    else:
        print(f"    ❌ failed: {result.stderr[:100]}")
PYEOF
    ;;

  *)
    echo "Usage: router.sh {route|who-can|table|dispatch}"
    echo ""
    echo "  route    <task-type> <args>   — route งานไปยัง organ"
    echo "  who-can  <capability>         — หา agent ที่ทำได้"
    echo "  table                         — แสดง routing table"
    echo "  dispatch <task-file.json>     — ส่งงานจาก file"
    ;;
esac
