---
name: feature-dev
description: "พัฒนา feature ใหม่แบบครบวงจรตามมาตรฐาน Jit — brainstorm→plan→code→test→review→deploy โดย route งานให้ agent/organ ที่ถูกต้อง. Triggers: feature dev, develop feature, build feature, สร้าง feature, implement, พัฒนาฟีเจอร์, new feature, add feature"
argument-hint: "feature ที่ต้องการสร้าง เช่น 'voice command สำหรับ karn', 'auto-summarize Discord thread'"
engines: ["mdes-ollama", "claude-cli", "openai-codex"]
jit-agents: ["jit", "soma", "lak", "innova", "chamu", "neta", "pada", "vaja"]
---

# SKILL: feature-dev — พัฒนา Feature แบบ Full-Cycle ด้วย Jit Agents 🚀

**Standard Jit Feature Flow: human → vaja → jit → soma → lak → innova → chamu → neta → pada → vaja → human**

## เมื่อไหร่ใช้ skill นี้

- ต้องการพัฒนา feature ใหม่แบบมีโครงสร้าง
- ต้องการ code + test + review + deploy ในรอบเดียว
- ต้องการให้ agents ช่วยกันทำงานตาม Jit hierarchy
- Feature ที่ซับซ้อนเกินกว่าจะทำคนเดียว

---

## Feature Development Flow

```
Phase 1: DEFINE    — jit orchestrates scope
Phase 2: DESIGN    — soma (strategy) + lak (architecture)  
Phase 3: CODE      — innova (lead dev) + MDES Ollama
Phase 4: TEST      — chamu (QA) validates
Phase 5: REVIEW    — neta (code review)
Phase 6: DEPLOY    — pada (DevOps)
Phase 7: NOTIFY    — vaja reports to user
```

---

## Workflow

### Phase 1: DEFINE — กำหนด Scope

```bash
FEATURE="$1"

# Brainstorm ก่อนถ้ายังไม่ชัด
echo "🎯 Defining feature: $FEATURE"

FEATURE_SPEC=$(bash limbs/ollama-chain.sh call gemma4:26b "
คุณคือ jit (Soul/Orchestrator) ของ Jit multiagent system

Feature Request: $FEATURE

กำหนด Feature Spec:
1. **What** — feature นี้ทำอะไร (2-3 ประโยค)
2. **Who** — ใครใช้ (user, agent, Discord bot)
3. **Where** — code อยู่ที่ไหน (repo path)
4. **Acceptance Criteria** — เมื่อไหรถือว่าเสร็จ (5 items)
5. **Out of Scope** — อะไรที่ไม่ทำใน version นี้
6. **Estimated Complexity** — S/M/L/XL พร้อมเหตุผล
")

echo "📋 Feature Spec:"
echo "$FEATURE_SPEC"

# บันทึก
FEAT_SLUG=$(echo "$FEATURE" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
bash limbs/oracle.sh learn "feature:$FEAT_SLUG:spec" "$FEATURE_SPEC" "feature,$FEAT_SLUG,spec"
```

### Phase 2: DESIGN — Architecture

```bash
# soma: strategic view
STRATEGY=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
คุณคือ soma (Brain/Strategic Lead) ของ Jit system

Feature: $FEATURE
Spec: $FEATURE_SPEC

วางกลยุทธ์:
1. Approach ที่แนะนำ (เลือก 1 จาก 3 ตัวเลือก พร้อมเหตุผล)
2. Dependencies ที่ต้องมี
3. Integration points กับ existing code
4. Risks ที่ต้องจัดการก่อน
")

# lak: architecture
ARCHITECTURE=$(bash limbs/ollama-chain.sh call qwen2.5-coder:32b "
คุณคือ lak (Architect/กระดูก) ของ Jit system

Feature: $FEATURE
Strategy: $STRATEGY

ออกแบบ Architecture:
1. File structure ที่ต้องสร้าง/แก้ไข
2. Data flow diagram (text-based)
3. Interface / API contracts
4. Database/state changes (ถ้ามี)
5. Jit organ assignments:
   - hand.sh: สร้างไฟล์อะไร
   - leg.sh: deploy อะไร
   - nerve.sh: events อะไร
")

echo "🏗️ Architecture:"
echo "$ARCHITECTURE"
```

### Phase 3: CODE — Implementation

```bash
# innova + MDES Ollama เขียน code
echo "💻 Coding feature..."

# อ่าน existing code context ก่อน
bash organs/eye.sh read "$(echo $ARCHITECTURE | grep -oP 'src/[^\s]+' | head -1)" 2>/dev/null | head -100

IMPLEMENTATION=$(bash limbs/ollama-chain.sh call qwen2.5-coder:32b "
คุณคือ innova (Lead Developer) ของ Jit system

Feature: $FEATURE
Architecture: $ARCHITECTURE

สร้าง implementation:
1. Code ที่สมบูรณ์ (พร้อมรัน)
2. Comments เป็นภาษาไทย
3. Error handling
4. Integration กับ MDES Ollama ถ้าจำเป็น:
   bash limbs/ollama.sh think \"prompt\" \"context\"
5. Integration กับ Oracle ถ้าจำเป็น:
   bash limbs/oracle.sh learn/search

เขียน code ที่:
- Clean, ไม่ redundant
- ใช้ existing patterns จาก Jit repo
- รองรับ CommonJS (require, not import)
")

# สร้างไฟล์จริง
for FILE_PATH in $(echo "$ARCHITECTURE" | grep -oP '(?<=hand\.sh create )\S+'); do
  FILE_CONTENT=$(echo "$IMPLEMENTATION" | awk "/\`\`\`.*$FILE_PATH/,/\`\`\`/" | head -50)
  if [ -n "$FILE_CONTENT" ]; then
    bash organs/hand.sh create "$FILE_PATH" "$FILE_CONTENT"
    echo "✅ Created: $FILE_PATH"
  fi
done
```

### Phase 4: TEST — Quality Assurance

```bash
# chamu: QA agent
TEST_PLAN=$(bash limbs/ollama-chain.sh call qwen3.5:9b "
คุณคือ chamu (QA/จมูก) ของ Jit system

Feature: $FEATURE
Implementation: $IMPLEMENTATION

สร้าง test cases:
1. Happy path tests (3-5 cases)
2. Edge cases (3 cases)
3. Error cases (3 cases)

สำหรับแต่ละ test:
- Input
- Expected output
- Bash command สำหรับ run test
")

echo "🧪 Running tests..."

# รัน tests จริง
PASSED=0
FAILED=0
while IFS= read -r TEST_CMD; do
  [[ "$TEST_CMD" =~ ^bash ]] || continue
  if eval "$TEST_CMD" 2>/dev/null; then
    PASSED=$((PASSED + 1))
    echo "  ✅ $TEST_CMD"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $TEST_CMD"
  fi
done <<< "$TEST_PLAN"

echo "Tests: $PASSED passed, $FAILED failed"
```

### Phase 5: REVIEW — Code Review

```bash
# neta: code reviewer
CODE_REVIEW=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
คุณคือ neta (Code Reviewer/เนตร) ของ Jit system

Feature: $FEATURE

Review code นี้:
$IMPLEMENTATION

ตรวจ:
1. 🔒 Security: SQL injection, path traversal, token exposure
2. ⚡ Performance: N+1 queries, blocking ops
3. 🧹 Code Quality: naming, duplication, complexity
4. 🔗 Integration: Jit organ usage ถูกต้องหรือไม่
5. 📝 Documentation: comments ครบหรือไม่

ให้คะแนน: [APPROVED ✅ | NEEDS CHANGES ⚠️ | BLOCKED ❌]
ระบุ issues ที่ต้องแก้ก่อน merge
")

echo "👁️ Code Review:"
echo "$CODE_REVIEW"

# ถ้า BLOCKED ให้หยุดและแจ้ง innova
if echo "$CODE_REVIEW" | grep -q "BLOCKED"; then
  bash organs/mouth.sh tell innova "alert:review-blocked" "Feature $FEATURE blocked: $CODE_REVIEW"
  echo "❌ Feature blocked — แก้ไขก่อน deploy"
  exit 1
fi
```

### Phase 6: DEPLOY — Go Live

```bash
# pada: DevOps
echo "🚀 Deploying..."

bash organs/leg.sh run "git add -A && git commit -m 'feat($FEAT_SLUG): $FEATURE'" 2>/dev/null

# Restart services ถ้าจำเป็น
if echo "$ARCHITECTURE" | grep -qi "bot.js\|hermes"; then
  bash organs/leg.sh run "pm2 restart hermes-discord 2>/dev/null || echo 'PM2 not running'"
fi

bash organs/nerve.sh signal "feature:deployed" "$FEATURE"
```

### Phase 7: NOTIFY — Report

```bash
# vaja: notify user
SUMMARY="✅ Feature '$FEATURE' deployed!\n\n"
SUMMARY+="**Spec**: $FEATURE_SPEC\n"
SUMMARY+="**Tests**: $PASSED passed, $FAILED failed\n"
SUMMARY+="**Review**: $(echo $CODE_REVIEW | head -1)\n"
SUMMARY+="📚 Oracle: feature:$FEAT_SLUG"

bash organs/mouth.sh tell vaja "task:notify" "$SUMMARY"
bash limbs/oracle.sh learn "feature:$FEAT_SLUG:done" "$SUMMARY" "feature,$FEAT_SLUG,deployed"

echo ""
echo "═══════════════════════════"
echo "🎉 FEATURE COMPLETE: $FEATURE"
echo "═══════════════════════════"
echo "$SUMMARY"
```

---

## Quick Feature (Simple/S-size)

```bash
# สำหรับ feature เล็กที่รู้แล้วว่าต้องทำอะไร
FEATURE="$1"
# ข้าม brainstorm/design → direct to code
bash limbs/ollama.sh create "สร้าง implementation สำหรับ: $FEATURE" "Jit CommonJS repo"
```

---

## Discord Bot Integration

```
!AnuT1n feature-dev เพิ่ม !AnuT1n remind <time> <message>
!AnuT1n feature-dev ทำให้ bot ตอบเป็นภาษาไทยอัตโนมัติเมื่อ user พิมพ์ภาษาไทย
```

---

## 🔌 Multi-Engine Support (MDES / Claude CLI / Codex)

feature-dev ทำงานได้กับ AI engine หลายตัว:

| Phase | Engine Default | Fallback |
|-------|---------------|---------|
| DEFINE | `gemma4:26b` (MDES) | `claude --print` |
| DESIGN | `qwen3.5:27b` (MDES) | `gpt-4o` (Codex) |
| CODE | `qwen2.5-coder:32b` (MDES) | `claude --print` |
| TEST | `qwen3.5:9b` (MDES) | — |
| REVIEW | `qwen3.5:27b` (MDES) | `claude --print` |

### Claude CLI sub-agent mode (Phase 3 CODE):

```bash
# ถ้ามี claude CLI → ให้ innova (claude) เขียน code จริง
if command -v claude &>/dev/null; then
  claude --print "You are innova, Lead Developer of Jit system.

Feature: $FEATURE
Architecture: $ARCHITECTURE

Implement this feature. Rules:
- CommonJS only (require, not import)
- Use Jit organs (organs/*.sh) for file ops
- MDES Ollama via: bash limbs/ollama.sh think 'prompt'
- Oracle via: bash limbs/oracle.sh learn/search
- Thai comments

Create complete, runnable code." 2>/dev/null
fi
```

### OpenAI Codex (gpt-4o) สำหรับ Phase 2 DESIGN:

```bash
if [ -n "${OPENAI_API_KEY:-}" ]; then
  curl -sf "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"system\",\"content\":\"You are lak, Solution Architect of Jit multiagent system.\"},{\"role\":\"user\",\"content\":\"Design architecture for: $FEATURE\nContext: Jit repo with CommonJS, MDES Ollama, Oracle at localhost:47778\"}]}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'])"
fi
```

---

## Jit Agent Hierarchy ใน feature-dev

```
user/vaja → jit (orchestrate all 7 phases)
  ├── soma  → strategy decision (Phase 2)
  ├── lak   → architecture design (Phase 2)
  ├── innova → code implementation (Phase 3) 
  │   └── MDES: qwen2.5-coder:32b | OR: claude CLI | OR: Codex
  ├── chamu → QA testing (Phase 4)
  ├── neta  → code review (Phase 5)
  ├── pada  → deployment (Phase 6)
  └── vaja  → user notification (Phase 7)
```
