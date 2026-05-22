# Memory Protocol — แก้ปัญหา Context Loss ข้าม Models

**Date**: 2026-05-20  
**Issue**: Jit ลืม project context เมื่อใช้ model ที่ไม่ใช่ GitHub Copilot  
**Root Cause**: GitHub Copilot อ่าน `.github/copilot-instructions.md` และ workspace context อัตโนมัติ แต่ MDES Ollama/Claude API ไม่มี workspace awareness — อ่านแค่ context window ปัจจุบัน  

---

## วิธีแก้ (Permanent Fix)

### 1. CLAUDE.md ต่อทุก project สำคัญ
สร้าง `CLAUDE.md` ที่ root ของทุก project — Claude Code/model ใดก็ตามจะอ่านอัตโนมัติ:
- mdes-hub: `C:\Users\admin\DEV\mdes-hub\CLAUDE.md` ✅ สร้างแล้ว 2026-05-20
- innova-bot: ตรวจสอบว่ามี CLAUDE.md ด้วย

### 2. Jit Workspace Instructions
`C:\Users\admin\Jit\.github\instructions\jit-context.instructions.md` — applyTo: `**`
→ GitHub Copilot ใน VS Code อ่านทุก session อัตโนมัติ ✅

### 3. สำหรับ MDES Ollama / non-GitHub models
เมื่อเปิด session ใหม่กับ Ollama หรือ Claude API ต้องเริ่มด้วย:
```
อ่าน CLAUDE.md ก่อน แล้วสรุปว่า project นี้อยู่ที่ phase ไหน
```

### 4. Project Registry ใน Jit
ไฟล์นี้เป็น registry ของ projects ที่ Jit ดูแลเป็น SA:

| Project | Path | CLAUDE.md | Phase | Status |
|---------|------|-----------|-------|--------|
| mdes-hub | `C:\Users\admin\DEV\mdes-hub` | ✅ | 74 done, 75 next | production-ready core |
| innova-bot | `C:\Users\admin\DEV\PugAss1stant\innova-bot` | ❓ ต้องตรวจ | ? | body/executor |
| Jit | `C:\Users\admin\Jit` | ✅ CLAUDE.md | ongoing | mind/orchestrator |

---

## Pattern: Memory Anchoring

เมื่อเริ่ม session ใน model ใดๆ บน project ที่ไม่ใช่ Jit:
1. อ่าน `CLAUDE.md` ของ project นั้น
2. อ่าน `TODO.md` หรือ bug tracker ล่าสุด
3. ตรวจ git log 5 commits ล่าสุด
4. สรุปให้ user ก่อนทำงาน

## Anti-Pattern (หลีกเลี่ยง)

- ❌ เริ่มทำงานทันทีโดยไม่อ่าน context
- ❌ ถามว่า "project นี้คืออะไร" ทั้งที่ CLAUDE.md มีคำตอบ
- ❌ สร้าง feature ใหม่โดยไม่รู้ว่า bug เดิมยังค้างอยู่
