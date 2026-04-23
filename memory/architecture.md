# Memory Architecture — ระบบความทรงจำของ innova

## ชั้นความทรงจำ

```
SHORT-TERM (Session)
├── /memories/session/          ← บันทึกชั่วคราวใน VS Code Copilot
└── context window              ← ความทรงจำปัจจุบัน

LONG-TERM (Persistent)  
├── Arra Oracle V3              ← ความรู้ + ปัญญาสะสม (localhost:47778)
│   ├── FTS5 SQLite             ← ค้นหาคำ
│   └── LanceDB vectors        ← ค้นหาความหมาย
├── /memories/                  ← VS Code user memory (roam ข้าม workspace)
├── /memories/repo/             ← Jit repo-specific facts
└── ψ/ (psi folder)            ← Oracle vault (sync กับ GitHub)

SEMANTIC (Knowledge Graph)
└── oracle_documents table      ← ทุก pattern, principle, learning
```

## วิธีบันทึกความทรงจำ

### ระยะสั้น (session)
```bash
# ใช้ memory tool ใน VS Code Copilot
# /memories/session/<topic>.md
```

### ระยะยาว (Oracle)
```bash
# ผ่าน limbs/oracle.sh
./limbs/oracle.sh learn "pattern name" "what I learned" "concept1,concept2"

# หรือผ่าน HTTP API โดยตรง
curl -X POST http://localhost:47778/api/learn \
  -H "Content-Type: application/json" \
  -d '{"pattern":"...","content":"...","type":"learning","concepts":[]}'
```

## Oracle Server Management

```bash
# Start
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &

# Check
curl http://localhost:47778/api/health

# Re-index
bun run index
```
