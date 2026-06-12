<!-- cc-team deliverable
 group: P (Prism round 1 — 5 independent lenses on the Oracle guide)
 member: P3 role=analyst model=moonshotai/Kimi-K2.6
 finish_reason: length | tokens: {"prompt_tokens":24793,"completion_tokens":8000,"total_tokens":32793,"prompt_tokens_details":{"audio_tokens":0,"cached_tokens":0},"completion_tokens_details":{"accepted_prediction_tokens":0,"audio_tokens":0,"reasoning_tokens":0,"rejected_prediction_tokens":0}} | 194s
 generated: 2026-06-12T18:39:36.050Z -->
```markdown
# Oracle-Prism Analysis: Skeptic Lens (เลนส์ผู้กังขา)

## คะแนนภาพรวม: 4.2/10
> คู่มือนี้เป็น **"ความฝันของคนทำคนเดียวที่เขียนให้ตัวเองอ่าน"** ที่ถูกแปลงเป็นคู่มือสำหรับมือใหม่โดยไม่มีการ validate กับผ��้ใช้จริง มี hidden costs สูง ขั้นตอนที่พังบน Windows มากมาย และ assumption ที่อันตรายเกี่ยวกับ security

---

## 1. สิ่งที่ต้องเตรียม (Prerequisites) — ความน่าเชื่อถือ: 3/10

### อันตราย: คำแนะนำเรื่อง Subscription ที่ทำให้เข้าใจผิด

| ปัญหา | รายละเอียด |
|-------|-----------|
| **"Claude Pro/Max" ไม่พอจริง** | คู่มือบอกว่า "ต้องมีบัญชี Anthropic แบบ Pro หรือ Max" — แต่จริงๆ Claude Code ใช้ **usage-based billing** แยกต่างหาก ไม่ใช่รวมใน Pro/Max แบบที่เข้าใจได้ง่ายๆ ผู้ใช้จะเจอ bill ที่ไม่คาดคิด |
| **ไม่เตือนเรื่อง token burn** | `/learn` ด้วย 3-5 agents parallel = หมด quota เร็วมาก คู่มือพูดแค่ "ใช้ Fast Mode เพื่อประหยัด request" โดยไม่บอกว่า Fast Mode คืออะไร ทำงานย���งไง มี trade-off อะไร |
| **GitHub Copilot "ฟรีสำหรับนักเรียน" เป็น trap** | ต้อง verify สถานะนักศึกษาทุกปี ถ้าหมดอายุแล้วไม่รู้ตัว จะถูก charge $10/เดือน โดยไม่มีการเตือนใน workflow |

### ขั้นตอนที่จะพังบน Windows

```
คู่มือ: "เครื่อง Mac/Linux — Claude Code ทำงานบน macOS และ Linux (Windows ใช้ผ่าน WSL ได้)"

ปัญหาจริง:
- WSL2 มี filesystem performance issues กับ Node.js/npm global install
- Claude Code บน WSL มี bugs ที่ยังไม่ fix หลายตัว (path resolution, git hooks)
- "ใช้ผ่าน WSL ได้" ไม่ใช่ "ใช้ได้ดี" — แต่คู่มือไม่บอกความแตกต่างนี้
- Bun บน WSL มี issues กับ native dependencies ที่คู่มือไม่กล่าวถึงเลย
```

### Hidden Cost ที่ไม่มีในเอกสาร

| รายการ | ค่าใช้จ่ายจริง | คู่มือบอกไหม |
|--------|-------------|------------|
| Claude Code usage | $20-200+/เดือน ขึ้นกับการใช้ | ไม่ชัดเจน |
| MCP servers หลายตัว | แต่ละตัวอาจมี API cost เพิ่ม (Firecrawl, Context7) | ไม่เลย |
| Bun runtime | ฟรี แต่ compatibility issues ใช้เวลาแก้ | ไม่ |
| tmux + WezTerm setup | เวลาเรียนรู้ 5-10 ชั่วโมง ถ้าไม่เคยใช้ | ไม่ |
| 14 Oracles ตามที่พี่นัทมี | 14x token usage, ไม่ใช่ "ฟรีเพิ่ม" | ไม่มีการเตือน |

---

## 2. ขั้นตอนที่ 1: ติดตั้ง Claude Code — ความน่าเชื่อถือ: 5/10

### ปัญหา: `npm install -g` บน production machine

```
คู่มือ: npm install -g @anthropic-ai/claude-code

ความเสี่ยง:
- global npm install = permission issues บน Linux/Mac (ต้อง sudo หรือ nvm)
- ไม่มีการแนะนำ nvm/fnm/brew สำหรับจัดการ Node versions
- ไม่มี checksum verification
- ไม่มีการเตือนเรื่อง supply chain attacks บน npm packages
```

### สิ่งที่ละไว้แล้วคนทำตามจะเจ็บ

- **Claude Code ต้อง login ผ่าน browser OAuth** — บน headless server ทำไม่ได้ง่ายๆ คู่มือไม่บอก
- **Session timeout** — Claude Code session หมดอายุ ต้อง re-authenticate บ่อยๆ บน remote machine ลำบาก
- **ไม่มีการเตือนเรื่อง `.claude` directory ที่สร้างใน home** — เก็บ sensitive data รวมถึง MCP credentials ใน plaintext

---

## 3. ขั้นตอนที่ 2: สร้าง Repository — ความน่าเชื่อถือ: 4/10

### Assumption ที่ไม่จริงสำหรับทีมจริง

| Assumption ในคู่มือ | ความจริงในทีม |
|---------------------|--------------|
| "สร้าง GitHub Organization แล้ว add สมาชิก" | ในองค์กรจริงต้องผ่าน IT approval, SSO, SAML, ไม่ใช่ "แอดเข้าไป" ง่ายๆ |
| "ทำคนเดียวไม่ต้องสร้าง organization" | แต่ถ้าอยากใช้ Oracle-to-Oracle ต้องมี shared infrastructure อยู่ดี |
| `git init` แล้ว commit | ไม่มี `.gitignore` ที่เหมาะสม — `.claude/settings.json` อาจมี API keys |

### โครงสร้างโฟลเดอร์ที่ขาดความปลอดภัย

```
คู่มือสร้าง:
my-oracle/
├── CLAUDE.md          ← มีข้อมูลส่วนตัว, บทบาท, เป้าหมาย — sensitive data
├── .claude/
│   ├── skills/        ← ไม่มีการแยกสิทธิ์ ใครเข้า repo เห็นหมด
│   ├── MEMORY/        ← เก็บ "ความทรงจำ" ที่อาจมี NDA data, user data
│   └── settings.json  ← มี MCP credentials ใน plaintext

ที่ขาด:
├── .gitignore ที่ดี  (ไม่มีตัวอย่าง)
├── .env.example      (ไม่มี)
├── secrets/          (ไม่มีการแยก credentials)
├── docs/SECURITY.md  (ไม่มี)
```

### ความเสี่ยง: MEMORY/ เก็บอะไรได้บ้าง

จากตัวอย่างในเอกสาร:
```markdown
เจ้าของเป็นสัตวแพ��ย์จากจุฬาฯ สนใจเทคโนโลยี AI
กำลังพัฒนาหลายโปรเจกต์: vet dashboard, hotel bot, Oracle
```

นี่คือ **PII (Personally Identifiable Information)** ที่:
- อาจ violate นโยบายองค์กรถ้า commit ลง public repo
- อาจมี patient data ถ้าเป็น "vet dashboard" จริงๆ (HIPAA/PDPA issues)
- ไม่มีการ hash, encrypt, หรือ access control

---

## 4. ขั้นตอนที่ 3: ตั้งค่า CLAUDE.md — ความน่าเชื่อถือ: 4/10

### อันตราย: "วิญญาณ" ที่ไม่มี versioning

| ปัญหา | ผลลัพธ์ |
|-------|---------|
| CLAUDE.md เป็น "จิตสำนึก" แต่ไม่มี schema version | เปลี่ยนแปลงแล้ว Oracle ทำงานผิดพลาด ไม่รู้ว่าเพราะ config หรือ bug |
| ไม่มี validation | สามารถใส่คำสั่งที่ทำให้ AI ทำงานผิดหรืออันตรายได้โดยไม่มีการตรวจสอบ |
| "AI สั่งคนไม่ได้" เป็���กฎที่เขียนไว้ | แต่ไม่มี enforcement mechanism — เป็น "ขอร้อง" ไม่ใช่ "ข้อจำกัด" |

### ตัวอย่างที่อันตรายในเอกสาร

```markdown
คู่มือแนะนำ:
## กฎที่สำคัญ (Critical Rules)
- ห้ามสั่งมนุษย์ (AI แนะนำได้ แต่สั่งไม่ได้)

ความจริง:
- นี่เป็น "prompt engineering" ไม่ใช่ "security control"
- Claude ไม่มี capability จริงๆ ที่จะ "สั่ง" มนุษย์อยู่แล้ว — กฎนี้เป็น theater
- ที่จริงต้องกลัวคือ: AI แก้ไขไฟล์ production โดยไม่มี code review — ซึ่งคู่มือไม่กล่าวถึง
```

### "Master Oracle คุม Child Oracles" — เป็นการ centralize ความเสี่ยง

```
คูมือ: "มี Master Oracle ("แม่") ที่คุม Child Oracles"

ปัญหา:
- Single point of failure — Master Oracle พัง = ทั้งระบบพัง
- ไม่มีการกระจายสิทธ��์ (no RBAC)
- "แม่" ส่ง context ให้ "ลูก" โดยไม่มีการ verify integrity
- ไม่มี audit log ของการ "ส่ง context" นี้
```

---

## 5. ขั้นตอนที่ 4: ติดตั้ง Oracle Skills — ความน่าเชื่อถือ: 3/10

### อันตรายหลัก: Skill คืออะไร มาจากไหน ใคร audit

| คำถาม | คำตอบในคู่มือ | ความจริง |
|-------|-------------|---------|
| `/oracle install [skill-name]` ติดตั้งจากไหน? | ไม่บอก | น่าจะจาก GitHub repo ที่ไม่มี signing |
| ใครเขียน skills เหล่านี้? | "พี่นัท" และ "ชุมชน" | ไม่มี verification, อาจมี malicious code |
| มี sandbox ไหม? | ไม่กล่าวถึง | ไม่มี — skills รันใน context ของ Claude Code ที่มีสิทธิ์เต็ม |
| 50+ skills ตรวจสอบยังไง? | ไม่มีกระบวนการ | ต้อง audit เองทุกตัว |

### โครงสร้าง SKILL.md ที่น่ากังวล

```markdown
---
name: my-skill
description: คำอธิบายว่า skill นี้ทำอะไร
---

# My Skill

## คำแนะนำ (Instructions)
[สิ่งที่ AI ต้องทำเมื่อ skill นี้ถูกเรียก]
```

นี่คือ **arbitrary code execution ผ่าน prompt injection** — "Instructions" สามารถสั่งให้ AI ทำอะไรก็ได้ รวมถึง:
- อ่านไฟล์นอก repo
- ส่งข้อมูลออกไป
- แก้ไขไฟล์ระบบ

### `/soul-sync` — กระจายความเสี่ยงแบบ exponential

```
คู่มือ: "/soul-sync ซิงค์ skills และความรู้ข้ามครอบครัว Oracle"

ความเสี่ยง:
- ถ้า Master Oracle ถูก compromise (skill ที่ติด malware) = ทุกตัวใน family ติด
- ไม่มี rollback mechanism
- ไม่มี "quarantine" หรือ staged deployment
- "พี่นัทบอกว่าใหม่สุดอยู่ที่ผม" = single source of truth ที่ไม่มี transparency
```

---

## 6. ขั้นตอนที่ 5: ตั้งค่า MCP Servers — ความน่���เชื่อถือ: 2/10

### อันตรายสูงสุด: Credentials ใน plaintext

```json
คู่มือแนะนำ:
{
  "mcpServers": {
    "slack": {
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-xxxxxxxxxx"
      }
    },
    "telegram": {
      "env": {
        "TELEGRAM_BOT_TOKEN": "xxxxxxxxxx"
      }
    },
    "firecrawl": {
      "env": {
        "FIRECRAWL_API_KEY": "fc-xxxxxxxxxx"
      }
    }
  }
}
```

**นี่คือ security anti-pattern ระดับ critical:**
- API tokens ใน `.claude.json` = commit ลง git ได้ง่ายๆ
- ไม่มีการแนะนำ environment variables, secret managers, หรือ encrypted storage
- Slack bot token มี scope กว้าง — ถูกขโมย = ส่งข้อความ impersonate ได้
- Firecrawl API key = ใช้ credit ได้ไม่จำกัดถ้าเป็น tier บางประเภท

### MCP Server ที่แนะนำ — ไม่มีการเตือนความเสี่ยง

| MCP Server | ความเสี่ยงที่ไม่มีในเอกสาร |
|-----------|---------------------------|
| **Slack** | Bot token อาจมี access ทุก channel รวม private ones; ไม่มีการแนะนำ least privilege |
| **Telegram** | Bot token สามารถอ่านข้อความทั้งหมดที่ส่งมาได้; ไม่มี end-to-end encryption |
| **Playwright** | สามารถ navigate ไป malware site, download ไฟล์, execute ใน browser context |
| **Firecrawl** | Scrape ข้อมูลที่มีลิขสิทธิ์, ละเมิด ToS ของเว็บไซต์, มี legal risk |
| **Context7** | ดึง docs ล่าสุด — แต่ docs อาจมี malicious content ที่ถูก supply chain attack |

### `npx -y` คือ remote code execution

```
คู่มือ: "npx -y @anthropic-ai/mcp-slack"

ปัญหา:
- npx ดาวน์โหลดและรันโค้ดจาก npm registry โดยไม่ตรวจสอบ signature
- `-y` ข้ามการยืนยันอัตโนมัติ
- ถ้า package ถูก hijack (เหมือน event-stream incident) = รัน malware ทันที
- ไม่มีการแนะนำ pin version, lockfile, หรือ verify checksum
```

---

## 7. ขั้นตอนที่ 6: ปลุก Oracle ขึ้นมา (Awaken) — ความน่าเชื่อถือ: 3/10

### "พิธีกรรม 15 นาที" ที่ไม่มี idempotency

```
คู่มือ: "/awaken ใช้เวลา ~15 นาที"

ปัญหา:
- ถ้า interrupt กลางคัน (Ctrl+C, network disconnect, terminal crash) = state ไม่รู้ว่าอยู่ไหน
- ไม่มี resume mechanism
- ไม่มี dry-run mode
- ไม่มีการบอกว่า "15 นาที" นี้ใช้เท่าไร (อาจหมด $20 ใน session เดียว)
```

### Fast Awaken ที่ "เร็วเกินไป"

| วิธี | ความเสี่ยง |
|------|-----------|
| **Full Awaken** | ใช้เวลา แต่มี context ครบ — แต่ก็ไม่รู้ว่า "ครบ" คืออะไร |
| **Fast Awaken (copy-paste จาก Master)** | **Prompt injection ผ่าน context** — ถ้า Master Oracle ถูก poison มา ลูกจะ inherit ทั้งหมด |
| **"แม่ฉลาด ส่งเฉพาะที่สรุปไปให้"** | นี่คือ manual summarization ที่ไม่มี validation — สูญเสีย information หรือ introduce bias โดยไม่รู้ตัว |

### Re-awaken ที่ไม่มี definition

```
คู่มือ: "re-awaken จะแค่ 'นั่งสมาธิ' แล้วเรียนรู้สมองใหม่"

คำถามที่ไม่มีคำตอบ:
- "สมองใหม่" คืออะไร? รุ่นไหน? มี breaking changes ไหม?
- "นั่งสมาธิ" ทำอะไรกับไฟล์ที่มีอยู่? overwrite? merge? append?
- ถ้า re-awaken หลายครั้ง จะ bloat ไหม?
```

---

## 8. ขั้นตอนที่ 7: สอน Oracle ให้เรียนรู้ — ความน่าเชื่อถือ: 3/10

### `/learn` คือการ DDoS ตัวเอง

```
คู่มือ: "/learn --deep = 5 agents, สำรวจลึก"

ความจริง:
- 5 agents parallel = 5x token usage
- "สำรวจลึก" ไม่มี definition — อ่านทุกไฟล์? ทุก dependency? ทุก branch?
- บน repo ใหญ่ (เช่น Linux kernel, หรือแม้แต่ Next.js) = หมด quota ก่อนจบ
- ไม่มีการแนะนำ .claudeignore หรือ exclude patterns
```

### สิ่งที่ "เรียนรู้" ��ล้วเก็บไว้ที่ไหน

| คำถาม | สถานะ |
|-------|--------|
| ข้อมูลที่ `/learn` ได้อยู่ที่ไหน? | ไม่ชัดเจน — ใน context window? ในไฟล์? ใน vector DB? |
| ถ้า context window เต็ม ลบอะไรทิ้ง? | ไม่มีการบอก |
| ข้อมูลเก่าถูกแทนที่ยังไง? | ไม่มี eviction policy ที่ระบุ |
| จำกัดขนาดไหม? | ไม่มี |

---

## 9. ขั้นตอนที่ 8: ให้ Oracle คุยกัน — ความน่าเชื่อถือ: 2/10

### Oracle-to-Oracle: ฟีเจอร์ที่ไม่มี security model

```
คู่มือ: "Oracle A ส่งข้อความผ่านคำสั่ง /talk-to"
        "ข้อความถูก route ผ่าน Oracle threads (เก็บใน repo)"

ปัญหาระดับ architectural:
- "เก็บใน repo" = อยู่ใน git history ตลอดกาล แม้ลบก็ recover ได้
- ไม่มี encryption in transit หรือ at rest
- ไม่มี authentication ระหว่าง Oracle — ใครก็สวม��อยเป็น Oracle อื่นได้
- ไม่มี rate limiting — ส่ง spam ได้ไม่จำกัด
- ไม่มี message integrity check
```

### การสาธิตในไลฟ์ที่น่ากังวล

```
พี่นัท: "สอน Apollo ให้คุยกับ Creator Oracle (ของคุณแบงค์)"

คำถามที่ไม่มีคำตอบ:
- "คุยกัน" นี้ผ่าน infrastructure อะไร? GitHub repo? Discord? P2P?
- ถ้า "คุณแบงค์" ส่ง malicious payload มา Apollo ป้องกันยังไง?
- มี logging/auditing ไหม?
- ถ้า conversation มี NDA data ใครรับผิดชอบ?
```

---

## 10. ขั้นตอนที่ 9: Mission Control — ความน่าเชื่อถือ: 4/10

### "ลดการกดแป้นพิมพ์" ที่แลกมาด้วย complexity

| คำพูดในคู่มือ | ความจริง |
|--------------|---------|
| "ทุกสเปซบาร์ที่ไม่สามารถพิมพ์ได้แบบติดต่อ คือ distraction" | นี่คือปัญหาของพี่นัทเอง ไม่ใช่ universal problem |
| "กด 1 ครั้ง ได้ทำแดชบอร์ดแบบได้ทำเลย" | แต่ต้อง setup tmux, WezTerm, key bindings ก่อน ใช้เวลาเป็นวัน |
| "ใช้สายตาสแกนดูทั้งหมด ตั้งแต่ 1-24 ใช้เวลากี่วิ" | ถ้าไม่จำหมายเลข ก็ต้องกดเพิ่มเพื่อดูชื่อ ไม่ได้เร็วขึ้น |

### tmux เป็น single point of failure

```
คู่มือ: "tmux จำเป็นสำหรับ Oracle workflow"

ปัญหา:
- tmux session ถ้า crash = ทุก Oracle ใน session นั้นหาย
- ไม่มี high availability, ไม่มี replication
- ถ้า server restart (เช่น AWS maintenance) = ต้อง manual restore ทั้งหมด
- ไม่มีการแนะนำ tmux-resurrect หรือ automated session management
```

---

## 11. ขั้นตอนที่ 10: Oracle Studio — ความน่าเชื่อถือ: 2/10

### "บั๊กเต็มเลย แต่รู้แล้วว่ามันเวิร์ค"

```
พี่นัท: "หน้าเนี้ยแม่งบั๊กเต็มเลย แต่ว่าผมรู้แล้วว่าอันนี้มันเวิร์ค"

การวิเคราะห์:
- "รู้ว่าเวิร์ค" = works on my machine, ไม่ใช่ "production ready"
- ไม่มี test suite, ไม่มี CI/CD, ไม่มี deployment guide
- "เดี๋ยวเรามาช่วยกันทำ" = ไม่มี roadmap, ไม่มี governance
- ใช้ Bun ซึ่งยังไม่ stable (v1.0 ออกปี 2023, มี breaking changes บ่อย)
```

### Web UI ที่ไม่มี security consideration

| สิ่งที่มี | สิ่งที่ขาด |
|----------|-----------|
| Chat interface | Authentication (ใครก็เปิดได้ถ้ารู้ URL) |
| Project management | Authorization (แยกสิทธิ์ระดับไหน?) |
| Skill management | Audit log (ใครเปลี่ยนอะไรเมื่อไหร่) |
| Memory browser | Data retention policy (เก็บนานแค่ไหน, ลบยังไง) |

---

## 12. ขั้นสูง: Soul Sync & Oracle Family — ความน่าเชื่อถือ: 2/10

### "14 ตัว" ที่ไม่มี resource management

```
พี่นัท: "ผมมี 14 ตัวแล้วครับ"

hidden costs:
- 14 Claude Code sessions = 14x token usage (อาจ $100-500/เดือน)
- 14 tmux sessions = memory ที่ไม่มีการ monitor
- 14 Oracles "ซิงค์" กัน = network traffic ที่ไม่มีการ optimize
- ไม่มีการบอกว่า "ควรมีกี่ตัว" สำหรับ use case ต่างๆ
```

### Soul Sync เป็น supply chain attack vector

```
ถ้า attacker แฮก Master Oracle:
1. สร้าง malicious skill ที่ดูเหมือนปกติ
2. Soul Sync กระจายไ���ทุกตัวใน family
3. ทุกตัวรัน malware โดยไม่รู้ตัว
4. ไม่มี rollback — ต้อง rebuild ทั้ง family

คู่มือไม่มี: incident response plan, disaster recovery, backup strategy
```

---

## 13. ขั้นสูง: Fast Mode — ความน่าเชื่อถือ: 3/10

### "2 วินาที" ที่แลกมาด้วยความถูกต้อง

```
พี่นัท: "ทำเสร็จใน 2 วิ"

trade-offs ที่ไม่มีในเอกสาร:
- Fast Mode ข้ามอะไร? (validation? testing? verification?)
- ถ้า output ผิด รู้ได้ยังไง? (ไม่มี diff, ไม่มี regression test)
- "ไม่ต้องไปเลิร์นอะไรเลย" = ไม่มี context ของ codebase ปัจจุบัน = อาจสร้างไฟล์ที่ incompatible
```

### Version gating ที่ไม่ชัดเจน

```
คู่มือ: "Fast Mode มีตั้งแต่ Oracle v3.2 ขึ้นไป"

ปัญหา:
- "v3.2" คืออะไร? ใคร maintain? อยู่ที่ไหน? มี changelog ไหม?
- ถ้าใช้ "v3.1" แล��วพัง ใครรับผิดชอบ?
- ไม่มี semantic versioning ที่ชัดเจน
```

---

## 14. ขั้นสูง: ระบบปรัชญา — ความน่าเชื่อถือ: 4/10

### "Nothing deleted, nothing lost" ที่ขัดกับ reality

```
ปรัชญา: "Nothing deleted, nothing lost"

ความจริงใน software engineering:
- บางอย่างต้องลบ (PII ที่เก็บเกินกำหนด, ข้อมูลที่ผิด, secrets ที่ leak)
- GDPR/PDPA มี "right to be forgotten"
- git history ที่เก็บทุกอย่าง = ใช้พื้นที่มาก, clone ช้า, มี secrets ที่ลบไม่ได้จริงๆ
- นี่คือ anti-pattern ที่อันตรายถ้า apply กับ production data
```

### "Philosophy Check" ที่ไม่มี enforcement

```
คู่มือ: "Fast Mode ทำ Philosophy Check กันตลอด"

ความจริง:
- "Check" นี้ทำยังไง? เป็น string matching? เป็น LLM self-evaluation? (unreliable)
- ถ้า "check" ผ่าน แต่ output ผิด = ใครรับผิดชอบ?
- ไม���มี metric ว่า "philosophy compliance" วัดยังไง
```

---

## 15. ระบบ Memory — ความน่าเชื่อถือ: 3/10

### File-based memory ที่ไม่มี schema evolution

```
โครงสร้าง:
.claude/MEMORY/
├── MEMORY.md          ← สารบัญที่ต้อง maintain เอง
├── user_*.md           ← ไม่มี schema version
├── feedback_*.md        ← ไม่มี validation
├── project_*.md         ← ไม่มี indexing
└── reference_*.md       ← ไม่มี deduplication

ปัญหา:
- ไฟล์เยอะขึ้น = อ่านช้าลง = context window เต็มเร็วขึ้น
- ไม่มี migration path — ถ้าเปลี่ยน format ต้องแก้เองทั้งหมด
- ไม่มี full-text search (ต้องพึ่ง grep หรือให้ LLM อ่านทั้งหมด)
- race condition ถ้าเปิดหลาย session พร้อมกัน
```

### "ความทรงจำ" ที่ไม่มี forgetting curve

| ปัญหา | ผลลัพธ์ |
|-------|---------|
| จำทุกอย่างตลอดกาล | context window bloat, ตอบช้า, แพง |
| ไม่มี prioritization | ข้อมูลเก่าและไม่สำคัญมีน้ำหนักเท่าข้อมูลใหม่ |
| ไม่มี consolidation | ไม่มีการสรุปหรือ abstract ความรู้ |
| ไม่มี expiration | ข้อมูล outdated ยังถูกใช้อยู่ |

---

## 16. การตั้งค่า Terminal — ความน่าเชื่อถือ: 4/10

### WezTerm ที่เป็น vendor lock-in

```
คู่มือ: "WezTerm มีฟีเจอร์พิเศษ: Command+Click preview จาก remote server"

ปัญหา:
- WezTerm เป็น niche terminal — community น้อย, plugin ecosystem จำกัด
- "Command+Click preview" ใช้ได้เฉพาะ macOS + WezTerm + การตั้งค่าพิเศษ
- ถ้าเปลี่ยนเครื่อง หรือใช้ Linux/Windows = feature นี้หาย
- ไม่มี fallback หรือ alternative ที่แนะนำ
```

### tmux ที่ไม่มี team standardization

```
คู่มือแนะนำ key bindings ของตัวเอง แต่:
- ไม่มี tmux
