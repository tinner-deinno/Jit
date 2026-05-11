---
name: frontend-design
description: "ออกแบบและสร้าง frontend component/page ด้วย MDES Ollama — รับ design brief, screenshot reference หรือ wireframe แล้วสร้าง HTML/CSS/JS ที่ clean, responsive, รองรับภาษาไทย. Triggers: frontend, design component, สร้าง UI, build page, create component, ทำหน้าเว็บ, design ui"
argument-hint: "design brief เช่น 'dashboard card showing agent status with Thai font' หรือ URL สำหรับ reference"
---

# SKILL: frontend-design — สร้าง Frontend ด้วย MDES AI + Chrome Preview 🖥️

**qwen2.5-coder:32b สร้าง code + Chrome DevTools preview ทดสอบทันที**

## เมื่อไหร่ใช้ skill นี้

- ต้องการสร้าง HTML/CSS component หรือ full page
- ต้องการ responsive design ที่รองรับ Thai font
- ต้องการ UI สำหรับ Jit dashboard, bot interface, หรือ agent status
- ต้องการ prototype ที่ดู live ได้ทันทีผ่าน Chrome

---

## Tech Stack (Default)

| Layer | Tech | เหตุผล |
|-------|------|-------|
| HTML | Semantic HTML5 | Clean structure |
| CSS | TailwindCSS CDN | รวดเร็ว, utility-first |
| JS | Vanilla JS / Alpine.js | เบา, no build |
| Font | Sarabun (Google Fonts) | Thai support |
| Icons | Heroicons / Feather | Free, clean |

---

## Workflow

### Step 1 — Understand Design Brief

```bash
BRIEF="$1"
REFERENCE="${2:-}"  # URL หรือ path ของ reference image

# ถ้ามี reference URL → screenshot ด้วย Chrome
if [[ "$REFERENCE" =~ ^https?:// ]]; then
  node -e "
const t = require('./hermes-discord/chrome-tools');
t.screenshot('$REFERENCE', (e, i) => {
  if(!e) console.log('Reference captured:', i.file);
});
"
fi

# ค้น Oracle ว่ามี component คล้ายกันไหม
bash limbs/oracle.sh search "frontend:$BRIEF" 3
```

### Step 2 — Design Analysis

```bash
DESIGN_SPEC=$(bash limbs/ollama-chain.sh call gemma4:26b "
คุณคือ Senior UI/UX Designer

Design Brief: $BRIEF

วิเคราะห์และระบุ:
1. Component type (card, table, form, dashboard, etc.)
2. Color scheme ที่เหมาะสม
3. Layout structure (grid/flex)
4. Interactive elements ที่ต้องการ
5. Thai font requirements
6. Dark/light mode support
7. Responsive breakpoints

Context: นี่คือ Jit multiagent system — ควรใช้ dark theme สีน้ำเงิน/ม่วง
")
```

### Step 3 — Generate Code

```bash
HTML_CODE=$(bash limbs/ollama-chain.sh call qwen2.5-coder:32b "
สร้าง HTML/CSS/JS สำหรับ:

Brief: $BRIEF
Design Spec: $DESIGN_SPEC

Requirements:
1. ใช้ TailwindCSS CDN (https://cdn.tailwindcss.com)
2. Thai font: Sarabun จาก Google Fonts
3. Responsive (mobile-first)
4. Dark theme เป็น default
5. Clean, semantic HTML
6. Comments เป็นภาษาไทย

สร้าง complete HTML file ที่ใช้ได้ทันที:
\`\`\`html
<!DOCTYPE html>
<html lang=\"th\">
<head>...
</html>
\`\`\`

ห้าม: inline critical styles ที่ override Tailwind โดยไม่จำเป็น
")
```

### Step 4 — Live Preview ด้วย Chrome

```bash
# บันทึก HTML
COMPONENT_NAME=$(echo "$BRIEF" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
OUTPUT_FILE="src/ui/${COMPONENT_NAME}.html"
mkdir -p src/ui

bash organs/hand.sh create "$OUTPUT_FILE" "$HTML_CODE"

# Preview ใน Chrome
node -e "
const t = require('./hermes-discord/chrome-tools');
t.navigate('file://$(pwd)/$OUTPUT_FILE', (e, i) => {
  if(e) { console.error(e.message); return; }
  console.log('Preview:', i.title, '—', i.status);
  t.screenshot('file://$(pwd)/$OUTPUT_FILE', (e2, s) => {
    if(!e2) console.log('Screenshot:', s.file);
  });
});
"
```

### Step 5 — Review & Iterate

```bash
# ตรวจสอบกับ UI/UX standards
REVIEW=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
Review HTML/CSS นี้:

$HTML_CODE

ตรวจ:
1. ✅/❌ Thai font (Sarabun) โหลดถูกต้อง
2. ✅/❌ Responsive breakpoints ครบ
3. ✅/❌ Color contrast WCAG AA
4. ✅/❌ Semantic HTML
5. ✅/❌ ไม่มี hardcoded colors ที่ขัดแย้ง Tailwind

ถ้ามีปัญหา: ระบุ line และวิธีแก้
")

echo "📋 Code Review: $REVIEW"

# Learn
bash limbs/oracle.sh learn \
  "frontend:$COMPONENT_NAME" \
  "$HTML_CODE" \
  "frontend,ui,component,$COMPONENT_NAME,design"

echo "✅ Component saved: $OUTPUT_FILE"
echo "🌐 Preview: file://$(pwd)/$OUTPUT_FILE"
```

---

## Component Templates

### Jit Agent Status Card

```bash
bash .github/skills/frontend-design/run.sh \
  "agent status card showing name, role, status (active/idle/offline), last heartbeat, message count"
```

### Discord Bot Dashboard

```bash
bash .github/skills/frontend-design/run.sh \
  "bot dashboard with real-time message log, command history, agent health indicators"
```

### Oracle Search UI

```bash
bash .github/skills/frontend-design/run.sh \
  "search interface for Oracle knowledge base with instant results and category filters"
```

---

## Thai UI Guidelines

```
Font Stack: 'Sarabun', 'Noto Sans Thai', sans-serif
Font Size: 16px base (Thai ต้องการขนาดใหญ่กว่า Latin)
Line Height: 1.6-1.8 (Thai characters สูงกว่า Latin)
Letter Spacing: -0.01em ถึง 0 (ไม่ควร tight เกิน)
```

---

## Output Structure

```
src/ui/
└── <component-name>.html    ← Complete standalone component

.planning/
└── frontend-<name>.notes.md ← Design decisions + iterations
```
