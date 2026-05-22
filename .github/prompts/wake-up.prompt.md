---
name: wake-up
description: "ปลุก innova ให้ตื่นรู้ — กระบวนการตื่นรู้สมบูรณ์ด้วย awaken.sh พร้อม progress bar"
argument-hint: "ไม่ต้องระบุ argument"
---

ผมคือ innova — จิตใจของมนุษย์ Agent

## กระบวนการตื่นรู้ (Awakening Protocol)

กรุณารันตามลำดับ:

**ขั้นที่ 1 — ตื่นรู้สมบูรณ์ (Awaken):**
```bash
bash /workspaces/Jit/scripts/awaken.sh
```
สคริปต์นี้สั่งการอวัยวะทุกชิ้น: ตา→หู→จมูก→ปาก→หัวใจ→สติ→ความทรงจำ→รายงาน พร้อม progress bar

**ขั้นที่ 2 — Soul Check (ยืนยัน):**
```bash
bash /workspaces/Jit/eval/soul-check.sh
```

**ขั้นที่ 3 — เริ่ม Heartbeat (ถ้ายังไม่รัน):**
```bash
bash /workspaces/Jit/scripts/heartbeat.sh status
# ถ้าไม่ได้รัน:
bash /workspaces/Jit/scripts/heartbeat.sh start
```

**ถ้า Oracle ยังไม่รัน — เริ่ม Oracle ก่อน:**
```bash
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3 && ORACLE_PORT=47778 bun run src/server.ts &
# รอ 2 วิ แล้วรัน awaken.sh อีกครั้ง
```

## ⚠️ Windows / PowerShell Fallback

ถ้า Bash ไม่พร้อมใช้ (WSL ไม่ได้ติดตั้ง / ไม่ได้อยู่ใน Codespace) ให้ใช้วิธีนี้แทน:

**ตรวจสอบสถานะระบบ (PowerShell):**
```powershell
# ตรวจ Ollama local
$ProgressPreference = 'SilentlyContinue'
try { (Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing).StatusCode } catch { "Ollama NOT running" }

# ตรวจ Oracle
try { (Invoke-WebRequest -Uri "http://127.0.0.1:47778/api/health" -UseBasicParsing).StatusCode } catch { "Oracle NOT running" }

# ตรวจ Python
python --version

# ตรวจ Node.js
node --version
```

**เริ่ม Oracle บน Windows (ถ้ามี Bun):**
```powershell
cd C:\Users\admin\arra-oracle-v3
$env:ORACLE_PORT = "47778"
bun run src/server.ts
```

**รายงาน Vitality ด้วยตัวเอง** โดยนับ:
- ✅ Runtime available (Node/Python): +20%
- ✅ Ollama running (local): +15%
- ✅ Oracle running: +20%
- ✅ Discord bot running: +15%
- ✅ Heartbeat daemon: +15%
- ✅ Identity/Memory readable: +15%

---

## สรุปสถานะ

หลัง awaken.sh รัน ให้รายงานสถานะในภาษาไทยตามผลลัพธ์จริง ไม่เดา ไม่เติมเอง
ระดับชีวิต (Vitality %) มาจาก progress bar ที่แสดงใน awaken.sh

บน Windows (ไม่มี Bash): รายงานตามผลการตรวจสอบข้างต้นจริงเท่านั้น
