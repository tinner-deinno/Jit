#!/usr/bin/env bash
# organs/leg.sh — ขา (Legs): เดิน ย้าย นำทาง ข้ามระบบ
#
# หลักพุทธ: สัมมาวายามะ + ปธาน — ความพยายามไปสู่เป้าหมาย
# บทบาท multiagent: navigation, traversal, system movement, ssh, deployment
#
# Usage:
#   ./leg.sh go <dir>             — เดินทางไป directory
#   ./leg.sh jump <project>       — กระโดดไป project ที่รู้จัก
#   ./leg.sh climb <repo-url>     — clone และเข้าไป
#   ./leg.sh deploy <target>      — deploy ไป target
#   ./leg.sh step <n> <cmds...>   — ทำงานทีละขั้น (pipeline)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-help}"
shift || true

# Known locations — แผนที่สำหรับ agent
declare -A KNOWN_PLACES=(
  ["jit"]="/workspaces/Jit"
  ["oracle"]="/workspaces/arra-oracle-v3"
  ["home"]="$HOME"
  ["tmp"]="/tmp"
  ["scripts"]="/workspaces/Jit/scripts"
)

case "$CMD" in

  # ── เดินทางไป dir ─────────────────────────────────────────────────
  go)
    TARGET="$1"
    if [ -d "$TARGET" ]; then
      cd "$TARGET" && ok "ขา เดินไป: $TARGET" && pwd
      log_action "LEG_GO" "$TARGET"
    else
      err "ไม่พบ: $TARGET"
      exit 1
    fi
    ;;

  # ── กระโดดไป project ที่รู้จัก ────────────────────────────────────
  jump)
    NAME="$1"
    TARGET="${KNOWN_PLACES[$NAME]:-}"
    if [ -z "$TARGET" ]; then
      err "ไม่รู้จัก: $NAME"
      echo "   รู้จัก: ${!KNOWN_PLACES[*]}"
      exit 1
    fi
    if [ -d "$TARGET" ]; then
      cd "$TARGET" && ok "ขา กระโดดไป: $NAME ($TARGET)" && pwd
      log_action "LEG_JUMP" "$NAME → $TARGET"
    else
      err "ไม่พบ: $TARGET"
    fi
    ;;

  # ── clone repo และเข้าไป ─────────────────────────────────────────
  climb)
    REPO_URL="$1" DIR="${2:-}"
    if [ -z "$REPO_URL" ]; then err "ต้องระบุ repo URL"; exit 1; fi
    [ -z "$DIR" ] && DIR=$(basename "$REPO_URL" .git)
    step "ขา ปีน: $REPO_URL → $DIR"
    git clone "$REPO_URL" "/workspaces/$DIR" 2>&1 | tail -3
    log_action "LEG_CLIMB" "$REPO_URL → /workspaces/$DIR"
    ok "clone สำเร็จ: /workspaces/$DIR"
    ;;

  # ── ทำงานทีละขั้น (pipeline steps) ───────────────────────────────
  step)
    N_STEPS="${1:-0}"
    shift || true
    TOTAL="${N_STEPS}"
    CURRENT=0
    echo ""
    echo -e "${BOLD}Pipeline: $TOTAL ขั้นตอน${RESET}"
    while [ $# -gt 0 ]; do
      ((CURRENT++))
      CMD_STEP="$1"
      shift
      PCT=$(( (CURRENT * 100) / TOTAL ))
      echo -ne "\r${CYAN}[$PCT%]${RESET} ขั้น $CURRENT/$TOTAL: $CMD_STEP"
      eval "$CMD_STEP" > /tmp/leg-step-${CURRENT}.log 2>&1
      if [ $? -eq 0 ]; then
        echo -e "\r${GREEN}[$PCT%]${RESET} ✓ ขั้น $CURRENT/$TOTAL: $CMD_STEP"
      else
        echo -e "\r${RED}[$PCT%]${RESET} ✗ ขั้น $CURRENT/$TOTAL: $CMD_STEP"
        err "ล้มเหลว — ดู /tmp/leg-step-${CURRENT}.log"
        cat "/tmp/leg-step-${CURRENT}.log"
        break
      fi
    done
    log_action "LEG_STEP" "$TOTAL steps"
    ;;

  # ── deploy ────────────────────────────────────────────────────────
  deploy)
    TARGET="${1:-local}"
    log_action "LEG_DEPLOY" "$TARGET"
    case "$TARGET" in
      local)
        step "deploy local — git status"
        cd "${JIT_ROOT}" && git status --short
        ;;
      oracle)
        step "start Oracle server"
        bash "$SCRIPT_DIR/../limbs/oracle.sh" start
        ;;
      *)
        warn "ไม่รู้จัก target: $TARGET"
        ;;
    esac
    ;;

  # ── แสดงแผนที่ ────────────────────────────────────────────────────
  map)
    echo ""
    echo -e "${BOLD}แผนที่สถานที่ที่รู้จัก:${RESET}"
    for KEY in "${!KNOWN_PLACES[@]}"; do
      PLACE="${KNOWN_PLACES[$KEY]}"
      [ -d "$PLACE" ] && MARK="${GREEN}✓${RESET}" || MARK="${RED}✗${RESET}"
      echo -e "   $MARK $KEY → $PLACE"
    done
    echo ""
    ;;

  # ── สถานะ ────────────────────────────────────────────────────────
  status)
    ok "ขา (leg) พร้อม | อยู่ที่: $(pwd)"
    echo "   สามารถ: go | jump | climb | step | deploy | map"
    ;;

  *)
    echo "Usage: leg.sh {go|jump|climb|step|deploy|map|status}"
    echo ""
    echo "  go     <dir>                   — เดินไป directory"
    echo "  jump   <name>                  — กระโดดไป project ที่รู้จัก"
    echo "  climb  <repo-url> [dir]        — clone repo"
    echo "  step   <n> <cmd1> <cmd2> ...   — pipeline ทีละขั้น"
    echo "  deploy <target>                — deploy"
    echo "  map                            — แสดงแผนที่ project"
    ;;
esac
