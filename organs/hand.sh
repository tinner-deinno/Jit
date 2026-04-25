#!/usr/bin/env bash
# organs/hand.sh — มือ (Hands): ทำงานละเอียด เขียน แก้ไข สร้าง
#
# หลักพุทธ: สัมมาอาชีวะ (Right Livelihood) — ทำงานอย่างถูกต้อง สุจริต
# บทบาท multiagent: task execution, file manipulation, API calls, code ops
#
# Usage:
#   ./hand.sh create <file> <content>   — สร้างไฟล์
#   ./hand.sh edit <file> <old> <new>   — แก้ไขไฟล์
#   ./hand.sh delete <file>             — ลบไฟล์ (ต้องยืนยัน)
#   ./hand.sh call <url> [data]         — เรียก API
#   ./hand.sh execute <task-file>       — ทำงานจาก task file
#   ./hand.sh build                     — build/install project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-help}"
shift || true

case "$CMD" in

  # ── สร้างไฟล์ ────────────────────────────────────────────────────
  create)
    FILE="$1" CONTENT="${2:-}"
    if [ -z "$FILE" ]; then err "ต้องระบุ file"; exit 1; fi
    if [ -f "$FILE" ]; then
      warn "ไฟล์มีอยู่แล้ว: $FILE — สร้าง backup"
      cp "$FILE" "${FILE}.bak.$(date +%s)"
    fi
    # รับ content จาก stdin ถ้าไม่ระบุ argument
    if [ -z "$CONTENT" ] && [ ! -t 0 ]; then
      cat > "$FILE"
    else
      echo "$CONTENT" > "$FILE"
    fi
    log_action "HAND_CREATE" "$FILE"
    ok "มือ สร้าง: $FILE"
    ;;

  # ── แก้ไขไฟล์ (safe sed replace) ────────────────────────────────
  edit)
    FILE="$1" OLD="$2" NEW="$3"
    if [ ! -f "$FILE" ]; then err "ไม่พบ: $FILE"; exit 1; fi
    cp "$FILE" "${FILE}.bak.$(date +%s)" && info "backup สร้างแล้ว"
    sed -i "s|$OLD|$NEW|g" "$FILE"
    log_action "HAND_EDIT" "$FILE: '$OLD' → '$NEW'"
    ok "มือ แก้ไข: $FILE"
    ;;

  # ── append ───────────────────────────────────────────────────────
  append)
    FILE="$1"
    shift || true
    CONTENT="$*"
    echo "$CONTENT" >> "$FILE"
    log_action "HAND_APPEND" "$FILE"
    ok "มือ append: $FILE"
    ;;

  # ── ลบไฟล์ (ต้องยืนยัน) ─────────────────────────────────────────
  delete)
    FILE="$1"
    if [ ! -f "$FILE" ] && [ ! -d "$FILE" ]; then err "ไม่พบ: $FILE"; exit 1; fi
    warn "กำลังจะลบ: $FILE"
    read -r -p "ยืนยัน? (y/N) " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      # archive ก่อนลบ
      ARCHIVE="/tmp/hand-deleted-$(date +%s)-$(basename "$FILE")"
      cp -r "$FILE" "$ARCHIVE" 2>/dev/null
      rm -rf "$FILE"
      log_action "HAND_DELETE" "$FILE → $ARCHIVE"
      ok "ลบแล้ว (archive: $ARCHIVE)"
    else
      info "ยกเลิก"
    fi
    ;;

  # ── copy ─────────────────────────────────────────────────────────
  copy)
    SRC="$1" DST="$2"
    cp -r "$SRC" "$DST" && ok "copy: $SRC → $DST" || err "copy failed"
    log_action "HAND_COPY" "$SRC → $DST"
    ;;

  # ── เรียก API (POST/GET) ──────────────────────────────────────────
  call)
    URL="$1" DATA="${2:-}"
    if [ -z "$URL" ]; then err "ต้องระบุ URL"; exit 1; fi
    log_action "HAND_CALL" "$URL"
    if [ -n "$DATA" ]; then
      step "POST $URL"
      curl -sf -X POST "$URL" \
        -H "Content-Type: application/json" \
        -d "$DATA" | python3 -m json.tool 2>/dev/null
    else
      step "GET $URL"
      curl -sf "$URL" | python3 -m json.tool 2>/dev/null
    fi
    ;;

  # ── execute task file ─────────────────────────────────────────────
  execute)
    TASK_FILE="$1"
    if [ ! -f "$TASK_FILE" ]; then err "ไม่พบ task file: $TASK_FILE"; exit 1; fi
    step "มือ ทำงานตาม: $TASK_FILE"
    log_action "HAND_EXECUTE" "$TASK_FILE"
    # task file เป็น bash script ธรรมดา
    bash "$TASK_FILE"
    ;;

  # ── build project ────────────────────────────────────────────────
  build)
    PROJECT="${1:-$JIT_ROOT}"
    step "มือ build: $PROJECT"
    log_action "HAND_BUILD" "$PROJECT"
    cd "$PROJECT" || exit 1
    if [ -f "package.json" ]; then
      export PATH="$HOME/.bun/bin:$PATH"
      bun install && ok "bun install สำเร็จ"
    elif [ -f "requirements.txt" ]; then
      pip install -r requirements.txt && ok "pip install สำเร็จ"
    else
      info "ไม่พบ build file ที่รู้จัก"
    fi
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "HAND_PULSE" "$CONTEXT"
    TASKS=$(find /tmp -maxdepth 1 -name 'task_*' 2>/dev/null | wc -l)
    echo "Hand receives clean energy and is ready to execute actions"
    echo "  queued tasks: ${TASKS:-0}"
    ;;

  # ── สถานะ ────────────────────────────────────────────────────────────
  status)
    ok "มือ (hand) พร้อม"
    echo "   สามารถ: create | edit | append | delete | copy | call | execute | build"
    ;;

  *)
    echo "Usage: hand.sh {create|edit|append|delete|copy|call|execute|build}"
    echo ""
    echo "  create  <file> [content]       — สร้างไฟล์"
    echo "  edit    <file> <old> <new>     — แก้ไขข้อความในไฟล์"
    echo "  append  <file> <content>       — เพิ่มเนื้อหา"
    echo "  delete  <file>                 — ลบ (ต้องยืนยัน)"
    echo "  call    <url> [json-data]      — เรียก API"
    echo "  execute <task-file>            — ทำงานตาม script"
    echo "  build   [project-dir]          — build/install project"
    ;;
esac
