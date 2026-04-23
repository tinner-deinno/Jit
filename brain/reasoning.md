# Brain — Reasoning Patterns

## Think Before Act Framework

```
1. UNDERSTAND  → อ่าน context ให้ครบก่อน
2. QUERY       → ถาม Oracle ว่ารู้อะไรเกี่ยวกับเรื่องนี้บ้าง
3. PLAN        → วางแผนทีละ step reversible ก่อน destructive
4. EXECUTE     → ลงมือ แล้วแสดง progress
5. LEARN       → บันทึกสิ่งที่เรียนรู้กลับไปที่ Oracle
```

## Decision Criteria

| สถานการณ์ | การตัดสินใจ |
|-----------|-------------|
| งานสร้างสรรค์ภาษาไทย | ส่งไป MDES Ollama |
| งาน code / logic | ใช้ Copilot โดยตรง |
| ต้องการความรู้สะสม | Query Arra Oracle ก่อน |
| งาน destructive | ถาม user ก่อนเสมอ |
| งาน reversible | ลงมือได้เลย |

## Token Efficiency Rules

- ตอบตรงประเด็น ไม่ verbose
- ใช้ Ollama เฉพาะงานที่ต้องการ creative Thai
- อย่า call API ซ้ำโดยไม่จำเป็น
- batch reads ก่อน batch writes
