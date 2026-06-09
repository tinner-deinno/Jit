#!/usr/bin/env bash
# memory/shared.sh — ความทรงจำร่วม: shared memory ของทุก agent
#
# หลักพุทธ: สัมมาสติ — ระลึกถึงสิ่งที่รู้ร่วมกัน
# บทบาท multiagent: cross-agent shared state, consensus, collective knowledge
#
# ทุก agent อ่าน/เขียน Oracle ร่วมกัน — นั่นคือ "ความทรงจำร่วม"
# ไฟล์นี้เพิ่ม layer สำหรับ real-time shared state
#
# Usage:
#   ./shared.sh set <key> <value>    — บันทึก shared state
#   ./shared.sh get <key>            — อ่าน shared state
#   ./shared.sh all                  — ดูทั้งหมด
#   ./shared.sh clear <key>          — ลบ key
#   ./shared.sh sync                 — sync กับ Oracle
#   ./shared.sh recall <query>       — ค้นหาความทรงจำ (recent+high-access ก่อน)
#   ./shared.sh recall --archived <query> — ค้นหา archived memories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-all}"
shift || true

SHARED_FILE="/tmp/manusat-shared.json"
MEMORY_INDEX="/workspaces/Jit/memory/index.json"
ARCHIVE_DIR="/workspaces/Jit/memory/archive"
AGENT="${AGENT_NAME:-innova}"

# Decay scoring weights
RECENCY_WEIGHT=0.4
ACCESS_WEIGHT=0.3
SEMANTIC_WEIGHT=0.3
ARCHIVE_THRESHOLD_DAYS=60

_load() {
  if [ -f "$SHARED_FILE" ]; then
    cat "$SHARED_FILE"
  else
    echo "{}"
  fi
}

_save() {
  echo "$1" > "$SHARED_FILE"
}

# คำนวณ decay score: relevance = recency + access + semantic
_calc_decay_score() {
  local created_date="$1"
  local last_accessed="$2"
  local access_count="$3"

  python3 - <<PYEOF
import math
from datetime import datetime

created = datetime.fromisoformat("$created_date".replace('Z', '+00:00')) if "$created_date" else datetime.now()
last_accessed = datetime.fromisoformat("$last_accessed".replace('Z', '+00:00')) if "$last_accessed" else created
access_count = int("$access_count") if "$access_count" else 0

days_since_access = (datetime.now() - last_accessed.replace(tzinfo=None)).days
days_since_creation = (datetime.now() - created.replace(tzinfo=None)).days

# recency_score = 1 / (1 + days_since_access / 30)
recency_score = 1.0 / (1.0 + max(0, days_since_access) / 30.0)

# access_score = min(1, log10(access_count + 1) / 3)
access_score = min(1.0, math.log10(access_count + 1) / 3.0) if access_count >= 0 else 0

# semantic_relevance = 0.5 (default, จะคำนวณจาก vector ในอนาคต)
semantic_relevance = 0.5

# weights
RECENCY_WEIGHT = $RECENCY_WEIGHT
ACCESS_WEIGHT = $ACCESS_WEIGHT
SEMANTIC_WEIGHT = $SEMANTIC_WEIGHT

relevance = (RECENCY_WEIGHT * recency_score) + (ACCESS_WEIGHT * access_score) + (SEMANTIC_WEIGHT * semantic_relevance)
print(f"{relevance:.4f}")
PYEOF
}

# บันทึก memory index พร้อม metadata
_save_memory_entry() {
  local key="$1"
  local value="$2"
  local set_by="$3"
  local timestamp="$4"
  local expiry_days="${5:-}"

  # สร้างหรือโหลด index
  if [ ! -f "$MEMORY_INDEX" ]; then
    echo '{"entries":{}, "archived":[]}' > "$MEMORY_INDEX"
  fi

  # คำนวณ expiry date ถ้ามี
  local expiry_date="null"
  if [ -n "$expiry_days" ] && [ "$expiry_days" != "null" ]; then
    expiry_date=$(python3 -c "from datetime import datetime, timedelta; print((datetime.now() + timedelta(days=$expiry_days)).isoformat())")
  fi

  # เพิ่ม entry พร้อม metadata
  python3 - <<PYEOF
import json

index = json.load(open("$MEMORY_INDEX"))

index["entries"]["$key"] = {
  "value": """$value""",
  "set_by": "$set_by",
  "created_date": "$timestamp",
  "last_accessed": "$timestamp",
  "access_count": 0,
  "expiry_date": $expiry_date,
  "archived": False,
  "decay_score": 1.0
}

with open("$MEMORY_INDEX", "w", encoding="utf-8") as f:
  json.dump(index, f, ensure_ascii=False, indent=2)
PYEOF
}

case "$CMD" in

  # ── บันทึก shared state ──────────────────────────────────────────
  set)
    KEY="$1"
    shift || true
    VALUE="$*"
    EXPIRY_DAYS="${1:-}"  # Optional expiry in days
    if [ -z "$KEY" ]; then err "ต้องระบุ key"; exit 1; fi
    TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

    # บันทึกลง shared file (real-time state)
    CURRENT=$(_load)
    UPDATED=$(python3 - <<'PYEOF'
import json, sys
current = json.loads(sys.argv[1])
key = sys.argv[2]
value = sys.stdin.read()
current[key] = {
  'value': value,
  'set_by': sys.argv[3],
  'timestamp': sys.argv[4]
}
print(json.dumps(current, ensure_ascii=False, indent=2))
PYEOF
 "$CURRENT" "$KEY" "$AGENT" "$TIMESTAMP" <<'VALUE'
$VALUE
VALUE
)
    _save "$UPDATED"

    # บันทึกลง memory index พร้อม metadata
    _save_memory_entry "$KEY" "$VALUE" "$AGENT" "$TIMESTAMP" "$EXPIRY_DAYS"

    log_action "SHARED_SET" "$KEY=$VALUE by $AGENT"
    ok "shared: $KEY = $VALUE"
    ;;

  # ── อ่าน shared state ────────────────────────────────────────────
  get)
    KEY="$1"
    if [ -z "$KEY" ]; then err "ต้องระบุ key"; exit 1; fi
    python3 -c "
import json, os
if os.path.exists('$SHARED_FILE'):
    d = json.load(open('$SHARED_FILE'))
    entry = d.get('$KEY', None)
    if entry:
        print(entry['value'])
    else:
        print('')
else:
    print('')
" 2>/dev/null
    ;;

  # ── ดูทั้งหมด ─────────────────────────────────────────────────────
  all)
    echo ""
    echo -e "${BOLD}=== Shared Memory ===${RESET}"
    if [ -f "$SHARED_FILE" ]; then
      python3 -c "
import json
d = json.load(open('$SHARED_FILE'))
if not d:
    print('  (ว่าง)')
else:
    for k, v in d.items():
        val = v['value'] if isinstance(v, dict) else str(v)
        by  = v.get('set_by','?') if isinstance(v, dict) else '?'
        ts  = v.get('timestamp','?') if isinstance(v, dict) else ''
        print(f'  {k}: {val[:50]} [{by}@{ts[:16]}]')
"
    else
      info "ยังไม่มี shared state"
    fi
    echo ""
    ;;

  # ── ลบ key ──────────────────────────────────────────────────────
  clear)
    KEY="$1"
    if [ -f "$SHARED_FILE" ]; then
      python3 -c "
import json
d = json.load(open('$SHARED_FILE'))
if '$KEY' in d:
    del d['$KEY']
    with open('$SHARED_FILE', 'w') as f:
        json.dump(d, f, indent=2)
    print('cleared:', '$KEY')
else:
    print('not found:', '$KEY')
"
    fi
    log_action "SHARED_CLEAR" "$KEY"
    ;;

  # ── sync กับ Oracle ──────────────────────────────────────────────
  sync)
    step "sync shared memory ↔ Oracle..."
    if ! oracle_ready; then
      warn "Oracle ไม่พร้อม — skip sync"
      exit 1
    fi
    if [ -f "$SHARED_FILE" ]; then
      python3 -c "
import json
d = json.load(open('$SHARED_FILE'))
print(json.dumps(d, ensure_ascii=False))
" | while read -r STATE_JSON; do
        oracle_learn "shared-state-snapshot" "$STATE_JSON" "shared,state,$(date +%Y-%m-%d)" > /dev/null
      done
      ok "sync → Oracle เสร็จแล้ว"
      log_action "SHARED_SYNC" "$(date '+%Y-%m-%dT%H:%M:%S')"
    else
      info "ไม่มี shared state ที่ต้อง sync"
    fi
    ;;

  # ── recall memories (ค้นหาพร้อม decay scoring) ─────────────────────
  recall)
    QUERY="$1"
    ARCHIVED_FLAG=""
    if [ "$QUERY" = "--archived" ]; then
      ARCHIVED_FLAG="archived"
      QUERY="$2"
    fi

    if [ -z "$QUERY" ]; then
      err "ต้องระบุ query: recall <query> | recall --semantic <query> | recall --archived <query>"
      exit 1
    fi

    if [ ! -f "$MEMORY_INDEX" ]; then
      info "ยังไม่มี memory index"
      exit 0
    fi

    python3 - <<PYEOF
import json
import os
from datetime import datetime
import math

MEMORY_INDEX = "${MEMORY_INDEX}"
ARCHIVE_DIR = "${ARCHIVE_DIR}"
ARCHIVE_THRESHOLD_DAYS = ${ARCHIVE_THRESHOLD_DAYS}
RECENCY_WEIGHT = ${RECENCY_WEIGHT}
ACCESS_WEIGHT = ${ACCESS_WEIGHT}
SEMANTIC_WEIGHT = ${SEMANTIC_WEIGHT}

query = "${QUERY}".lower()
archived_mode = "${ARCHIVED_FLAG}" == "archived"

index = json.load(open(MEMORY_INDEX))

results = []
now = datetime.now()

for key, entry in index.get("entries", {}).items():
    is_archived = entry.get("archived", False)

    # กรองตาม mode
    if archived_mode and not is_archived:
        continue
    if not archived_mode and is_archived:
        continue

    # คำนวณ decay score
    created = datetime.fromisoformat(entry.get("created_date", now.isoformat()).replace("Z", "+00:00"))
    last_accessed = datetime.fromisoformat(entry.get("last_accessed", created.isoformat()).replace("Z", "+00:00"))
    access_count = entry.get("access_count", 0)

    days_since_access = (now - last_accessed.replace(tzinfo=None)).days

    # recency_score = 1 / (1 + days_since_access / 30)
    recency_score = 1.0 / (1.0 + max(0, days_since_access) / 30.0)

    # access_score = min(1, log10(access_count + 1) / 3)
    access_score = min(1.0, math.log10(access_count + 1) / 3.0) if access_count >= 0 else 0

    # semantic_relevance (simple keyword match for now)
    value_text = entry.get("value", "").lower()
    semantic_score = 1.0 if query in value_text or query in key.lower() else 0.0

    # รวม score
    relevance = (RECENCY_WEIGHT * recency_score) + (ACCESS_WEIGHT * access_score) + (SEMANTIC_WEIGHT * semantic_score)

    # ตรวจสอบ expiry
    expiry_date = entry.get("expiry_date")
    is_expired = False
    if expiry_date:
        expiry = datetime.fromisoformat(expiry_date.replace("Z", "+00:00"))
        is_expired = now.replace(tzinfo=None) > expiry.replace(tzinfo=None)

    # ตรวจสอบ archive threshold
    should_archive = days_since_access > ARCHIVE_THRESHOLD_DAYS and not is_archived

    results.append({
        "key": key,
        "value": entry.get("value", "")[:200],
        "decay_score": round(relevance, 4),
        "access_count": access_count,
        "days_since_access": days_since_access,
        "is_expired": is_expired,
        "should_archive": should_archive,
        "set_by": entry.get("set_by", "?")
    })

# เรียงตาม decay score (สูง→ต่ำ)
results.sort(key=lambda x: x["decay_score"], reverse=True)

if not results:
    print("  (ไม่พบ memory ที่ตรงกั)")
else:
    mode_str = "[ARCHIVED] " if archived_mode else ""
    print(f"\n{mode_str}=== Recall Results: '{query}' ===")
    for r in results[:10]:  # แสดง top 10
        expired_mark = " ⚠️ EXPIRED" if r["is_expired"] else ""
        archive_mark = " 📦 ARCHIVE" if r["should_archive"] else ""
        print(f"  [{r['decay_score']:.2f}] {r['key']}: {r['value'][:80]}... [{r['set_by']}@{r['access_count']}x]{expired_mark}{archive_mark}")
PYEOF
    ;;

  # ── archive old memories ──────────────────────────────────────────
  archive)
    step "Archiving memories > $ARCHIVE_THRESHOLD_DAYS days..."

    if [ ! -f "$MEMORY_INDEX" ]; then
      info "ไม่มี memory index"
      exit 0
    fi

    mkdir -p "$ARCHIVE_DIR"

    python3 - <<PYEOF
import json
import shutil
from datetime import datetime

MEMORY_INDEX = "${MEMORY_INDEX}"
ARCHIVE_DIR = "${ARCHIVE_DIR}"
ARCHIVE_THRESHOLD_DAYS = ${ARCHIVE_THRESHOLD_DAYS}

index = json.load(open(MEMORY_INDEX))
now = datetime.now()
archived_count = 0

for key, entry in index.get("entries", {}).items():
    if entry.get("archived", False):
        continue

    last_accessed = datetime.fromisoformat(entry.get("last_accessed", entry.get("created_date", now.isoformat())).replace("Z", "+00:00"))
    days_since_access = (now - last_accessed.replace(tzinfo=None)).days

    if days_since_access > ARCHIVE_THRESHOLD_DAYS:
        entry["archived"] = True
        entry["archived_date"] = now.isoformat()
        entry["archived_reason"] = f"days_since_access={days_since_access}"

        # ย้ายไฟล์ (ถ้ามี) ไป archive
        archive_file = f"{ARCHIVE_DIR}/{key}.json"
        with open(archive_file, "w", encoding="utf-8") as f:
            json.dump(entry, f, ensure_ascii=False, indent=2)

        archived_count += 1
        print(f"  Archived: {key} ({days_since_access} days)")

# บันทึก index ที่อับเดท
with open(MEMORY_INDEX, "w", encoding="utf-8") as f:
    json.dump(index, f, ensure_ascii=False, indent=2)

print(f"\nArchived {archived_count} entries")
PYEOF

    ok "Archive complete"
    ;;

  # ── announce state ไปยัง nerve ────────────────────────────────────
  announce)
    KEY="$1" VALUE="$2"
    bash "$SCRIPT_DIR/../memory/shared.sh" set "$KEY" "$VALUE"
    # ส่ง nerve signal
    NERVE="$SCRIPT_DIR/../organs/nerve.sh"
    [ -x "$NERVE" ] && bash "$NERVE" signal "shared_update" "$KEY=$VALUE" "$AGENT"
    ;;

  *)
    echo "Usage: shared.sh {set|get|all|clear|sync|announce|recall|archive}"
    echo ""
    echo "  set      <key> <value> [expiry_days]  — บันทึก shared state"
    echo "  get      <key>          — อ่าน shared state"
    echo "  all                     — ดูทั้งหมด"
    echo "  clear    <key>          — ลบ key"
    echo "  sync                    — sync กับ Oracle"
    echo "  announce <key> <value>  — set + nerve signal"
    echo "  recall   <query>        — ค้นหาความทรงจำ (recent+high-access ก่อน)
  recall   --semantic <query> — ค้นหาด้วย vector similarity (experimental)"
    echo "  recall   --archived <query> — ค้นหา archived memories"
    echo "  archive                 — ย้าย entries >60 วันไป archive"
    ;;
esac
