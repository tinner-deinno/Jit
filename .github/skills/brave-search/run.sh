#!/usr/bin/env bash
# brave-search/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
QUERY="${*:-}"
[ -z "$QUERY" ] && { err "ระบุ search query"; exit 1; }

step "🔍 Brave Search: $QUERY"

_mdes_call() {
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'gemma4:26b','prompt':sys.stdin.read(),'stream':False}))" <<< "$1" 2>/dev/null)
  curl -sf --max-time 60 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo ""
}

RESULTS=""

# Method 1: Brave Search API
if [ -n "${BRAVE_API_KEY:-}" ]; then
  ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
  RAW=$(curl -sf --max-time 15 \
    "https://api.search.brave.com/res/v1/web/search?q=$ENCODED&count=5&search_lang=th&country=TH" \
    -H "Accept: application/json" \
    -H "Accept-Encoding: identity" \
    -H "X-Subscription-Token: $BRAVE_API_KEY" 2>/dev/null)
  
  RESULTS=$(echo "$RAW" | python3 -c "
import json, sys
try:
  data = json.load(sys.stdin)
  results = data.get('web', {}).get('results', [])
  for i, r in enumerate(results[:5], 1):
    print(f'{i}. **{r.get(\"title\",\"\")}**')
    print(f'   {r.get(\"description\",\"\")[:150]}')
    print(f'   {r.get(\"url\",\"\")}')
    print()
except: pass
" 2>/dev/null)
fi

# Fallback: DuckDuckGo
if [ -z "$RESULTS" ]; then
  info "Brave API unavailable — using DuckDuckGo"
  ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
  DDG_RAW=$(curl -sA "Mozilla/5.0" --max-time 15 "https://html.duckduckgo.com/html/?q=$ENCODED" 2>/dev/null)
  RESULTS=$(echo "$DDG_RAW" | python3 -c "
import sys, re
html = sys.stdin.read()
links = re.findall(r'class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)', html)
descs = re.findall(r'class=\"result__snippet\"[^>]*>([^<]+)', html)
for i, (url, title) in enumerate(links[:5]):
  desc = descs[i] if i < len(descs) else ''
  print(f'{i+1}. **{title.strip()}**')
  print(f'   {desc.strip()[:150]}')
  print(f'   {url}')
  print()
" 2>/dev/null)
fi

[ -z "$RESULTS" ] && RESULTS="ไม่พบผลลัพธ์"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Search Results: $QUERY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$RESULTS"

# MDES Analysis
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧠 AI Analysis:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ANALYSIS=$(_mdes_call "ค้นหา: $QUERY

ผลลัพธ์:
$RESULTS

สรุป:
1. คำตอบหลักสำหรับ: $QUERY
2. Key insights 3-5 ข้อ
3. Relevance สำหรับ Jit development

ภาษาไทย กระชับ")

echo "$ANALYSIS"

SLUG=$(echo "$QUERY" | tr ' ' '-' | cut -c1-40)
bash "$JIT_ROOT/limbs/oracle.sh" learn "search:$SLUG" "Query: $QUERY\n$RESULTS\nAnalysis: $ANALYSIS" "search,$SLUG" 2>/dev/null || true
echo ""
ok "Saved — Oracle: search:$SLUG"
