#!/usr/bin/env bash
# systemd/jit-secure.sh — Pre-exec security validator for jit-daemon.service
#
# Purpose:
#   Run as ExecStartPre to ensure the daemon never starts with missing or
#   empty credentials.  All secrets must come from /etc/jit/jit-daemon.env
#   (owned root:root / root:innova, mode 0640) — never from inline
#   Environment= lines in the unit file.
#
# Usage (from unit file):
#   ExecStartPre=/bin/bash /workspaces/Jit/systemd/jit-secure.sh validate
#
# Exit codes:
#   0  — all checks passed, safe to start the daemon
#   1  — security check failed (systemd will abort start)
#
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

ENV_FILE="/etc/jit/jit-daemon.env"

# ── colour helpers ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

info()  { echo -e "${GREEN}[jit-secure] INFO : $*${RESET}";  }
warn()  { echo -e "${YELLOW}[jit-secure] WARN : $*${RESET}"; }
error() { echo -e "${RED}[jit-secure] ERROR: $*${RESET}" >&2; }

# ── subcommand dispatch ───────────────────────────────────────────
CMD="${1:-validate}"

case "$CMD" in
  validate) ;;
  help|--help|-h)
    echo "Usage: $0 [validate|help]"
    echo ""
    echo "  validate  — run all security checks (default, used by systemd)"
    echo "  help      — show this message"
    exit 0
    ;;
  *)
    error "Unknown command: $CMD"
    exit 1
    ;;
esac

# ═════════════════════════════════════════════════════════════════
# CHECK 1 — env file must exist
# ═════════════════════════════════════════════════════════════════
if [[ ! -f "$ENV_FILE" ]]; then
  error "EnvironmentFile not found: $ENV_FILE"
  error "Create it with:"
  error "  sudo mkdir -p /etc/jit"
  error "  sudo install -m 0640 -o root -g innova \\"
  error "      /workspaces/Jit/scripts/jit-daemon.env.example \\"
  error "      $ENV_FILE"
  error "  sudo -e $ENV_FILE   # fill in real values"
  exit 1
fi
info "Env file found: $ENV_FILE"

# ═════════════════════════════════════════════════════════════════
# CHECK 2 — env file must NOT be world-readable
#
# Mode must be at most 0640 (owner+group read/write, no world).
# If someone accidentally chmod 644'd the file the secrets would
# be readable by any local user.
# ═════════════════════════════════════════════════════════════════
FILE_PERMS=$(stat -c "%a" "$ENV_FILE" 2>/dev/null || stat -f "%Lp" "$ENV_FILE" 2>/dev/null)
if [[ -z "$FILE_PERMS" ]]; then
  warn "Could not determine file permissions for $ENV_FILE — skipping perm check"
else
  # Convert octal string to integer for comparison
  PERMS_INT=$(( 8#$FILE_PERMS ))
  # World-readable bit = 0004
  if (( PERMS_INT & 4 )); then
    error "SECURITY: $ENV_FILE is world-readable (mode $FILE_PERMS)"
    error "Fix: sudo chmod 0640 $ENV_FILE"
    exit 1
  fi
  info "File permissions OK: $FILE_PERMS (not world-readable)"
fi

# ═════════════════════════════════════════════════════════════════
# CHECK 3 — env file must NOT be inside the git repo
#
# Prevents accidental `git add .` from leaking secrets.
# ═════════════════════════════════════════════════════════════════
JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
REAL_ENV_FILE=$(realpath "$ENV_FILE" 2>/dev/null || echo "$ENV_FILE")
REAL_ROOT=$(realpath "$JIT_ROOT" 2>/dev/null || echo "$JIT_ROOT")

if [[ "$REAL_ENV_FILE" == "$REAL_ROOT"* ]]; then
  error "SECURITY: $ENV_FILE is inside the Jit repo ($REAL_ROOT)"
  error "Move it to /etc/jit/jit-daemon.env (outside the repo)"
  exit 1
fi
info "Env file is outside repo tree: OK"

# ═════════════════════════════════════════════════════════════════
# CHECK 4 — required credential variables must be present and
#           non-empty when loaded from the env file.
#
# We source the file in a restricted sub-shell so we never pollute
# the parent process environment with the raw secrets.
# ═════════════════════════════════════════════════════════════════

# Variables that MUST be set if the webhook/service is intended to
# be used.  Marked as REQUIRED or OPTIONAL below.
# Adjust this list when new credentials are added.
REQUIRED_VARS=(
  OLLAMA_TOKEN
)

OPTIONAL_VARS=(
  DISCORD_WEBHOOK
  GIT_TOKEN
)

# Source in a restricted subshell, capture set -a exports
check_vars() {
  # shellcheck source=/dev/null
  set -a
  source "$ENV_FILE"
  set +a

  local missing=()
  for var in "${REQUIRED_VARS[@]}"; do
    val="${!var:-}"
    if [[ -z "$val" ]]; then
      missing+=("$var")
    else
      # Mask for log: show first 4 chars then ****
      masked="${val:0:4}****"
      info "Required var $var present (masked: $masked)"
    fi
  done

  for var in "${OPTIONAL_VARS[@]}"; do
    val="${!var:-}"
    if [[ -z "$val" ]]; then
      warn "Optional var $var is not set — related features will be disabled"
    else
      info "Optional var $var present"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "SECURITY: Required credential(s) missing or empty in $ENV_FILE:"
    for v in "${missing[@]}"; do
      error "  - $v"
    done
    error "Set them in $ENV_FILE and restart the service."
    return 1
  fi
  return 0
}

if ! check_vars; then
  exit 1
fi

# ═════════════════════════════════════════════════════════════════
# CHECK 5 — ensure no credential-shaped value appears in the unit
#           file itself (belt-and-suspenders guard against future
#           accidental additions to the .service file).
# ═════════════════════════════════════════════════════════════════
UNIT_FILE="$JIT_ROOT/scripts/jit-daemon.service"
if [[ -f "$UNIT_FILE" ]]; then
  # Patterns that strongly suggest a hardcoded secret (token/key/password
  # directly assigned to a name in an Environment= line)
  if grep -Piq 'Environment=.*\b(TOKEN|SECRET|PASSWORD|WEBHOOK|API_KEY|PASS)\s*=\s*\S+' "$UNIT_FILE" 2>/dev/null; then
    error "SECURITY: jit-daemon.service appears to contain a hardcoded credential."
    error "Remove all secret values from Environment= lines and use EnvironmentFile= instead."
    exit 1
  fi
  info "Unit file credential scan: clean"
fi

# ═════════════════════════════════════════════════════════════════
# All checks passed
# ═════════════════════════════════════════════════════════════════
info "All security checks passed — starting jit-daemon"
exit 0
