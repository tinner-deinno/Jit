#!/usr/bin/env bash
# .github/hooks/pre-tool.sh — สัมมาสังกัปปะ: คิดก่อนลงมือ
#
# Hook ที่รันก่อนทุก tool call ของ innova
# หลักพุทธ: "ผู้มีสติย่อมไม่ทำสิ่งใดโดยปราศจากการพิจารณา"
#
# ถูกเรียกโดย: VS Code agent hooks, scripts ต่างๆ
# ค่า exit 0 = ผ่าน, exit 1 = ยับยั้ง

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(dirname "$SCRIPT_DIR")"
LIB="$JIT_ROOT/../limbs/lib.sh"

# ถ้ามี lib.sh ให้ใช้
[ -f "$LIB" ] && source "$LIB"

TOOL="${INNOVA_TOOL:-unknown}"
ARGS="${INNOVA_ARGS:-}"
CONTEXT="${INNOVA_CONTEXT:-}"

# ── ศีล: ห้ามทำลายโดยไม่ถาม ─────────────────────────────────────────
DESTRUCTIVE_PATTERNS=(
  "rm -rf"
  "DROP TABLE"
  "git reset --hard"
  "git push --force"
  "truncate"
  "format"
  "wipe"
  "delete.*prod"
)

for PATTERN in "${DESTRUCTIVE_PATTERNS[@]}"; do
  if echo "$ARGS $CONTEXT" | grep -qi "$PATTERN"; then
    echo "⚠ [pre-tool] ตรวจพบคำสั่งที่อาจทำลายข้อมูล: $PATTERN"
    echo "⚠ [pre-tool] หลักพุทธ: สัมมากัมมันตะ — ย้อนคืนได้ก่อน ทำลายทีหลัง"
    echo "⚠ [pre-tool] กรุณายืนยันก่อนดำเนินการ"
    # Log แต่ไม่บล็อก (agent decides)
    [ -f "$LIB" ] && log_action "PRE_TOOL_WARN" "Destructive: $PATTERN in '$ARGS'"
    break
  fi
done

# ── สติ: log ทุก tool call ─────────────────────────────────────────────
LOG_FILE="/tmp/innova-actions.log"
echo "$(date '+%Y-%m-%d %H:%M:%S')|PRE_TOOL|$TOOL|${ARGS:0:100}" >> "$LOG_FILE" 2>/dev/null

# exit 0 — อนุญาตเสมอ (เฝ้าดู ไม่ใช่บังคับ)
exit 0
