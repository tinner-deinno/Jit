#!/usr/bin/env bash
# socialcrawl/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
QUERY="${*:-}"
[ -z "$QUERY" ] && { err "ระบุ: <platform> <query> — platforms: github, reddit, hn"; exit 1; }

step "📡 Social Crawl: $QUERY"
PLATFORM=$(echo "$QUERY" | awk '{print tolower($1)}')
REST=$(echo "$QUERY" | cut -d' ' -f2-)

_mdes_call() {
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'gemma4:26b','prompt':sys.stdin.read(),'stream':False}))" <<< "$1" 2>/dev/null)
  curl -sf --max-time 60 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo ""
}

DATA=""

case "$PLATFORM" in
  github|gh)
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$REST")
    RAW=$(curl -sf --max-time 15 \
      "https://api.github.com/search/repositories?q=$ENCODED&sort=updated&per_page=5" \
      -H "Accept: application/vnd.github+json" \
      ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} 2>/dev/null)
    DATA=$(echo "$RAW" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for r in d.get('items', [])[:5]:
  print(f\"⭐{r.get('stargazers_count',0)} [{r.get('full_name','')}]({r.get('html_url','')}) — {r.get('description','')[:100]}\")
" 2>/dev/null)
    ;;
  reddit|r/)
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$REST")
    RAW=$(curl -sA "Jit-Bot/1.0" --max-time 15 \
      "https://www.reddit.com/search.json?q=$ENCODED&sort=hot&limit=5&t=week" 2>/dev/null)
    DATA=$(echo "$RAW" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for p in d.get('data',{}).get('children',[])[:5]:
  r = p['data']
  print(f\"[{r.get('score',0)}↑] {r.get('title','')} — https://reddit.com{r.get('permalink','')}\")
" 2>/dev/null)
    ;;
  hn|hackernews|hacker)
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$REST")
    RAW=$(curl -sf --max-time 15 \
      "https://hn.algolia.com/api/v1/search?query=$ENCODED&tags=story&hitsPerPage=5" 2>/dev/null)
    DATA=$(echo "$RAW" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for h in d.get('hits', [])[:5]:
  print(f\"[{h.get('points',0)}pts] {h.get('title','')} — https://news.ycombinator.com/item?id={h.get('objectID','')}\")
" 2>/dev/null)
    ;;
  *)
    # ถ้าไม่ระบุ platform ให้ search ทั้ง 3
    ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
    DATA="GitHub: $(curl -sf "https://api.github.com/search/repositories?q=$ENCODED&per_page=3" | python3 -c "import json,sys; [print(r['full_name']) for r in json.load(sys.stdin).get('items',[])[:3]]" 2>/dev/null)"
    DATA="$DATA\nHN: $(curl -sf "https://hn.algolia.com/api/v1/search?query=$ENCODED&hitsPerPage=3" | python3 -c "import json,sys; [print(h['title'][:80]) for h in json.load(sys.stdin).get('hits',[])[:3]]" 2>/dev/null)"
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 $PLATFORM Results: $REST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${DATA:-ไม่พบข้อมูล}"

# MDES Analysis
echo ""
ANALYSIS=$(_mdes_call "วิเคราะห์ผล social media search:
Platform: $PLATFORM
Query: $REST

ข้อมูล:
$DATA

สรุป key insights สำหรับ Jit development ภาษาไทย (3-5 ข้อ)" 2>/dev/null || echo "")

[ -n "$ANALYSIS" ] && echo -e "\n🧠 Analysis:\n$ANALYSIS"

SLUG=$(echo "$QUERY" | tr ' ' '-' | cut -c1-40)
bash "$JIT_ROOT/limbs/oracle.sh" learn "social:$SLUG" "$DATA\n$ANALYSIS" "social,$PLATFORM,$SLUG" 2>/dev/null || true
ok "Saved — Oracle: social:$SLUG"
