#!/usr/bin/env bash
# frontend-design/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
BRIEF="${*:-}"
[ -z "$BRIEF" ] && { err "ระบุ design brief"; exit 1; }

step "🖥️ Frontend Design: $BRIEF"

_mdes_call() {
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'qwen2.5-coder:32b','prompt':sys.stdin.read(),'stream':False}))" <<< "$1" 2>/dev/null)
  curl -sf --max-time 120 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "(unavailable)"
}

# Oracle context สำหรับ similar components
ORACLE_CTX=$(bash "$JIT_ROOT/limbs/oracle.sh" search "frontend:$BRIEF" 2 2>/dev/null || true)

HTML=$(_mdes_call "คุณคือ Senior Frontend Developer

Brief: $BRIEF
${ORACLE_CTX:+Similar components: $ORACLE_CTX}

Jit context: dark theme, Thai language, agent status dashboard

สร้าง complete HTML file:
Requirements:
1. TailwindCSS CDN: <script src=\"https://cdn.tailwindcss.com\"></script>
2. Thai font: <link href=\"https://fonts.googleapis.com/css2?family=Sarabun:wght@300;400;500;700&display=swap\" rel=\"stylesheet\">
3. Dark theme (bg-gray-900, text-gray-100)
4. Responsive mobile-first
5. Clean semantic HTML5
6. Thai comments

ออก HTML ที่ใช้ได้ทันที ไม่มี explanation เพิ่มเติม
เริ่มด้วย <!DOCTYPE html> จบด้วย </html>")

# Save ไฟล์
SLUG=$(echo "$BRIEF" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
mkdir -p "$JIT_ROOT/src/ui"
OUTPUT="$JIT_ROOT/src/ui/${SLUG}.html"

echo "$HTML" > "$OUTPUT"
ok "Component saved: src/ui/${SLUG}.html"
echo ""

# Preview URL
echo "🌐 Preview: file://$OUTPUT"
echo ""

# Brief summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$HTML" | head -20
echo "... ($(echo "$HTML" | wc -l) lines total)"

bash "$JIT_ROOT/limbs/oracle.sh" learn "frontend:$SLUG" "$HTML" "frontend,ui,component,$SLUG" 2>/dev/null || true
