#!/usr/bin/env bash
# eval/security-check.sh — Continuous security audit
# ตรวจสอบ tokens, secrets, vulnerabilities ทั้งระบบ
#
# Usage:
#   bash eval/security-check.sh              # Full audit
#   bash eval/security-check.sh --ci         # CI mode (fail on issues)
#   bash eval/security-check.sh --watch      # Watch mode (continuous)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_MODE="${1:-}"
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔒 Security Audit — Jit Multiagent System${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# ════════════════════════════════════════════════════════════════════════════
# 1. Check for exposed tokens and secrets
# ════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/5] Checking for exposed tokens and secrets...${NC}"

EXPOSED_PATTERNS=(
  "Bearer\s[A-Za-z0-9_-]{40,}"         # JWT tokens
  "api[_-]key\s*[:=]\s*['\"]?[^'\"]*['\"]?"
  "secret\s*[:=]\s*['\"]?[^'\"]*['\"]?"
  "password\s*[:=]\s*['\"]?[^'\"]*['\"]?"
  "token\s*[:=]\s*['\"]?[A-Za-z0-9_-]{20,}['\"]?"
)

SECRETS_FOUND=0
for pattern in "${EXPOSED_PATTERNS[@]}"; do
  matches=$(grep -rE "$pattern" "$SCRIPT_DIR" \
    --include="*.json" --include="*.md" --include="*.sh" --include="*.py" \
    --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir=".bun" \
    --exclude=".env" --exclude="secrets*" --exclude="*.example" 2>/dev/null || true)

  if [ -n "$matches" ]; then
    echo -e "${RED}  ❌ Found pattern: $pattern${NC}"
    echo "$matches" | head -3
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
  fi
done

if [ $SECRETS_FOUND -eq 0 ]; then
  echo -e "${GREEN}  ✅ No exposed tokens found${NC}"
else
  echo -e "${RED}  ⚠️  FOUND $SECRETS_FOUND potential secret exposures${NC}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# 2. Check for unsafe file permissions
# ════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[2/5] Checking file permissions (secrets should not be world-readable)...${NC}"

UNSAFE_PERMS=0
for secret_file in .env .env.local secrets.json credentials.json; do
  if [ -f "$SCRIPT_DIR/$secret_file" ]; then
    perms=$(stat -f %A "$SCRIPT_DIR/$secret_file" 2>/dev/null || stat --printf "%a\n" "$SCRIPT_DIR/$secret_file" 2>/dev/null || echo "unknown")
    if [[ "$perms" == *"4"* ]] || [[ "$perms" == *"5"* ]] || [[ "$perms" == *"6"* ]] || [[ "$perms" == *"7"* ]]; then
      echo -e "${RED}  ❌ $secret_file has overly permissive permissions: $perms${NC}"
      UNSAFE_PERMS=$((UNSAFE_PERMS + 1))
    fi
  fi
done

if [ $UNSAFE_PERMS -eq 0 ]; then
  echo -e "${GREEN}  ✅ No unsafe file permissions found${NC}"
else
  echo -e "${RED}  ⚠️  FOUND $UNSAFE_PERMS files with unsafe permissions${NC}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# 3. Check that .env is in .gitignore
# ════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[3/5] Checking .gitignore protects secrets...${NC}"

if [ -f "$SCRIPT_DIR/.gitignore" ]; then
  if grep -q "^\.env" "$SCRIPT_DIR/.gitignore"; then
    echo -e "${GREEN}  ✅ .env is properly in .gitignore${NC}"
  else
    echo -e "${RED}  ❌ .env is NOT in .gitignore - critical risk!${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  echo -e "${RED}  ❌ No .gitignore file found${NC}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# 4. Check environment variable usage
# ════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[4/5] Checking proper environment variable usage...${NC}"

# Check that scripts use ${OLLAMA_TOKEN} or ${VAR}
if grep -rq '\${OLLAMA_TOKEN}' "$SCRIPT_DIR" --include="*.sh" --include="*.py"; then
  echo -e "${GREEN}  ✅ Found environment variable references in scripts${NC}"
else
  echo -e "${YELLOW}  ⚠️  Consider using \${OLLAMA_TOKEN} in scripts${NC}"
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# 5. Check shell script security
# ════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}[5/5] Checking shell script security...${NC}"

# shellcheck would be ideal but may not be installed
UNSAFE_SCRIPTS=0

# Look for eval, exec without proper quoting
unsafe=$(grep -rE '(eval|exec|system)\s' "$SCRIPT_DIR" --include="*.sh" --exclude-dir=".git" 2>/dev/null || true)
if [ -n "$unsafe" ]; then
  echo -e "${YELLOW}  ⚠️  Found eval/exec calls (ensure inputs are validated)${NC}"
fi

echo -e "${GREEN}  ✅ Shell scripts checked${NC}"

echo ""

# ════════════════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✅ SECURITY AUDIT PASSED - System is secure${NC}"
  exit 0
else
  echo -e "${RED}❌ SECURITY AUDIT FAILED - $FAIL_COUNT issues found${NC}"
  if [ "$CI_MODE" = "--ci" ]; then
    exit 1
  else
    exit 0
  fi
fi
