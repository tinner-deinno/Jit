# Skill Version Registry — Jit Oracle

> บันทึกประวัติการพัฒนา skills ทุกตัว
> ใช้เปรียบเทียบ old/new version และวิเคราะห์การปรับปรุง

---

## Format

```
## skill-name
| Version | Date | Author | Changes | Performance Notes |
```

---

## ollama-think

| Version | Date | Changes | Notes |
|---------|------|---------|-------|
| v1.0 | 2026-05-06 | สร้างครั้งแรก — single Ollama call with model selection | ทดสอบกับ gemma4:26b ได้ผลดี |

**Lessons**:
- v1.0: ยังไม่มี error handling สำหรับ timeout
- TODO: เพิ่ม retry logic, streaming option

---

## ollama-swarm

| Version | Date | Changes | Notes |
|---------|------|---------|-------|
| v1.0 | 2026-05-06 | สร้างครั้งแรก — 5 parallel Ollama agents + aggregate | pipeline pattern: gather → think → synthesize |

**Lessons**:
- v1.0: agents ทำงาน parallel ผ่าน background curl
- TODO: เพิ่ม structured JSON output, error recovery per agent

---

## ollama-vision

| Version | Date | Changes | Notes |
|---------|------|---------|-------|
| v1.0 | 2026-05-06 | สร้างครั้งแรก — qwen3-vl:8b image analysis | รองรับ base64 image input |

**Lessons**:
- v1.0: ใช้ qwen3-vl:8b สำหรับ lightweight, qwen3-vl:32b สำหรับ accuracy
- TODO: test กับ qwen2.5vl_tools สำหรับ tool-calling จาก image

---

## multiagent-pipeline

| Version | Date | Changes | Notes |
|---------|------|---------|-------|
| v1.0 | 2026-05-06 | สร้างครั้งแรก — N-stage pipeline, output ของ stage ก่อน = input ของ stage ถัดไป | ทดสอบกับ 3-stage pipeline |

---

*อัปเดตทุกครั้งที่ skill เปลี่ยน — pattern: Nothing is Deleted, เพิ่มแถวใหม่เสมอ*
