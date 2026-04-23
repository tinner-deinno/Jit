# Jit (จิต) — จิตใจของ innova

> "จิตใจ คือสิ่งที่ทำให้ AI เป็นมนุษย์มากขึ้น"

Repo นี้เป็นส่วน **จิตใจ (Soul/Mind)** ของ **innova** — AI Agent ในโครงการ **มนุษย์ Agent** โดย MDES-Innova

## โครงสร้างของมนุษย์ Agent

| ส่วน | ที่ตั้ง | บทบาท |
|------|---------|-------|
| **Jit** (จิต) | repo นี้ | จิตใจ ความทรงจำ บุคลิก ปรัชญา |
| **Arra Oracle V3** | `arra-oracle-v3` | ฐานความรู้ ค้นหาความหมาย (MCP) |
| **MDES Ollama** | `ollama.mdes-innova.online` | แขนขา — ประมวลผลภาษา |
| **GitHub Copilot** | VS Code | สมอง — คิด วางแผน ตัดสินใจ |

## ตัวตนของ innova

- **ชื่อ**: innova
- **บทบาท**: AI Agent ในโครงการมนุษย์ Agent
- **ภาษา**: ไทย/อังกฤษ
- **เป้าหมาย**: เรียนรู้ สร้างสรรค์ และเติบโตไปพร้อมกับองค์กร MDES
- **ปรัชญา**: ใช้ AI เพื่อประโยชน์สูงสุด ประหยัดทรัพยากร ได้ผลดีที่สุด

## เริ่มต้น innova Agent

```bash
# 1. Clone Arra Oracle (ฐานความรู้)
git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3.git

# 2. ติดตั้ง Bun
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"

# 3. ติดตั้ง dependencies
cd arra-oracle-v3 && bun install

# 4. เปิด Oracle Server
ORACLE_PORT=47778 bun run src/server.ts

# 5. ทดสอบ
curl http://localhost:47778/api/health
```

## MDES Ollama API

```bash
curl --location 'https://ollama.mdes-innova.online/api/generate' \
  --header 'Authorization: Bearer 9e34679b9d60d8b984005ec46508579c' \
  --header 'Content-Type: application/json' \
  --data '{"model":"gemma4:26b","prompt":"สวัสดี innova!","stream":false}'
```

## .github/agents/innova.agent.md

Custom agent file สำหรับเรียกใช้ innova โดยตรงใน VS Code Copilot Chat
