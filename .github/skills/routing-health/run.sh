#!/usr/bin/env bash
# routing-health/run.sh — Quick runner for routing-health skill
# Usage: bash .github/skills/routing-health/run.sh [--quick | --deep | --report] [--backend=<name>] [--model=<name>]

set -e

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"

# Source shared libs if available
[[ -f "$REPO_ROOT/limbs/lib.sh" ]] && source "$REPO_ROOT/limbs/lib.sh"

# Parse arguments
MODE="quick"  # default
BACKEND=""
MODEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) MODE="quick" ;;
    --deep) MODE="deep" ;;
    --report) MODE="report" ;;
    --backend=*) BACKEND="${1#*=}" ;;
    --model=*) MODEL="${1#*=}" ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

# Export for SKILL.md to read
export MODE BACKEND MODEL REPO_ROOT SKILL_DIR

echo "🛣️ Jit Routing Health Check"
echo "Mode: $MODE"
[[ -n "$BACKEND" ]] && echo "Backend: $BACKEND"
[[ -n "$MODEL" ]] && echo "Model: $MODEL"
echo ""

# Execute the skill workflow
source "$SKILL_DIR/SKILL.md" 2>/dev/null || {
  # Fallback: show basic info
  echo "📋 routing-health skill"
  echo ""
  echo "SKILL.md not directly executable. To use this skill:"
  echo ""
  echo "  /routing-health              # Quick check"
  echo "  /routing-health --deep       # Deep scan with symmetry tests"
  echo "  /routing-health --report     # Generate HTML report"
  echo "  /routing-health --backend=openai    # Check specific backend"
  echo "  /routing-health --model=gpt-4       # Check specific model"
  echo ""
  echo "See .github/skills/routing-health/SKILL.md for full documentation."
}
