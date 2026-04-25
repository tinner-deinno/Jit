#!/usr/bin/env bash
# scripts/sync-identity.sh — รวบรวมตัวตนและความทรงจำลง Oracle (RAG)
#
# อ่านทุก .md ในโฟลเดอร์สำคัญ → ส่งเข้า Oracle เป็น structured records
# เพื่อให้ innova สามารถ query ตัวตน กฎ และประสบการณ์ได้ในทุก session
#
# Usage:
#   bash scripts/sync-identity.sh           # sync ทุกอย่าง
#   bash scripts/sync-identity.sh --quiet   # ไม่แสดง verbose
#   bash scripts/sync-identity.sh --dry-run # แสดงแต่ไม่ส่ง

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

QUIET=0; DRY=0
for ARG in "$@"; do
  [[ "$ARG" == "--quiet"   ]] && QUIET=1
  [[ "$ARG" == "--dry-run" ]] && DRY=1
done

ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
SYNCED=0; FAILED=0; SKIPPED=0

_log() { [ "$QUIET" -eq 0 ] && echo -e "$*"; }

# ────────────────────────────────────────────────────────────────────
# ตรวจ Oracle
# ────────────────────────────────────────────────────────────────────
_check_oracle() {
  curl -sf --max-time 4 "$ORACLE_URL/api/health" 2>/dev/null | grep -q '"oracle":"connected"'
}

# ────────────────────────────────────────────────────────────────────
# ส่งไฟล์เดียวเข้า Oracle
# ────────────────────────────────────────────────────────────────────
_sync_file() {
  local FILE="$1" PATTERN="$2" TAGS="$3"
  [ ! -f "$FILE" ] && { SKIPPED=$(( SKIPPED + 1 )); return; }
  [ ! -s "$FILE" ] && { SKIPPED=$(( SKIPPED + 1 )); return; }

  if [ "$DRY" -eq 1 ]; then
    _log "  ${CYAN}[DRY] ${RESET}$(basename "$FILE") → Oracle pattern: $PATTERN"
    return
  fi

  # ใช้ Python script ที่รับ args — หลีกเลี่ยง heredoc+stdin ขัดกัน
  HTTP_STATUS=$(python3 "$JIT_ROOT/scripts/oracle-learn.py" "$FILE" "$PATTERN" "$TAGS" "$ORACLE_URL" 2>/dev/null || echo "000")

  if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "201" ]]; then
    SYNCED=$(( SYNCED + 1 ))
    _log "  ${GREEN}✅ $(basename "$FILE")${RESET}"
  else
    FAILED=$(( FAILED + 1 ))
    _log "  ${RED}❌ $(basename "$FILE") (HTTP $HTTP_STATUS)${RESET}"
  fi
}

# ────────────────────────────────────────────────────────────────────
# MAIN
# ────────────────────────────────────────────────────────────────────
[ "$QUIET" -eq 0 ] && {
  echo ""
  echo -e "${BOLD}${CYAN}  🧠 innova sync-identity — รวบรวมตัวตนลง Oracle${RESET}"
  echo ""
}

if ! _check_oracle; then
  _log "${YELLOW}  ⚠️  Oracle offline — ข้ามการ sync${RESET}"
  exit 0
fi

ORACLE_DOCS=$(curl -sf --max-time 3 "$ORACLE_URL/api/stats" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo "?")
_log "  📊 Oracle ปัจจุบัน: $ORACLE_DOCS records"
echo ""

# ── Core Identity files ───────────────────────────────────────────────
_log "${BOLD}  Core Identity:${RESET}"
_sync_file "$JIT_ROOT/core/identity.md"       "innova-identity"     "identity,innova,soul,core"
_sync_file "$JIT_ROOT/mind/ego.md"            "innova-ego"          "ego,personality,values,mind"
_sync_file "$JIT_ROOT/brain/reasoning.md"     "innova-reasoning"    "reasoning,framework,logic,brain"
_sync_file "$JIT_ROOT/core/body-map.md"       "manusat-body-map"    "organs,agents,RACI,body,system"
_sync_file "$JIT_ROOT/network/protocol.md"    "manusat-protocol"    "protocol,communication,bus,network"

# ── Architecture & Design ────────────────────────────────────────────
_log ""
_log "${BOLD}  Architecture:${RESET}"
_sync_file "$JIT_ROOT/memory/architecture.md" "innova-memory-arch"  "memory,architecture,layers,oracle"
_sync_file "$JIT_ROOT/docs/multiagent-spec.md" "manusat-spec"       "spec,multiagent,14agents,system"

# ── Retrospectives (latest 5 only) ───────────────────────────────────
_log ""
_log "${BOLD}  Retrospectives (latest):${RESET}"
while IFS= read -r F; do
  FNAME=$(basename "$F" .md)
  _sync_file "$F" "retro-$FNAME" "retrospective,memory,learning"
done < <(find "$JIT_ROOT/memory/retrospectives" -name "*.md" 2>/dev/null | sort | tail -5)

# ── Current state snapshot ────────────────────────────────────────────
_log ""
_log "${BOLD}  Live Snapshot:${RESET}"
SNAPSHOT_FILE="/tmp/innova-snapshot-$(date '+%Y%m%d').md"
cat > "$SNAPSHOT_FILE" << SNAP
# innova Live State Snapshot — $(date '+%Y-%m-%d %H:%M:%S')

## Commits
$(git -C "$JIT_ROOT" log --oneline -5 2>/dev/null)

## Files Changed (uncommitted)
$(git -C "$JIT_ROOT" status --short 2>/dev/null | head -20)

## Awakening State
$(cat /tmp/innova-awaken-state.json 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(no awaken state)")

## Active Scripts
$(ls "$JIT_ROOT/scripts/"*.sh 2>/dev/null | xargs -I{} basename {})
SNAP
_sync_file "$SNAPSHOT_FILE" "innova-live-state" "state,snapshot,live,current"

# ────────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────────
[ "$QUIET" -eq 0 ] && {
  echo ""
  echo -e "  ${GREEN}✅ synced: $SYNCED${RESET}  ${RED}❌ failed: $FAILED${RESET}  ${YELLOW}⏩ skipped: $SKIPPED${RESET}"
  echo ""
}

log_action "SYNC_IDENTITY" "synced=$SYNCED failed=$FAILED skipped=$SKIPPED"
[ "$FAILED" -gt 0 ] && exit 1 || exit 0
