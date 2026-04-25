#!/usr/bin/env bash
# organs/eye.sh — ตา (Vision): มองเห็น สังเกต อ่านข้อมูล
#
# หลักพุทธ: สัมมาทิฏฐิ (Right View) — เห็นสิ่งต่างๆ ตามความเป็นจริง
# บทบาท multiagent: รับข้อมูลจากสิ่งแวดล้อม ส่งต่อให้สมอง (soma/innova)
#
# Usage:
#   ./eye.sh read <file>          — อ่านไฟล์
#   ./eye.sh watch <dir>          — ดูการเปลี่ยนแปลง
#   ./eye.sh scan <dir> <pattern> — สแกนหาไฟล์
#   ./eye.sh web <url>            — ดูหน้าเว็บ
#   ./eye.sh observe <topic>      — สังเกตและสรุป
#   ./eye.sh diff                 — เห็นความเปลี่ยนแปลง git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-help}"
shift || true

case "$CMD" in

  # ── อ่านไฟล์ ─────────────────────────────────────────────────────
  read)
    FILE="$1"
    if [ ! -f "$FILE" ]; then err "ไม่พบไฟล์: $FILE"; exit 1; fi
    log_action "EYE_READ" "$FILE"
    info "ตา อ่าน: $FILE ($(wc -l < "$FILE") lines)"
    cat "$FILE"
    ;;

  # ── สแกนหาไฟล์ ───────────────────────────────────────────────────
  scan)
    DIR="${1:-.}" PATTERN="${2:-*}"
    log_action "EYE_SCAN" "$DIR/$PATTERN"
    step "ตา สแกน: $DIR สำหรับ '$PATTERN'"
    find "$DIR" -name "$PATTERN" -not -path '*/.git/*' 2>/dev/null | sort
    ;;

  # ── ดูการเปลี่ยนแปลงในโฟลเดอร์ ────────────────────────────────────
  watch)
    DIR="${1:-.}"
    log_action "EYE_WATCH" "$DIR"
    step "ตา เฝ้าดู: $DIR (Ctrl+C หยุด)"
    # ใช้ inotifywait ถ้ามี, ไม่งั้นใช้ polling
    if command -v inotifywait &>/dev/null; then
      inotifywait -r -m -e modify,create,delete "$DIR" --exclude '.git'
    else
      warn "inotifywait ไม่มี — ใช้ snapshot mode"
      SNAP=$(find "$DIR" -newer "$DIR" -not -path '*/.git/*' 2>/dev/null | head -20)
      echo "$SNAP"
    fi
    ;;

  # ── ดูหน้าเว็บ (รับข้อมูลภายนอก) ─────────────────────────────────
  web)
    URL="$1"
    if [ -z "$URL" ]; then err "ต้องระบุ URL"; exit 1; fi
    log_action "EYE_WEB" "$URL"
    step "ตา ดูเว็บ: $URL"
    curl -sL "$URL" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
# strip tags
text = re.sub(r'<[^>]+>', ' ', html)
text = re.sub(r'\s+', ' ', text).strip()
print(text[:2000])
print('...(ตัดที่ 2000 chars)')
"
    ;;

  # ── git diff — เห็นสิ่งที่เปลี่ยน ─────────────────────────────────
  diff)
    log_action "EYE_DIFF" "git diff"
    step "ตา มองการเปลี่ยนแปลง:"
    cd "${JIT_ROOT}" && git diff --stat 2>/dev/null
    git status --short 2>/dev/null
    ;;

  # ── สังเกตและสรุป (ส่งให้ Oracle) ────────────────────────────────
  observe)
    TOPIC="$1"
    log_action "EYE_OBSERVE" "$TOPIC"
    step "ตา สังเกต: $TOPIC"
    # ค้นหา Oracle ว่าเคยเห็นเรื่องนี้ไหม
    if oracle_ready; then
      oracle_search "$TOPIC" 3
    fi
    # ส่งสัญญาณผ่าน nerve (ถ้ามี)
    NERVE="$SCRIPT_DIR/../organs/nerve.sh"
    [ -x "$NERVE" ] && bash "$NERVE" signal "eye_observed" "$TOPIC" "eye"
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "EYE_PULSE" "$CONTEXT"
    echo "Eye receives clean energy and focuses on observation"
    ;;

  # ── สถานะ ─────────────────────────────────────────────────────────
  status)
    ok "ตา (eye) พร้อม"
    echo "   สามารถ: read | scan | watch | web | diff | observe"
    ;;

  *)
    echo "Usage: eye.sh {read|scan|watch|web|diff|observe|status}"
    echo ""
    echo "  read   <file>           — อ่านไฟล์"
    echo "  scan   <dir> <pattern>  — หาไฟล์"
    echo "  watch  <dir>            — เฝ้าดูการเปลี่ยนแปลง"
    echo "  web    <url>            — อ่านหน้าเว็บ"
    echo "  diff                    — เห็นการเปลี่ยนแปลง git"
    echo "  observe <topic>         — สังเกตและสรุปลง Oracle"
    ;;
esac
