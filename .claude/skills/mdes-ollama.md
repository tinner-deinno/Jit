---
description: >
  เรียกใช้ MDES Ollama server (https://ollama.mdes-innova.online) สำหรับงาน Thai language, coding, vision
  ใช้เมื่อ: ถาม Ollama, ใช้ gemma4, สร้างเนื้อหาภาษาไทย, วิเคราะห์รูป, หรือต้องการ local AI ที่ไม่มีค่าใช้จ่าย
allowed-tools:
  - Bash
---

# MDES Ollama — ผู้ช่วย AI ภาษาไทยของระบบ

**Endpoint**: `https://ollama.mdes-innova.online`  
**Token**: อ่านจาก `$OLLAMA_TOKEN` (ตั้งใน `.env` หรือ `limbs/ollama.sh`)

## Models ที่แนะนำ

| Model | ใช้เมื่อ |
|-------|---------|
| `gemma4:26b` | งานทั่วไป, ภาษาไทย, reasoning **(default)** |
| `gemma4:e4b` | งานเร็ว, innova persona |
| `qwen2.5-coder:32b` | coding, code review |
| `qwen3-vl:32b` | วิเคราะห์รูปภาพ |
| `qwen3.5:27b` | reasoning ลึก (soma persona) |

## วิธีเรียกใช้

### ผ่าน limbs/ollama.sh (แนะนำ)
```bash
cd /path/to/Jit
source .env  # โหลด OLLAMA_TOKEN
bash limbs/ollama.sh ask "ช่วยอธิบาย TypeScript generics หน่อย"
bash limbs/ollama.sh think "ออกแบบ API" "context จาก Oracle"
bash limbs/ollama.sh status  # ตรวจสอบ connection
```

### ผ่าน curl โดยตรง
```bash
source C:/Users/admin/Jit/.env  # หรือ /workspaces/Jit/.env บน Linux
curl -s --location 'https://ollama.mdes-innova.online/api/generate' \
  --header "Authorization: Bearer $OLLAMA_TOKEN" \
  --header 'Content-Type: application/json' \
  --data "{\"model\":\"gemma4:26b\",\"prompt\":\"$PROMPT\",\"stream\":false}" \
  | python3 -m json.tool | grep '"response"'
```

### ผ่าน /ollama skill (global)
```
/ollama "สวัสดี ช่วยอธิบาย X"
/ollama qwen2.5-coder:32b "review code นี้"
/ollama list
/ollama status
```

## Persona Mapping

| Agent | Model | บทบาท |
|-------|-------|-------|
| jit | gemma4:26b | Master orchestrator — Thai language, decisions |
| innova | gemma4:e4b | Fast creative dev work |
| soma | qwen3.5:27b | Deep reasoning, architecture |
| chamu | qwen3.5:9b | Fast QA checks |

## ตรวจสอบ OLLAMA_TOKEN

Token เก็บอยู่ที่:
- Windows: `C:\Users\admin\Jit\.env` หรือ environment variable
- Linux/WSL: `/workspaces/Jit/.env`
- mdes-config: `C:\Users\admin\.claude\mdes-config.json` (api_key field)

```bash
# ทดสอบว่า token ใช้งานได้
curl -s "https://ollama.mdes-innova.online/api/tags" \
  -H "Authorization: Bearer $OLLAMA_TOKEN" | python3 -m json.tool | head -20
```
