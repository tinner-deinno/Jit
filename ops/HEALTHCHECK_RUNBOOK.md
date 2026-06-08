# Jit Health Check Runbook

## ภาพรวม

เอกสารนี้อธิบายระบบ health checks และ liveness probes สำหรับ Hermes Discord Bot และ Heartbeat Monitor

## Components

| Component | Port | Health Endpoint | systemd Service |
|-----------|------|-----------------|-----------------|
| Hermes Discord Bot | 47780 | `/healthz` | `hermes-discord.service` |
| Heartbeat Monitor | N/A | File-based | `jit-heartbeat.service` |

---

## Health Check Endpoints

### Hermes `/healthz`

```bash
curl http://localhost:47780/healthz
# Response: ok (HTTP 200)
```

**Implementation:** `hermes-discord/bot.js` lines 773-790

```javascript
function startHealthServer() {
  healthServer = http.createServer((req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200);
      res.end('ok');
    } else {
      res.writeHead(404);
      res.end('not found');
    }
  });
  healthServer.listen(HEALTH_PORT, () => {
    console.log(`✅ Health endpoint listening on port ${HEALTH_PORT} (/healthz)`);
  });
}
```

---

## Systemd Configuration

### Watchdog Settings

Both services use systemd watchdog with 30-second timeout:

```ini
[Service]
WatchdogSec=30
RuntimeMaxSec=86400  # 24 hours max runtime before auto-restart
```

### Timer Schedule

`jit-healthcheck.timer` runs every 5 minutes:

```ini
[Timer]
OnBootSec=2min       # First check 2 minutes after boot
OnUnitActiveSec=5min # Then every 5 minutes
Persistent=true      # Run missed checks if system was asleep
RandomizedDelaySec=30 # Add jitter to prevent thundering herd
```

---

## Installation

### 1. Copy service files to systemd

```bash
sudo cp /workspaces/Jit/ops/systemd/*.service /etc/systemd/system/
sudo cp /workspaces/Jit/ops/systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

### 2. Enable and start services

```bash
# Enable services
sudo systemctl enable hermes-discord.service jit-heartbeat.service
sudo systemctl enable jit-healthcheck.timer

# Start services
sudo systemctl start hermes-discord.service jit-heartbeat.service
sudo systemctl start jit-healthcheck.timer
```

### 3. Verify status

```bash
# Check service status
systemctl status hermes-discord.service jit-heartbeat.service

# Check timer status
systemctl list-timers | grep jit-healthcheck
systemctl status jit-healthcheck.timer

# View recent health check logs
journalctl -u jit-healthcheck.service -n 20 --no-pager
```

---

## Health Check Script

Location: `/workspaces/Jit/ops/systemd/jit-healthcheck.sh`

**Checks performed:**

1. **Hermes HTTP health** — GET `/healthz` on port 47780
2. **Heartbeat freshness** — Status file age < 5 minutes
3. **Systemd service state** — Both services must be `active`

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_HEALTH_URL` | `http://localhost:47780/healthz` | Hermes health endpoint |
| `HEARTBEAT_STATUS_FILE` | `/tmp/innova-discord-heartbeat.status` | Heartbeat status file path |
| `MAX_HEARTBEAT_AGE_SEC` | `300` | Maximum allowed heartbeat age (seconds) |

---

## Incident Response

### P1: Hermes Unhealthy

**Symptoms:**
- `curl localhost:47780/healthz` returns nothing or error
- `systemctl status hermes-discord.service` shows `failed`

**Actions:**
```bash
# 1. Check logs
journalctl -u hermes-discord.service -n 50 --no-pager

# 2. Restart service
sudo systemctl restart hermes-discord.service

# 3. Verify recovery
curl http://localhost:47780/healthz
systemctl status hermes-discord.service
```

**Escalation:** Notify vaja → human if not recovered in 5 minutes

---

### P2: Heartbeat Stale

**Symptoms:**
- Health check reports heartbeat file > 5 minutes old
- No heartbeat updates in logs

**Actions:**
```bash
# 1. Check heartbeat service
systemctl status jit-heartbeat.service

# 2. Check heartbeat logs
journalctl -u jit-heartbeat.service -n 50 --no-pager

# 3. Verify status file exists
ls -la /tmp/innova-discord-heartbeat.status
cat /tmp/innova-discord-heartbeat.status

# 4. Restart if needed
sudo systemctl restart jit-heartbeat.service
```

---

### P3: Health Check Failing

**Symptoms:**
- `jit-healthcheck.service` exits non-zero
- Logs show specific failure reason

**Actions:**
```bash
# 1. Run health check manually
bash /workspaces/Jit/ops/systemd/jit-healthcheck.sh

# 2. Check all service states
systemctl status hermes-discord.service jit-heartbeat.service

# 3. Review health check logs
journalctl -u jit-healthcheck.service -n 30 --no-pager
```

---

## Monitoring Commands

```bash
# Quick health summary
curl -sf http://localhost:47780/healthz && echo "Hermes: OK" || echo "Hermes: FAIL"
ls -la /tmp/innova-discord-heartbeat.status && echo "Heartbeat: OK" || echo "Heartbeat: FAIL"

# Watch health checks in real-time
journalctl -f -u jit-healthcheck.service

# Check timer next run time
systemctl list-timers jit-healthcheck.timer

# View watchdog status
systemctl show hermes-discord.service | grep -i watch
systemctl show jit-heartbeat.service | grep -i watch
```

---

## Files Changed (JIT-010)

| File | Purpose |
|------|---------|
| `hermes-discord/bot.js` | Added `/healthz` endpoint on port 47780 (already present) |
| `ops/systemd/hermes-discord.service` | Added `WatchdogSec=30`, `RuntimeMaxSec=86400` |
| `ops/systemd/jit-heartbeat.service` | Added `WatchdogSec=30`, `RuntimeMaxSec=86400` |
| `ops/systemd/jit-healthcheck.service` | New oneshot service for health checks |
| `ops/systemd/jit-healthcheck.timer` | New timer — runs every 5 minutes |
| `ops/systemd/jit-healthcheck.sh` | New health check script |
| `ops/HEALTHCHECK_RUNBOOK.md` | This runbook documentation |

---

## Acceptance Criteria ✅

- [x] Hermes `/healthz` endpoint on port 47780
- [x] Systemd watchdog configured (`WatchdogSec=30`)
- [x] `jit-healthcheck.timer` runs every 5 minutes
- [x] Runbook documented at `ops/HEALTHCHECK_RUNBOOK.md`
