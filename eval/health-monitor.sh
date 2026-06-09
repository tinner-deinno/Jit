#!/usr/bin/env bash
# eval/health-monitor.sh — Real-time health monitoring with JSON output
# Fast, non-blocking health checks optimized for Codex CLI
# Usage: bash eval/health-monitor.sh [--format json|text] [--check oracle|agents|limbs|all]
#
# Outputs JSON structure:
# {
#   "status": "healthy|degraded|critical",
#   "timestamp": "2026-06-08T10:16:57Z",
#   "completion_percent": 0-100,
#   "services": { "oracle": {...}, "agents": {...}, ... },
#   "summary": { "pass": N, "fail": N, "warn": N }
# }

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
FORMAT="${1:-json}"
CHECK_TARGET="${2:-all}"
TIMEOUT_SHORT=2
TIMEOUT_LONG=5

# Initialize counters
PASS=0
FAIL=0
WARN=0
TOTAL_CHECKS=0

# Load color codes if in text mode
if [ "$FORMAT" = "text" ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  RESET='\033[0m'
else
  GREEN=""
  RED=""
  YELLOW=""
  RESET=""
fi

# Helper: emit JSON incrementally
json_service() {
  local name="$1" status="$2" message="$3"
  echo "    \"$name\": {\"status\": \"$status\", \"message\": \"$message\"}"
}

# Helper: check pass/fail/warn
check_pass() {
  ((PASS++)) || true
  ((TOTAL_CHECKS++)) || true
  [ "$FORMAT" = "text" ] && echo -e "  ${GREEN}✅${RESET} $1" || true
}

check_fail() {
  ((FAIL++)) || true
  ((TOTAL_CHECKS++)) || true
  [ "$FORMAT" = "text" ] && echo -e "  ${RED}❌${RESET} $1" || true
}

check_warn() {
  ((WARN++)) || true
  ((TOTAL_CHECKS++)) || true
  [ "$FORMAT" = "text" ] && echo -e "  ${YELLOW}⚠️ ${RESET} $1" || true
}

# Calculate completion percent (fast: non-blocking, test spawn capability)
calc_completion() {
  local pass="$1" total="$2"
  if [ "$total" -gt 0 ]; then
    echo $(( (pass * 100) / total ))
  else
    echo 0
  fi
}

# Start JSON output
if [ "$FORMAT" = "json" ]; then
  echo "{"
  echo "  \"status\": \"pending\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"completion_percent\": 0,"
  echo "  \"services\": {"
fi

[ "$FORMAT" = "text" ] && echo "=== Health Monitor ===" && echo ""

# ════════════════════════════════════════════════════════
# ORACLE CHECK (fast timeout: 2s)
# ════════════════════════════════════════════════════════
if [ "$CHECK_TARGET" = "all" ] || [ "$CHECK_TARGET" = "oracle" ]; then
  [ "$FORMAT" = "text" ] && echo "[ Oracle Service ]"

  ORACLE_HEALTH=$(curl -s --max-time $TIMEOUT_SHORT "$ORACLE_URL/api/health" 2>/dev/null || echo "")
  if [ -n "$ORACLE_HEALTH" ] && echo "$ORACLE_HEALTH" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
    check_pass "Oracle API responding"
    ORACLE_STATUS="healthy"
  else
    check_fail "Oracle API unreachable"
    ORACLE_STATUS="offline"
  fi

  if [ "$FORMAT" = "json" ]; then
    echo "    \"oracle\": {\"status\": \"$ORACLE_STATUS\", \"message\": \"Oracle at $ORACLE_URL\"},"
  fi
fi

# ════════════════════════════════════════════════════════
# AGENT MESSAGE BUS CHECK (fast timeout: 1s)
# ════════════════════════════════════════════════════════
if [ "$CHECK_TARGET" = "all" ] || [ "$CHECK_TARGET" = "agents" ]; then
  [ "$FORMAT" = "text" ] && echo "[ Message Bus ]"

  BUS_DIR="/tmp/manusat-bus"
  if [ -d "$BUS_DIR" ]; then
    QUEUE_COUNT=$(find "$BUS_DIR" -type f -name "*.msg" 2>/dev/null | wc -l)
    check_pass "Message bus directory exists ($QUEUE_COUNT pending)"
    BUS_STATUS="healthy"
    [ "$QUEUE_COUNT" -gt 50 ] && { check_warn "Queue backing up (>50 messages)"; BUS_STATUS="degraded"; }
  else
    check_fail "Message bus directory not found"
    BUS_STATUS="offline"
  fi

  if [ "$FORMAT" = "json" ]; then
    echo "    \"message_bus\": {\"status\": \"$BUS_STATUS\", \"message\": \"Queue: $QUEUE_COUNT pending\"},"
  fi
fi

# ════════════════════════════════════════════════════════
# HEARTBEAT CHECK (fast file I/O)
# ════════════════════════════════════════════════════════
HEART_OUT="/workspaces/Jit/memory/state/heart.out.json"
[ "$FORMAT" = "text" ] && echo "[ Vital Signs ]"

if [ -f "$HEART_OUT" ]; then
  HEART_TS=$(python3 -c "import json; print(json.load(open('$HEART_OUT')).get('timestamp', 'invalid'))" 2>/dev/null)
  if [ "$HEART_TS" != "invalid" ]; then
    HEART_EPOCH=$(date -d "$HEART_TS" +%s 2>/dev/null || echo "0")
    NOW_EPOCH=$(date +%s)
    HEART_AGE=$((NOW_EPOCH - HEART_EPOCH))
    if [ "$HEART_AGE" -lt 300 ]; then
      check_pass "Heart pulse fresh (${HEART_AGE}s)"
      HEART_STATUS="healthy"
    else
      check_warn "Heart pulse stale (${HEART_AGE}s old)"
      HEART_STATUS="stale"
    fi
  else
    check_fail "Heart pulse timestamp invalid"
    HEART_STATUS="invalid"
  fi
else
  check_fail "heart.out.json missing"
  HEART_STATUS="missing"
fi

if [ "$FORMAT" = "json" ]; then
  echo "    \"heartbeat\": {\"status\": \"$HEART_STATUS\", \"message\": \"Last pulse: ${HEART_AGE:-?}s ago\"},"
fi

# ════════════════════════════════════════════════════════
# LIMBS CHECK (fast file existence)
# ════════════════════════════════════════════════════════
if [ "$CHECK_TARGET" = "all" ] || [ "$CHECK_TARGET" = "limbs" ]; then
  [ "$FORMAT" = "text" ] && echo "[ Limbs (Cognition) ]"

  LIMBS_OK=0
  LIMBS=(lib think act speak ollama oracle)
  for L in "${LIMBS[@]}"; do
    if [ -f "$JIT_ROOT/limbs/${L}.sh" ]; then
      ((LIMBS_OK++)) || true
    fi
  done

  LIMBS_TOTAL=${#LIMBS[@]}
  check_pass "Limbs: $LIMBS_OK/$LIMBS_TOTAL available"
  [ "$LIMBS_OK" -eq "$LIMBS_TOTAL" ] && LIMBS_STATUS="healthy" || LIMBS_STATUS="degraded"

  if [ "$FORMAT" = "json" ]; then
    echo "    \"limbs\": {\"status\": \"$LIMBS_STATUS\", \"message\": \"$LIMBS_OK/$LIMBS_TOTAL limbs present\"},"
  fi
fi

# ════════════════════════════════════════════════════════
# ORGANS CHECK (fast file existence)
# ════════════════════════════════════════════════════════
if [ "$CHECK_TARGET" = "all" ] || [ "$CHECK_TARGET" = "agents" ]; then
  [ "$FORMAT" = "text" ] && echo "[ Organs (I/O) ]"

  ORGANS_OK=0
  ORGANS=(eye ear mouth nose hand leg heart nerve)
  for O in "${ORGANS[@]}"; do
    if [ -f "$JIT_ROOT/organs/${O}.sh" ] && [ -x "$JIT_ROOT/organs/${O}.sh" ]; then
      ((ORGANS_OK++)) || true
    fi
  done

  ORGANS_TOTAL=${#ORGANS[@]}
  check_pass "Organs: $ORGANS_OK/$ORGANS_TOTAL available"
  [ "$ORGANS_OK" -eq "$ORGANS_TOTAL" ] && ORGANS_STATUS="healthy" || ORGANS_STATUS="degraded"

  if [ "$FORMAT" = "json" ]; then
    echo "    \"organs\": {\"status\": \"$ORGANS_STATUS\", \"message\": \"$ORGANS_OK/$ORGANS_TOTAL organs ready\"},"
  fi
fi

# ════════════════════════════════════════════════════════
# AGENT REGISTRY CHECK
# ════════════════════════════════════════════════════════
[ "$FORMAT" = "text" ] && echo "[ Agent Registry ]"

if [ -f "$JIT_ROOT/network/registry.json" ]; then
  AGENT_COUNT=$(python3 -c "import json; print(len(json.load(open('$JIT_ROOT/network/registry.json')).get('agents',[])))" 2>/dev/null || echo "0")
  check_pass "Registry exists ($AGENT_COUNT agents)"
  REGISTRY_STATUS="healthy"
else
  check_fail "Agent registry not found"
  REGISTRY_STATUS="missing"
fi

if [ "$FORMAT" = "json" ]; then
  echo "    \"registry\": {\"status\": \"$REGISTRY_STATUS\", \"message\": \"$AGENT_COUNT agents registered\"}"
  echo "  },"
fi

# ════════════════════════════════════════════════════════
# CALCULATE OVERALL STATUS & COMPLETION
# ════════════════════════════════════════════════════════
COMPLETION=$(calc_completion "$PASS" "$TOTAL_CHECKS")

if [ "$FAIL" -eq 0 ]; then
  OVERALL_STATUS="healthy"
elif [ "$FAIL" -le 2 ]; then
  OVERALL_STATUS="degraded"
else
  OVERALL_STATUS="critical"
fi

# ════════════════════════════════════════════════════════
# OUTPUT SUMMARY
# ════════════════════════════════════════════════════════
if [ "$FORMAT" = "json" ]; then
  echo "  \"summary\": {"
  echo "    \"pass\": $PASS,"
  echo "    \"fail\": $FAIL,"
  echo "    \"warn\": $WARN,"
  echo "    \"total\": $TOTAL_CHECKS"
  echo "  },"
  echo "  \"completion_percent\": $COMPLETION,"
  echo "  \"status\": \"$OVERALL_STATUS\""
  echo "}"
else
  echo ""
  echo "════════════════════════════════"
  echo -e "  ${GREEN}PASS: $PASS${RESET} | ${RED}FAIL: $FAIL${RESET} | ${YELLOW}WARN: $WARN${RESET}"
  echo "  Completion: $COMPLETION%"
  echo ""
  case "$OVERALL_STATUS" in
    healthy)
      echo -e "  ${GREEN}✅ System Healthy${RESET}"
      ;;
    degraded)
      echo -e "  ${YELLOW}⚠️  System Degraded${RESET}"
      ;;
    critical)
      echo -e "  ${RED}❌ System Critical${RESET}"
      ;;
  esac
  echo ""
fi

# Exit code based on status
case "$OVERALL_STATUS" in
  healthy) exit 0 ;;
  degraded) exit 1 ;;
  critical) exit 2 ;;
esac
