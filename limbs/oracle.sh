#!/usr/bin/env bash
# limbs/oracle.sh — ปัญญา (Wisdom): คลังความรู้ Arra Oracle V3
#
# หลักพุทธ: สัมมาสังกัปปะ + ปัญญา — ปัญญาเกิดจากการศึกษาและประสบการณ์
# "จงเรียนรู้จากทุกสิ่ง และสอนสิ่งที่เรียนรู้กลับคืน"
#
# Usage:
#   ./oracle.sh health              — ตรวจสอบ Oracle
#   ./oracle.sh search "คำค้นหา"   — ค้นหาความรู้
#   ./oracle.sh learn "pattern"..  — สอน Oracle
#   ./oracle.sh stats               — สถิติ Oracle
#   ./oracle.sh start               — เปิด Oracle (ถ้ายังไม่รัน)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"

CMD="${1:-health}"
shift || true

case "$CMD" in

  # ── สุขภาพ Oracle ────────────────────────────────────────────────
  health)
    step "ตรวจสอบ Oracle..."
    RESULT=$(curl -sf "$ORACLE_URL/api/health" 2>/dev/null)
    if [ $? -eq 0 ]; then
      STATUS=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null)
      ok "Oracle: $STATUS"
      echo "$RESULT" | python3 -m json.tool 2>/dev/null
    else
      err "Oracle ไม่ตอบสนอง (ลอง: act.sh start-oracle)"
      exit 1
    fi
    ;;

  # ── ค้นหาความรู้ ─────────────────────────────────────────────────
  search)
    QUERY="${1:-oracle}" LIMIT="${2:-5}"
    step "ค้นหาใน Oracle: '$QUERY'"
    oracle_search "$QUERY" "$LIMIT"
    ;;

  # ── บันทึกความรู้ ────────────────────────────────────────────────
  learn)
    PATTERN="${1:-new learning}"
    CONTENT="${2:-content here}"
    CONCEPTS="${3:-general}"
    step "สอน Oracle: $PATTERN"
    ID=$(oracle_learn "$PATTERN" "$CONTENT" "$CONCEPTS")
    if [ -n "$ID" ]; then
      ok "Oracle จำแล้ว: $ID"
    else
      err "บันทึกไม่สำเร็จ"
      exit 1
    fi
    ;;

  # ── สถิติ ────────────────────────────────────────────────────────
  stats)
    step "Oracle stats..."
    STATS=$(curl -sf "$ORACLE_URL/api/stats" 2>/dev/null || curl -sf "$ORACLE_URL/stats" 2>/dev/null)
    echo "$STATS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
total = d.get('totalDocuments', d.get('total', '?'))
print(f'  Total docs: {total}')
by_type = d.get('byType', d.get('by_type', {}))
for t,n in by_type.items():
    print(f'    {t}: {n}')
" 2>/dev/null || echo "$STATS"
    ;;

  # ── เปิด Oracle ──────────────────────────────────────────────────
  start)
    if oracle_ready; then
      ok "Oracle ทำงานอยู่แล้ว"
    else
      step "เริ่ม Oracle server..."
      export PATH="$HOME/.bun/bin:$PATH"
      ORACLE_ROOT="${ORACLE_ROOT:-/workspaces/arra-oracle-v3}"
      cd "$ORACLE_ROOT" 2>/dev/null || { err "ไม่พบ arra-oracle-v3"; exit 1; }
      ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
      sleep 3
      oracle_ready && ok "Oracle พร้อมแล้ว" || err "Oracle เริ่มไม่ได้ — ดู /tmp/oracle-server.log"
    fi
    ;;

  *)
    echo "Usage: oracle.sh <command>"
    echo ""
    echo "  health          — ตรวจสอบ Oracle"
    echo "  search <query>  — ค้นหาความรู้"
    echo "  learn  <pattern> <content> <concepts>  — บันทึกความรู้"
    echo "  stats           — สถิติ Oracle"
    echo "  start           — เปิด Oracle (ถ้ายังไม่รัน)"
    ;;
esac
