# JIT-007 Operational Runbook
## Add Log Rotation for Daemon Logs

**Audience**: pada (DevOps operator)  
**Status**: DRAFT  
**Execution Time**: ~1 hour

---

## Quick Start

```bash
# 1. Create log directory
sudo mkdir -p /var/log/jit
sudo chown jit:jit /var/log/jit
sudo chmod 0755 /var/log/jit

# 2. Create logrotate configuration
sudo tee /etc/logrotate.d/jit-heartbeat > /dev/null << 'EOF'
/var/log/jit/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 jit jit
    postrotate
        /usr/lib/systemd/systemd-update-utmp
        systemctl reload-or-restart rsyslog 2>/dev/null || true
    endscript
}
EOF

# 3. Update systemd service (see Step 2)
# 4. Reload systemd
sudo systemctl daemon-reload

# 5. Restart service
sudo systemctl restart jit-heartbeat

# 6. Validate (see Validation section)
```

---

## Step-by-Step Procedure

### Step 1: Pre-Flight Checks

```bash
# Verify systemd version (need 235+)
systemctl --version | head -1
# Output: systemd 252 (or higher)

# Verify logrotate installed
which logrotate
# Output: /usr/sbin/logrotate

# Check disk space (need > 1GB in /var/log)
df -h /var/log
# Output: ... 50G available ...

# Verify sudo access
sudo -n systemctl status >/dev/null 2>&1 && echo "✅ sudo ready" || echo "⚠️  sudo password needed"
```

### Step 2: Update systemd Service File

**File**: `/workspaces/Jit/jit-heartbeat.service`

**Changes to [Service] section**:

```ini
[Service]
Type=simple
User=jit
Group=jit
WorkingDirectory=/workspaces/Jit

# Credential loading (from JIT-006)
LoadCredential=ollama_token:/etc/jit-credentials/ollama_token
ExecStart=/bin/bash -c 'export OLLAMA_TOKEN=$(cat $CREDENTIALS_DIRECTORY/ollama_token) && bash scripts/heartbeat-24h-daemon.sh'

# Logging configuration (new)
RuntimeDirectory=jit
LogsDirectory=jit
StandardOutput=journal
StandardError=journal
SyslogIdentifier=jit-heartbeat

# Reliability
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Key additions**:
- `RuntimeDirectory=jit` → systemd creates `/run/jit/` at startup
- `LogsDirectory=jit` → systemd journalctl writes to `/var/log/jit/`
- `StandardOutput=journal` → forward all stdout to journal
- `StandardError=journal` → forward all stderr to journal
- `SyslogIdentifier=jit-heartbeat` → label for journal filtering

### Step 3: Create Log Directory

```bash
# Create directory
sudo mkdir -p /var/log/jit

# Set permissions
sudo chown jit:jit /var/log/jit
sudo chmod 0755 /var/log/jit

# Verify
ls -la /var/log/jit
# Output: drwxr-xr-x 2 jit jit 4096 Jun  7 10:00 .
```

### Step 4: Create logrotate Configuration

```bash
# Create config file
sudo tee /etc/logrotate.d/jit-heartbeat > /dev/null << 'EOF'
/var/log/jit/*.log {
    # Schedule: rotate daily at midnight
    daily
    
    # Keep 14 days of history
    rotate 14
    
    # Compression
    compress
    delaycompress
    
    # Handling
    missingok
    notifempty
    create 0640 jit jit
    
    # Post-rotation cleanup
    postrotate
        /usr/lib/systemd/systemd-update-utmy
        systemctl reload-or-restart rsyslog 2>/dev/null || true
    endscript
}
EOF

# Verify syntax
sudo logrotate -d /etc/logrotate.d/jit-heartbeat
# Output: reading config file /etc/logrotate.d/jit-heartbeat
#         Handling 1 logs
#         rotating pattern: "/var/log/jit/*.log"  daily (14 rotations)
```

### Step 5: Refactor heartbeat.sh

**File**: `scripts/heartbeat.sh`

**Changes** (around line 38-40):

**Before:**
```bash
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"
LAST_ACTIVITY_FILE="/tmp/heartbeat-last-active.timestamp"
DISCORD_ACTIVITY_FILE="${DISCORD_ACTIVITY_FILE:-/tmp/discord-bot-last-active.timestamp}"
HEARTBEAT_STATUS_FILE="${HEARTBEAT_STATUS_FILE:-/tmp/innova-discord-heartbeat.status}"
LOG_FILE="/tmp/innova-heartbeat.log"
```

**After:**
```bash
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"
JIT_LOG_DIR="${JIT_LOG_DIR:-/var/log/jit}"
LAST_ACTIVITY_FILE="/tmp/heartbeat-last-active.timestamp"
DISCORD_ACTIVITY_FILE="${DISCORD_ACTIVITY_FILE:-/tmp/discord-bot-last-active.timestamp}"
HEARTBEAT_STATUS_FILE="/run/jit/innova-discord-heartbeat.status"
LOG_FILE="$JIT_LOG_DIR/heartbeat.log"

# Ensure log directory exists
mkdir -p "$JIT_LOG_DIR"
```

**Changes** (around line 250-260, in the daemon startup loop):

**Before:**
```bash
(
  PULSE_COUNT=0
  while true; do
    _do_pulse >> "$LOG_FILE" 2>&1
    sleep "$PULSE_INTERVAL"
  done
) &
DAEMON_PID=$!
echo "$DAEMON_PID" > "$PID_FILE"
echo -e "${GREEN}✅ Daemon PID $DAEMON_PID · log: $LOG_FILE${RESET}"
```

**After:**
```bash
(
  PULSE_COUNT=0
  while true; do
    # Forward to systemd journal instead of direct file
    _do_pulse 2>&1 | systemd-cat -t jit-heartbeat -p info
    sleep "$PULSE_INTERVAL"
  done
) &
DAEMON_PID=$!
echo "$DAEMON_PID" > "$PID_FILE"
echo -e "${GREEN}✅ Daemon PID $DAEMON_PID · logs: journalctl -u jit-heartbeat -f${RESET}"
echo -e "${CYAN}💡 Persistent logs in: $JIT_LOG_DIR/${RESET}"
```

### Step 6: Update systemd Unit & Reload

```bash
# Verify syntax
sudo systemd-analyze verify /workspaces/Jit/jit-heartbeat.service
# Output: /workspaces/Jit/jit-heartbeat.service: OK

# Reload daemon configuration
sudo systemctl daemon-reload

# Check that service can start
sudo systemctl status jit-heartbeat 2>&1 | head -10
# (Will be inactive at first, that's OK)
```

### Step 7: Start Service & Verify Logging

```bash
# Start the service
sudo systemctl restart jit-heartbeat

# Wait for first pulse
sleep 3

# Check status
sudo systemctl status jit-heartbeat
# Output: Active: active (running)

# View recent logs from journal
journalctl -u jit-heartbeat -n 20
# Output: [timestamps] jit-heartbeat[PID] Pulse #1 mode=normal ...

# Verify logs directory
ls -la /var/log/jit/
# Output: -rw-r----- 1 jit jit ... heartbeat.log

# Check that logs are being written
wc -l /var/log/jit/heartbeat.log
# Output: 25 /var/log/jit/heartbeat.log (should grow)
```

### Step 8: Monitor Logs for 24+ Hours

```bash
# Day 1 setup: Start monitoring
watch -n 60 'du -h /var/log/jit/ && echo && ls -lh /var/log/jit/heartbeat.log*'

# Should see growth:
# 4.0K → 8.0K → 12K → ... (over 24 hours)

# After 24 hours, verify rotation occurred
ls -la /var/log/jit/
# Expected: heartbeat.log (current) + heartbeat.log.1.gz (yesterday)

# Force a rotation to test immediately
sudo logrotate -f /etc/logrotate.d/jit-heartbeat
# Then check:
ls -la /var/log/jit/
# Expected: heartbeat.log (new empty) + heartbeat.log.1.gz (rotated)
```

### Step 9: Verify No Logs in /tmp

```bash
# Check that old /tmp logs are not being created
ls -la /tmp/innova-heartbeat* 2>/dev/null || echo "✅ No logs in /tmp"

# Monitor for 24h
for i in {1..288}; do  # 288 = 24h at 5m intervals
  sleep 300
  ls -la /tmp/innova-heartbeat* 2>/dev/null && echo "❌ Found /tmp logs!" && break
done
echo "✅ Verified: No /tmp logs created over 24h"
```

---

## Validation Checklist

### ✅ Check 1: Service File Valid

```bash
sudo systemd-analyze verify /workspaces/Jit/jit-heartbeat.service
# Expected: OK (no errors)
```

### ✅ Check 2: Log Directory Created

```bash
ls -la /var/log/jit/
# Expected: drwxr-xr-x 2 jit jit ... jit/
```

### ✅ Check 3: logrotate Config Valid

```bash
sudo logrotate -d /etc/logrotate.d/jit-heartbeat
# Expected: reading config file ... rotating pattern ... daily ...
```

### ✅ Check 4: Service Starts & Logs

```bash
sudo systemctl restart jit-heartbeat
sleep 2
journalctl -u jit-heartbeat -n 5
# Expected: Recent entries with timestamps
```

### ✅ Check 5: 24h Log History

```bash
journalctl -u jit-heartbeat --since "24 hours ago" | wc -l
# Expected: > 0 (at least some logs from last 24h)
```

### ✅ Check 6: No Logs in /tmp

```bash
ls /tmp/innova-heartbeat* 2>/dev/null | wc -l
# Expected: 0
```

### ✅ Check 7: Logs Are Persistent

```bash
# Even after service restart, logs should persist
sudo systemctl restart jit-heartbeat
sleep 2
cat /var/log/jit/heartbeat.log | head -5
# Should show log entries
```

### ✅ Check 8: Full System Health

```bash
bash /workspaces/Jit/eval/body-check.sh
# Expected: All agents healthy
```

---

## Monitoring After Deployment

### Daily Log Size Check

```bash
# Add to cron: 0 1 * * * (runs daily at 1am)
du -h /var/log/jit/ | mail -s "Jit Log Size Report" pada@example.com
```

### Disk Space Alert

```bash
# Alert if logs exceed 100M
if [ "$(du -s /var/log/jit/ | awk '{print $1}')" -gt 100000 ]; then
  echo "⚠️  Jit logs exceed 100M" | mail -s "Disk Space Alert" pada@example.com
fi
```

### Log Entry Count Trend

```bash
# Weekly: Count logs created (should be ~500-600/day)
journalctl -u jit-heartbeat --since "7 days ago" | wc -l
# Expected: ~3500-4200 entries (500-600/day)
```

---

## Troubleshooting

### Problem: "LogsDirectory not recognized"

**Cause**: systemd version < 235

**Solution**:
```bash
# Check version
systemctl --version

# If < 235, use fallback
# Edit jit-heartbeat.service:
StandardOutput=file:/var/log/jit/heartbeat.log
StandardError=file:/var/log/jit/heartbeat.log

# Then reload
sudo systemctl daemon-reload
sudo systemctl restart jit-heartbeat
```

### Problem: Logs in /tmp still appearing

**Cause**: heartbeat.sh still using /tmp paths in some code path

**Solution**:
```bash
# Search for /tmp references in heartbeat.sh
grep -n '/tmp' /workspaces/Jit/scripts/heartbeat.sh

# Example: HEARTBEAT_STATUS_FILE="/tmp/..."
# Fix: Change to /run/jit/... or $JIT_LOG_DIR/...

# Restart after fix
sudo systemctl restart jit-heartbeat

# Verify
ls /tmp/innova-heartbeat* 2>/dev/null || echo "✅ Fixed"
```

### Problem: Rotation not happening

**Cause**: logrotate not scheduled or config invalid

**Solution**:
```bash
# Test manually
sudo logrotate -f /etc/logrotate.d/jit-heartbeat

# Verify rotation occurred
ls -la /var/log/jit/
# Should show .1.gz file

# Check logrotate logs
sudo tail -20 /var/lib/logrotate/status | grep jit

# If still failing: check systemd postrotate script
systemctl status rsyslog
# rsyslog should reload cleanly without errors
```

### Problem: Journal grows too large

**Cause**: RuntimeMaxUse or SystemMaxUse not limited

**Solution**:
```bash
# Check current journal size
journalctl --disk-usage
# If > 1GB, trim old entries

# Limit journal:
# Edit /etc/systemd/journald.conf (as root):
# SystemMaxUse=1G
# RuntimeMaxUse=100M

# Restart journald
sudo systemctl restart systemd-journald

# Verify limits
journalctl --disk-usage
```

### Problem: Permission denied on /var/log/jit/

**Cause**: Directory permissions wrong or user not jit

**Solution**:
```bash
# Fix permissions
sudo chown -R jit:jit /var/log/jit
sudo chmod 0755 /var/log/jit
sudo chmod 0640 /var/log/jit/*.log

# Restart service
sudo systemctl restart jit-heartbeat

# Verify
ls -la /var/log/jit/
```

---

## Rollback Procedure

If systemd LogsDirectory causes issues:

```bash
# 1. Revert to file logging
sudo sed -i 's/LogsDirectory=jit/# LogsDirectory=jit/' /workspaces/Jit/jit-heartbeat.service
sudo sed -i 's/StandardOutput=journal/StandardOutput=file:\/var\/log\/jit\/heartbeat.log/' /workspaces/Jit/jit-heartbeat.service

# 2. Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart jit-heartbeat

# 3. Verify
journalctl -u jit-heartbeat -n 5
# Should show logs via file fallback
```

---

## Sign-Off

After validation:

```bash
cat > /workspaces/Jit/reports/JIT-007-validation.txt << 'EOF'
JIT-007 Validation Report
Date: $(date)
Operator: pada

✅ All checks passed:
  - Log directory created with proper permissions
  - systemd unit valid
  - Logs appear in journalctl
  - logrotate configuration valid
  - No logs in /tmp/
  - 24h+ log history available
  - Rotation verified
  - Full system health OK

Status: READY FOR MERGE
EOF

# Notify completion
bash /workspaces/Jit/organs/mouth.sh tell jit "JIT-007 complete: log rotation configured, heartbeat daemon logs centralized to journalctl" 2>/dev/null || true
```

---

## References

- Spec: `/workspaces/Jit/specs/JIT-007-spec.md`
- TOR: `/workspaces/Jit/specs/tor/JIT-007-tor.md`
- systemd.service(5) manpage: `man systemd.service`
- logrotate(8) manpage: `man logrotate`

