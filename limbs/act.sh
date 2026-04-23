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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

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

  *)
    echo "Usage: act.sh <command>"
    echo ""
    echo "  git {commit|push|status|log|diff}  — git operations"
    echo "  write  <file> <content>             — เขียนไฟล์ (สร้าง backup อัตโนมัติ)"
    echo "  append <file> <content>             — เพิ่มเนื้อหา (safe)"
    echo "  run    <command>                    — รันคำสั่ง + บันทึก"
    echo "  http   <GET|POST> <url> [data]      — HTTP call"
    echo "  learn  <pattern> <content> <tags>   — บันทึกลง Oracle"
    echo "  start-oracle                        — เปิด Oracle ถ้าไม่ได้รัน"
    ;;
esac
