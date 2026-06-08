#!/usr/bin/env bash
# limbs/oracle.sh — ปญญา (Wisdom): คลังความรู Arra Oracle V3
#
# หลักพุทธ: สัมมาสังกัปปะ + ปญญา — ปญญาเกิดจากการศึกษาและประสบการณ
# "จงเรียนรูจากทุกสิ่ง และสอนสิ่งที่เรียนรูกลับคืน"
#
# Usage:
#   ./oracle.sh health              — ตรวจสอบ Oracle
#   ./oracle.sh search "คำคนหา"   — คนหาความรู
#   ./oracle.sh learn "pattern"..  — สอน Oracle
#   ./oracle.sh learn-expires "pattern" "content" "concepts" <days> — บันทึกพรอมวันหมดอายุ
#   ./oracle.sh stats               — สถิติ Oracle
#   ./oracle.sh start               — เปด Oracle (ถายังไมรัน)

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
      err "Oracle ไมตอบสนอง (ลอง: act.sh start-oracle)"
      exit 1
    fi
    ;;

  # ─– คนหาความรู ─────────────────────────────────────────────────
  search)
    QUERY="${1:-oracle}"
    LIMIT="${2:-5}"
    MODE="${3:-hybrid}"  # hybrid, semantic, keyword

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --semantic|-s) MODE="vector" ;;
        --keyword|-k) MODE="fts" ;;
        --hybrid|-h) MODE="hybrid" ;;
        --model) MODEL="$2"; shift ;;
        *) ;;
      esac
      shift
    done

    step "คนหาใน Oracle: '$QUERY' (mode=$MODE)"
    oracle_search "$QUERY" "$LIMIT" "$MODE" "$MODEL"
    ;;

  # ─– บันทึกความรู ────────────────────────────────────────────────
  learn)
    PATTERN="${1:-new learning}"
    CONTENT="${2:-content here}"
    CONCEPTS="${3:-general}"
    step "สอน Oracle: $PATTERN"
    ID=$(oracle_learn "$PATTERN" "$CONTENT" "$CONCEPTS")
    if [ -n "$ID" ]; then
      ok "Oracle จำแลว: $ID"
    else
      err "บันทึกไมสำเร็จ"
      exit 1
    fi
    ;;

  # ─– บันทึกความรูพรอมวันหมดอายุ ───────────────────────────────────
  learn-expires)
    PATTERN="${1:-expiring learning}"
    CONTENT="${2:-content here}"
    CONCEPTS="${3:-general,expiring}"
    EXPIRY_DAYS="${4:-30}"  # ค่าเริ่มต้น 30 วัน

    if [ -z "$PATTERN" ] || [ -z "$CONTENT" ]; then
      err "ต้องระบุ pattern และ content"
      echo "Usage: oracle.sh learn-expires <pattern> <content> [concepts] [expiry_days]"
      exit 1
    fi

    # คำนวณ expiry date
    EXPIRY_DATE=$(python3 -c "from datetime import datetime, timedelta; print((datetime.now() + timedelta(days=$EXPIRY_DAYS)).strftime('%Y-%m-%d'))")

    step "สอน Oracle (หมดอายุ: $EXPIRY_DATE): $PATTERN"

    # เพิ่ม metadata expiry ใน concepts
    FULL_CONCEPTS="$CONCEPTS,expiry=$EXPIRY_DAYS days"
    ID=$(oracle_learn "$PATTERN" "$CONTENT" "$FULL_CONCEPTS")

    if [ -n "$ID" ]; then
      # บันทึก expiry metadata ใน memory index
      MEMORY_INDEX="/workspaces/Jit/memory/index.json"
      if [ ! -f "$MEMORY_INDEX" ]; then
        echo '{"entries":{}, "archived":[]}' > "$MEMORY_INDEX"
      fi

      python3 - <<PYEOF
import json
from datetime import datetime

index = json.load(open("$MEMORY_INDEX"))
expiry_date_iso = "$EXPIRY_DATE"

# สร้าง entry สำหรับ learning นี้
key = "oracle_learning_$ID"
index["entries"][key] = {
  "value": """$CONTENT""",
  "set_by": "oracle_learn_expires",
  "created_date": datetime.now().isoformat(),
  "last_accessed": datetime.now().isoformat(),
  "access_count": 0,
  "expiry_date": "$EXPIRY_DATE",
  "archived": False,
  "decay_score": 1.0,
  "oracle_id": "$ID",
  "pattern": "$PATTERN",
  "concepts": "$CONCEPTS".split(",")
}

with open("$MEMORY_INDEX", "w", encoding="utf-8") as f:
  json.dump(index, f, ensure_ascii=False, indent=2)
PYEOF

      ok "Oracle จำแลว (หมดอายุ $EXPIRY_DATE): $ID"
    else
      err "บันทึกไมสำเร็จ"
      exit 1
    fi
    ;;

  # ─– สถิติ ────────────────────────────────────────────────────────
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

  # ─– เปด Oracle ──────────────────────────────────────────────────
  start)
    if oracle_ready; then
      ok "Oracle ทำงานอยูแลว"
    else
      step "เริ่ม Oracle server..."
      export PATH="\$HOME/.bun/bin:\$PATH"
      ORACLE_ROOT="\${ORACLE_ROOT:-/workspaces/arra-oracle-v3}"
      cd "\$ORACLE_ROOT" 2>/dev/null || { err "ไมพบ arra-oracle-v3"; exit 1; }
      ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
      sleep 3
      oracle_ready && ok "Oracle พรอมแลว" || err "Oracle เริ่มไมได — ดู /tmp/oracle-server.log"
    fi
    ;;

  *)
    echo "Usage: oracle.sh <command>"
    echo ""
    echo "  health                — ตรวจสอบ Oracle"
    echo "  search <query> [limit] [mode] — คนหาความรู (mode: hybrid, --semantic, --keyword)"
    echo "    --semantic, -s      — Vector similarity search (find by meaning)"
    echo "    --keyword, -k       — FTS5 keyword search only"
    echo "    --hybrid, -h        — Combine both (default)"
    echo "    --model <name>      — Embedding model: bge-m3, nomic, qwen3"
    echo "  learn  <pattern> <content> <concepts>  — บันทึกความรู (auto-embeds for vector search)"
    echo "  learn-expires <pattern> <content> <concepts> <days> — บันทึกพรอมวันหมดอายุ"
    echo "  stats                 — สถิติ Oracle"
    echo "  start                 — เปด Oracle (ถายังไมรัน)"
    ;;
esac
