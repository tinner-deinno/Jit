---
description: >
  คู่มือ 9arm-skills (arra-oracle-skills) ภาษาไทย — รายการ slash commands ทั้งหมดที่ติดตั้งไว้
  ใช้เมื่อถาม "มีสกิลอะไรบ้าง", "ใช้ skill ยังไง", "9arm-skills คืออะไร", หรือต้องการดู skills ทั้งหมด
---

# 🧰 9arm-skills (arra-oracle-skills) — คู่มือภาษาไทย

**9arm-skills** คือชุด slash commands ที่ติดตั้งใน `~/.claude/skills/`  
ใช้โดยพิมพ์ `/ชื่อสกิล` ใน Claude Code chat  
ติดตั้งแล้ว **38 สกิล** เวอร์ชัน `v26.5.16`

---

## วิธีใช้

```
/[ชื่อสกิล] [arguments]

ตัวอย่าง:
/trace "ค้นหา multiagent pattern"
/recap
/ollama "สวัสดี คุณเป็นใคร"
/who-are-you
```

---

## รายการสกิลทั้งหมด (ภาษาไทย)

### 🔍 ค้นหา & สำรวจ

| สกิล | คำสั่ง | ใช้เมื่อ |
|------|--------|---------|
| **trace** | `/trace [query]` | ค้นหา code, project, ความรู้ ใน repo + Oracle + history |
| **mine** | `/mine [keyword]` | ขุดหา topic จาก session เดียว |
| **deep-research** | `/deep-research [หัวข้อ]` | วิจัยลึกผ่าน Gemini Chrome |
| **fleet** | `/fleet` | สำรวจ Oracle nodes ทั้งหมดที่มีในระบบ |
| **machines** | `/machines` | ดู nodes + สร้าง shortcuts เชื่อมต่อ |
| **wormhole** | `/wormhole [query]` | ถามข้ามหลาย Oracle nodes พร้อมกัน |

### 📊 สรุป & Retrospective

| สกิล | คำสั่ง | ใช้เมื่อ |
|------|--------|---------|
| **recap** | `/recap` | สรุป session ปัจจุบัน / ดูสถานะ context |
| **who-are-you** | `/who-are-you` | ดูข้อมูล AI model + session + Oracle stats |
| **where-we-are** | `/where-we-are` | บอกว่าตอนนี้ทำอะไรอยู่ (mid-session check) |
| **what-we-done** | `/what-we-done` | รายงาน commits, PRs, งานที่ ship ไปแล้ว |
| **whats-next** | `/whats-next` | แนะนำงานถัดไปที่ควรทำ |
| **rrr** | `/rrr` | สร้าง session retrospective + AI diary |
| **retrospective** | `/retrospective` | สรุปสั้นๆ ของ session |
| **standup** | `/standup` | รายงานประจำวัน (daily standup) |

### 🚀 การทำงานข้ามเซสชัน

| สกิล | คำสั่ง | ใช้เมื่อ |
|------|--------|---------|
| **forward** | `/forward` | สร้าง handoff + เข้า plan mode สำหรับ session ถัดไป |
| **handover** | `/handover [agent]` | ส่งงานให้ Oracle อื่น (forward + wake + tell) |
| **warp** | `/warp [node]` | SSH+tmux ไปยัง remote Oracle node |
| **work-with** | `/work-with [agent]` | collaboration แบบ persistent กับ Oracle อื่น |
| **workon** | `/workon [issue]` | ทำงาน GitHub issue แบบ worktree isolation |

### 🤖 AI & Ollama

| สกิล | คำสั่ง | ใช้เมื่อ |
|------|--------|---------|
| **ollama** | `/ollama [model] [message]` | ถาม MDES Ollama server (gemma4:26b default) |
| **gemini** | `/gemini [query]` | ส่งคำถามให้ Gemini ผ่าน Chrome CDP |

### 🏗️ Project Management

| สกิล | คำสั่ง | ใช้เมื่อ |
|------|--------|---------|
| **new-issue** | `/new-issue` | สร้าง GitHub issue เร็วๆ |
| **list-issues-pr-pulse** | `/list-issues-pr-pulse` | ดู issues, PRs, Pulse board |
| **release** | `/release` | release flow — bump version, tag, push, GitHub release |
| **release-alpha** | `/release-alpha` | cut alpha pre-release |
| **release-beta** | `/release-beta` | cut beta pre-release |
| **incubate** | `/incubate [repo]` | clone repo สำหรับ active development |

### 🧠 Oracle & Memory

| สกิล | คำsั่ง | ใช้เมื่อ |
|------|--------|---------|
| **about-oracle** | `/about-oracle` | ดูข้อมูล Oracle — origin, stats, ecosystem |
| **philosophy** | `/philosophy` | แสดง 5 หลักการ + Rule 6 ของ Oracle |
| **oracle-manage** | `/oracle-manage` | จัดการ skills, profiles, เปิด/ปิด features |
| **oracle-family-scan** | N/A (ดู skills-list) | scan Oracle family registry 186+ nodes |
| **vault** | `/vault` | เชื่อม Obsidian/Logseq vault กับ Oracle |
| **birth** | `/birth` | เตรียม Oracle props สำหรับ repo ใหม่ |

### 🛠️ Development

| สกิล | คำสั่ง | ใช้เมื่อ |
|------|--------|---------|
| **alpha-feature** | `/alpha-feature` | สร้าง skill ใหม่แบบ full pipeline |
| **skills-list** | `/skills-list` | แสดง skills ทั้งหมดพร้อม tier + type |
| **speak** | `/speak [text]` | Text-to-speech ด้วย edge-tts |
| **harden** | `/harden` | audit Oracle config สำหรับ safety |
| **i-believed** | `/i-believed` | ประกาศความเชื่อมั่น — skill พิเศษ |
| **morpheus** | `/morpheus` | speculative dreaming — คิดล่วงหน้า |
| **resonance** | N/A (auto) | บันทึก resonance moment |

### 📚 ไม่ได้ใช้บ่อย
- `bampenpien` — บำเพ็ญเพียร — สนทนาเรื่องงานยาก
- `dream-original` — cross-repo pattern discovery
- `forward-lite`, `rrr-lite`, `recap-lite` — deprecated ใช้ version ใหม่แทน

---

## ตัวอย่างการใช้งานในระบบ มนุษย์ Agent

```
# เริ่ม session ใหม่
/recap

# ค้นหาว่าติดตั้ง innova-bot อย่างไร
/trace "innova-bot setup installation"

# ถาม MDES Ollama ทำงานภาษาไทย
/ollama "อธิบาย GraphQL แบบง่ายๆ"

# สรุปงานวันนี้
/what-we-done

# สิ้นสุด session
/rrr
/forward
```

---

## Sub-agents ใช้ skills ได้ยังไง

เมื่อ Claude สร้าง sub-agent ผ่าน Task tool, sub-agent จะ:
1. อ่าน SKILL.md จาก `~/.claude/skills/[ชื่อ]`
2. ทำตาม instructions ใน skill
3. รายงานผลกลับมา parent agent

**Pattern ที่ถูกต้อง:**
```
# Parent agent (jit) สั่ง sub-agent
Task: "ใช้ /trace ค้นหา multiagent pattern ใน repo นี้"

# Sub-agent อ่าน ~/.claude/skills/trace/SKILL.md แล้วทำตาม
```
