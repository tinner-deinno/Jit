# Jit Heartbeat systemd Service & Log Rotation

## Installation

### 1. Copy systemd service file

```bash
sudo cp /workspaces/Jit/systemd/jit-heartbeat.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### 2. Copy logrotate config

```bash
sudo cp /workspaces/Jit/systemd/logrotate-jit-heartbeat /etc/logrotate.d/jit-heartbeat
```

### 3. Create log directory (if not using systemd's LogsDirectory)

```bash
sudo mkdir -p /var/log/jit
sudo chown innova:innova /var/log/jit
sudo chmod 0755 /var/log/jit
```

### 4. Enable and start service

```bash
sudo systemctl enable jit-heartbeat
sudo systemctl start jit-heartbeat
```

### 5. Verify

```bash
# Check service status
systemctl status jit-heartbeat

# View logs via journalctl
journalctl -u jit-heartbeat -f

# View logs via file
tail -f /var/log/jit/innova-heartbeat-daemon.log

# Test log rotation
logrotate -f /etc/logrotate.d/jit-heartbeat
ls -la /var/log/jit/
```

## Log Rotation Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| frequency | daily | Rotate every day |
| keep | 14 | Keep 14 rotated logs |
| compress | yes | Compress old logs with gzip |
| delaycompress | yes | Compress on next rotation (not immediately) |
| size | 10M | Also rotate if file exceeds 10MB |
| maxage | 30 days | Delete logs older than 30 days |

## Resource Limits

- Memory: 512M max
- CPU: 10% quota
- Log rate limit: 1000 messages per 30s

## Circuit Breaker

Service will NOT restart automatically if exit code is 42 (circuit breaker tripped). Manual intervention required.
