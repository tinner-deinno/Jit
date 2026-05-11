#!/usr/bin/env bash
# ui-ux-pro-max/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
URL="${1:-}"
FOCUS="${2:-all dimensions}"
[ -z "$URL" ] && { err "ระบุ URL"; exit 1; }

step "🎨 UI/UX Analysis: $URL (focus: $FOCUS)"

_mdes_call() {
  local MODEL="$1" PROMPT="$2"
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.stdin.read(),'stream':False}))" <<< "$PROMPT" 2>/dev/null)
  curl -sf --max-time 90 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "(unavailable)"
}

# Get page HTML/text ด้วย curl (always available)
PAGE_CONTENT=$(curl -sA "Mozilla/5.0" --max-time 15 "$URL" 2>/dev/null | python3 -c "
import sys, re, html as h
text = sys.stdin.read()
# Extract title
title = re.search(r'<title[^>]*>([^<]+)', text)
title = title.group(1) if title else ''
# Get meta description
desc = re.search(r'<meta[^>]+name=[\"']description[\"'][^>]+content=[\"']([^\"']+)', text, re.I)
desc = desc.group(1) if desc else ''
# Extract text
text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
text = re.sub(r'<[^>]+>', ' ', text)
text = h.unescape(text)
text = re.sub(r'\s+', ' ', text).strip()[:3000]
print(f'Title: {title}\nDescription: {desc}\nContent: {text}')
" 2>/dev/null || echo "Could not fetch $URL")

# Chrome เพิ่มเติม (optional)
CHROME_DATA=""
if [ -f "$JIT_ROOT/hermes-discord/chrome-tools.js" ] && command -v node &>/dev/null; then
  CHROME_DATA=$(node -e "
const t = require('$JIT_ROOT/hermes-discord/chrome-tools');
t.analyzeUI('$URL', (e, a) => {
  if(e) { console.log(''); return; }
  console.log(JSON.stringify(a).substring(0, 1500));
});
" 2>/dev/null || echo "")
fi

ANALYSIS=$(_mdes_call "gemma4:26b" "คุณคือ Senior UI/UX Expert วิเคราะห์หน้าเว็บนี้:

URL: $URL
Focus: $FOCUS

ข้อมูลหน้าเว็บ:
$PAGE_CONTENT
${CHROME_DATA:+Chrome Analysis: $CHROME_DATA}

วิเคราะห์ทุกมิติ:
## 🎨 UI/UX Analysis: $URL

**Overall Score**: X/10

### Layout & Visual Hierarchy
### Color & Contrast (WCAG)
### Typography (Thai support)
### User Experience Flow
### Accessibility Issues
### Mobile Responsiveness

### 🚨 Critical Issues (ต้องแก้ทันที)
1.

### ⚡ Quick Wins (< 10 นาที)
- [ ]

### 💊 CSS Fix ที่สำคัญที่สุด
\`\`\`css
/* ... */
\`\`\`

ตอบเป็นภาษาไทย")

echo "$ANALYSIS"

SLUG=$(echo "$URL" | sed 's|https*://||;s|[/.]|-|g' | cut -c1-40)
bash "$JIT_ROOT/limbs/oracle.sh" learn "ui-analysis:$SLUG" "$ANALYSIS" "ui,ux,analysis,$SLUG" 2>/dev/null || true
echo ""
ok "Analysis saved — Oracle: ui-analysis:$SLUG"
