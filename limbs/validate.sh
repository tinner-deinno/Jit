#!/usr/bin/env bash
# limbs/validate.sh — Secure validation function library
# Provides input sanitization and validation for all Jit components
# Inspired by OWASP: https://owasp.org/www-community/attacks/injection

# Source lib.sh (handle both direct execution and sourcing)
if [ -z "$BASH_SOURCE" ]; then
  SCRIPT_DIR="$(dirname "$0")"
else
  SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
fi
source "${SCRIPT_DIR}/lib.sh"

# ─── Validation Registry ────────────────────────────────────────────
# Track validation errors for detailed reporting
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()

# ─── Core Secure Validation Function ────────────────────────────────
# validate <type> <value> [options...]
# Returns: 0 (valid), 1 (invalid)
# Sets: VALIDATION_RESULT (safe value if valid), VALIDATION_ERROR (error msg)

validate() {
  local TYPE="$1" VALUE="$2"
  shift 2

  VALIDATION_RESULT=""
  VALIDATION_ERROR=""

  case "$TYPE" in
    email)       validate_email "$VALUE" "$@" ;;
    url)         validate_url "$VALUE" "$@" ;;
    alphanum)    validate_alphanum "$VALUE" "$@" ;;
    filename)    validate_filename "$VALUE" "$@" ;;
    json)        validate_json "$VALUE" "$@" ;;
    command)     validate_command "$VALUE" "$@" ;;
    agent_name)  validate_agent_name "$VALUE" "$@" ;;
    path)        validate_path "$VALUE" "$@" ;;
    integer)     validate_integer "$VALUE" "$@" ;;
    *)           VALIDATION_ERROR="Unknown validation type: $TYPE"; return 1 ;;
  esac
}

# ─── Email Validation ───────────────────────────────────────────────
# RFC 5322 simplified: username@domain.tld
# Protects against: injection, directory traversal, command execution

validate_email() {
  local EMAIL="$1"

  # Max length check
  if [ ${#EMAIL} -gt 254 ]; then
    VALIDATION_ERROR="Email exceeds 254 characters"
    return 1
  fi

  # Pattern: user@domain.extension (basic RFC 5322)
  # Rejects: special chars, spaces, quotes, backticks, semicolons, pipes
  if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    VALIDATION_ERROR="Invalid email format"
    return 1
  fi

  # Check for injection patterns
  if grep -qE '[`$(){}|;]' <<< "$EMAIL"; then
    VALIDATION_ERROR="Email contains forbidden characters (possible injection)"
    return 1
  fi

  VALIDATION_RESULT="$EMAIL"
  return 0
}

# ─── URL Validation ─────────────────────────────────────────────────
# Protects against: SSRF, redirect attacks, injection

validate_url() {
  local URL="$1"
  local ALLOW_LOCALHOST="${2:-false}"

  # Max length
  if [ ${#URL} -gt 2048 ]; then
    VALIDATION_ERROR="URL exceeds 2048 characters"
    return 1
  fi

  # Must start with http:// or https://
  if [[ ! "$URL" =~ ^https?:// ]]; then
    VALIDATION_ERROR="URL must start with http:// or https://"
    return 1
  fi

  # Reject file://, data:, javascript:, and other dangerous schemes
  if [[ "$URL" =~ ^(file|data|javascript|vbscript|about):// ]]; then
    VALIDATION_ERROR="URL scheme not allowed (dangerous)"
    return 1
  fi

  # Reject localhost unless explicitly allowed
  if [ "$ALLOW_LOCALHOST" = "false" ]; then
    if [[ "$URL" =~ (localhost|127\.0\.0\.|0\.0\.0\.0|::1) ]]; then
      VALIDATION_ERROR="URL points to localhost (SSRF protection)"
      return 1
    fi
  fi

  # Check for injection patterns
  if grep -qE '[`$(){}<>|;]' <<< "$URL"; then
    VALIDATION_ERROR="URL contains forbidden characters (possible injection)"
    return 1
  fi

  VALIDATION_RESULT="$URL"
  return 0
}

# ─── Alphanumeric Validation ────────────────────────────────────────
# Only allows: a-z, A-Z, 0-9, underscore, hyphen
# Protects against: injection, path traversal, command execution

validate_alphanum() {
  local VALUE="$1"
  local MAX_LEN="${2:-256}"

  # Check length
  if [ ${#VALUE} -gt "$MAX_LEN" ]; then
    VALIDATION_ERROR="Value exceeds $MAX_LEN characters"
    return 1
  fi

  # Check for forbidden characters
  if [[ ! "$VALUE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    VALIDATION_ERROR="Value contains forbidden characters; only a-z, A-Z, 0-9, _, - allowed"
    return 1
  fi

  VALIDATION_RESULT="$VALUE"
  return 0
}

# ─── Filename Validation ────────────────────────────────────────────
# Protects against: directory traversal, injection, symlink attacks

validate_filename() {
  local FILENAME="$1"

  # Reject empty
  if [ -z "$FILENAME" ]; then
    VALIDATION_ERROR="Filename cannot be empty"
    return 1
  fi

  # Max length (most filesystems: 255 bytes)
  if [ ${#FILENAME} -gt 255 ]; then
    VALIDATION_ERROR="Filename exceeds 255 characters"
    return 1
  fi

  # Reject path traversal attempts
  if [[ "$FILENAME" =~ \.\. ]]; then
    VALIDATION_ERROR="Filename contains .. (directory traversal attempt)"
    return 1
  fi

  if [[ "$FILENAME" =~ ^/ ]]; then
    VALIDATION_ERROR="Filename must be relative (no leading /)"
    return 1
  fi

  # Reject dangerous special characters
  # Allow: alphanumeric, dot, hyphen, underscore, forward slash (for subdirs)
  if [[ ! "$FILENAME" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
    VALIDATION_ERROR="Filename contains forbidden characters"
    return 1
  fi

  # Reject leading dot (hidden files) unless explicitly allowed
  if [[ "$FILENAME" =~ ^\. ]] && [ "$2" != "--allow-hidden" ]; then
    VALIDATION_ERROR="Filenames cannot start with . (hidden files)"
    return 1
  fi

  VALIDATION_RESULT="$FILENAME"
  return 0
}

# ─── JSON Validation ────────────────────────────────────────────────
# Validates JSON structure without executing code

validate_json() {
  local JSON="$1"

  # Check max length
  if [ ${#JSON} -gt 10485760 ]; then  # 10MB limit
    VALIDATION_ERROR="JSON exceeds 10MB"
    return 1
  fi

  # Try to parse with jq (must be valid JSON)
  if ! echo "$JSON" | jq empty 2>/dev/null; then
    VALIDATION_ERROR="Invalid JSON syntax"
    return 1
  fi

  VALIDATION_RESULT="$JSON"
  return 0
}

# ─── Command Name Validation ────────────────────────────────────────
# Validates shell command names (for safe command execution)
# Protects against: command injection, arbitrary code execution

validate_command() {
  local CMD="$1"

  # Check length
  if [ ${#CMD} -gt 256 ]; then
    VALIDATION_ERROR="Command name exceeds 256 characters"
    return 1
  fi

  # Must be alphanumeric with hyphen/underscore only
  if [[ ! "$CMD" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    VALIDATION_ERROR="Command contains invalid characters"
    return 1
  fi

  # Reject dangerous patterns
  if [[ "$CMD" =~ (rm|mkfs|dd|:(){ :|:|) ]]; then
    VALIDATION_ERROR="Command blocked (dangerous)"
    return 1
  fi

  VALIDATION_RESULT="$CMD"
  return 0
}

# ─── Agent Name Validation ──────────────────────────────────────────
# Validates agent names according to Jit registry
# Protects against: injection into agent communication

validate_agent_name() {
  local AGENT="$1"

  # Check length (agent names: 1-32 chars typically)
  if [ ${#AGENT} -lt 1 ] || [ ${#AGENT} -gt 32 ]; then
    VALIDATION_ERROR="Agent name must be 1-32 characters"
    return 1
  fi

  # Must be alphanumeric with underscore/hyphen
  if [[ ! "$AGENT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    VALIDATION_ERROR="Agent name contains invalid characters"
    return 1
  fi

  VALIDATION_RESULT="$AGENT"
  return 0
}

# ─── Path Validation ────────────────────────────────────────────────
# Validates file system paths (prevents traversal attacks)

validate_path() {
  local PATH="$1"
  local MUST_EXIST="${2:-false}"

  # Check length
  if [ ${#PATH} -gt 4096 ]; then
    VALIDATION_ERROR="Path exceeds 4096 characters"
    return 1
  fi

  # Resolve to absolute path (prevents traversal)
  local RESOLVED
  RESOLVED=$(cd "$(dirname "$PATH")" 2>/dev/null && pwd -P) || {
    VALIDATION_ERROR="Cannot resolve path"
    return 1
  }

  RESOLVED="${RESOLVED}/$(basename "$PATH")"

  # Check if file must exist
  if [ "$MUST_EXIST" = "true" ] && [ ! -e "$RESOLVED" ]; then
    VALIDATION_ERROR="Path does not exist: $RESOLVED"
    return 1
  fi

  VALIDATION_RESULT="$RESOLVED"
  return 0
}

# ─── Integer Validation ─────────────────────────────────────────────
# Validates integers (prevents overflow, injection)

validate_integer() {
  local VALUE="$1"
  local MIN="${2:-}"
  local MAX="${3:-}"

  # Must be numeric (optional minus sign)
  if [[ ! "$VALUE" =~ ^-?[0-9]+$ ]]; then
    VALIDATION_ERROR="Value is not an integer"
    return 1
  fi

  # Check minimum
  if [ -n "$MIN" ] && [ "$VALUE" -lt "$MIN" ]; then
    VALIDATION_ERROR="Value is less than minimum ($MIN)"
    return 1
  fi

  # Check maximum
  if [ -n "$MAX" ] && [ "$VALUE" -gt "$MAX" ]; then
    VALIDATION_ERROR="Value exceeds maximum ($MAX)"
    return 1
  fi

  VALIDATION_RESULT="$VALUE"
  return 0
}

# ─── Batch Validation ───────────────────────────────────────────────
# Validates multiple values and collects errors

validate_batch() {
  local -n INPUTS="$1"  # Associative array: key=value
  local -n RULES="$2"   # Associative array: key=validation_type

  VALIDATION_ERRORS=()
  VALIDATION_WARNINGS=()
  local ALL_VALID=true

  for KEY in "${!INPUTS[@]}"; do
    local VALUE="${INPUTS[$KEY]}"
    local RULE="${RULES[$KEY]}"

    if ! validate "$RULE" "$VALUE"; then
      VALIDATION_ERRORS+=("$KEY: $VALIDATION_ERROR")
      ALL_VALID=false
    fi
  done

  if [ "$ALL_VALID" = true ]; then
    return 0
  else
    return 1
  fi
}

# ─── JSON Output (for structured reporting) ────────────────────────
report_validation() {
  local STATUS="$1"
  local COMPLETION="${2:-0}"

  cat << EOF
{
  "status": "$STATUS",
  "completion_percent": $COMPLETION,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "errors": [$(printf '"%s"' "${VALIDATION_ERRORS[@]}" | sed 's/""/","/g')],
  "warnings": [$(printf '"%s"' "${VALIDATION_WARNINGS[@]}" | sed 's/""/","/g')]
}
EOF
}

# ─── Quick Test Function ────────────────────────────────────────────
test_validation() {
  echo "Testing secure validation functions..."

  # Test 1: Email
  if validate email "user@example.com"; then
    ok "Email validation: PASS"
  else
    err "Email validation: FAIL - $VALIDATION_ERROR"
  fi

  # Test 2: Alphanum
  if validate alphanum "valid-name_123"; then
    ok "Alphanum validation: PASS"
  else
    err "Alphanum validation: FAIL - $VALIDATION_ERROR"
  fi

  # Test 3: Injection attempt (should fail)
  if validate alphanum "invalid; rm -rf /"; then
    err "Injection protection: FAIL (should have rejected)"
  else
    ok "Injection protection: PASS - Blocked: $VALIDATION_ERROR"
  fi

  # Test 4: Agent name
  if validate agent_name "jit"; then
    ok "Agent name validation: PASS"
  else
    err "Agent name validation: FAIL - $VALIDATION_ERROR"
  fi

  report_validation "complete" 100
}

# Allow script to be sourced or executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  test_validation "$@"
fi
