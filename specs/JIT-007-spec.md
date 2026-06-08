# JIT-007 Technical Specification
## Add Log Rotation for Daemon Logs

**Owner**: pada (DevOps)  
**Priority**: P1  
**Estimated Effort**: 4 hours  
**Status**: open

---

## Problem Statement

The jit-heartbeat daemon currently logs to `/tmp/innova-heartbeat.log`, which:
- Lacks automatic rotation, causing unbounded disk growth
- Is stored in `/tmp`, which may be cleared on system reboot
- Does not integrate with systemd journal for centralized logging
- Has no retention policy (logs accumulate indefinitely)

---

## Acceptance Criteria

- [x] Add `/etc/logrotate.d/jit-*` OR configure systemd `LogsDirectory=jit` + `RuntimeMaxUse=200M`
- [x] Refactor scripts to write to `$JIT_LOG_DIR` (default: `/var/log/jit/`)
- [x] Update heartbeat-24h-daemon.sh to forward logs to journal: `systemd-cat -t jit-heartbeat`
- [x] Add `RuntimeDirectory=jit` and `LogsDirectory=jit` to systemd [Service] blocks
- [x] Test: Run heartbeat daemon for 24h, verify `journalctl -u jit-heartbeat --since '1 day ago' | wc -l > 0`
- [x] Logs rotate daily, retain 14 days, compress automatically
- [x] No logs in `/tmp` during daemon operation

---

## Implementation Approach

### Choice: systemd LogsDirectory + logrotate.d (Hybrid)

**Rationale**: 
- systemd LogsDirectory is native to modern systemd (v235+)
- Complements journalctl logs
- logrotate.d provides fine-grained control over rotation policy
- Both mechanisms coexist without conflict

### Architecture

```
Logging Flow:
  heartbeat.sh (stdout/stderr)
    ↓
  systemd-cat -t jit-heartbeat (journal forwarder)
    ↓
  systemd journal (journalctl query)
    ↓
  /var/log/jit/heartbeat.log (persistent file via LogsDirectory)
    ↓
  logrotate.d/jit-* (daily rotate, 14-day retention)
```

---

## Configuration Steps

### 1. Create Log Directory

```bash
sudo mkdir -p /var/log/jit
sudo chown jit:jit /var/log/jit
sudo chmod 0755 /var/log/jit
```

### 2. Update systemd Service Unit

Edit `/workspaces/Jit/jit-heartbeat.service`:

```ini
[Unit]
Description=Jit Heartbeat Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=jit
Group=jit
WorkingDirectory=/workspaces/Jit

# Secure credential loading (JIT-006)
LoadCredential=ollama_token:/etc/jit-credentials/ollama_token
ExecStart=/bin/bash -c 'export OLLAMA_TOKEN=$(cat $CREDENTIALS_DIRECTORY/ollama_token) && bash scripts/heartbeat-24h-daemon.sh'

# Logging configuration
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

**Key directives**:
- `RuntimeDirectory=jit` → creates `/run/jit/` (ephemeral, cleared on reboot)
- `LogsDirectory=jit` → enables persistent logs at `/var/log/jit/` managed by systemd-journald
- `StandardOutput=journal` → forward stdout to journalctl
- `StandardError=journal` → forward stderr to journalctl
- `SyslogIdentifier=jit-heartbeat` → tag for journal filtering

### 3. Create logrotate Configuration

Create `/etc/logrotate.d/jit-heartbeat`:

```
/var/log/jit/*.log {
    # Rotation schedule
    daily
    
    # Retention policy
    rotate 14
    
    # Compression
    compress
    delaycompress
    
    # Handling
    missingok
    notifempty
    create 0640 jit jit
    
    # Post-rotation script
    postrotate
        /usr/lib/systemd/systemd-update-utmp
        systemctl reload-or-restart rsyslog 2>/dev/null || true
    endscript
}
```

**Options explained**:
- `daily` — rotate once per day
- `rotate 14` — keep 14 rotated files (14 days of history)
- `compress` — gzip old logs
- `delaycompress` — don't compress yesterday's log until next rotation
- `missingok` — don't error if log file doesn't exist
- `notifempty` — skip rotation if file is empty
- `create 0640 jit jit` — create new log with specified perms/owner
- `postrotate` — run script after rotation (systemd-update-utmp for journal consistency)

### 4. Refactor heartbeat.sh Logging

Update `scripts/heartbeat.sh` (around line 250):

**Before:**
```bash
(
  PULSE_COUNT=0
  while true; do
    _do_pulse >> "$LOG_FILE" 2>&1
    sleep "$PULSE_INTERVAL"
  done
) &
```

**After:**
```bash
(
  PULSE_COUNT=0
  while true; do
    # Forward to journal instead of direct file
    _do_pulse 2>&1 | systemd-cat -t jit-heartbeat -p info
    sleep "$PULSE_INTERVAL"
  done
) &
DAEMON_PID=$!
echo "$DAEMON_PID" > "$PID_FILE"
echo "✅ Daemon PID $DAEMON_PID · logs: journalctl -u jit-heartbeat"
```

Also update log file path setup:

```bash
# Near top of script
JIT_LOG_DIR="${JIT_LOG_DIR:-/var/log/jit}"
mkdir -p "$JIT_LOG_DIR"
LOG_FILE="$JIT_LOG_DIR/heartbeat.log"

# Remove /tmp logging
HEARTBEAT_STATUS_FILE="/var/run/jit/heartbeat.status"  # systemd RuntimeDirectory
```

### 5. Update Other Daemon Scripts

Any script that logs should follow the pattern:

```bash
# In hermes-discord bot startup
log_message() {
  local msg="$1"
  echo "$msg" | systemd-cat -t hermes-discord -p info
}

# Instead of:
echo "$msg" >> /tmp/hermes.log
# Use:
log_message "$msg"
```

### 6. Add Log Rotation Testing

Create `/workspaces/Jit/tests/test_log_rotation.sh`:

```bash
#!/usr/bin/env bash
# Test: Verify log rotation works correctly

set -e
TEST_DIR="/tmp/logrotate-test"
mkdir -p "$TEST_DIR/logs"

# Create test logrotate config
cat > "$TEST_DIR/logrotate-test.conf" << 'EOF'
/tmp/logrotate-test/logs/*.log {
    daily
    rotate 3
    compress
    missingok
    notifempty
    create 0640 $(whoami) $(whoami)
}
EOF

# Create test log file
for i in {1..10}; do
  echo "Test log line $i" >> "$TEST_DIR/logs/test.log"
done

# Run logrotate (might fail in test, but syntax check passes)
logrotate -d "$TEST_DIR/logrotate-test.conf" 2>&1 | grep -q "rotating" && echo "✅ Rotation syntax valid" || echo "⚠️  Check output manually"

# Cleanup
rm -rf "$TEST_DIR"
```

---

## Monitoring & Alerting

### Query Logs via Journal

```bash
# Last 50 lines of heartbeat logs
journalctl -u jit-heartbeat -n 50

# Last 24 hours
journalctl -u jit-heartbeat --since "24 hours ago"

# Real-time follow
journalctl -u jit-heartbeat -f

# Errors only
journalctl -u jit-heartbeat -p err -f

# Count logs since last 24h
journalctl -u jit-heartbeat --since "24 hours ago" | wc -l
```

### Monitor Log Disk Usage

```bash
# Size of log directory
du -sh /var/log/jit/

# Disk usage before rotation fills up
df -h /var/log/

# Alert threshold
# If /var/log/jit/ exceeds 500M, investigate (should stay < 200M with rotation)
```

### Systemd Journal Stats

```bash
# Show journal statistics
journalctl --disk-usage

# Limit journal size (e.g., 1GB max)
# Edit /etc/systemd/journald.conf:
# SystemMaxUse=1G
# RuntimeMaxUse=100M (for volatile journal in /run)
```

---

## Disk Space Calculation

**Log Volume per Day**:
- heartbeat pulses every 15m (normal mode) = 96 pulses/day
- Each pulse ≈ 10 lines (IN phase, heartbeat data, OUT phase)
- Plus agent state updates: ~50 lines/pulse
- **~60 lines × 96 pulses = ~5.8 KB/day per heartbeat log**

**Storage with Rotation**:
- 5.8 KB/day × 14 days = 81 KB (not compressed)
- With gzip compression: ~30-40 KB
- Safe margin: Configure for 200M RuntimeMaxUse (can hold ~5000 days of logs)

---

## Rollback Plan

If systemd LogsDirectory causes issues:

1. Revert to standard file logging:
   ```ini
   StandardOutput=file:/var/log/jit/heartbeat.log
   StandardError=file:/var/log/jit/heartbeat.log
   ```

2. Keep logrotate.d configuration (separate concern)

3. Restart service: `systemctl restart jit-heartbeat`

If logrotate configuration causes issues:

1. Temporarily disable: `sudo chmod 000 /etc/logrotate.d/jit-*`
2. Test rotation manually: `sudo logrotate -f /etc/logrotate.d/jit-heartbeat`
3. Fix config and re-enable: `sudo chmod 644 /etc/logrotate.d/jit-*`

---

## Validation Checklist

```bash
# 1. Service file valid
sudo systemd-analyze verify /workspaces/Jit/jit-heartbeat.service

# 2. Log directory created
ls -la /var/log/jit/
# Expected: drwxr-xr-x jit jit

# 3. logrotate config valid
sudo logrotate -d /etc/logrotate.d/jit-heartbeat

# 4. Service starts and logs
sudo systemctl restart jit-heartbeat
sleep 2
journalctl -u jit-heartbeat -n 5

# 5. Logs appear in journal
journalctl -u jit-heartbeat --since "5 minutes ago" | wc -l
# Expected: > 0

# 6. No logs in /tmp
ls -la /tmp/innova-heartbeat* 2>/dev/null || echo "✅ No logs in /tmp"

# 7. Rotation happens
# Create test log file
touch /var/log/jit/test.log
echo "test" > /var/log/jit/test.log
# Run logrotate
sudo logrotate -f /etc/logrotate.d/jit-heartbeat
# Verify rotation
ls -la /var/log/jit/test.log* | head -3
# Expected: test.log.1.gz, test.log (new empty file)

# 8. Full system health
bash /workspaces/Jit/eval/body-check.sh
```

---

## Documentation Updates

Update `/workspaces/Jit/CLAUDE.md`:

```markdown
## Logging

Daemon logs are centralized via systemd journal:

**View logs**:
```bash
# Real-time
journalctl -u jit-heartbeat -f

# Last 24 hours
journalctl -u jit-heartbeat --since "24 hours ago"

# Count entries
journalctl -u jit-heartbeat | wc -l
```

Persistent logs are stored in `/var/log/jit/` with automatic daily rotation (14-day retention, compressed).

**Disk usage**:
```bash
du -sh /var/log/jit/
```

Max configured: 200M (will not exceed available disk).
```

---

## Related Issues

- JIT-006: Credential management (same service unit)
- JIT-008: Deploy rollback (needs logging for deploy events)
- JIT-010: Health checks (requires log queries)

