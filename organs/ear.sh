#!/usr/bin/env bash
# organs/ear.sh — หู (Hearing): ฟัง รับข้อมูล รับคำสั่ง
#
# หลักพุทธ: โสตาปัตติมรรค — เกิดปัญญาจากการฟัง (สุตมยปัญญา)
# บทบาท multiagent: รับ message จาก agent อื่น, ฟัง queue, รับ webhook
#
# Usage:
#   ./ear.sh listen               — รอรับ message (blocking)
#   ./ear.sh receive              — รับ message ที่รอ (non-blocking)
#   ./ear.sh inbox                — ดู inbox ของ agent นี้
#   ./ear.sh from <agent>         — รับเฉพาะจาก agent นั้น
#   ./ear.sh clear                — ล้าง inbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

# inbox directory: แต่ละ agent มี inbox ของตัวเอง
AGENT_NAME="${AGENT_NAME:-innova}"
INBOX_DIR="${INBOX_DIR:-/tmp/manusat-bus}"
MY_INBOX="$INBOX_DIR/$AGENT_NAME"

mkdir -p "$MY_INBOX"

CMD="${1:-inbox}"
shift || true

# ─── Message Header Parsing ─────────────────────────────────────────
# Safely extracts metadata from message files using parameter expansion
# Handles colons in values (e.g., timestamps like 2026-06-08T00:25:18)
# Usage: eval "$(parse_message_header "$MSG_FILE")"
# Outputs: FROM=... SUBJECT=... TO=... TIMESTAMP=... EXPIRES_AT=...

# Trims leading/trailing whitespace from a string
_trim() {
  local var="$1"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# Validates that required message headers were found
# Returns 0 if valid, 1 if missing required fields
_validate_message_headers() {
  local FROM="$1" TO="$2" SUBJECT="$3" MSG_FILE="$4"

  local MISSING=""
  [ -z "$FROM" ] && MISSING="$MISSING from"
  [ -z "$TO" ] && MISSING="$MISSING to"
  [ -z "$SUBJECT" ] && MISSING="$MISSING subject"

  if [ -n "$MISSING" ]; then
    err "BUS_PARSE_FAIL: Message missing required headers ($MISSING)"
    log_action "EAR_REJECTED" "Missing headers in $(basename "$MSG_FILE"): $MISSING"
    return 1
  fi
  return 0
}

parse_message_header() {
  local MSG_FILE="$1"
  local FROM="" SUBJECT="" TO="" TIMESTAMP="" EXPIRES_AT="" SIGNATURE=""

  # Verify file exists and is readable
  if [ ! -f "$MSG_FILE" ]; then
    err "BUS_PARSE_FAIL: Message file not found: $MSG_FILE"
    return 1
  fi

  # Read headers (everything before ---)
  local HEADERS
  HEADERS=$(sed -n '1,/^---$/p' "$MSG_FILE" | head -n -1)

  # Handle empty or missing headers
  if [ -z "$HEADERS" ]; then
    err "BUS_PARSE_FAIL: No headers found in $MSG_FILE"
    return 1
  fi

  # Parse each header line safely using parameter expansion
  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Extract key and value using parameter expansion (handles colons in values)
    # Trim whitespace from both key and value for tolerance of format variations
    case "$(_trim "$line")" in
      from:*)           FROM="$(_trim "${line#from:}")" ;;
      to:*)             TO="$(_trim "${line#to:}")" ;;
      subject:*)        SUBJECT="$(_trim "${line#subject:}")" ;;
      timestamp:*)      TIMESTAMP="$(_trim "${line#timestamp:}")" ;;
      expires-at:*)     EXPIRES_AT="$(_trim "${line#expires-at:}")" ;;
      x-signature:*)    SIGNATURE="$(_trim "${line#x-signature:hmac-sha256=}")" ;;
    esac
  done <<< "$HEADERS"

  # Output as shell variables for eval (single-quote values, escape internal quotes)
  _escape_for_shell() {
    printf '%s' "$1" | sed "s/'/'\\\"'\\\"'/g"
  }
  printf "FROM='%s'\n" "$(_escape_for_shell "$FROM")"
  printf "SUBJECT='%s'\n" "$(_escape_for_shell "$SUBJECT")"
  printf "TO='%s'\n" "$(_escape_for_shell "$TO")"
  printf "TIMESTAMP='%s'\n" "$(_escape_for_shell "$TIMESTAMP")"
  printf "EXPIRES_AT='%s'\n" "$(_escape_for_shell "$EXPIRES_AT")"
  printf "SIGNATURE='%s'\n" "$(_escape_for_shell "$SIGNATURE")"
}

# ─── Signature Verification for Incoming Messages ───────────────────
# Validates message signature and TTL before processing
# Returns: 0=valid, 1=expired, 2=auth_fail, 3=parse_error
# Sets global PARSE_* variables for caller to inspect
_verify_message() {
  local MSG_FILE="$1"

  # Parse headers safely using new function
  eval "$(parse_message_header "$MSG_FILE")" || {
    log_action "EAR_REJECTED" "Parse error: $(basename "$MSG_FILE")"
    return 3
  }

  # Validate required fields were found using dedicated validation function
  if ! _validate_message_headers "$FROM" "$TO" "$SUBJECT" "$MSG_FILE"; then
    return 3
  fi

  # Read body (everything after ---)
  local BODY
  BODY=$(sed -n '/^---$/,$ p' "$MSG_FILE" | tail -n +2)

  # Check TTL expiration
  if [ -n "$EXPIRES_AT" ]; then
    local NOW_TS EXPIRES_TS
    NOW_TS=$(date +%s)
    EXPIRES_TS=$(date -d "$EXPIRES_AT" +%s 2>/dev/null || echo "0")
    if [ "$EXPIRES_TS" -lt "$NOW_TS" ]; then
      warn "BUS_EXPIRED: Message expired at $EXPIRES_AT"
      log_action "EAR_EXPIRED" "Message expired: $(basename "$MSG_FILE") expires:$EXPIRES_AT"
      return 1
    fi
  fi

  # Verify signature
  if ! bus_verify_signature "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY" "$SIGNATURE"; then
    return 2
  fi

  return 0
}

case "$CMD" in

  # ── รอรับ message (blocking poll) ───────────────────────────────
  listen)
    TIMEOUT="${1:-60}"
    step "หู ฟัง inbox: $MY_INBOX (timeout ${TIMEOUT}s)"
    log_action "EAR_LISTEN" "waiting..."
    ELAPSED=0
    while [ $ELAPSED -lt "$TIMEOUT" ]; do
      MSG_FILE=$(ls "$MY_INBOX"/*.msg 2>/dev/null | head -1)
      if [ -n "$MSG_FILE" ]; then
        # Verify signature and TTL before processing
        _verify_message "$MSG_FILE"
        VERIFY_STATUS=$?
        case $VERIFY_STATUS in
          0)
            # Valid message - process it
            CONTENT=$(cat "$MSG_FILE")
            BASENAME=$(basename "$MSG_FILE")
            ok "หู ได้ยิน: $BASENAME"
            echo "$CONTENT"
            mv "$MSG_FILE" "$MY_INBOX/read_${BASENAME}"
            log_action "EAR_RECEIVED" "$BASENAME"
            break
            ;;
          1)
            # Expired: move to .expired
            mv "$MSG_FILE" "${MSG_FILE%.msg}.expired"
            log_action "EAR_EXPIRED" "Moved to quarantine: $(basename "$MSG_FILE")"
            continue
            ;;
          2)
            # Auth fail: move to rejected
            err "BUS_AUTH_FAIL: Rejecting message with invalid signature"
            log_action "EAR_REJECTED" "Invalid signature: $(basename "$MSG_FILE")"
            mkdir -p "$MY_INBOX/rejected"
            mv "$MSG_FILE" "$MY_INBOX/rejected/"
            continue
            ;;
          3)
            # Parse error: reject silently or move to rejected
            err "BUS_PARSE_FAIL: Rejecting malformed message"
            log_action "EAR_REJECTED" "Malformed headers: $(basename "$MSG_FILE")"
            mkdir -p "$MY_INBOX/rejected"
            mv "$MSG_FILE" "$MY_INBOX/rejected/"
            continue
            ;;
        esac
      fi
      sleep 2
      ELAPSED=$((ELAPSED + 2))
    done
    [ $ELAPSED -ge "$TIMEOUT" ] && warn "timeout — ไม่มี message"
    exit 0
    ;;

  # ── รับ message ที่รอ (non-blocking) ────────────────────────────
  receive)
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    if [ "$MSGS" -eq 0 ]; then
      info "inbox ว่าง"
      exit 0
    fi

    REJECTED=0
    EXPIRED=0
    PARSE_ERROR=0
    step "หู รับ $MSGS messages:"
    for MSG_FILE in "$MY_INBOX"/*.msg; do
      [ -f "$MSG_FILE" ] || continue
      BASENAME=$(basename "$MSG_FILE")

      # Verify signature and TTL before processing
      _verify_message "$MSG_FILE"
      VERIFY_STATUS=$?
      case $VERIFY_STATUS in
        0)
          # Valid message - process it
          CONTENT=$(cat "$MSG_FILE")
          echo ""
          echo -e "${CYAN}── $BASENAME ──${RESET}"
          echo "$CONTENT"
          mv "$MSG_FILE" "$MY_INBOX/read_${BASENAME}"
          log_action "EAR_RECEIVED" "$BASENAME"
          ;;
        1)
          # Expired: move to .expired
          mv "$MSG_FILE" "${MSG_FILE%.msg}.expired"
          log_action "EAR_EXPIRED" "Moved to quarantine: $BASENAME"
          ((EXPIRED++))
          ;;
        2|3)
          # Auth fail or parse error: move to rejected
          err "BUS_AUTH_FAIL: Rejecting $BASENAME"
          log_action "EAR_REJECTED" "Invalid signature or malformed: $BASENAME"
          mkdir -p "$MY_INBOX/rejected"
          mv "$MSG_FILE" "$MY_INBOX/rejected/"
          ((REJECTED++))
          ;;
      esac
    done

    [ "$EXPIRED" -gt 0 ] && warn "ย้าย $EXPIRED messages ไป quarantine (expired)"
    [ "$REJECTED" -gt 0 ] && warn "ปฏิเสธ $REJECTED messages ที่ไม่ถูกต้อง"
    exit 0
    ;;

  # ── ดู inbox ─────────────────────────────────────────────────────
  inbox)
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    READ=$(ls "$MY_INBOX"/read_*.msg 2>/dev/null | wc -l)
    EXPIRED=$(ls "$MY_INBOX"/*.expired 2>/dev/null | wc -l)
    echo ""
    echo -e "${BOLD}📬 Inbox ของ $AGENT_NAME${RESET}"
    echo "   รอ: $MSGS | อ่านแล้ว: $READ | Expired: $EXPIRED"
    echo ""
    if [ "$MSGS" -gt 0 ]; then
      for MSG_FILE in "$MY_INBOX"/*.msg; do
        [ -f "$MSG_FILE" ] || continue
        BASENAME=$(basename "$MSG_FILE")
        # อ่าน metadata จาก header ของ message - ใช้ safe parsing
        eval "$(parse_message_header "$MSG_FILE")"
        if [ -n "$EXPIRES_AT" ]; then
          echo "   📩 $BASENAME | from:${FROM:-?} | ${SUBJECT:-no subject} | expires:$EXPIRES_AT"
        else
          echo "   📩 $BASENAME | from:${FROM:-?} | ${SUBJECT:-no subject}"
        fi
      done
    else
      info "ไม่มี message รอ"
    fi
    if [ "$EXPIRED" -gt 0 ]; then
      echo -e "   ${YELLOW}⚠️  $EXPIRED expired messages in quarantine${RESET}"
    fi
    echo ""
    ;;

  # ── รับเฉพาะจาก agent ─────────────────────────────────────────────
  from)
    SENDER="$1"
    if [ -z "$SENDER" ]; then err "ต้องระบุ sender"; exit 1; fi
    step "หู ฟัง message จาก: $SENDER"
    for MSG_FILE in "$MY_INBOX"/*.msg; do
      [ -f "$MSG_FILE" ] || continue
      # Use safe parsing instead of grep
      eval "$(parse_message_header "$MSG_FILE")"
      if [ "$FROM" = "$SENDER" ]; then
        cat "$MSG_FILE"
        mv "$MSG_FILE" "$MY_INBOX/read_$(basename "$MSG_FILE")"
      fi
    done
    ;;

  # ── ล้าง inbox ───────────────────────────────────────────────────
  clear)
    rm -f "$MY_INBOX"/*.msg "$MY_INBOX"/read_*.msg 2>/dev/null
    ok "ล้าง inbox แล้ว"
    log_action "EAR_CLEAR" "$MY_INBOX"
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "EAR_PULSE" "$CONTEXT"
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    echo "Ear receives clean energy and listens for new signals"
    echo "  inbox pending: ${MSGS:-0}"
    ;;

  # ── สถานะ ────────────────────────────────────────────────────────
  status)
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    ok "หู (ear) พร้อม | inbox: $MY_INBOX | รอ: $MSGS messages"
    ;;

  *)
    echo "Usage: ear.sh {listen|receive|inbox|from|clear|status}"
    echo ""
    echo "  listen  [timeout]   — รอรับ message (default 60s)"
    echo "  receive             — รับทุก message ที่รอ"
    echo "  inbox               — ดูสถานะ inbox"
    echo "  from <agent>        — รับเฉพาะจาก agent"
    echo "  clear               — ล้าง inbox"
    ;;
esac
