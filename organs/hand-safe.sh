#!/usr/bin/env bash
# organs/hand-safe.sh — มือ (Safe wrapper): validates inputs before delegating to hand.sh
#
# JIT-020 fix: input-validation layer in front of hand.sh `edit` command.
# Rejects inputs that previously triggered sed injection:
#   - Paths outside the project root (path traversal)
#   - NUL bytes in any argument
#   - Excessively long arguments (> 10 MB) that could exhaust memory
#
# All other commands pass through to hand.sh unchanged.
#
# Usage: identical to hand.sh
#   ./hand-safe.sh edit   <file> <old> <new>
#   ./hand-safe.sh create <file> [content]
#   ./hand-safe.sh <any other hand.sh command>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAND_SH="$SCRIPT_DIR/hand.sh"

# ── Safety constants ──────────────────────────────────────────────────────────
MAX_ARG_BYTES=$((10 * 1024 * 1024))   # 10 MB per argument
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────
_die() { echo "[hand-safe] ERROR: $*" >&2; exit 1; }

# Reject NUL bytes in a value (printf %s handles binary safely)
_check_no_nul() {
  local label="$1" value="$2"
  # bash variables cannot hold NUL; this guard is for explicitness / future-proofing
  if printf '%s' "$value" | grep -qP '\x00' 2>/dev/null; then
    _die "NUL byte detected in $label — rejected"
  fi
}

# Reject arguments exceeding MAX_ARG_BYTES
_check_length() {
  local label="$1" value="$2"
  local len
  len=$(printf '%s' "$value" | wc -c)
  if [ "$len" -gt "$MAX_ARG_BYTES" ]; then
    _die "$label exceeds maximum allowed size (${len} bytes > ${MAX_ARG_BYTES} bytes)"
  fi
}

# Resolve FILE to a real path and ensure it stays within PROJECT_ROOT
_check_path() {
  local raw_path="$1"
  # Resolve symlinks/.. components; allow non-existent files (for create)
  local resolved
  resolved="$(realpath -m "$raw_path" 2>/dev/null)" || resolved="$raw_path"
  if [[ "$resolved" != "$PROJECT_ROOT"* ]]; then
    _die "path traversal rejected: '$raw_path' resolves outside project root ($PROJECT_ROOT)"
  fi
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
CMD="${1:-help}"

case "$CMD" in

  edit)
    FILE="${2:-}" OLD="${3:-}" NEW="${4:-}"

    # Validate each argument
    [ -z "$FILE" ] && _die "edit requires FILE argument"
    [ -z "$OLD"  ] && _die "edit requires OLD argument"
    # NEW may legitimately be empty (delete a string)

    _check_path  "$FILE"
    _check_no_nul "FILE" "$FILE"
    _check_no_nul "OLD"  "$OLD"
    _check_no_nul "NEW"  "$NEW"
    _check_length "OLD"  "$OLD"
    _check_length "NEW"  "$NEW"

    # Delegate to the fixed hand.sh (Python literal replacement, no sed injection)
    exec "$HAND_SH" edit "$FILE" "$OLD" "$NEW"
    ;;

  create)
    FILE="${2:-}"
    [ -n "$FILE" ] && _check_path "$FILE"
    exec "$HAND_SH" "$@"
    ;;

  delete)
    FILE="${2:-}"
    [ -n "$FILE" ] && _check_path "$FILE"
    exec "$HAND_SH" "$@"
    ;;

  copy)
    SRC="${2:-}" DST="${3:-}"
    [ -n "$SRC" ] && _check_path "$SRC"
    [ -n "$DST" ] && _check_path "$DST"
    exec "$HAND_SH" "$@"
    ;;

  *)
    # All other commands pass through unchanged
    exec "$HAND_SH" "$@"
    ;;

esac
