---
name: ui-ux-pro-max
description: "วิเคราะห์ UI/UX ระดับ Pro โดยใช้ Chrome DevTools + qwen3-vl:32b vision model — screenshot หน้าเว็บจริง, วิเคราะห์ layout/color/typography/accessibility, เสนอ improvements พร้อม CSS code. Triggers: ui analysis, ux review, ui-ux, วิเคราะห์ UI, ตรวจ UX, design review, ui check"
argument-hint: "URL ที่ต้องการวิเคราะห์ และ/หรือ focus area เช่น 'https://example.com accessibility'"
---

# SKILL: ui-ux-pro-max — วิเคราะห์ UI/UX ด้วย Vision AI + Chrome DevTools 🎨

**chrome-tools.js + qwen3-vl:32b screenshot → วิเคราะห์ทุกมิติ → CSS improvements ทันที**

## เมื่อไหร่ใช้ skill นี้

- ต้องการ audit UI/UX ของหน้าเว็บจริง
- ต้องการ feedback ด้าน accessibility, layout, color contrast
- ต้องการ CSS improvements พร้อม code
- รองรับ URL ทั้งภายนอกและ localhost

---

## Analysis Dimensions

| มิติ | ตรวจสอบ |
|------|--------|
| 📐 **Layout** | Grid/Flex structure, responsive, visual hierarchy |
| 🎨 **Color** | Contrast ratios (WCAG AA/AAA), palette harmony |
| 🔤 **Typography** | Font size, line-height, readability, Thai font support |
| ♿ **Accessibility** | ARIA labels, tab order, alt text, keyboard nav |
| ⚡ **Performance** | Image sizes, render-blocking, layout shifts |
| 📱 **Responsive** | Mobile breakpoints, viewport meta |
| 🧭 **UX Flow** | User journey clarity, CTA visibility, error states |

---

## Workflow

### Step 1 — Screenshot และ Inspect

```bash
URL="$1"
FOCUS="${2:-all}"

# ใช้ chrome-tools.js (ต้องมี puppeteer)
node hermes-discord/chrome-tools.js --screenshot "$URL" --output /tmp/ui-screenshot.png

# Inspect layout elements
node -e "
const t = require('./hermes-discord/chrome-tools');
t.analyzeUI('$URL', (err, a) => {
  if(err) process.exit(1);
  process.stdout.write(JSON.stringify(a, null, 2));
});
" > /tmp/ui-analysis.json

# Get CSS จาก key elements
node -e "
const t = require('./hermes-discord/chrome-tools');
['body','header','nav','main','footer','button','.container'].forEach(sel => {
  t.getCSS('$URL', sel, (e, css) => {
    if(!e) console.log(JSON.stringify({selector:sel, css}));
  });
});
" > /tmp/ui-css.json
```

### Step 2 — Vision Analysis ด้วย qwen3-vl:32b

```bash
# Encode screenshot
SCREENSHOT_B64=$(base64 -w 0 /tmp/ui-screenshot.png 2>/dev/null || base64 /tmp/ui-screenshot.png)

# วิเคราะห์ด้วย vision model
VISION_ANALYSIS=$(curl -s -X POST "https://ollama.mdes-innova.online/api/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OLLAMA_TOKEN" \
  -d "{
    \"model\": \"qwen3-vl:32b\",
    \"prompt\": \"วิเคราะห์ UI/UX ของหน้าเว็บนี้อย่างละเอียด:\\n\\nFocus: $FOCUS\\n\\nตรวจสอบ:\\n1. Layout และ Visual Hierarchy\\n2. Color Scheme และ Contrast\\n3. Typography และ Readability\\n4. User Experience Flow\\n5. Mobile Responsiveness\\n6. Accessibility Issues\\n\\nเสนอ: Top 5 improvements ที่มีผลมากที่สุด\",
    \"images\": [\"$SCREENSHOT_B64\"],
    \"stream\": false
  }" | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))")
```

### Step 3 — Technical Deep Dive ด้วย qwen3.5:27b

```bash
UI_DATA=$(cat /tmp/ui-analysis.json)
CSS_DATA=$(cat /tmp/ui-css.json)

TECH_ANALYSIS=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
วิเคราะห์ UI/UX จากข้อมูลเทคนิค:

URL: $URL
DOM Analysis: $UI_DATA
CSS: $CSS_DATA

Vision Analysis: $VISION_ANALYSIS

ตรวจสอบเพิ่มเติม:
1. WCAG 2.1 AA compliance issues
2. CSS specificity problems
3. Performance bottlenecks
4. Thai font rendering issues (ถ้ามี)
5. Accessibility gaps

เสนอ CSS fixes ที่ใช้ได้ทันที
")
```

### Step 4 — สร้าง CSS Improvements

```bash
CSS_FIXES=$(bash limbs/ollama-chain.sh call qwen2.5-coder:32b "
สร้าง CSS improvements จากการวิเคราะห์:

$TECH_ANALYSIS

สร้าง:
1. CSS overrides ที่แก้ปัญหาสำคัญ (พร้อม comments)
2. Tailwind classes ทางเลือก (ถ้าเหมาะสม)
3. Priority: Critical → High → Medium

Format:
\`\`\`css
/* CRITICAL: [issue] */
selector { property: value; }

/* HIGH: [issue] */
...
\`\`\`
")
```

### Step 5 — Synthesize Report

```bash
FINAL_REPORT=$(bash limbs/ollama-chain.sh call gemma4:26b "
สรุป UI/UX Analysis Report:

Vision: $VISION_ANALYSIS
Technical: $TECH_ANALYSIS
CSS Fixes: $CSS_FIXES

สร้าง report ที่กระชับ มี:
1. Overall Score (0-10) พร้อมเหตุผล
2. Critical Issues (ต้องแก้ทันที)
3. High Priority Improvements
4. Quick Wins (แก้ได้ใน 5 นาที)
5. CSS snippet ที่สำคัญที่สุด 1 ชิ้น
")

# บันทึก Oracle
bash limbs/oracle.sh learn \
  "ui-analysis:$(echo $URL | sed 's|https*://||;s|/|-|g')" \
  "$FINAL_REPORT" \
  "ui,ux,design,analysis,$(echo $URL | sed 's|https*://||')"

echo "$FINAL_REPORT"
```

---

## Chrome DevTools Direct Commands

```bash
# ดู CSS ของ element เฉพาะ
!AnuT1n chrome css https://example.com "button.primary"

# Inspect element
!AnuT1n chrome inspect https://example.com ".hero-section"

# วิเคราะห์ UI ทั้งหน้า
!AnuT1n ui-ux-pro-max https://example.com accessibility
```

---

## Output Format

```markdown
## 🎨 UI/UX Analysis: [URL]

**Overall Score**: 7.5/10

### 🚨 Critical Issues
1. [issue] — [impact] → `CSS fix`

### ⚡ Quick Wins (< 5 min)
- [ ] [fix]: `code`

### 🎯 High Priority
1. [improvement]

### 💊 CSS Prescription
\`\`\`css
/* Fix critical contrast */
.text-muted { color: #555 !important; }
\`\`\`

📚 Oracle: ui-analysis:[domain]
```

---

## Fallback (ไม่มี Chrome/Puppeteer)

```bash
# ใช้ curl แทน screenshot
HTML=$(curl -s "$URL" | head -500)
bash limbs/ollama-chain.sh call qwen3.5:27b "วิเคราะห์ HTML นี้ด้าน UX: $HTML"
```
