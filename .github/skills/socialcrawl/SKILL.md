---
name: socialcrawl
description: "ดึงข้อมูลจาก social media (Twitter/X, GitHub, Reddit, LinkedIn) ด้วย Chrome DevTools + MDES analysis — ติดตาม trends, mentions, activity ที่เกี่ยวข้อง. Triggers: socialcrawl, social crawl, monitor social, twitter search, github activity, reddit search, ติดตาม social media"
argument-hint: "platform + query เช่น 'twitter #discordbot', 'github innova-bot issues', 'reddit puppeteer'"
---

# SKILL: socialcrawl — ดึงข้อมูล Social Media ด้วย Chrome + MDES 📡

**Chrome headless → social platforms → qwen3-vl:32b สรุปข้อมูล → Oracle trends**

## เมื่อไหร่ใช้ skill นี้

- ติดตาม mentions, trends ที่เกี่ยวข้องกับ Jit/innova/MDES
- Monitor GitHub issues, PRs, discussions
- ค้นหา Reddit discussions เกี่ยวกับ tech ที่ใช้
- วิเคราะห์ community sentiment

---

## Supported Platforms

| Platform | ข้อมูลที่ดึงได้ | Method |
|----------|--------------|--------|
| 🐙 **GitHub** | Issues, PRs, releases, commits | API + Chrome |
| 🐦 **Twitter/X** | Tweets, trends, mentions | Chrome scrape |
| 🟠 **Reddit** | Posts, comments, scores | Reddit JSON API |
| 💼 **LinkedIn** | Posts (public only) | Chrome scrape |
| 📰 **Hacker News** | Stories, comments | Algolia API |

---

## Workflow

### GitHub (Best Support — Official API)

```bash
QUERY="$1"   # เช่น "innova-bot issues", "discord.js v14 new"
PLATFORM=$(echo "$QUERY" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')

# GitHub API — ไม่ต้องการ auth สำหรับ public
if [[ "$PLATFORM" == "github" || "$QUERY" =~ github ]]; then
  REPO=$(echo "$QUERY" | grep -oP '[\w-]+/[\w-]+' | head -1)
  SEARCH_TERM=$(echo "$QUERY" | sed "s|github||;s|$REPO||" | xargs)
  
  # Issues
  GH_ISSUES=$(curl -s \
    "https://api.github.com/search/issues?q=$SEARCH_TERM+repo:$REPO&sort=updated&per_page=5" \
    -H "Accept: application/vnd.github+json" \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"})
  
  # Releases
  GH_RELEASES=$(curl -s \
    "https://api.github.com/repos/$REPO/releases?per_page=3")
    
  echo "$GH_ISSUES" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', [])[:5]:
    print(f\"#{item['number']}: {item['title']} [{item['state']}] — {item['html_url']}\")
"
fi
```

### Reddit (JSON API)

```bash
if [[ "$QUERY" =~ reddit ]] || [[ "$PLATFORM" == "reddit" ]]; then
  SUBREDDIT=$(echo "$QUERY" | grep -oP 'r/[\w]+' | head -1 | tr -d 'r/')
  SEARCH=$(echo "$QUERY" | sed "s|reddit||;s|r/$SUBREDDIT||" | xargs)
  
  REDDIT_URL="https://www.reddit.com"
  [ -n "$SUBREDDIT" ] && REDDIT_URL="$REDDIT_URL/r/$SUBREDDIT"
  REDDIT_URL="$REDDIT_URL/search.json?q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$SEARCH")&sort=hot&limit=5&t=week"
  
  REDDIT_DATA=$(curl -sA "Mozilla/5.0 (compatible; Jit-Bot/1.0)" "$REDDIT_URL")
  
  echo "$REDDIT_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
posts = data.get('data', {}).get('children', [])
for p in posts[:5]:
    d = p['data']
    print(f\"[{d.get('score',0)}↑] {d.get('title','')} — https://reddit.com{d.get('permalink','')}\")
"
fi
```

### Hacker News (Algolia API)

```bash
if [[ "$QUERY" =~ "hacker news" ]] || [[ "$QUERY" =~ "hn" ]]; then
  SEARCH=$(echo "$QUERY" | sed "s|hacker news||;s|hn ||" | xargs)
  
  HN_DATA=$(curl -s \
    "https://hn.algolia.com/api/v1/search?query=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$SEARCH")&tags=story&numericFilters=created_at_i>$(date -d '7 days ago' +%s 2>/dev/null || date -v-7d +%s)&hitsPerPage=5")
  
  echo "$HN_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for h in data.get('hits', [])[:5]:
    print(f\"[{h.get('points',0)}pts] {h.get('title','')} — https://news.ycombinator.com/item?id={h.get('objectID','')}\")
"
fi
```

### Twitter/X + LinkedIn (Chrome Scrape)

```bash
if [[ "$QUERY" =~ twitter ]] || [[ "$QUERY" =~ "x.com" ]]; then
  SEARCH_TERM=$(echo "$QUERY" | sed "s|twitter||" | xargs)
  
  # ใช้ Chrome headless
  TWITTER_DATA=$(node -e "
const t = require('./hermes-discord/chrome-tools');
const searchUrl = 'https://nitter.privacydev.net/search?q=' + encodeURIComponent('$SEARCH_TERM') + '&f=tweets';
t.runJS(searchUrl,
  'Array.from(document.querySelectorAll(\".tweet-content\")).slice(0,5).map(e => e.innerText).join(\"|||\")',
  (e, r) => console.log(r));
" 2>/dev/null)

  # Parse tweets
  echo "$TWITTER_DATA" | tr '|||' '\n' | head -5
fi
```

### Step — MDES Analysis

```bash
ALL_DATA="$GH_ISSUES\n$REDDIT_DATA\n$HN_DATA\n$TWITTER_DATA"

ANALYSIS=$(bash limbs/ollama-chain.sh call gemma4:26b "
วิเคราะห์ social media data เกี่ยวกับ: $QUERY

ข้อมูลที่รวบรวม:
$ALL_DATA

สรุป:
1. Trending topics ที่เกี่ยวข้อง
2. Community sentiment (positive/negative/neutral)
3. Issues หรือ problems ที่พบบ่อย
4. ข้อมูลที่น่าสนใจสำหรับ Jit development
5. Action items (ถ้ามี)

ตอบเป็นภาษาไทย
")

# บันทึก Oracle
CRAWL_SLUG=$(echo "$QUERY" | tr ' ' '-' | cut -c1-40)
bash limbs/oracle.sh learn \
  "social:$CRAWL_SLUG" \
  "$ANALYSIS\n\nRaw data summary: $ALL_DATA" \
  "social,crawl,$CRAWL_SLUG,$(date +%Y-%m-%d)"

echo "$ANALYSIS"
```

---

## Rate Limits & Ethics

| Platform | Limit | หมายเหตุ |
|----------|-------|---------|
| GitHub API | 60/hr (unauth) / 5000/hr (auth) | ใส่ `GITHUB_TOKEN` ใน .env |
| Reddit | 60/min | user-agent จำเป็น |
| HN Algolia | ไม่จำกัด | Free public API |
| Twitter | หลีกเลี่ยง scrape | ใช้ Nitter mirror |

---

## Discord Bot Usage

```
!AnuT1n socialcrawl github Soul-Brews-Studio/arra-oracle-v3 issues
!AnuT1n socialcrawl reddit r/discordapp bot Thai language
!AnuT1n socialcrawl hn chromium puppeteer
```
