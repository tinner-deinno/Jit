#!/usr/bin/env bash
# mind/memory-decay.sh — การสลายตัวของความทรงจำ
#
# หน้าที่:
# 1. คำนวณ decay scores สำหรับทุก memory entries
# 2. Archive entries ที่ >60 วันไม่ถูกเข้าถึง
# 3. แจ้งเตือน entries ที่ใกล้หมดอายุ
#
# Usage:
#   ./memory-decay.sh check     — ตรวจสอบ decay status
#   ./memory-decay.sh archive   — ทำการ archive
#   ./memory-decay.sh report    — สร้างรายงาน

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

MEMORY_INDEX="/workspaces/Jit/memory/index.json"
ARCHIVE_DIR="/workspaces/Jit/memory/archive"
ARCHIVE_THRESHOLD_DAYS=60
EXPIRY_WARNING_DAYS=7

CMD="${1:-check}"

case "$CMD" in

  # ── ตรวจสอบ decay status ─────────────────────────────────────────
  check)
    step "Checking memory decay..."

    if [ ! -f "$MEMORY_INDEX" ]; then
      info "ไม่มี memory index"
      exit 0
    fi

    python3 - <<'PYEOF'
import json
from datetime import datetime

MEMORY_INDEX = "/workspaces/Jit/memory/index.json"
ARCHIVE_THRESHOLD_DAYS = 60
EXPIRY_WARNING_DAYS = 7

index = json.load(open(MEMORY_INDEX))
now = datetime.now()

active_count = 0
archived_count = 0
expired_count = 0
to_archive_count = 0
warning_entries = []

print("\n=== Memory Decay Status ===\n")

for key, entry in index.get("entries", {}).items():
    is_archived = entry.get("archived", False)

    if is_archived:
        archived_count += 1
        continue

    active_count += 1

    # คำนวณ days since access
    last_accessed = datetime.fromisoformat(
        entry.get("last_accessed", entry.get("created_date", now.isoformat())).replace("Z", "+00:00")
    )
    days_since_access = (now - last_accessed.replace(tzinfo=None)).days

    # ตรวจสอบ expiry
    expiry_date = entry.get("expiry_date")
    is_expired = False
    days_until_expiry = None

    if expiry_date:
        expiry = datetime.fromisoformat(expiry_date.replace("Z", "+00:00")) if "T" in expiry_date else datetime.strptime(expiry_date, "%Y-%m-%d")
        days_until_expiry = (expiry - now.replace(tzinfo=None)).days
        is_expired = days_until_expiry < 0

        if is_expired:
            expired_count += 1
        elif days_until_expiry <= EXPIRY_WARNING_DAYS:
            warning_entries.append((key, f"expires in {days_until_expiry} days"))

    # ตรวจสอบ archive threshold
    if days_since_access > ARCHIVE_THRESHOLD_DAYS:
        to_archive_count += 1
        print(f"  📦 {key}: {days_since_access} days (ready for archive)")

    # แสดง decay score
    access_count = entry.get("access_count", 0)
    recency_score = 1.0 / (1.0 + max(0, days_since_access) / 30.0)
    access_score = min(1.0, __import__('math').log10(access_count + 1) / 3.0) if access_count >= 0 else 0
    decay_score = 0.4 * recency_score + 0.3 * access_score + 0.3 * 0.5

    status_icon = "⚠️ EXPIRED" if is_expired else "📦 ARCHIVE" if days_since_access > ARCHIVE_THRESHOLD_DAYS else "✅"
    print(f"  {status_icon} {key}: score={decay_score:.2f}, accessed={access_count}x, days={days_since_access}")

print(f"\n=== Summary ===")
print(f"  Active: {active_count}")
print(f"  Archived: {archived_count}")
print(f"  Expired: {expired_count}")
print(f"  Ready for archive: {to_archive_count}")

if warning_entries:
    print(f"\n⚠️  Expiry Warnings:")
    for key, msg in warning_entries:
        print(f"  - {key}: {msg}")
PYEOF
    ;;

  # ── Archive old memories ─────────────────────────────────────────
  archive)
    step "Archiving memories older than $ARCHIVE_THRESHOLD_DAYS days..."

    mkdir -p "$ARCHIVE_DIR"

    if [ ! -f "$MEMORY_INDEX" ]; then
      info "ไม่มี memory index"
      exit 0
    fi

    python3 - <<'PYEOF'
import json
from datetime import datetime
import os

MEMORY_INDEX = "/workspaces/Jit/memory/index.json"
ARCHIVE_DIR = "/workspaces/Jit/memory/archive"
ARCHIVE_THRESHOLD_DAYS = 60

index = json.load(open(MEMORY_INDEX))
now = datetime.now()
archived_count = 0

for key, entry in index.get("entries", {}).items():
    if entry.get("archived", False):
        continue

    last_accessed_str = entry.get("last_accessed", entry.get("created_date", now.isoformat()))
    last_accessed = datetime.fromisoformat(last_accessed_str.replace("Z", "+00:00"))
    days_since_access = (now - last_accessed.replace(tzinfo=None)).days

    if days_since_access > ARCHIVE_THRESHOLD_DAYS:
        entry["archived"] = True
        entry["archived_date"] = now.isoformat()
        entry["archived_reason"] = f"days_since_access={days_since_access}"

        # บันทึกไฟล์ archive
        archive_file = os.path.join(ARCHIVE_DIR, f"{key}.json")
        with open(archive_file, "w", encoding="utf-8") as f:
            json.dump(entry, f, ensure_ascii=False, indent=2)

        archived_count += 1
        print(f"  📦 Archived: {key} ({days_since_access} days)")

# บันทึก index ที่อัพเดท
with open(MEMORY_INDEX, "w", encoding="utf-8") as f:
    json.dump(index, f, ensure_ascii=False, indent=2)

print(f"\n✅ Archived {archived_count} entries to {ARCHIVE_DIR}")
PYEOF

    ok "Archive complete"
    log_action "MEMORY_ARCHIVE" "$(date '+%Y-%m-%dT%H:%M:%S')"
    ;;

  # ── รายงาน decay statistics ──────────────────────────────────────
  report)
    step "Generating memory decay report..."

    if [ ! -f "$MEMORY_INDEX" ]; then
      echo "No memory index found"
      exit 0
    fi

    REPORT_FILE="/workspaces/Jit/reports/memory-decay-$(date +%Y%m%d).md"
    mkdir -p "$(dirname "$REPORT_FILE")"

    python3 - <<PYEOF
import json
from datetime import datetime
import math

MEMORY_INDEX = "/workspaces/Jit/memory/index.json"
ARCHIVE_THRESHOLD_DAYS = 60

index = json.load(open(MEMORY_INDEX))
now = datetime.now()

stats = {
    "total": 0,
    "active": 0,
    "archived": 0,
    "expired": 0,
    "high_decay": 0,  # score < 0.3
    "medium_decay": 0,  # 0.3-0.6
    "low_decay": 0,  # > 0.6
    "avg_access_count": 0,
    "avg_days_since_access": 0
}

access_counts = []
days_list = []
decay_scores = []

for key, entry in index.get("entries", {}).items():
    stats["total"] += 1

    is_archived = entry.get("archived", False)
    if is_archived:
        stats["archived"] += 1
        continue

    stats["active"] += 1

    # คำนวณ metrics
    last_accessed = datetime.fromisoformat(
        entry.get("last_accessed", entry.get("created_date", now.isoformat())).replace("Z", "+00:00")
    )
    days_since_access = (now - last_accessed.replace(tzinfo=None)).days
    access_count = entry.get("access_count", 0)

    # ตรวจสอบ expiry
    expiry_date = entry.get("expiry_date")
    if expiry_date:
        expiry = datetime.fromisoformat(expiry_date.replace("Z", "+00:00")) if "T" in expiry_date else datetime.strptime(expiry_date, "%Y-%m-%d")
        if (expiry - now.replace(tzinfo=None)).days < 0:
            stats["expired"] += 1

    # คำนวณ decay score
    recency_score = 1.0 / (1.0 + max(0, days_since_access) / 30.0)
    access_score = min(1.0, math.log10(access_count + 1) / 3.0) if access_count >= 0 else 0
    decay_score = 0.4 * recency_score + 0.3 * access_score + 0.3 * 0.5

    decay_scores.append(decay_score)
    access_counts.append(access_count)
    days_list.append(days_since_access)

    if decay_score < 0.3:
        stats["high_decay"] += 1
    elif decay_score < 0.6:
        stats["medium_decay"] += 1
    else:
        stats["low_decay"] += 1

if access_counts:
    stats["avg_access_count"] = sum(access_counts) / len(access_counts)
    stats["avg_days_since_access"] = sum(days_list) / len(days_list)

report = f"""# Memory Decay Report

Generated: {now.isoformat()}

## Summary

| Metric | Value |
|--------|-------|
| Total Entries | {stats["total"]} |
| Active | {stats["active"]} |
| Archived | {stats["archived"]} |
| Expired | {stats["expired"]} |

## Decay Distribution

| Level | Count | Description |
|-------|-------|-------------|
| Low Decay (>0.6) | {stats["low_decay"]} | Recent & frequently accessed |
| Medium Decay (0.3-0.6) | {stats["medium_decay"]} | Moderate activity |
| High Decay (<0.3) | {stats["high_decay"]} | Old & rarely accessed |

## Averages

- Average Access Count: {stats["avg_access_count"]:.1f}
- Average Days Since Access: {stats["avg_days_since_access"]:.1f}

## Recommendations

1. Review expired entries for potential deletion or renewal
2. Consider archiving entries with high decay scores
3. Monitor entries approaching archive threshold ({ARCHIVE_THRESHOLD_DAYS} days)
"""

print(report)

with open("$REPORT_FILE", "w", encoding="utf-8") as f:
    f.write(report)

print(f"\nReport saved to: $REPORT_FILE")
PYEOF
    ;;

  *)
    echo "Usage: memory-decay.sh {check|archive|report}"
    echo ""
    echo "  check   — ตรวจสอบ decay status"
    echo "  archive — ทำการ archive entries เก่า"
    echo "  report  — สร้างรายงานสถิติ"
    ;;
esac
