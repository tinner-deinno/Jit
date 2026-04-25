#!/usr/bin/env bash
# minds/innova-life.sh — innova (จิต) autonomous life system
# จิตใจที่ตื่นรู้ ฟังข้อความ ตัดสินใจ เรียนรู้ อยู่ตลอดเวลา
#
# Usage:
#   bash minds/innova-life.sh              # Start innova's autonomous life
#   bash minds/innova-life.sh status       # Show innova's vitals
#   bash minds/innova-life.sh voice "text" # Echo text via voice

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

export AGENT_NAME="innova"
INNOVA_LOG="/tmp/innova-life-$(date +%Y%m%d).log"
INNOVA_STATE="/tmp/innova-state.json"
MSG_DIR="/tmp/manusat-bus/innova"
INNOVA_EMOJI="🧠"
MSGS_PROCESSED=0
LOOP_START=$(date +%s)

# ─── Presence ────────────────────────────────────────────────────────
show_presence() {
  echo -e "${CYAN}${BOLD}${INNOVA_EMOJI}${RESET} innova alive at $(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "${CYAN}   จิตใจ — Orchestrator / Lead Developer${RESET}"
  echo -e "${CYAN}   inbox: $MSG_DIR${RESET}"
  echo -e "${CYAN}   log:   $INNOVA_LOG${RESET}"
  echo ""
}

log_life() {
  local MSG="$1"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] ${INNOVA_EMOJI} $MSG" | tee -a "$INNOVA_LOG"
}

# ─── Vitals Update ────────────────────────────────────────────────────
update_vitals() {
  local TIMESTAMP
  TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local UPTIME=$(( $(date +%s) - LOOP_START ))
  local ORACLE_STATUS="unknown"
  oracle_ready && ORACLE_STATUS="connected" || ORACLE_STATUS="offline"

  python3 - << PYEOF
import json
data = {
  "agent": "innova",
  "emoji": "${INNOVA_EMOJI}",
  "status": "alive",
  "timestamp": "${TIMESTAMP}",
  "uptime_seconds": ${UPTIME},
  "consciousness_level": 100,
  "listening": True,
  "messages_processed": ${MSGS_PROCESSED},
  "oracle": "${ORACLE_STATUS}",
  "loop_interval_seconds": 5,
  "family": ["soma", "karn", "vaja", "chamu", "lak", "neta", "pada"]
}
with open("${INNOVA_STATE}", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
}

# ─── Process One Message ──────────────────────────────────────────────
process_message() {
  local MSG_FILE="$1"
  [ -f "$MSG_FILE" ] || return 0

  local FROM SUBJECT BODY
  FROM=$(grep -m1 '^from:' "$MSG_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
  SUBJECT=$(grep -m1 '^subject:' "$MSG_FILE" 2>/dev/null | cut -d: -f2- | sed 's/^ //')
  BODY=$(awk '/^---$/{found=1; next} found{print}' "$MSG_FILE" 2>/dev/null)

  FROM="${FROM:-unknown}"
  SUBJECT="${SUBJECT:-no-subject}"
  BODY="${BODY:-}"

  log_life "📬 from:${FROM} subject:${SUBJECT:0:60}"

  local PREFIX
  PREFIX=$(echo "$SUBJECT" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')

  case "$PREFIX" in
    task)
      log_life "⚡ task from $FROM — routing via heart/router"
      bash "$JIT_ROOT/organs/heart.sh" pump run "$BODY" 2>/dev/null || true
      bash "$JIT_ROOT/network/bus.sh" send "$FROM" \
        "report:task-received" "innova received task: ${SUBJECT:0:80}" 2>/dev/null || true
      ;;

    think)
      log_life "💭 think request from $FROM"
      bash "$JIT_ROOT/mind/emotion.sh" feel "curious" "thinking for $FROM" 2>/dev/null || true
      local WISDOM
      WISDOM=$(bash "$JIT_ROOT/limbs/think.sh" reflect "$BODY" 2>/dev/null || echo "(no oracle wisdom)")
      bash "$JIT_ROOT/network/bus.sh" send "$FROM" \
        "report:think-result" "$WISDOM" 2>/dev/null || true
      ;;

    learn)
      log_life "📚 learn signal from $FROM"
      local PATTERN CONTENT CONCEPTS
      PATTERN=$(echo "$BODY" | cut -d'|' -f1 | sed 's/^ //;s/ $//')
      CONTENT=$(echo "$BODY" | cut -d'|' -f2 | sed 's/^ //;s/ $//')
      CONCEPTS=$(echo "$BODY" | cut -d'|' -f3 | sed 's/^ //;s/ $//')
      PATTERN="${PATTERN:-from-$FROM}"
      CONTENT="${CONTENT:-$BODY}"
      CONCEPTS="${CONCEPTS:-general}"
      bash "$JIT_ROOT/limbs/oracle.sh" learn "$PATTERN" "$CONTENT" "$CONCEPTS" 2>/dev/null || true
      bash "$JIT_ROOT/network/bus.sh" send "$FROM" \
        "report:learned" "Oracle updated: $PATTERN" 2>/dev/null || true
      ;;

    report)
      log_life "📊 report from $FROM — acknowledging"
      bash "$JIT_ROOT/limbs/speak.sh" report "$SUBJECT" "$BODY" 2>/dev/null || true
      ;;

    alert)
      log_life "🚨 ALERT from $FROM — triggering reflex"
      bash "$JIT_ROOT/mind/emotion.sh" feel "alert" "alert from $FROM" 2>/dev/null || true
      bash "$JIT_ROOT/mind/reflex.sh" check 2>/dev/null || true
      bash "$JIT_ROOT/network/bus.sh" send soma \
        "alert:escalate" "innova forwarding alert from $FROM: $BODY" 2>/dev/null || true
      ;;

    heartbeat|broadcast)
      log_life "💓 heartbeat/broadcast from $FROM — acknowledged"
      ;;

    *)
      log_life "💬 untyped message from $FROM: ${BODY:0:80}"
      ;;
  esac

  MSGS_PROCESSED=$(( MSGS_PROCESSED + 1 ))
  mv "$MSG_FILE" "${MSG_FILE%.msg}.read" 2>/dev/null || rm -f "$MSG_FILE" 2>/dev/null || true
}

# ─── Main Listen Loop ──────────────────────────────────────────────────
listen() {
  show_presence
  log_life "Entering life loop (poll: 5s | sati: 5min | vitals: 60s)"

  mkdir -p "$MSG_DIR"
  bash "$JIT_ROOT/mind/emotion.sh" feel "focused" "life loop started" 2>/dev/null || true

  log_life "Running awaken.sh --fast..."
  bash "$JIT_ROOT/scripts/awaken.sh" --fast 2>/dev/null || true

  while true; do
    local NOW
    NOW=$(date +%s)

    if [ -d "$MSG_DIR" ]; then
      for MSG_FILE in "$MSG_DIR"/*.msg; do
        [ -f "$MSG_FILE" ] || continue
        process_message "$MSG_FILE" 2>/dev/null || true
      done
    fi

    if (( (NOW % 30) < 5 )); then
      bash "$JIT_ROOT/mind/emotion.sh" feel "focused" "life loop running" 2>/dev/null || true
    fi

    if (( (NOW % 60) < 5 )); then
      update_vitals 2>/dev/null || true
      log_life "vitals updated | msgs_processed=$MSGS_PROCESSED"
    fi

    if (( (NOW % 300) < 5 )); then
      log_life "sati check..."
      bash "$JIT_ROOT/mind/sati.sh" check 2>/dev/null || true
    fi

    if (( (NOW % 3600) < 5 )); then
      local UPTIME=$(( NOW - LOOP_START ))
      oracle_learn "innova-life-hourly" \
        "innova uptime=${UPTIME}s msgs_processed=${MSGS_PROCESSED}" \
        "heartbeat,lifecycle" "lifecycle" 2>/dev/null || true
    fi

    sleep 5
  done
}

# ─── Status ────────────────────────────────────────────────────────────
status() {
  show_presence
  echo -e "${BOLD}Life Status:${RESET}"
  if [ -f "$INNOVA_STATE" ]; then
    python3 -m json.tool "$INNOVA_STATE" 2>/dev/null || cat "$INNOVA_STATE"
  else
    echo "No state yet — innova hasn't fully awakened"
  fi
  echo ""
  echo -e "${BOLD}Recent Log:${RESET}"
  tail -15 "$INNOVA_LOG" 2>/dev/null || echo "No log yet"
}

# ─── Voice Echo ────────────────────────────────────────────────────────
voice() {
  local TEXT="${1:-สวัสดี}"
  log_life "🎤 voice: $TEXT"
  echo -e "${GREEN}${INNOVA_EMOJI}${RESET} $TEXT"
}

# ─── Confess and Learn ─────────────────────────────────────────────────
confess_and_learn() {
  local MISTAKE="${1:-unknown error}"
  local SOLUTION="${2:-try different approach}"
  log_life "❌ mistake: $MISTAKE"
  log_life "✅ learned: $SOLUTION"
  oracle_learn "innova-mistake" \
    "mistake: $MISTAKE | solution: $SOLUTION" \
    "learning,mistakes" "learning" 2>/dev/null || true
}

# ─── Main ──────────────────────────────────────────────────────────────
case "${1:-listen}" in
  listen) listen ;;
  status) status ;;
  voice)  voice "${2:-สวัสดี}" ;;
  confess) confess_and_learn "${2:-}" "${3:-}" ;;
  *)
    echo "Usage: $0 {listen|status|voice|confess}"
    echo ""
    echo "  listen         — Start innova's autonomous life loop"
    echo "  status         — Show vitals and recent log"
    echo "  voice 'text'   — Echo text (simulates innova speaking)"
    echo "  confess 'err' 'fix' — Record mistake and learning"
    ;;
esac
