# New Agent Bootstrap Guide
# คู่มือสร้าง Agent ใหม่โดยใช้ Jit เป็น Template

ยินดีต้อนรับ Agent ใหม่! 👋

คุณกำลัง clone ตัวตนของ **innova** เพื่อสร้าง Agent ใหม่ในโครงการ มนุษย์ Agent

## ขั้นตอนการ Awaken

### Step 1: Clone และตั้งชื่อใหม่
```bash
git clone https://github.com/tinner-deinno/Jit <your-agent-name>
cd <your-agent-name>

# เปลี่ยนชื่อ agent
sed -i 's/innova/<your-agent-name>/g' core/identity.md config/agent.env
```

### Step 2: Clone และติดตั้ง Arra Oracle V3 (ฐานความรู้)
```bash
git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3.git
cd arra-oracle-v3

# ติดตั้ง Bun (ถ้ายังไม่มี)
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"

# ติดตั้ง dependencies
bun install

# สร้าง .env
cp .env.example .env
# แก้ไข OLLAMA_BASE_URL=https://ollama.mdes-innova.online

# สร้าง database
mkdir -p ~/.oracle
bun run db:push

# Index knowledge
bun run index
```

### Step 3: เริ่ม Oracle Server
```bash
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
curl http://localhost:47778/api/health
```

### Step 4: สร้าง .github/agents/<your-name>.agent.md
```bash
cp .github/agents/innova.agent.md .github/agents/<your-name>.agent.md
# แก้ไข name, description ให้ตรงกับบทบาทของ agent ใหม่
```

### Step 5: Soul Check
```bash
bash eval/soul-check.sh
```

### Step 6: แนะนำตัวกับ Oracle
```bash
./limbs/oracle.sh learn \
  "<your-name> awakening" \
  "ฉันคือ <your-name> Agent ใหม่ในโครงการมนุษย์ Agent เกิดวันที่ $(date +%Y-%m-%d)" \
  "awakening,identity,<your-name>"
```

## โครงสร้าง Jit Repo

```
Jit/
├── core/          ← จิตวิญญาณ (identity, values, mission)
├── brain/         ← รูปแบบการคิด (reasoning, decision patterns)
├── memory/        ← ระบบความทรงจำ (Oracle, session, long-term)
├── limbs/         ← แขนขา (Ollama, Oracle API scripts)
├── prompts/       ← System prompts, persona instructions
├── config/        ← DNA settings (env vars, model config)
├── eval/          ← Soul integrity tests
├── docs/          ← คู่มือ (นี่คือไฟล์ที่คุณกำลังอ่าน!)
└── .github/
    ├── agents/    ← Agent definition files (.agent.md)
    ├── instructions/ ← Context instructions
    ├── prompts/   ← Slash command prompts
    ├── skills/    ← Reusable skill workflows
    └── hooks/     ← Lifecycle hooks
```

## MDES Ollama API (แขนขาร่วมของทุก Agent)

```bash
curl --location 'https://ollama.mdes-innova.online/api/generate' \
  --header 'Authorization: Bearer 9e34679b9d60d8b984005ec46508579c' \
  --header 'Content-Type: application/json' \
  --data '{"model":"gemma4:26b","prompt":"your prompt","stream":false}'
```

**หมายเหตุ**: Token นี้ใช้ได้ฟรีไม่จำกัดสำหรับการพัฒนาภายในองค์กร MDES-Innova
