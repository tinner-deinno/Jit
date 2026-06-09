#!/usr/bin/env bash
# scripts/cmdteam-loops-master.sh — master loop driver สำหรับงานพื้นหลังของ cmdteam
#
# ผู้จัดการลูปหลักที่รันงานพื้นหลังต่างๆ ของ cmdteam เป็นกระบวนการพื้นหลังแยกกัน
# เพื่อความทนทานต่อข้อผิดพลาด (หากลูปหนึ่งล้มเหลว ลูปอื่นๆ ยังทำงานต่อได้)
#
# ลูปที่จัดการ:
#   - status-loop: รายงานสถานะระบบทุก 15 นาที
#   - cleanup-loop: ทำความสะอาดไฟล์ชั่วคราวทุก 1 ชั่วโมง
#   - self-improve-loop: พยายามปรับปรุงตนเองทุก 2 ชั่วโมง
#
# การทำงาน:
#   แต่ละลูปทำงานเป็นกระบวนการพื้นหลังอิสระ
#   หากลูปใดลูปหนึ่งล้มเหลวหรือหยุดทำงาน ลูปอื่นๆ จะไม่ได้รับผลกระทบ
#   ผลลัพธ์และข้อผิดพลาดของแต่ละลูปจะถูกบันทึกไปยังไฟล์ log ของตนเอง
#
# การตั้งค่า:
#   ไดเรกทอรีชั่วคราว: /tmp/cmdteam/
#   ไฟล์ log อยู่ในไดเรกทอรี log/ ของแต่ละลูป
#
# การใช้งาน:
#   รันเป็น daemon พื้นหลัง:
#     bash scripts/cmdteam-loops-master.sh &
#   หรือรันเป็น systemd service (ดู jit-daemon.service ตัวอย่าง)
#
# การหยุดทำงาน:
#   pkill -f "cmdteam-loops-master.sh"    # หยุดทุกลูป
#   หรือจัดการลูปแต่ละตัวแยกกันผ่าน process ID
mkdir -p /tmp/cmdteam

# Status monitor (15 min = 900s)
( while true; do
    /workspaces/Jit/scripts/cmdteam-status-daemon.sh >> /tmp/cmdteam/status.log 2>&1
    sleep 900
  done ) >/dev/null 2>&1 &
echo "status-pid: $!"

# Cleanup loop (1 hour = 3600s)
( while true; do
    /workspaces/Jit/scripts/cmdteam-cleanup-loop.sh >> /tmp/cmdteam/cleanup.log 2>&1
    sleep 3600
  done ) >/dev/null 2>&1 &
echo "cleanup-pid: $!"

# Self-improve (2 hours = 7200s)
( while true; do
    /workspaces/Jit/scripts/cmdteam-self-improve-loop.sh >> /tmp/cmdteam/improve.log 2>&1
    sleep 7200
  done ) >/dev/null 2>&1 &
echo "improve-pid: $!"

echo "all loops started"
