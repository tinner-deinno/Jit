#!/usr/bin/env bash
# skill-creator/run.sh — สร้าง Jit skill ใหม่
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
SKILL_REQUEST="${*:-}"
[ -z "$SKILL_REQUEST" ] && { err "ระบุ: skill-name — description"; exit 1; }

SKILL_NAME=$(echo "$SKILL_REQUEST" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
TARGET="$JIT_ROOT/.github/skills/$SKILL_NAME"

step "🛠️ Creating skill: $SKILL_NAME"

_mdes_call() {
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'qwen2.5-coder:32b','prompt':sys.stdin.read(),'stream':False}))" <<< "$1" 2>/dev/null)
  curl -sf --max-time 120 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo ""
}

CONTENT=$(_mdes_call "สร้าง SKILL.md สำหรับ Jit multiagent system:

REQUEST: $SKILL_REQUEST

Jit stack: MDES Ollama (https://ollama.mdes-innova.online, model gemma4:26b), Oracle (http://localhost:47778), Organs (mouth.sh/ear.sh/eye.sh/hand.sh/nerve.sh), Bus (/tmp/manusat-bus/)

สร้าง SKILL.md ในรูปแบบ:
---
name: $SKILL_NAME
description: \"[Thai] Triggers: [keywords]\"
argument-hint: \"[hint]\"
---

# SKILL: $SKILL_NAME — [Thai title]

## เมื่อไหร่ใช้
[situations]

## MDES Model: [model + reason]

## Workflow
[step-by-step bash commands ที่รันได้จริง]

## ตัวอย่าง
[examples]

กฎ: ทุก step ต้องใช้ bash commands จาก /workspaces/Jit/ ที่รันได้จริง
")

if [ -z "$CONTENT" ]; then
  warn "AI ไม่ตอบสนอง — ใช้ template"
  CONTENT="---
name: $SKILL_NAME
description: \"$SKILL_REQUEST. Triggers: $SKILL_NAME\"
argument-hint: \"args for $SKILL_NAME\"
---

# SKILL: $SKILL_NAME

## เมื่อไหร่ใช้
$SKILL_REQUEST

## MDES Model: gemma4:26b

## Workflow

\`\`\`bash
bash limbs/ollama.sh think \"$SKILL_REQUEST\" \"Jit context\"
\`\`\`"
fi

mkdir -p "$TARGET"
echo "$CONTENT" > "$TARGET/SKILL.md"
ok "Created: $TARGET/SKILL.md"

# Register Oracle
bash "$JIT_ROOT/limbs/oracle.sh" learn "skill:$SKILL_NAME" "$CONTENT" "skill,$SKILL_NAME" 2>/dev/null || true

echo ""
echo "✅ Skill '$SKILL_NAME' created!"
echo "   Path: .github/skills/$SKILL_NAME/SKILL.md"
echo "   Add to bot.js case handler for: $SKILL_NAME"
