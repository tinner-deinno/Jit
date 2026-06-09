#!/usr/bin/env bash
# scripts/housekeeper.sh — Jit Oracle Housekeeping
# ════════════════════════════════════════════════════════════════
# แม่บ้านของ Jit Oracle — คอยทำความสะอาดบ้านตามรอบ
#
# หน้าที่:
#   1. Archive ψ/outbox/ cycle files ที่เกิน RETAIN_DAYS วัน
#   2. Archive ψ/inbox/ messages ที่เกิน INBOX_RETAIN_DAYS วัน
#   3. รายงาน root/.* stray directories และแจ้งเตือน
#   4. Log ผลลัพธ์ทุก run
#
# Usage:
#   bash scripts/housekeeper.sh           — full clean (default)
#   bash scripts/housekeeper.sh --dry-run — แสดงว่าจะทำอะไร โดยไม่ทำจริง
#   bash scripts/housekeeper.sh --status  — แสดงสถานะปัจจุบัน
#
# Schedule: ควรรันทุกวัน เช่น ผ่าน Windows Task Scheduler
#   Action: wsl.exe bash /path/to/scripts/housekeeper.sh
#   OR: PowerShell -File scripts/housekeeper.ps1
# ════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Config ──────────────────────────────────────────────────────
OUTBOX_DIR="$JIT_ROOT/ψ/outbox"
INBOX_DIR="$JIT_ROOT/ψ/inbox"
ARCHIVE_BASE="$JIT_ROOT/ψ/archive"
LOG_FILE="$JIT_ROOT/ψ/memory/logs/housekeeper.log"
RETAIN_DAYS="${HOUSEKEEPER_RETAIN_DAYS:-7}"       # outbox cycle files เก่ากว่านี้จะถูก archive
INBOX_RETAIN_DAYS="${HOUSEKEEPER_INBOX_RETAIN:-30}" # inbox messages เก่ากว่านี้จะถูก archive
OUTBOX_MAX_COUNT="${HOUSEKEEPER_OUTBOX_MAX:-100}"  # จำนวนสูงสุดใน outbox ก่อน force-archive
DRY_RUN=false
STATUS_ONLY=false

# ── Args ────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --status)  STATUS_ONLY=true ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────────
log() {
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S')
  echo "[$ts] HOUSEKEEPER: $*"
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "[$ts] HOUSEKEEPER: $*" >> "$LOG_FILE"
}

header() {
  echo ""
  echo "══════════════════════════════════════════════════"
  echo "  Jit Housekeeper — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "══════════════════════════════════════════════════"
}

# ── Status ──────────────────────────────────────────────────────
show_status() {
  echo ""
  echo "── ψ/outbox/ ──────────────────────────────────────"
  if [ -d "$OUTBOX_DIR" ]; then
    local total old_count
    total=$(find "$OUTBOX_DIR" -maxdepth 1 -name "*jit-mother-loop-cycle-*.md" | wc -l | tr -d ' ')
    old_count=$(find "$OUTBOX_DIR" -maxdepth 1 -name "*jit-mother-loop-cycle-*.md" \
      -mtime "+${RETAIN_DAYS}" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Total cycle files: $total"
    echo "  Older than ${RETAIN_DAYS}d: $old_count"
  else
    echo "  (not found)"
  fi

  echo ""
  echo "── ψ/inbox/ ───────────────────────────────────────"
  if [ -d "$INBOX_DIR" ]; then
    local inbox_total inbox_old
    inbox_total=$(find "$INBOX_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')
    inbox_old=$(find "$INBOX_DIR" -maxdepth 1 -type f \
      -mtime "+${INBOX_RETAIN_DAYS}" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Total files: $inbox_total"
    echo "  Older than ${INBOX_RETAIN_DAYS}d: $inbox_old"
  else
    echo "  (not found)"
  fi

  echo ""
  echo "── ψ/archive/ ─────────────────────────────────────"
  if [ -d "$ARCHIVE_BASE" ]; then
    local archive_total
    archive_total=$(find "$ARCHIVE_BASE" -type f | wc -l | tr -d ' ')
    echo "  Total archived files: $archive_total"
  else
    echo "  (empty)"
  fi

  echo ""
  echo "── Root stray check ───────────────────────────────"
  # ตรวจหา psi/ หรือ C:Users... dirs ที่เกิดจาก path bug
  for suspicious in "$JIT_ROOT/psi" "$JIT_ROOT/C:Users"*; do
    if [ -e "$suspicious" ]; then
      echo "  WARN: Stray directory found: $suspicious"
    fi
  done
  echo "  Root .md count: $(ls "$JIT_ROOT"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  echo "  Root .txt count: $(ls "$JIT_ROOT"/*.txt 2>/dev/null | wc -l | tr -d ' ')"
  echo ""
}

# ── Archive outbox cycle files ──────────────────────────────────
archive_outbox() {
  if [ ! -d "$OUTBOX_DIR" ]; then
    log "outbox dir not found, skipping"
    return
  fi

  local today
  today=$(date '+%Y-%m-%d')
  local archive_dir="$ARCHIVE_BASE/outbox/$today"

  # Find old files by age
  local old_files
  mapfile -t old_files < <(find "$OUTBOX_DIR" -maxdepth 1 \
    -name "*jit-mother-loop-cycle-*.md" \
    -mtime "+${RETAIN_DAYS}" 2>/dev/null | sort)

  # Also enforce max count limit
  local all_cycle_files
  mapfile -t all_cycle_files < <(find "$OUTBOX_DIR" -maxdepth 1 \
    -name "*jit-mother-loop-cycle-*.md" 2>/dev/null | sort)

  local total=${#all_cycle_files[@]}
  if [ "$total" -gt "$OUTBOX_MAX_COUNT" ]; then
    local excess=$(( total - OUTBOX_MAX_COUNT ))
    log "outbox count $total > max $OUTBOX_MAX_COUNT — forcing archive of $excess oldest files"
    old_files+=("${all_cycle_files[@]:0:$excess}")
    # deduplicate
    mapfile -t old_files < <(printf '%s\n' "${old_files[@]}" | sort -u)
  fi

  local count=${#old_files[@]}
  if [ "$count" -eq 0 ]; then
    log "outbox: nothing to archive (${total} files, all fresh)"
    return
  fi

  log "outbox: archiving $count files → $archive_dir"

  if [ "$DRY_RUN" = "true" ]; then
    echo "  [DRY-RUN] Would archive $count files to $archive_dir"
    return
  fi

  mkdir -p "$archive_dir"
  local moved=0
  for f in "${old_files[@]}"; do
    local fname
    fname=$(basename "$f")
    local dest="$archive_dir/$fname"
    if [ ! -f "$dest" ]; then
      mv "$f" "$dest" && (( moved++ )) || true
    else
      rm "$f"  # duplicate — just remove
    fi
  done
  log "outbox: archived $moved files"
}

# ── Archive old inbox messages ───────────────────────────────────
archive_inbox() {
  if [ ! -d "$INBOX_DIR" ]; then
    log "inbox dir not found, skipping"
    return
  fi

  local today
  today=$(date '+%Y-%m-%d')
  local archive_dir="$ARCHIVE_BASE/inbox/$today"

  # Archive flat inbox files (not subdirs like handoff/)
  local old_files
  mapfile -t old_files < <(find "$INBOX_DIR" -maxdepth 1 -type f \
    -mtime "+${INBOX_RETAIN_DAYS}" 2>/dev/null | sort)

  local count=${#old_files[@]}
  if [ "$count" -eq 0 ]; then
    log "inbox: nothing to archive (all files fresh)"
    return
  fi

  log "inbox: archiving $count files older than ${INBOX_RETAIN_DAYS}d → $archive_dir"

  if [ "$DRY_RUN" = "true" ]; then
    echo "  [DRY-RUN] Would archive $count inbox files to $archive_dir"
    return
  fi

  mkdir -p "$archive_dir"
  local moved=0
  for f in "${old_files[@]}"; do
    local fname
    fname=$(basename "$f")
    mv "$f" "$archive_dir/$fname" && (( moved++ )) || true
  done
  log "inbox: archived $moved files"
}

# ── Stray directory check & auto-heal ──────────────────────────
check_stray_dirs() {
  local found=0

  # psi/ สร้างจาก bash path bug (ψ → psi fallback บน Windows)
  if [ -d "$JIT_ROOT/psi" ]; then
    (( found++ ))
    log "WARN: stray psi/ directory found (should be ψ/)"
    if [ "$DRY_RUN" = "true" ]; then
      echo "  [DRY-RUN] Would merge psi/ → ψ/ and remove"
    else
      # Move non-duplicate files into ψ/
      find "$JIT_ROOT/psi" -type f | while read -r f; do
        local rel="${f#$JIT_ROOT/psi/}"
        local dest="$JIT_ROOT/ψ/$rel"
        mkdir -p "$(dirname "$dest")"
        if [ ! -f "$dest" ]; then
          mv "$f" "$dest"
          log "healed: psi/$rel → ψ/$rel"
        fi
      done
      rm -rf "$JIT_ROOT/psi"
      log "stray psi/ removed"
    fi
  fi

  # C:Users... dirs สร้างจาก unquoted Windows path ใน bash
  for d in "$JIT_ROOT"/C:Users* "$JIT_ROOT"/C:*; do
    if [ -d "$d" ]; then
      (( found++ ))
      log "WARN: stray Windows-path dir found: $(basename "$d")"
      if [ "$DRY_RUN" = "true" ]; then
        echo "  [DRY-RUN] Would archive: $(basename "$d")"
      else
        local today
        today=$(date '+%Y-%m-%d')
        mv "$d" "$JIT_ROOT/archive/stray-$today/" 2>/dev/null || true
        log "stray dir archived: $(basename "$d")"
      fi
    fi
  done

  if [ "$found" -eq 0 ]; then
    log "stray check: clean"
  fi
}

# ── Trim log file ────────────────────────────────────────────────
trim_log() {
  if [ -f "$LOG_FILE" ]; then
    local lines
    lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$lines" -gt 500 ]; then
      local tmp
      tmp=$(mktemp)
      tail -400 "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"
      log "housekeeper log trimmed to 400 lines"
    fi
  fi
}

# ── Main ─────────────────────────────────────────────────────────
header

if [ "$STATUS_ONLY" = "true" ]; then
  show_status
  exit 0
fi

show_status

if [ "$DRY_RUN" = "true" ]; then
  echo ""
  echo "  *** DRY-RUN MODE — no files will be moved ***"
  echo ""
fi

log "=== housekeeper run START (dry=$DRY_RUN) ==="

archive_outbox
archive_inbox
check_stray_dirs
trim_log

log "=== housekeeper run DONE ==="
echo ""
echo "  Done. Log: $LOG_FILE"
echo ""
