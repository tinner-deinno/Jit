# Antigravity × CommandCode Fusion Playbook

## 1. หลักการแบ่งงาน 3 ชั้น

| ชั้น | Provider | จุดแข็ง | บทบาท |
|---|---|---|---|
| Layer-1 | CommandCode (deepseek-v4-pro, Qwen3.7-Max, GLM-5.1, Kimi-K2.6, claude-sonnet-4-6) | bulk codegen, text-gen, ราคาคุ้มสุด, embed context ได้ | ผลิตโค้ดปริมาณมาก, draft, refactor |
| Layer-2 | Antigravity / Gemini 3 (agy CLI) | long-context 1M, multimodal, agentic execution, tool use ใน sandbox | อ่าน codebase ใหญ่, วิเคราะห์ media, รัน tool |
| Layer-3 | Claude Code (Fable 5) | orchestration, SA review, ตัดสินใจ | กำกับ workflow, gatekeeping, ตัดสินข้อขัดแย้ง |

## 2. Fusion Patterns 5 แบบ

### 2.1 Generate-Review-Arbitrate
```
[CC] --generate--> [Draft Code]
[agy] --review--> [Feedback]
[Claude Fable] --arbitrate--> [Final Merge]
```

### 2.2 Long-Context Scout
```
[agy] --read 1M context--> [Contract Summary]
[CC] --codegen from contract--> [New Module]
[Claude Fable] --apply + gate--> [Commit]
```

### 2.3 Parallel Burst
```
[CC] --task A/B/C/D--> [Output 1..4]
[agy] --heavy task E--> [Output 5]
[Claude Fable] --merge--> [Unified Result]
```

### 2.4 Cross-Examination
```
[CC model] --answer--> [Answer A]
[agy] --answer--> [Answer B]
[Claude Fable] --compare--> [Match?]
           └--interrogate--> [Truth]
```

### 2.5 Quota Ladder
```
[CC] --default--> [OK?]
 └--[agy flash] --tool/long-context?--> [OK?]
    └--[agy pro] --quota 1500/day--> [OK?]
       └--[Claude Fable 5] --last resort--> [Done]
```

## 3. ตาราง Cost/Quota Discipline

| Provider | เพดาน | งานที่เหมาะ | งานที่ห้าม |
|---|---|---|---|
| CommandCode | quota เหลือ | bulk codegen, text-gen, embedded context, parallel tasks | long-context >1M, multimodal, agentic tool-use |
| agy flash | ภายใน 1500 req/day | quick tool-use, multimodal scout, short agentic loop | deep reasoning ซับซ้อน, SA review |
| agy pro | ภายใน 1500 req/day | long-context 1M, heavy agentic execution, sandbox | งานที่ CC ทำได้ราคาถูกกว่า |
| Claude Fable 5 | cost สูงสุด | orchestration, arbitration, final gate, SA review | งาน bulk ที่ไม่ผ่าน Quota Ladder |

## 4. Failure Handling

- **agy timeout / auth fail**: fallback ไป CommandCode ทันที; ถ้าเป็น long-context ให้ shard context แล้วส่ง CC
- **CC fence-marker corruption**: ต้องผ่าน `tsc` gate ก่อน commit เสมอ (บทเรียน MEGA-100)
- **agy quota 1500 req/day หมด**: หยุดส่ง agy; เปลี่ยนเป็น CC + Claude Fable 5 แทน
