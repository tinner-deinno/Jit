---
name: firecrawl
description: "Crawl และ extract ข้อมูลจากเว็บไซต์ด้วย Firecrawl API + Chrome fallback — แปลง URL เป็น clean Markdown แล้วส่งให้ MDES Ollama วิเคราะห์. Triggers: firecrawl, crawl, scrape, extract content, ดึงข้อมูลเว็บ, read url, อ่านเว็บ"
argument-hint: "URL + optional context เช่น 'https://docs.discord.js.org สรุป slash commands', 'https://example.com extract pricing table'"
---

# SKILL: firecrawl — Extract Web Content + MDES Analysis 🕷️

**Firecrawl API (ถ้ามี) หรือ Chrome DevTools → clean Markdown → MDES Ollama วิเคราะห์ → Oracle เก็บ**

## เมื่อไหร่ใช้ skill นี้

- ต้องการอ่านเนื้อหาหน้าเว็บให้ MDES วิเคราะห์
- ดึง documentation, API reference, tutorials
- Extract structured data (tables, lists, code)
- ใช้ใน pipeline: brave-search → firecrawl → brainstorming

---

## Method Priority

```
1. Firecrawl API (best quality — ถ้ามี FIRECRAWL_API_KEY)
   ↓ fallback
2. Chrome DevTools headless (hermes-discord/chrome-tools.js)
   ↓ fallback  
3. curl + html-to-text (basic fallback)
```

---

## Workflow

### Step 1 — Extract Content

```bash
URL="$1"
TASK="${2:-สรุปสาระสำคัญ}"

CONTENT=""

# Method 1: Firecrawl API
if [ -n "$FIRECRAWL_API_KEY" ]; then
  FIRECRAWL_RESPONSE=$(curl -s -X POST "https://api.firecrawl.dev/v1/scrape" \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"url\": \"$URL\",
      \"formats\": [\"markdown\"],
      \"onlyMainContent\": true,
      \"removeBase64Images\": true,
      \"timeout\": 30000
    }")
  
  CONTENT=$(echo "$FIRECRAWL_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('success'):
    md = data.get('data', {}).get('markdown', '')
    print(md[:8000])  # limit
else:
    print('')
" 2>/dev/null)
  
  [ -n "$CONTENT" ] && echo "✅ Firecrawl: extracted $(echo "$CONTENT" | wc -c) chars"
fi

# Method 2: Chrome DevTools fallback
if [ -z "$CONTENT" ]; then
  CONTENT=$(node -e "
const t = require('./hermes-discord/chrome-tools');
t.runJS('$URL',
  \`(function() {
    // Remove nav, footer, ads, scripts
    ['nav','footer','header','aside','script','style','.ad','.sidebar','.cookie'].forEach(sel => {
      document.querySelectorAll(sel).forEach(el => el.remove());
    });
    // Get main content
    const main = document.querySelector('main,article,[role=main],.content,.docs-content') || document.body;
    return main.innerText.substring(0, 6000);
  })()\`,
  (e, r) => {
    if(e) { console.error(e.message); process.exit(1); }
    console.log(r);
  });
" 2>/dev/null)
  
  [ -n "$CONTENT" ] && echo "✅ Chrome: extracted $(echo "$CONTENT" | wc -c) chars"
fi

# Method 3: curl fallback
if [ -z "$CONTENT" ]; then
  CONTENT=$(curl -sA "Mozilla/5.0" "$URL" | python3 -c "
import sys, re, html
text = sys.stdin.read()
# Remove tags
text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)  
text = re.sub(r'<[^>]+>', ' ', text)
text = html.unescape(text)
text = re.sub(r'\s+', ' ', text).strip()
print(text[:4000])
")
  echo "⚠️ curl fallback: $(echo "$CONTENT" | wc -c) chars"
fi
```

### Step 2 — Smart Extraction

```bash
# ถ้า task บอกว่าต้องการ structured data
if echo "$TASK" | grep -qiE "table|price|list|extract|ดึง"; then
  # ใช้ qwen2.5-coder สำหรับ structured extraction
  EXTRACTION_MODEL="qwen2.5-coder:32b"
else
  EXTRACTION_MODEL="gemma4:26b"
fi

RESULT=$(bash limbs/ollama-chain.sh call "$EXTRACTION_MODEL" "
URL: $URL
Task: $TASK

เนื้อหาจากหน้าเว็บ:
$CONTENT

${TASK}

ตอบ:
1. สาระสำคัญที่เกี่ยวข้องกับ task
2. ข้อมูลที่ต้องการ
3. Links ที่สำคัญ (ถ้ามี)
4. สิ่งที่ยังต้องค้นหาเพิ่ม

ตอบเป็นภาษาไทย ถ้าหน้าเป็นภาษาอังกฤษ
")
```

### Step 3 — บันทึก Oracle

```bash
URL_SLUG=$(echo "$URL" | sed 's|https*://||;s|[/.]|-|g' | cut -c1-50)
TODAY=$(date +%Y-%m-%d)

bash limbs/oracle.sh learn \
  "crawl:$URL_SLUG:$TODAY" \
  "URL: $URL\nTask: $TASK\n\nResult:\n$RESULT\n\nRaw Content (first 1000):\n${CONTENT:0:1000}" \
  "crawl,web,$URL_SLUG,$TODAY"

echo ""
echo "═══════════════════════════"
echo "🕷️ Firecrawl: $URL"
echo "═══════════════════════════"
echo "$RESULT"
echo ""
echo "📚 Oracle: crawl:$URL_SLUG"
```

---

## Batch Crawl

```bash
# Crawl หลาย URL พร้อมกัน
URLS=(
  "https://discord.js.org/#/docs"
  "https://puppeteer.github.io/puppeteer/"
  "https://ollama.com/library"
)

for URL in "${URLS[@]}"; do
  echo "🕷️ Crawling: $URL"
  bash .github/skills/firecrawl/run.sh "$URL" "สรุปสาระสำคัญ" &
done
wait
echo "✅ Batch crawl complete"
```

---

## Integration Pipeline

```
brave-search "query"
    ↓ (top URLs)
firecrawl "url" "extract relevant info"
    ↓ (clean content)
brainstorming "ideas based on research"
    ↓
writing-plans "plan based on research"
```

---

## Discord Bot Usage

```
!AnuT1n firecrawl https://docs.discord.js.org อ่าน slash commands docs
!AnuT1n crawl https://ollama.com/library รายชื่อ models ทั้งหมด
```

---

## Firecrawl Setup (Optional)

```bash
# ขอ API key จาก https://firecrawl.dev (free tier: 500 credits/mo)
# เพิ่มใน hermes-discord/.env:
FIRECRAWL_API_KEY=fc-xxxxxxxxxxxxxxxx

# ทดสอบ
curl -X POST "https://api.firecrawl.dev/v1/scrape" \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  -d '{"url":"https://example.com","formats":["markdown"]}'
```
