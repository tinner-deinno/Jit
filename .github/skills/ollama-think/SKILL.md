---
name: ollama-think
version: 1.0
description: "เรียก MDES Ollama single agent — คิดคนเดียว เลือก model ได้ ใช้สำหรับ quick inference, Thai language, coding"
argument-hint: "prompt [--model gemma4:26b|deepseek-coder:33b|qwen3.5:9b] [--stream]"
updated: 2026-05-06
---

# SKILL: ollama-think v1.0
# บันทึก: สร้างจาก README Jit + MDES Ollama API spec

## Models ที่ใช้ได้

| Model | ขนาด | เหมาะกับ |
|-------|------|---------|
| `gemma4:26b` | 26B | Thai language, general, multimodal |
| `deepseek-coder:33b` | 33B | code generation, debugging |
| `qwen3.5:9b` | 9B | Thai/EN fast, lightweight |
| `qwen3.5:27b` | 27B | Thai/EN balanced |
| `llama3.1:8b` | 8B | English, fast |
| `phi3:medium` | 14B | reasoning, analysis |

## Usage

```bash
# ใน skill นี้ AI จะ:
# 1. อ่าน OLLAMA_TOKEN จาก .env
# 2. เรียก MDES Ollama API
# 3. return ผลลัพธ์

OLLAMA_TOKEN=$(grep "^OLLAMA_TOKEN=" /workspaces/Jit/.env | cut -d= -f2)
MODEL="${MODEL:-gemma4:26b}"
PROMPT="$1"

curl -s --location 'https://ollama.mdes-innova.online/api/generate' \
  --header "Authorization: Bearer ${OLLAMA_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data "{\"model\":\"${MODEL}\",\"prompt\":\"${PROMPT}\",\"stream\":false}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response','ERROR'))"
```

## Step-by-Step (เมื่อ user เรียก skill นี้)

1. ดู prompt และ model ที่ต้องการ (default: gemma4:26b)
2. โหลด OLLAMA_TOKEN จาก .env
3. เรียก MDES Ollama API
4. Return response
5. บันทึกลง Oracle ถ้าเป็น insight สำคัญ

## Version History
ดู: /workspaces/Jit/ψ/memory/skills/SKILL-VERSIONS.md
