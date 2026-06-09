#!/usr/bin/env bash
# limbs/act.sh — กาย (Right Action): ลงมือทำอย่างถูกต้อง ปลอดภัย
#
# หลักพุทธ: สัมมากัมมันตะ (Right Action) + ศีล (Virtue)
# "การกระทำที่ดีต้องไม่เบียดเบียน ต้องพิจารณาก่อนทำ และย้อนคืนได้"
#
# Usage:
#   ./act.sh git "commit message"     — commit อย่างปลอดภัย
#   ./act.sh write "file" "content"   — เขียนไฟล์ (สร้าง backup)
#   ./act.sh run "command"            — รันคำสั่ง + บันทึก log
#   ./act.sh http GET "url"           — HTTP call
#   ./act.sh learn "pattern" "..."    — บันทึกลง Oracle
#
# ─── JIT-022: Safe String Handling (Prevention) ─────────────────────
# WARNING: Never embed user input directly in sed/perl regex patterns.
#
# Safe patterns for file operations:
#   ✅ USE: echo "$CONTENT" > "$FILE"      — Direct write (no interpretation)
#   ✅ USE: echo "$CONTENT" >> "$FILE"     — Append (safe)
#   ✅ USE: python3 with re.escape()       — For complex transformations
#   ❌ AVOID: sed "s/$USER_INPUT/..."      — Injection risk
#   ❌ AVOID: perl -pe "s/$USER_INPUT/..." — Injection risk
#
# If sed/perl operations are ever added in future:
#   1. Always escape user input: $(printf '%s\n' "$input" | sed 's/[&/\]/\\&/g')
#   2. Prefer python3 for complex regex: python3 -c "import re; re.escape('$input')"
#   3. Consider dedicated templating tools for file generation
#
# This script currently uses only safe echo-based file operations.
# No sed/perl regex operations are present — preventive documentation only.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Action journal for branch decisions
ACTION_JOURNAL="${ACTION_JOURNAL:-/tmp/manusat-act-journal.log}"

# Log branch decision to journal
log_branch_decision() {
  local condition="$1"
  local result="$2"
  local true_cmd="$3"
  local false_cmd="$4"
  echo "$(date +%Y-%m-%dT%H:%M:%S)|BRANCH|$condition|$result|$true_cmd|$false_cmd" >> "$ACTION_JOURNAL"
}

# Check condition implementations
check_condition() {
  local cond="$1"
  case "$cond" in
    file_exists:*)
      [ -f "${cond#file_exists:}" ]
      ;;
    git_dirty:*)
      [ -n "$(git -C "${cond#git_dirty:}" status --porcelain 2>/dev/null)" ]
      ;;
    oracle_available)
      curl -sf "$ORACLE_URL/api/health" >/dev/null 2>&1
      ;;
    agent_online:*)
      [ -d "/tmp/manusat-bus/${cond#agent_online:}" ]
      ;;
    last_status_ok)
      [ "$(cat /tmp/manusat-last-status.txt 2>/dev/null)" = "ok" ]
      ;;
    *)
      # Unknown condition - treat as false
      return 1
      ;;
  esac
}

CMD="${1:-help}"
shift || true

case "$CMD" in

  # ── Git: ศีลของ version control ───────────────────────────────────
  git)
    SUBCMD="${1:-status}"
    shift || true
    case "$SUBCMD" in
      commit)
        MSG="${1:-update}"
        step "Git commit: $MSG"
        log_action "GIT_COMMIT" "$MSG"
        cd "${2:-$(pwd)}" 2>/dev/null || true
        git add -A
        git commit -m "$MSG" && ok "Committed: $MSG" || err "Commit failed"
        ;;
      push)
        REMOTE="${1:-origin}" BRANCH="${2:-$(git branch --show-current)}"
        warn "Push ไปที่ $REMOTE/$BRANCH — ย้อนคืนได้ยาก"
        read -r -p "ยืนยัน? (y/N) " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
          log_action "GIT_PUSH" "$REMOTE/$BRANCH"
          git push "$REMOTE" "$BRANCH" && ok "Pushed" || err "Push failed"
        else
          info "ยกเลิก push"
        fi
        ;;
      status)
        git status --short 2>/dev/null || err "ไม่ได้อยู่ใน git repo"
        ;;
      log)
        git log --oneline -10 2>/dev/null
        ;;
      diff)
        git diff --stat 2>/dev/null
        ;;
    esac
    ;;

  # ── Write: เขียนไฟล์อย่างระวัง (backup ก่อน) ──────────────────────
  write)
    FILE="$1" CONTENT="$2"
    if [ -z "$FILE" ]; then err "ต้องระบุ file path"; exit 1; fi
    # Backup ถ้ามีไฟล์อยู่แล้ว
    if [ -f "$FILE" ]; then
      cp "$FILE" "${FILE}.bak.$(date +%s)" 2>/dev/null
      info "Backup สร้างแล้ว: ${FILE}.bak.*"
    fi
    echo "$CONTENT" > "$FILE"
    log_action "WRITE" "$FILE"
    ok "เขียนไฟล์: $FILE"
    ;;

  # ── Append: เพิ่มเนื้อหา (non-destructive) ────────────────────────
  append)
    FILE="$1" CONTENT="$2"
    if [ -z "$FILE" ]; then err "ต้องระบุ file path"; exit 1; fi
    echo "$CONTENT" >> "$FILE"
    log_action "APPEND" "$FILE"
    ok "เพิ่มเนื้อหาใน: $FILE"
    ;;

  # ── Run: รันคำสั่ง + log ──────────────────────────────────────────
  run)
    CMD_TO_RUN="$*"
    if [ -z "$CMD_TO_RUN" ]; then err "ต้องระบุคำสั่ง"; exit 1; fi
    step "รัน: $CMD_TO_RUN"
    log_action "RUN" "$CMD_TO_RUN"
    eval "$CMD_TO_RUN"
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
      log_action "RUN_OK" "$CMD_TO_RUN"
    else
      log_action "RUN_FAIL" "$CMD_TO_RUN (exit $STATUS)"
      err "คำสั่งล้มเหลว (exit $STATUS)"
    fi
    return $STATUS
    ;;

  # ── HTTP: เรียก API ────────────────────────────────────────────────
  http)
    METHOD="${1:-GET}" URL="$2"
    shift 2 || true
    if [ -z "$URL" ]; then err "ต้องระบุ URL"; exit 1; fi
    log_action "HTTP_${METHOD}" "$URL"
    step "$METHOD $URL"
    if [ "$METHOD" = "POST" ]; then
      DATA="${1:-{}}"
      curl -s -X POST "$URL" -H "Content-Type: application/json" -d "$DATA" | python3 -m json.tool 2>/dev/null
    else
      curl -s "$URL" | python3 -m json.tool 2>/dev/null
    fi
    ;;

  # ── Learn: บันทึกความรู้ลง Oracle (อกาลิโก — ความรู้ไม่มีวันหมดอายุ) ──
  learn)
    PATTERN="$1" CONTENT="$2" CONCEPTS="${3:-general}"
    if [ -z "$PATTERN" ]; then err "ต้องระบุ pattern"; exit 1; fi
    step "บันทึกลง Oracle: $PATTERN"
    log_action "LEARN" "$PATTERN"
    if oracle_ready; then
      ID=$(oracle_learn "$PATTERN" "$CONTENT" "$CONCEPTS")
      ok "Oracle จำแล้ว: $ID"
    else
      warn "Oracle ไม่พร้อม — บันทึกลง /tmp/innova-pending-learn.log"
      echo "$(date +%s)|$PATTERN|$CONTENT|$CONCEPTS" >> /tmp/innova-pending-learn.log
    fi
    ;;

  # ── Ensure Oracle running ──────────────────────────────────────────
  start-oracle)
    if oracle_ready; then
      ok "Oracle ทำงานอยู่แล้ว"
    else
      step "เริ่ม Oracle server..."
      export PATH="$HOME/.bun/bin:$PATH"
      cd "$ORACLE_ROOT" 2>/dev/null || { err "ไม่พบ arra-oracle-v3"; exit 1; }
      ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
      sleep 3
      oracle_ready && ok "Oracle พร้อมแล้ว" || err "Oracle เริ่มไม่ได้"
    fi
    ;;

  # ── Branch: Conditional execution ──────────────────────────────────
  branch)
    # Usage: act.sh branch <condition> <if-true-cmd> <if-false-cmd>
    CONDITION="$1"
    TRUE_CMD="$2"
    FALSE_CMD="$3"

    if [ -z "$CONDITION" ]; then
      err "ต้องระบุ condition: act.sh branch <condition> <true-cmd> <false-cmd>"
      exit 1
    fi

    step "ตรวจสอบเงื่อนไข: $CONDITION"
    log_action "BRANCH_CHECK" "$CONDITION"

    if check_condition "$CONDITION"; then
      info "เงื่อนไขเป็นจริง — ดำเนินการ: $TRUE_CMD"
      log_branch_decision "$CONDITION" "true" "$TRUE_CMD" "${FALSE_CMD:-none}"
      if [ -n "$TRUE_CMD" ]; then
        eval "$TRUE_CMD"
        EXIT_CODE=$?
        log_action "BRANCH_TRUE_RESULT" "$TRUE_CMD (exit $EXIT_CODE)"
        exit $EXIT_CODE
      fi
      exit 0
    else
      info "เงื่อนไขเป็นเท็จ — ดำเนินการ: ${FALSE_CMD:-none}"
      log_branch_decision "$CONDITION" "false" "$TRUE_CMD" "${FALSE_CMD:-none}"
      if [ -n "$FALSE_CMD" ]; then
        eval "$FALSE_CMD"
        EXIT_CODE=$?
        log_action "BRANCH_FALSE_RESULT" "$FALSE_CMD (exit $EXIT_CODE)"
        exit $EXIT_CODE
      fi
      exit 0
    fi
    ;;

  # ── Sequence: Command chaining with error handling ─────────────────
  sequence)
    # Usage: act.sh sequence <cmd1> && <cmd2> || <cmd3>
    # Parse and execute command chain
    SEQUENCE_EXPR="$*"

    if [ -z "$SEQUENCE_EXPR" ]; then
      err "ต้องระบุลำดับคำสั่ง: act.sh sequence <cmd1> && <cmd2> || <cmd3>"
      exit 1
    fi

    step "ดำเนินการลำดับ: $SEQUENCE_EXPR"
    log_action "SEQUENCE_START" "$SEQUENCE_EXPR"

    # Execute the sequence and capture final exit code
    eval "$SEQUENCE_EXPR"
    FINAL_STATUS=$?

    if [ $FINAL_STATUS -eq 0 ]; then
      log_action "SEQUENCE_OK" "$SEQUENCE_EXPR"
      ok "ลำดับสำเร็จ (exit 0)"
    else
      log_action "SEQUENCE_FAIL" "$SEQUENCE_EXPR (exit $FINAL_STATUS)"
      err "ลำดับล้มเหลว (exit $FINAL_STATUS)"
    fi

    # Store last status for last_status_ok condition
    if [ $FINAL_STATUS -eq 0 ]; then
      echo "ok" > /tmp/manusat-last-status.txt
    else
      echo "fail" > /tmp/manusat-last-status.txt
    fi

    exit $FINAL_STATUS
    ;;

  *)
    echo "Usage: act.sh <command>"
    echo ""
    echo "  git {commit|push|status|log|diff}  — git operations"
    echo "  write  <file> <content>             — เขียนไฟลล์ (สร้าง backup อัตโนมัติ)"
    echo "  append <file> <content>             — เพิ่ิมเนื้้อหา (safe)"
    echo "  run    <command>                    — รันคำสั่่ง + บันทึก"
    echo "  http   <GET|POST> <url> [data]      — HTTP call"
    echo "  learn  <pattern> <content> <tags>   — บันทึกลง Oracle"
    echo "  start-oracle                        — เปิิด Oracle ถ้้าไม่ได้รัน"
    echo ""
    echo "  --- Conditional Execution (JIT-025) ---"
    echo "  branch   <condition> <true-cmd> <false-cmd>  — ดำเนินการตามเงื่่อนไข"
    echo "  sequence <cmd1 && cmd2 || cmd3>              — ลำดับคำสั่่งพร้อมจัดการข้อผิิดพลาด"
    echo ""
    echo "  Conditions:"
    echo "    file_exists:<path>    — ไฟล์มีอยู่หรือไม่"
    echo "    git_dirty:<path>      — git repo มี uncommitted changes"
    echo "    oracle_available      — Oracle server พร้อมทำงาน"
    echo "    agent_online:<name>   — agent มี inbox directory"
    echo "    last_status_ok        — คำสั่่งล่าสุดสำเร็จ"
    ;;
esac
