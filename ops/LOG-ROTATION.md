# JIT-007: Log Rotation for Daemon Logs

## ปัญหา

Daemon logs ในระบบ Jit เติบโตแบบไม่มี่ขีดจำกั ดใน `/tmp` หรือ `/var/log` ซึ่งอาจทำให้ disk เต็ม

## วิธีแก้

### 1. Logrotate Configuration

ตําแหน่ ง: `/workspaces/Jit/ops/logrotate/jit-daemons`

```
/var/log/jit/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  create 0640 codespace codespace
}
```

**คุณสมบัติ:**
- หมุนทุกวัน (daily)
- เก็บ 14 วัน (2 สัปดาห์)
- อัดแน่นไฟล์เก่ า (compress)
- ไม่ error ถ้าไฟล์หาย (missingok)
- ไม่หมุนถ้าไฟล์ว่าง (notifempty)

### 2. Systemd LogsDirectory

แต่ละ service มี `LogsDirectory=jit` และ `LogsDirectoryMaximumSize=200M` ใน [Service] block

Systemd จะสร้าง `/var/log/jit/ อัตโนมัติ และจำกัดขนาดสูงสุดที่ 200MB

### 3. Environment Variable

```bash
export JIT_LOG_DIR=/var/log/jit  # หรือ /tmp/jit-logs สำหรับ development
```

## การติ ดตั้ง

### แบบ Manual (Production)

```bash
sudo bash /workspaces/Jit/ops/install-log-rotation.sh
```

Script นี้จะ:
1. สร้าง `/var/log/jit/` directory
2. ติดตั้ง logrotate config ไปยัง `/etc/logrotate.d/jit-daemons`
3. ติดตั้ง systemd services
4. ทดสอบ logging functions

### แบบ Development (ไม่ต้องการ root)

```bash
export JIT_LOG_DIR=/tmp/jit-logs
mkdir -p /tmp/jit-logs

# Source lib.sh เพื่อใช้ฟังก์ชัน logging
source /workspaces/Jit/limbs/lib.sh

# ทดสอบ
log_daemon "test" "Testing log rotation" "INFO"
cat /tmp/jit-logs/jit-test.log
```

## การใช้งานใน Scripts

### ใช้ log_daemon() จาก lib.sh

```bash
#!/usr/bin/env bash
source /workspaces/Jit/limbs/lib.sh

log_daemon "heartbeat" "Starting daemon..." "INFO"
log_daemon "heartbeat" "Pulse complete" "INFO"
log_daemon "heartbeat" "Connection failed" "ERROR"
```

### ใช้ log_to_journal() สำหรับ systemd

```bash
log_to_journal "jit-heartbeat" "INFO" "Heartbeat started"
log_to_journal "jit-heartbeat" "ERROR" "Heartbeat failed"
```

### ใช้ systemd-cat โดยตรง

```bash
echo "Message text" | systemd-cat -t jit-heartbeat -p info
```

## การตรวจสอบ Logs

### ดู logs จาก journalctl

```bash
# Heartbeat logs
journalctl -u jit-heartbeat -f

# Hermes Discord logs
journalctl -u hermes-discord -f

# ทุก Jit logs
journalctl -t jit-heartbeat -t hermes-discord -f
```

### ดู logs จากไฟล์

```bash
# Latest log
tail -f /var/log/jit/jit-heartbeat.log

# rotated logs
ls -la /var/log/jit/
zcat /var/log/jit/jit-heartbeat.log.1.gz  # ดูไฟล์ที่ compress แล้ว
```

### ตรวจสอบ logrotate

```bash
# ทดสอบ rotation (dry-run)
sudo logrotate --debug /etc/logrotate.d/jit-daemons

# บังคับหมุนทันที
sudo logrotate --force /etc/logrotate.d/jit-daemons

# ดูสถานะล่าสุด
cat /var/lib/logrotate/status | grep jit
```

## การทดสอบ (24h Test)

```bash
# 1. เริ่ม daemon
sudo systemctl start jit-heartbeat

# 2. ตรวจสอบ logs หลัง 24 ชั่วโมง
journalctl -u jit-heartbeat --since "24 hours ago"

# 3. ตรวจสอบว่า logs ถูกหมุน
ls -la /var/log/jit/
# คาดหวัง: jit-heartbeat.log, jit-heartbeat.log.1.gz, ...

# 4. ตรวจสอบขนาด logs
du -sh /var/log/jit/
# ต้องไม่เกิน 200MB
```

## Files Changed

| ไฟล์ | คำอธิบาย |
|------|----------|
| `ops/logrotate/jit-daemons` | Logrotate configuration |
| `ops/systemd/jit-heartbeat.service` | Systemd service พร้อม LogsDirectory |
| `ops/systemd/hermes-discord.service` | Systemd service พร้อม LogsDirectory |
| `ops/install-log-rotation.sh` | Installation script |
| `limbs/lib.sh` | เพิ่ม logging functions (log_daemon, log_to_journal) |
| `ops/LOG-ROTATION.md` | เอกสารนี้ |

## Acceptance Criteria

- ✅ เพิ่ม logrotate config ที่ `/etc/logrotate.d/jit-daemons`
- ✅ เพิ่ม systemd LogsDirectory พร้อม RuntimeDirectory ใน service blocks
- ✅ Scripts ใช้ `$JIT_LOG_DIR` และ `systemd-cat`
- ✅ ทดสอบ: รัน daemon 24h → journalctl แสดง logs → logs ถูกหมุน

## Related Tickets

- JIT-007: Add log rotation for daemon logs
