#!/bin/bash
# Syntax verification script for thai-route-audit skill

set -e

SKILL_MD="$(dirname "$0")/SKILL.md"
SKILL_DIR="$(dirname "$0")"
SKILL_NAME=$(basename "$SKILL_DIR")

echo "🔍 Verifying thai-route-audit skill syntax..."
echo ""

# 1. Check file exists
if [ ! -f "$SKILL_MD" ]; then
  echo "❌ SKILL.md not found at $SKILL_MD"
  exit 1
fi
echo "✓ SKILL.md exists"

# 2. Verify YAML frontmatter
FIRST_LINE=$(head -1 "$SKILL_MD")
if [ "$FIRST_LINE" != "---" ]; then
  echo "❌ Missing YAML frontmatter opening (---)"
  exit 1
fi
echo "✓ YAML frontmatter opening present"

# 3. Find closing delimiter
CLOSE_LINE=$(sed -n '2,10p' "$SKILL_MD" | grep -n "^---$" | head -1 | cut -d: -f1)
if [ -z "$CLOSE_LINE" ]; then
  echo "❌ Missing YAML frontmatter closing (---)"
  exit 1
fi
echo "✓ YAML frontmatter closing present (line $((CLOSE_LINE + 1)))"

# 4. Extract and validate frontmatter fields
NAME=$(grep "^name:" "$SKILL_MD" | head -1 | sed 's/^name: *//')
DESC=$(grep "^description:" "$SKILL_MD" | head -1 | sed 's/^description: *//')
ARG=$(grep "^argument-hint:" "$SKILL_MD" | head -1 | sed 's/^argument-hint: *//')

if [ -z "$NAME" ]; then
  echo "❌ Missing 'name' field in frontmatter"
  exit 1
fi
echo "✓ name field: $NAME"

if [ -z "$DESC" ]; then
  echo "❌ Missing 'description' field in frontmatter"
  exit 1
fi
echo "✓ description field present (${#DESC} chars)"

if [ -z "$ARG" ]; then
  echo "⚠ argument-hint field empty or missing (optional)"
else
  echo "✓ argument-hint field: $ARG"
fi

# 5. Verify name matches directory
if [ "$NAME" != "$SKILL_NAME" ]; then
  echo "❌ name field ($NAME) doesn't match directory ($SKILL_NAME)"
  exit 1
fi
echo "✓ name field matches directory name"

# 6. Check for critical sections
if ! grep -q "^## Usage" "$SKILL_MD"; then
  echo "❌ Missing '## Usage' section"
  exit 1
fi
echo "✓ Usage section present"

if ! grep -q "^## Mode" "$SKILL_MD"; then
  echo "⚠ No operation modes documented (optional)"
fi

# 7. Verify markdown syntax (basic check)
UNCLOSED_BACKTICKS=$(grep -o '```' "$SKILL_MD" | wc -l)
if [ $((UNCLOSED_BACKTICKS % 2)) -ne 0 ]; then
  echo "⚠ Possible unclosed code blocks"
fi
echo "✓ Code block count: $UNCLOSED_BACKTICKS (likely balanced)"

# 8. Check for common typos/issues
if grep -q "TODO\|FIXME\|XXX" "$SKILL_MD"; then
  echo "⚠ Found TODO/FIXME markers (should be resolved)"
fi

echo ""
echo "✅ Skill verification PASSED"
echo ""
echo "Skill Summary:"
echo "  Name:    $NAME"
echo "  Dir:     $SKILL_DIR"
echo "  Size:    $(wc -c < "$SKILL_MD") bytes"
echo "  Ready:   Yes"
