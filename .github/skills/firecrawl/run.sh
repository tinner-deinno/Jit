#!/usr/bin/env bash
# firecrawl/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
URL="${1:-}"
TASK="${2:-สรุปสาระสำคัญ}"
[ -z "$URL" ] && { err "ระบุ URL"; exit 1; }

step "🕷️ Firecrawl: $URL"
step "   Task: $TASK"

_mdes_call() {
  local MODEL="${1:-gemma4:26b}" PROMPT="$2"
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.stdin.read(),'stream':False}))" <<< "$PROMPT" 2>/dev/null)
  curl -sf --max-time 90 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo ""
}

CONTENT=""

# Method 1: Firecrawl API
if [ -n "${FIRECRAWL_API_KEY:-}" ]; then
  step "  Using Firecrawl API..."
  FC_RAW=$(curl -sf --max-time 30 -X POST "https://api.firecrawl.dev/v1/scrape" \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"$URL\",\"formats\":[\"markdown\"],\"onlyMainContent\":true}" 2>/dev/null)
  
  CONTENT=$(echo "$FC_RAW" | python3 -c "
import json, sys
try:
  d = json.load(sys.stdin)
  if d.get('success'):
    print(d.get('data', {}).get('markdown', '')[:6000])
except: pass
" 2>/dev/null)
  [ -n "$CONTENT" ] && ok "Firecrawl: $(echo "$CONTENT" | wc -c) chars"
fi

# Method 2: Chrome DevTools
if [ -z "$CONTENT" ] && [ -f "$JIT_ROOT/hermes-discord/chrome-tools.js" ] && command -v node &>/dev/null; then
  step "  Using Chrome DevTools..."
  CONTENT=$(node -e "
const t = require('$JIT_ROOT/hermes-discord/chrome-tools');
t.runJS('$URL',
  \`(function(){
    ['nav','footer','header','aside','script','style','.ad','.cookie-banner'].forEach(s=>{
      document.querySelectorAll(s).forEach(e=>e.remove());
    });
    const m = document.querySelector('main,article,[role=main],.content,.markdown') || document.body;
    return m.innerText.substring(0,5000);
  })()\`,
  (e,r)=>{ if(!e) process.stdout.write(r||''); });
" 2>/dev/null || echo "")
  [ -n "$CONTENT" ] && ok "Chrome: $(echo "$CONTENT" | wc -c) chars"
fi

# Method 3: curl + html strip
if [ -z "$CONTENT" ]; then
  step "  Using curl fallback..."
  CONTENT=$(curl -sA "Mozilla/5.0" --max-time 15 "$URL" 2>/dev/null | python3 -c "
import sys, re, html as h
text = sys.stdin.read()
text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
text = re.sub(r'<[^>]+>', ' ', text)
text = h.unescape(text)
text = re.sub(r'\s+', ' ', text).strip()[:4000]
print(text)
" 2>/dev/null)
  [ -n "$CONTENT" ] && ok "curl: $(echo "$CONTENT" | wc -c) chars"
fi

[ -z "$CONTENT" ] && CONTENT="ไม่สามารถดึงเนื้อหาจาก $URL ได้"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Choose model based on task
MODEL="gemma4:26b"
echo "$TASK" | grep -qiE "code|extract|json|table|ดึง" && MODEL="qwen2.5-coder:32b"

ANALYSIS=$(_mdes_call "$MODEL" "URL: $URL
Task: $TASK

เนื้อหา:
$CONTENT

ทำ task ต่อไปนี้: $TASK

ตอบเป็นภาษาไทย ถ้าหน้าเว็บเป็นภาษาอื่น")

echo "$ANALYSIS"

SLUG=$(echo "$URL" | sed 's|https*://||;s|[/.]|-|g' | cut -c1-50)
bash "$JIT_ROOT/limbs/oracle.sh" learn "crawl:$SLUG" "URL: $URL\nTask: $TASK\n$ANALYSIS" "crawl,$SLUG" 2>/dev/null || true
echo ""
ok "Saved — Oracle: crawl:$SLUG"
