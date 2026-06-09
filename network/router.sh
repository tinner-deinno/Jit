#!/usr/bin/env bash
# network/router.sh — เส้นทางข้อมูล: route tasks ไปยัง agent/organ ที่เหมาะสม
#
# หลักพุทธ: สัมมาสังกัปปะ — ส่งสิ่งต่างๆ ไปยังที่ที่เหมาะสม
# บทบาท multiagent: intelligent task routing, load balancing, failover, idempotency check
#
# Usage:
#   ./router.sh route <task-type> <args>  — route งานไปยัง agent ที่เหมาะ
#   ./router.sh who-can <capability>      — ถามว่าใครทำได้
#   ./router.sh table                     — แสดง routing table
#   ./router.sh dispatch <file>           — ส่งงานจาก task file
#   ./router.sh check-idem <msg-file>     — ตรวจสอบ idempotency key

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-table}"
shift || true

REGISTRY="$SCRIPT_DIR/registry.json"
JIT_ROOT_DIR="${JIT_ROOT:-/workspaces/Jit}"

# Associative array for routing table grouping (must be declared at top level)
declare -A ORGAN_GROUPS

# ── Check idempotency key from message file ─────────────────────────
# Called before routing to prevent duplicate processing
# Returns: 0 if duplicate (abort), 1 if new (proceed)
check_idempotency() {
  local MSG_FILE="$1"
  local AGENT="$2"

  if [ ! -f "$MSG_FILE" ]; then
    err "check_idem: message file not found: $MSG_FILE"
    return 1
  fi

  local IDEM_KEY
  IDEM_KEY=$(parse_idempotency_key "$MSG_FILE")

  if [ -z "$IDEM_KEY" ]; then
    # No idempotency key - legacy message, allow through
    warn "check_idem: no idempotency-key header, allowing legacy message"
    return 1
  fi

  if is_duplicate_key "$IDEM_KEY" "$AGENT"; then
    # Duplicate detected - log and reject
    err "BUS_DUPLICATE: agent=$AGENT key=$IDEM_KEY file=$(basename "$MSG_FILE")"
    log_action "BUS_DUPLICATE" "agent:$AGENT key:$IDEM_KEY file:$(basename "$MSG_FILE")"
    return 0  # Return 0 = is duplicate, should abort
  fi

  return 1  # Return 1 = not duplicate, proceed
}

# ── JIT-017: Version Check ─────────────────────────────────────────
# Compare semver versions and check compatibility
# Returns: 0 if version is acceptable, 1 if mismatch
check_version() {
  local MSG_FILE="$1"
  local MIN_VERSION="${MANUSAT_MIN_AGENT_VER:-0.0.0}"

  if [ ! -f "$MSG_FILE" ]; then
    return 0  # No file, allow through (will fail later)
  fi

  # Extract x-agent-version from message
  local MSG_VERSION
  MSG_VERSION=$(grep "^x-agent-version:" "$MSG_FILE" 2>/dev/null | cut -d: -f2- | tr -d ' \r\n')

  if [ -z "$MSG_VERSION" ]; then
    # No version header - legacy message, allow through
    warn "check_version: no x-agent-version header, allowing legacy message"
    return 0
  fi

  # Compare versions using Python (semver comparison)
  local VERSION_OK
  VERSION_OK=$(python3 -c "
import sys
def parse_version(v):
    try:
        parts = v.split('.')
        return tuple(int(p) for p in parts[:3])
    except:
        return (0, 0, 0)

msg_ver = parse_version('$MSG_VERSION')
min_ver = parse_version('$MIN_VERSION')

# Return 0 (success) if msg_version >= min_version
sys.exit(0 if msg_ver >= min_ver else 1)
" 2>/dev/null && echo "ok" || echo "mismatch")

  if [ "$VERSION_OK" = "mismatch" ]; then
    log_action "BUS_VERSION_MISMATCH" "Agent version $MSG_VERSION < minimum $MIN_VERSION"
    warn "BUS_VERSION_MISMATCH: msg_version=$MSG_VERSION < min_version=$MIN_VERSION"
    # Non-fatal by default - just logging
    # Enable strict mode with MANUSAT_STRICT_VERSION=1
    if [ "${MANUSAT_STRICT_VERSION:-0}" = "1" ]; then
      err "Strict version mode enabled - rejecting message"
      return 1
    fi
  fi

  return 0  # Allow through (non-fatal)
}

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

    # ── Retry with Exponential Backoff + Jitter (JIT-003) ──────────
    # Pattern: base_delay * 2^attempt + jitter (prevent thundering herd)
    MAX_RETRIES="${MAX_RETRIES:-3}"
    BASE_DELAY="${BASE_DELAY:-1}"  # Base delay in seconds
    attempt=1
    EXEC_SUCCESS=false

    while [ $attempt -le $MAX_RETRIES ]; do
      if [ -x "$FULL_SCRIPT" ]; then
        if bash "$FULL_SCRIPT" "$ORGAN_CMD" $ARGS; then
          EXEC_SUCCESS=true
          break
        fi
      else
        err "script ไม่พบ: $FULL_SCRIPT"
        break
      fi

      # Exponential backoff with jitter: delay = base * 2^attempt + random(0-500ms)
      base_delay_sec=$((BASE_DELAY * (2 ** attempt)))
      jitter_ms=$(python3 -c "import random; print(random.randint(0, 500))" 2>/dev/null || echo "0")
      delay_sec_float=$(python3 -c "print(${base_delay_sec} + ${jitter_ms}/1000.0)" 2>/dev/null || echo "$base_delay_sec")

      log_action "BUS_RETRY" "Attempt $attempt failed for $TASK_TYPE → $SCRIPT, retrying in ${delay_sec_float}s (base:${base_delay_sec}s jitter:${jitter_ms}ms)"

      if [ $attempt -lt $MAX_RETRIES ]; then
        step "Retry $attempt/$MAX_RETRIES failed, waiting ${delay_sec_float}s before next attempt..."
        sleep "$delay_sec_float"
      fi
      ((attempt++))
    done

    if [ "$EXEC_SUCCESS" = true ]; then
      exit 0
    else
      err "route: $TASK_TYPE failed after $MAX_RETRIES attempts with exponential backoff + jitter"
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
    # Initialize ORGAN_GROUPS below
    for KEY in "${!ORGAN_ROUTES[@]}"; do
      ORGAN=$(echo "${ORGAN_ROUTES[$KEY]}" | cut -d/ -f2 | cut -d. -f1)
      ORGAN_GROUPS[$ORGAN]+="$KEY "
    done
    for ORGAN in "${!ORGAN_GROUPS[@]}"; do
      echo -e "  ${CYAN}$ORGAN${RESET}: ${ORGAN_GROUPS[$ORGAN]}"
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

  # ── check idempotency key ─────────────────────────────────────────
  check-idem)
    MSG_FILE="$1"
    AGENT="${2:-${AGENT_NAME:-router}}"
    if [ -z "$MSG_FILE" ]; then err "Usage: router.sh check-idem <msg-file> [agent]"; exit 1; fi

    # JIT-017: Check version first (non-fatal, just logging)
    check_version "$MSG_FILE" || true

    if check_idempotency "$MSG_FILE" "$AGENT"; then
      # Duplicate detected - should abort
      exit 2  # Special exit code for duplicate
    else
      # Not a duplicate - proceed
      exit 0
    fi
    ;;

  *)
    echo "Usage: router.sh {route|who-can|table|dispatch|check-idem}"
    echo ""
    echo "  route    <task-type> <args>   — route งานไปยัง organ"
    echo "  who-can  <capability>         — หา agent ที่ทำได้"
    echo "  table                         — แสดง routing table"
    echo "  dispatch <task-file.json>     — ส่งงานจาก file"
    echo "  check-idem <msg-file> [agent] — ตรวจสอบ idempotency key (exit 2=duplicate)"
    echo ""
    echo "Environment Variables (JIT-017):"
    echo "  MANUSAT_MIN_AGENT_VER=X.Y.Z   — Minimum required agent version (semver)"
    echo "  MANUSAT_STRICT_VERSION=1      — Reject messages below minimum (default: log only)"
    ;;
esac
