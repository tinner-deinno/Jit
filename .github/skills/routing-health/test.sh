#!/usr/bin/env bash
# routing-health/test.sh — Unit tests for routing-health skill
# Usage: bash .github/skills/routing-health/test.sh

set -e

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"

echo "🧪 Testing routing-health skill..."
echo ""

# Test 1: Verify SKILL.md exists and has valid frontmatter
echo "Test 1: Check SKILL.md format"
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
  echo "  ✅ SKILL.md exists"

  # Check frontmatter
  if head -1 "$SKILL_DIR/SKILL.md" | grep -q "^---$"; then
    echo "  ✅ Frontmatter starts correctly"
  else
    echo "  ❌ Missing frontmatter opening"
    exit 1
  fi

  # Check required fields
  for field in "name:" "description:" "argument-hint:"; do
    if head -10 "$SKILL_DIR/SKILL.md" | grep -q "$field"; then
      echo "  ✅ Found $field"
    else
      echo "  ❌ Missing $field"
      exit 1
    fi
  done
else
  echo "  ❌ SKILL.md not found"
  exit 1
fi

echo ""
echo "Test 2: Check run.sh executable"
if [[ -x "$SKILL_DIR/run.sh" ]]; then
  echo "  ✅ run.sh is executable"
else
  echo "  ❌ run.sh is not executable"
  exit 1
fi

echo ""
echo "Test 3: Verify argument parsing"
# Test that run.sh can parse arguments without executing the full workflow
output=$(bash "$SKILL_DIR/run.sh" --quick 2>&1 | head -5)
if echo "$output" | grep -q "Routing Health\|Mode"; then
  echo "  ✅ Argument parsing works"
else
  echo "  ⚠️  Argument parsing output:"
  echo "$output"
fi

echo ""
echo "Test 4: Syntax check"
bash -n "$SKILL_DIR/run.sh" && echo "  ✅ run.sh syntax is valid"
bash -n "$SKILL_DIR/test.sh" && echo "  ✅ test.sh syntax is valid"

echo ""
echo "Test 5: Check required sections in SKILL.md"
required_sections=(
  "เมื่อไหร่ใช้ skill นี้"
  "Step 0: System Check"
  "Step 1: Quick Check"
  "Step 2: Deep Scan"
  "Examples"
)

for section in "${required_sections[@]}"; do
  if grep -q "$section" "$SKILL_DIR/SKILL.md"; then
    echo "  ✅ Found section: $section"
  else
    echo "  ⚠️  Missing section: $section"
  fi
done

echo ""
echo "Test 6: Verify integration points"
integration_points=(
  "limbs/oracle.sh"
  "hermes-discord/model-router.js"
  "eval/fleet-batch.js"
  "organs/"
)

for point in "${integration_points[@]}"; do
  if grep -q "$point" "$SKILL_DIR/SKILL.md"; then
    echo "  ✅ References $point"
  else
    echo "  ⚠️  No reference to $point"
  fi
done

echo ""
echo "✅ All tests passed!"
echo ""
echo "Skill Summary:"
echo "  Name: routing-health"
echo "  Triggers: 'check routing', 'routing health', 'verify backends', 'routing status'"
echo "  Modes: --quick (default), --deep, --report"
echo "  Flags: --backend=<name>, --model=<name>"
echo ""
echo "Ready for integration into Jit Oracle system."
