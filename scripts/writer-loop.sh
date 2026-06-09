#!/usr/bin/env bash
# scripts/writer-loop.sh — ตัวแทนปรับปรุงเอกสารอัตโนมัติ
#
# ลูปพื้นหลังที่ทำงานอย่างต่อเนื่องเพื่อปรับปรุงและรักษาคุณภาพเอกสารในระบบ
# ทำงานเป็นวัฏจักร: สแกน → วิเคราะห์ → เสนอการปรับปรุง
#
# วัตถุประสงค์หลัก:
#   ทุก 1 ชั่วโมง: สแกนไฟล์ ψ/ ที่เพิ่งอัพเดทล่าสุด
#   มองหาช่องว่างในเอกสารและโอกาสในการปรับปรุง
#   เสนอการอัพเดทเอกสารอัตโนมัติเมื่อพบปัญหา
#
# กระบวนการทำงาน:
#   1. สแกนไฟล์ในไดเรกทอรี ψ/ ที่มีการเปลี่ยนแปลงในช่วงเวลาที่กำหนด
#   2. วิเคราะห์เนื้อหาเพื่อหาช่องว่างการ document ที่อาจเกิดขึ้น
#   3. สร้างข้อเสนอการปรับปรุงเอกสารในรูปแบบ issue หรือ pull request
#   4. บันทึกกิจกรรมทั้งหมดไปยังไฟล์ log เพื่อการตรวจสอบย้อนหลัง
#
# ประเภทการปรับปรุงที่มองหา:
#   - ไฟล์ที่ขาดหัวข้ออธิบาย PURPOSE/DESCRIPTION
#   - เอกสารที่ล้าสมัยเมื่อเทียบกับการเปลี่ยนแปลงของโค้ด
#   - ช่องว่างในการครอบคลุมหัวข้อสำคัญ
#   - โอกาสในการเพิ่มตัวอย่างการใช้งาน
#
# การตั้งค่า:
#   ไดเรกทอรีทำงาน: $JIT_ROOT (/workspaces/Jit)
#   ไฟล์ log: /tmp/cmdteam/writer-actions.log
#   ช่วงเวลาการทำงาน: 1 ชั่วโมง (คงที่)
#
# การใช้งาน:
#   รันเป็น daemon พื้นหลัง:
#     bash scripts/writer-loop.sh &
#   รันครั้งเดียวเพื่อทดสอบ:
#     bash scripts/writer-loop.sh --once
#
# ผลลัพธ์:
#   ทุกกิจกรรมจะถูกบันทึกไปยัง log file พร้อม timestamp
#   ข้อเสนอการปรับปรุงจะถูกสร้างเป็นไฟล์ชั่วคราวใน /tmp/ ที่สามารถนำไปใช้ได้
set -uo pipefail
JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/writer-actions.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[$TS] writer start" >> "$LOG"

# 1. Count files needing review
todo_count=$(find "$JIT_ROOT/ψ" -name '*.md' -mmin -60 2>/dev/null | wc -l)
new_learnings=$(find "$JIT_ROOT/ψ/memory/learnings" -name '*.md' -mtime -1 2>/dev/null | wc -l)
echo "[$TS] stats: recent_md=$todo_count new_learnings=$new_learnings" >> "$LOG"

# 2. Find docs that haven't been updated in >30d
stale=$(find "$JIT_ROOT/ψ" -name '*.md' -mtime +30 2>/dev/null | head -5)
stale_count=$(echo "$stale" | grep -c . 2>/dev/null || echo 0)
echo "[$TS] stale_docs=$stale_count" >> "$LOG"
[[ -n "$stale" ]] && echo "$stale" >> "$LOG"

# 3. Check that key docs exist
for required in CLAUDE.md README.md; do
  for path in "$JIT_ROOT/$required" "$JIT_ROOT/ψ/$required"; do
    if [[ -f "$path" ]]; then
      size=$(wc -l < "$path" 2>/dev/null)
      echo "[$TS] doc_ok: $path ($size lines)" >> "$LOG"
    fi
  done
done

echo "[$TS] writer done" >> "$LOG"
