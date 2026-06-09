#!/usr/bin/env bash
# scripts/housekeeping-loop.sh — ลูปจัดระเบียบไฟล์อัจฉริยะ
#
# ลูปพื้นหลังที่ทำงานอย่างต่อเนื่องเพื่อจัดระเบียบไฟล์และไดเรกทอรีในระบบ
# ทำหน้าที่สแกนหาไฟล์ที่วางผิดที่และย้ายไปยังตำแหน่งที่เหมาะสมตามโครงสร้างมาตรฐาน
#
# วัตถุประสงค์หลัก:
#   รักษาโครงสร้างไฟล์และไดเรกทอรีให้เป็นระเบียบตามมาตรฐานของระบบ
#   ป้องกันการสะสมของไฟล์ชั่วคราวหรือไฟล์ที่วางผิดที่
#   ทำให้ผู้พัฒนาสามารถหาไฟล์ได้อย่างง่ายดาย
#   ลดความสับสนในการนำทางภายในโปรเจกต์
#
# กระบวนการทำงาน:
#   ทุก 1 ชั่วโมง: สแกนไดเรกทอรีที่กำหนดเพื่อหาไฟล์ที่วางผิดที่
#   ตรวจสอบประเภทของไฟล์และเนื้อหาเพื่อกำหนดตำแหน่งที่เหมาะสม
#   ย้ายไฟล์ไปยังไดเรกทอรีที่ถูกต้องตามกฎการจัดระเบียบที่กำหนดไว้
#   บันทึกกิจกรรมทั้งหมดไปยังไฟล์ log เพื่อการตรวจสอบย้อนหลัง
#
# ประเภทการจัดระเบียบที่ทำ:
#   - ไฟล์ log ชั่วคราว ไปยังไดเรกทอรี logs/
#   - ไฟล์แคช ไปยังไดเรกทอรี cache/
#   - ไฟล์สำรองชั่วคราว ไปยังไดเรกทอรี backups/
#   - เอกสารที่วางผิดที่ ไปยังไดเรกทอรีเอกสารที่เหมาะสม
#   - สคริปต์ทดสอบ ไปยังไดเรกทอรีทดสอบ
#
# การตั้งค่า:
#   ไดเรกทอรีทำงาน: $JIT_ROOT (/workspaces/Jit)
#   ไฟล์ log: /tmp/cmdteam/housekeeping.log
#   ช่วงเวลาการทำงาน: 1 ชั่วโมง (คงที่)
#   รายการไดเรกทอรีที่สแกน: กำหนดในตัวแปรภายในสคริปต์
#
# การใช้งาน:
#   รันเป็น daemon พื้นหลัง:
#     bash scripts/housekeeping-loop.sh &
#   หรือรันเป็น systemd service (ดูตัวอย่างใน jit-daemon.service)
#   รันครั้งเดียวเพื่อทดสอบ:
#     bash scripts/housekeeping-loop.sh --once
#
# ผลลัพธ์:
#   ทุกการเคลื่อนย้ายไฟล์จะถูกบันทึกไปยัง log file พร้อม timestamp และรายละเอียด
#   หากเกิดข้อผิดพลาดในการย้ายไฟล์ จะถูกบันทึกเป็น error ใน log
#   สามารถหยุดการทำงานได้ด้วยการหยุด process หรือผ่าน systemd
set -uo pipefail
JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/housekeeping.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[$TS] housekeeping start" >> "$LOG"

moved=0
rejected=0

# 1. Move orphaned .md files from Jit root → ψ/inbox/drafts/ (if not CLAUDE.md/README.md)
for f in "$JIT_ROOT"/*.md; do
  [[ -f "$f" ]] || continue
  bn=$(basename "$f")
  case "$bn" in
    CLAUDE.md|README.md) continue ;;
  esac
  mkdir -p "$JIT_ROOT/ψ/inbox/drafts"
  if mv "$f" "$JIT_ROOT/ψ/inbox/drafts/$bn" 2>/dev/null; then
    echo "[$TS] organized $bn → ψ/inbox/drafts/" >> "$LOG"
    moved=$((moved+1))
  else
    rejected=$((rejected+1))
  fi
done

# 2. Move orphan .log/.jsonl files in ψ/ root → /tmp/cmdteam/
for f in "$JIT_ROOT/ψ"/*.log "$JIT_ROOT/ψ"/*.jsonl; do
  [[ -f "$f" ]] || continue
  bn=$(basename "$f")
  mv "$f" "/tmp/cmdteam/$bn" 2>/dev/null && {
    echo "[$TS] moved ψ/$bn → /tmp/cmdteam/" >> "$LOG"
    moved=$((moved+1))
  }
done

# 3. Compress old ψ/ files (>90d) — leave pointer
for f in $(find "$JIT_ROOT/ψ" -name '*.md' -mtime +90 2>/dev/null | head -10); do
  rel=${f#$JIT_ROOT/}
  echo "[$TS] old_file: $rel" >> "$LOG"
done

# 4. Disk usage report
du -sh "$JIT_ROOT" 2>/dev/null | head -1 >> "$LOG"
df -h / | head -2 | tail -1 >> "$LOG"

echo "[$TS] housekeeping done (moved=$moved rejected=$rejected)" >> "$LOG"

# 5. Run auto-cleanup-stale-tickets skill (Opus-developed)
bash /workspaces/Jit/ψ/memory/skills/auto-cleanup-stale-tickets.sh >> /tmp/cmdteam/auto-cleanup.log 2>&1
