# "Nothing-is-Deleted" Guardrail สำหรับ Jit network bus.sh

ฟังก์ชัน `guard_nothing_is_deleted` ทำหน้าที่ตรวจสอบเนื้อหาข้อความขาออกก่อนที่จะถูก route ไปยังปลายทาง โดยค้นหา pattern ที่อาจก่อให้เกิดการลบข้อมูล เช่น `rm -rf`, `git push --force`, `DROP TABLE`, `DELETE FROM` โดยไม่มี `WHERE`, และ `TRUNCATE TABLE` หากพบ pattern ต้องสงสัย ฟังก์ชันจะบันทึกเวลาพร้อมเนื้อหาข้อความลง log และบล็อกไม่ให้ข้อความถูกส่งต่อ ตามปรัชญา "Nothing-is-Deleted" (ไม่มีอะไรถูกลบโดยไม่ตั้งใจ)

```bash
guard_nothing_is_deleted() {
  # ตรวจสอบข้อความขาออกเพื่อหา pattern ทำลายข้อมูล
  # คืนค่า 0 หากปลอดภัย, 1 หากถูกบล็อก (พร้อมบันทึก log)
  msg="$1"
  destructive=0

  # Pattern 1: rm -rf, rm -fr, rm -r -f, rm -f -r
  if echo "$msg" | grep -qiE 'rm\s+(-[rR][fF]|-r\s+-f|-f\s+-r)'; then
    destructive=1
  fi

  # Pattern 2: git push --force / -f
  if echo "$msg" | grep -qiE 'git\s+push\s+(-f|--force)'; then
    destructive=1
  fi

  # Pattern 3: DROP TABLE
  if echo "$msg" | grep -qiE 'DROP\s+TABLE'; then
    destructive=1
  fi

  # Pattern 4: DELETE FROM โดยไม่มี WHERE
  if echo "$msg" | grep -qiE 'DELETE\s+FROM' && ! echo "$msg" | grep -qi 'WHERE'; then
    destructive=1
  fi

  # Pattern 5: TRUNCATE TABLE
  if echo "$msg" | grep -qiE 'TRUNCATE\s+TABLE'; then
    destructive=1
  fi

  if [ "$destructive" -eq 1 ]; then
    log_msg="$(date '+%Y-%m-%d %H:%M:%S') [BLOCKED] Destructive pattern detected in message: $msg"
    printf '%s\n' "$log_msg" >> /var/log/bus_guard.log
    return 1
  fi

  return 0
}
```

### จุดที่ต้องติดตั้ง (Hook Point)

ใน `bus.sh` ภายในฟังก์ชันที่ทำหน้าที่ส่งข้อความ (เช่น `route_message()` หรือ `bus_send()`) ก่อนที่จะเรียกใช้คำสั่ง route จริง ให้เพิ่มการเรียก guard function ดังนี้:

```sh
if ! guard_nothing_is_deleted "$MSG_BODY"; then
  return 1  # หรือ exit 1 ตามบริบทของ bus.sh
fi
```

เพื่อให้ข้อความที่อาจเป็นอันตรายถูกบล็อกก่อนถึงปลายทางตามนโยบาย `Nothing-is-Deleted`
