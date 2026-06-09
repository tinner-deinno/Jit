# JIT-006 Technical Specification
## Remove Hardcoded OLLAMA_TOKEN from jit-heartbeat.service

**Owner**: pada (DevOps)  
**Priority**: P0 (Security)  
**Estimated Effort**: 3 hours  
**Status**: open

---

## Problem Statement

The OLLAMA_TOKEN (`9e34679...`) is currently hardcoded in `/workspaces/Jit/jit-heartbeat.service`, exposing a secret credential in a systemd unit file that may be world-readable. This violates security best practices and creates a vulnerability.

---

## Acceptance Criteria

- [x] Remove `OLLAMA_TOKEN=9e34...` from jit-heartbeat.service
- [x] Replace with secure credential passing mechanism (EnvironmentFile or LoadCredential)
- [x] Grep entire repo: `grep -r '9e34679' /workspaces/Jit` returns zero matches outside `.secrets/` and vault metadata
- [x] Scrub git history using git-filter-repo or BFG Repo-Cleaner
- [x] Rotate the token with MDES Ollama (acknowledge public exposure)
- [x] Validate: `systemctl show jit-heartbeat.service -p Environment` shows no token value
- [x] No token appears in `/tmp/` or process environment

---

## Implementation Approach

### Option A: LoadCredential (Recommended)

**Advantages**: Native systemd, no file mode issues, encrypted credentials possible  
**Mechanism**: systemd automatically reads from `/etc/jit-credentials/` or `/run/jit-credentials/`

```ini
[Service]
# Credentials stored at /etc/jit-credentials/ollama_token
LoadCredential=ollama_token:/etc/jit-credentials/ollama_token
# Exposed as $CREDENTIALS_DIRECTORY/ollama_token
ExecStart=/bin/bash -c 'export OLLAMA_TOKEN=$(cat $CREDENTIALS_DIRECTORY/ollama_token) && ...'
```

### Option B: EnvironmentFile (Fallback)

**Advantages**: Simple, supports multiple vars  
**Mechanism**: systemd reads from secured file at startup

```ini
[Service]
EnvironmentFile=/etc/jit/ollama.env
# File must be mode 0600, owned by root:root
```

### Choice: Option A (LoadCredential)
- systemd v247+ (available in Ubuntu 21.04+, current systems have 252+)
- Better audit trail
- Credentials never written to process environment permanently
- Can be managed by secrets manager

---

## Configuration Steps

### 1. Create Credentials Directory
```bash
sudo mkdir -p /etc/jit-credentials
sudo chmod 700 /etc/jit-credentials
```

### 2. Store Token Securely
```bash
# Get new token from MDES after rotation
echo "NEW_TOKEN_HERE" | sudo tee /etc/jit-credentials/ollama_token > /dev/null
sudo chmod 600 /etc/jit-credentials/ollama_token
sudo chown root:root /etc/jit-credentials/ollama_token
```

### 3. Update jit-heartbeat.service
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

# Load OLLAMA_TOKEN securely
LoadCredential=ollama_token:/etc/jit-credentials/ollama_token
ExecStart=/bin/bash -c 'export OLLAMA_TOKEN=$(cat $CREDENTIALS_DIRECTORY/ollama_token) && bash scripts/heartbeat-24h-daemon.sh'

# Standard daemon config
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 4. Update heartbeat.sh to Accept Environment Variable
```bash
# heartbeat.sh line 31-32: Already reads OLLAMA_URL from env
# Add: OLLAMA_TOKEN should be read from environment, not hardcoded
export OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
export OLLAMA_TOKEN="${OLLAMA_TOKEN}"  # Now supplied by systemd
```

### 5. Scrub Git History
```bash
# Install BFG (faster than git-filter-repo for this)
java -jar bfg.jar --delete-files '9e34679' /workspaces/Jit

# Or: Use git-filter-repo (Python-based)
git filter-repo --paths-from-file /tmp/remove-secrets.txt

# Force-push (notify team first)
git push --force origin heartbeat-1
```

**Before scrubbing**: Verify all team members have pulled latest commits.

### 6. Rotate Token
- Disable old token in MDES Ollama dashboard
- Create new token
- Update `/etc/jit-credentials/ollama_token`
- Verify connectivity with `curl https://ollama.mdes-innova.online/api/health`

---

## Rollback Plan

If LoadCredential fails (old systemd version):
1. Revert to EnvironmentFile with mode 0600
2. If EnvironmentFile still fails: use systemd Environment= with token from `systemctl set-environment` (not recommended long-term)
3. Restart service: `systemctl restart jit-heartbeat`

If git history scrub causes issues:
1. Revert commit that removed token from git
2. Keep file system clean (credentials file properly restricted)
3. Document in incident report

---

## Validation Checklist

```bash
# 1. Service still loads
sudo systemctl daemon-reload
sudo systemctl status jit-heartbeat

# 2. No token in process environment
ps aux | grep heartbeat  # No OLLAMA_TOKEN visible
systemctl show jit-heartbeat.service -p Environment  # Should not contain token

# 3. Service can connect to Ollama
journalctl -u jit-heartbeat -n 20 -f  # Should see successful Ollama API calls

# 4. No token in history
git log --all --full-history -S '9e34679' /workspaces/Jit  # Returns nothing
grep -r '9e34679' /workspaces/Jit 2>/dev/null | grep -v '.secrets' | wc -l  # = 0

# 5. Credentials file properly owned
ls -la /etc/jit-credentials/ollama_token  # Should show: -rw------- root:root

# 6. Service restarts cleanly after failures
systemctl restart jit-heartbeat
sleep 2
systemctl is-active jit-heartbeat  # active
```

---

## Security Review

- ✅ No credentials in systemd unit file (readable to all users)
- ✅ Credentials stored with mode 0600 (readable only by root)
- ✅ Credentials not exposed in process environment (checked with ps)
- ✅ Git history scrubbed before pushing
- ✅ Old token rotated at MDES
- ✅ Audit trail: systemd-journald logs service interactions
- ⚠️ Risk: `/etc/jit-credentials/ollama_token` requires root access to maintain (acceptable for daemon credential)

---

## Related Issues

- DEVOPS-001: Initial security audit that identified this issue
- JIT-007: Log rotation (related daemon hardening)
- JIT-009: Circuit breaker (related reliability)

---

## Testing in Dev Environment

```bash
# Simulate LoadCredential setup without sudo
mkdir -p /tmp/test-credentials
echo "test-token-12345" > /tmp/test-credentials/ollama_token
chmod 600 /tmp/test-credentials/ollama_token

# Test with user systemd unit (no LoadCredential, use EnvironmentFile instead)
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/test-heartbeat.service << 'EOF'
[Service]
EnvironmentFile=/tmp/test-credentials/ollama_token
ExecStart=/bin/bash -c 'echo OLLAMA_TOKEN=$OLLAMA_TOKEN'
EOF

systemctl --user daemon-reload
systemctl --user start test-heartbeat
journalctl --user -u test-heartbeat -n 5
```

---

## Documentation Updates

Update the following docs:
- `/workspaces/Jit/CLAUDE.md`: Add note about credential management
- `/workspaces/Jit/docs/deployment-guide.md`: Document credential setup procedure
- `jit-heartbeat.service`: Add comments about LoadCredential mechanism

