---
name: brave-search
description: "ค้นหาข้อมูลจากอินเทอร์เน็ตด้วย Brave Search API — ส่งผลลัพธ์ให้ MDES Ollama สรุปและวิเคราะห์ แล้วบันทึก Oracle. Triggers: brave search, search web, ค้นหา, search online, หาข้อมูล, web search, ค้นเว็บ"
argument-hint: "query สำหรับค้นหา เช่น 'latest Discord.js v14 breaking changes', 'วิธีใช้ puppeteer headless'"
---

# SKILL: brave-search — ค้นหาเว็บด้วย Brave + MDES Analysis 🔍

**Brave Search API → กรองผล → MDES Ollama สรุป → Oracle เก็บ**

## เมื่อไหร่ใช้ skill นี้

- ต้องการข้อมูลล่าสุดจากอินเทอร์เน็ต
- ค้นหา API docs, changelogs, tutorials
- วิจัยเพื่อ brainstorming หรือ planning
- ดึงข้อมูลก่อนตัดสินใจ technical

---

## Setup

```bash
# Brave Search API Key (ใส่ใน .env)
BRAVE_API_KEY="your-brave-api-key"
# ขอได้ที่: https://brave.com/search/api/
```

---

## Workflow

### Step 1 — ค้นหาด้วย Brave Search API

```bash
QUERY="$1"
NUM_RESULTS="${2:-5}"

# Brave Search API call
SEARCH_RESULTS=$(curl -s \
  "https://api.search.brave.com/res/v1/web/search?q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")&count=$NUM_RESULTS&search_lang=th&country=TH&freshness=pw" \
  -H "Accept: application/json" \
  -H "Accept-Encoding: gzip" \
  -H "X-Subscription-Token: $BRAVE_API_KEY")

# ตรวจสอบ response
if echo "$SEARCH_RESULTS" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'web' in d else 1)" 2>/dev/null; then
  echo "✅ Brave Search: พบผลลัพธ์"
else
  echo "⚠️ Brave Search ไม่ตอบสนอง — ใช้ fallback"
  # Fallback: DuckDuckGo scrape ผ่าน Chrome
  node -e "
const t = require('./hermes-discord/chrome-tools');
t.navigate('https://duckduckgo.com/?q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")', (e, i) => {
  console.log(JSON.stringify(i));
});
"
fi
```

### Step 2 — Parse ผลลัพธ์

```bash
# แยก titles, descriptions, URLs
PARSED_RESULTS=$(echo "$SEARCH_RESULTS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('web', {}).get('results', [])
for i, r in enumerate(results[:$NUM_RESULTS]):
    print(f\"{i+1}. [{r.get('title','')}]({r.get('url','')})\")
    print(f\"   {r.get('description','')[:150]}\")
    print()
")

echo "📊 Results:"
echo "$PARSED_RESULTS"
```

### Step 3 — อ่านหน้าเว็บสำคัญ (Optional Deep Read)

```bash
# อ่าน top result ด้วย Chrome เพื่อข้อมูลเพิ่มเติม
TOP_URL=$(echo "$SEARCH_RESULTS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('web', {}).get('results', [])
if results:
    print(results[0].get('url', ''))
" 2>/dev/null)

if [ -n "$TOP_URL" ]; then
  PAGE_CONTENT=$(node -e "
const t = require('./hermes-discord/chrome-tools');
t.runJS('$TOP_URL', 
  'document.body.innerText.substring(0, 3000)', 
  (e, r) => console.log(r));
" 2>/dev/null)
fi
```

### Step 4 — MDES Analysis

```bash
ANALYSIS=$(bash limbs/ollama-chain.sh call gemma4:26b "
ค้นหา: $QUERY

ผลลัพธ์จาก Brave Search:
$PARSED_RESULTS

$([ -n "$PAGE_CONTENT" ] && echo "เนื้อหาหน้าแรก: $PAGE_CONTENT")

สรุป:
1. คำตอบหลักสำหรับ: $QUERY
2. ข้อมูลสำคัญที่พบ (3-5 ข้อ)
3. Links ที่น่าสนใจที่สุด
4. สิ่งที่ยังต้องค้นหาเพิ่ม (ถ้ามี)

ตอบเป็นภาษาไทย กระชับ
")
```

### Step 5 — บันทึก Oracle

```bash
SEARCH_SLUG=$(echo "$QUERY" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-40)

bash limbs/oracle.sh learn \
  "search:$SEARCH_SLUG" \
  "Query: $QUERY\n\nResults:\n$PARSED_RESULTS\n\nAnalysis:\n$ANALYSIS" \
  "search,brave,$SEARCH_SLUG,$(date +%Y-%m-%d)"

echo ""
echo "═══════════════════════════"
echo "🔍 Brave Search: $QUERY"
echo "═══════════════════════════"
echo "$ANALYSIS"
echo ""
echo "📚 Oracle: search:$SEARCH_SLUG"
```

---

## Brave Search Parameters

| Parameter | ค่า | ความหมาย |
|-----------|-----|---------|
| `count` | 1-20 | จำนวนผลลัพธ์ |
| `search_lang` | `th`, `en` | ภาษาของผลลัพธ์ |
| `country` | `TH`, `US` | ประเทศ |
| `freshness` | `pd`, `pw`, `pm` | วัน/อาทิตย์/เดือน |
| `safesearch` | `off`, `moderate`, `strict` | ความปลอดภัย |

---

## Integration กับ Skills อื่น

```bash
# ค้น Brave แล้วระดมสมอง
brave-search "Discord bot Thai language features"
→ brainstorming "ไอเดียจาก web research"

# ค้น Brave แล้วเขียน plan
brave-search "puppeteer best practices 2026"  
→ writing-plans "implement Chrome DevTools"
```

---

## Discord Bot Usage

```
!AnuT1n brave-search Discord.js slash commands 2026
!AnuT1n search วิธีใช้ gemma4:26b สำหรับ Thai chatbot
```

---

## Fallback ถ้าไม่มี Brave API Key

```bash
# ใช้ SearXNG หรือ DuckDuckGo HTML
curl -sA "Mozilla/5.0" "https://html.duckduckgo.com/html/?q=$QUERY" \
  | python3 -c "
import sys, re
html = sys.stdin.read()
results = re.findall(r'<a class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)', html)
for url, title in results[:5]:
    print(f'- [{title}]({url})')
"
```
