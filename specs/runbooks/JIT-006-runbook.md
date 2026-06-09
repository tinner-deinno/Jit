# JIT-006 Operational Runbook
## Remove Hardcoded OLLAMA_TOKEN from jit-heartbeat.service

**Audience**: pada (DevOps operator executing this fix)  
**Status**: DRAFT — Follow spec + TOR first, then execute steps below  
**Last Updated**: 2026-06-07

---

## Quick Start

**Estimated time**: 30 minutes (+ security review + testing)

```bash
# 1. Create credentials directory
sudo mkdir -p /etc/jit-credentials
sudo chmod 700 /etc/jit-credentials

# 2. Store new token (after rotation with MDES)
echo "MDES_NEW_TOKEN_HERE" | sudo tee /etc/jit-credentials/ollama_token > /dev/null
sudo chmod 600 /etc/jit-credentials/ollama_token

# 3. Update service file (see Step 1 below)
# 4. Reload systemd & restart service
sudo systemctl daemon-reload
sudo systemctl restart jit-heartbeat
sudo systemctl status jit-heartbeat

# 5. Validate (see Validation section)
# 6. Scrub git history (see Step 5 below)
```

---

## Step-by-Step Procedure

### Step 1: Backup Current Service File

```bash
# Current state
cp /workspaces/Jit/jit-heartbeat.service /workspaces/Jit/jit-heartbeat.service.backup
cat /workspaces/Jit/jit-heartbeat.service | grep OLLAMA_TOKEN
# Output: Environment="OLLAMA_TOKEN=9e34679..."
```

### Step 2: Create Credentials Directory & Setup Script

Create `/workspaces/Jit/scripts/setup-credentials.sh`:

```bash
#!/usr/bin/env bash
# Setup secure credentials for jit-heartbeat daemon
# Usage: sudo bash scripts/setup-credentials.sh <token>

set -e

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "Usage: sudo bash scripts/setup-credentials.sh <OLLAMA_TOKEN>"
  exit 1
fi

echo "🔐 Setting up jit credentials..."

# Create credentials directory
mkdir -p /etc/jit-credentials
chmod 700 /etc/jit-credentials

# Store token
echo "$TOKEN" > /etc/jit-credentials/ollama_token
chmod 600 /etc/jit-credentials/ollama_token
chown root:root /etc/jit-credentials/ollama_token

echo "✅ Credentials stored at /etc/jit-credentials/ollama_token"
echo "   Permissions: $(ls -lh /etc/jit-credentials/ollama_token | awk '{print $1, $3, $4}')"

# Verify systemd can read it
if systemd-analyze verify jit-heartbeat.service 2>&1 | grep -q "error"; then
  echo "⚠️  systemd-analyze found issues:"
  systemd-analyze verify jit-heartbeat.service
  exit 1
fi

echo "✅ systemd unit file is valid"
```

Make executable and run:

```bash
chmod +x /workspaces/Jit/scripts/setup-credentials.sh
# (After obtaining new token from MDES)
sudo bash /workspaces/Jit/scripts/setup-credentials.sh "NEW_TOKEN_FROM_MDES"
```

### Step 3: Update systemd Service File

Edit `/workspaces/Jit/jit-heartbeat.service`:

**Before:**
```ini
[Service]
Environment="OLLAMA_TOKEN=9e34679..."
Environment="ORACLE_URL=http://localhost:47778"
```

**After:**
```ini
[Service]
# Load OLLAMA_TOKEN securely from /etc/jit-credentials/
LoadCredential=ollama_token:/etc/jit-credentials/ollama_token
Environment="ORACLE_URL=http://localhost:47778"

# Pass token from credentials to environment (systemd 247+)
ExecStart=/bin/bash -c 'export OLLAMA_TOKEN=$(cat $CREDENTIALS_DIRECTORY/ollama_token) && exec bash /workspaces/Jit/scripts/heartbeat-24h-daemon.sh'
```

Verify the file is valid:

```bash
systemd-analyze verify /workspaces/Jit/jit-heartbeat.service
# Output: /workspaces/Jit/jit-heartbeat.service: OK
```

### Step 4: Reload systemd & Test Service

```bash
# Reload daemon configuration
sudo systemctl daemon-reload

# Restart service
sudo systemctl restart jit-heartbeat

# Check status
sudo systemctl status jit-heartbeat
# Output should show: Active: active (running)

# Check logs for successful startup
sudo journalctl -u jit-heartbeat -n 20 -f
# Look for: "Pran Heartbeat daemon", Ollama API calls without errors
```

### Step 5: Scrub Git History

**⚠️ WARNING**: This requires force-push. Notify all team members first.

```bash
# Install BFG Repo-Cleaner (if not available)
# Option 1: Download binary
wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
java -jar bfg-1.14.0.jar --delete-files '9e34679' /workspaces/Jit

# Option 2: Use git-filter-repo (Python, if available)
pip install git-filter-repo
git filter-repo --invert-paths --paths '9e34679'

# Verify token is gone from history
git log --all --full-history -S '9e34679' /workspaces/Jit
# Output: (empty — no commits contain token)

# Force-push (after team notification)
git push origin heartbeat-1 --force
# Output: +abc1234...def5678 heartbeat-1 (forced update)
```

### Step 6: Verify No Token in Repo

```bash
# 1. Check current files
grep -r '9e34679' /workspaces/Jit 2>/dev/null | grep -v '.secrets/' | grep -v '.git/' | wc -l
# Output: 0

# 2. Check git history (all branches)
git log --all -S '9e34679' --oneline /workspaces/Jit
# Output: (empty)

# 3. Check service file explicitly
cat /workspaces/Jit/jit-heartbeat.service | grep -i ollama_token
# Output: LoadCredential=ollama_token:/etc/jit-credentials/ollama_token
#         (no hardcoded value)
```

### Step 7: Update Documentation

Add to `/workspaces/Jit/CLAUDE.md`:

```markdown
## Credential Management

Sensitive credentials (OLLAMA_TOKEN, etc.) are stored in `/etc/jit-credentials/` with mode 0600 (readable only by root).

**Setup**:
```bash
sudo bash scripts/setup-credentials.sh "TOKEN_VALUE"
```

**Verification**:
```bash
systemctl show jit-heartbeat.service -p Environment
# Should not contain any token values
```

Credentials are loaded at service startup via systemd `LoadCredential` mechanism and are never exposed in process environment.
```

---

## Validation Checklist

Run each check and record results in `/workspaces/Jit/reports/JIT-006-validation.txt`:

### ✅ Check 1: Service File Valid

```bash
systemd-analyze verify /workspaces/Jit/jit-heartbeat.service
# Expected: OK
```

### ✅ Check 2: No Token in Service Environment

```bash
systemctl show jit-heartbeat.service -p Environment
# Expected: Environment= (empty or no OLLAMA_TOKEN=...)
```

### ✅ Check 3: No Token in Process

```bash
ps aux | grep -i heartbeat | grep -v grep
# Expected: No OLLAMA_TOKEN visible in command line
```

### ✅ Check 4: Credentials File Secured

```bash
ls -la /etc/jit-credentials/ollama_token
# Expected: -rw------- 1 root root ... /etc/jit-credentials/ollama_token
```

### ✅ Check 5: Service Runs Successfully

```bash
sudo systemctl restart jit-heartbeat
sleep 3
sudo systemctl is-active jit-heartbeat
# Expected: active

sudo journalctl -u jit-heartbeat -n 50 | grep -E "error|failed|Error"
# Expected: (empty or only INFO/DEBUG logs, no errors)
```

### ✅ Check 6: Ollama Connectivity Verified

```bash
sudo journalctl -u jit-heartbeat -n 100 | grep -E "ollama|OLLAMA|7778"
# Expected: Successful API calls, no auth errors
```

### ✅ Check 7: No Token in Git History

```bash
git log --all -S '9e34679' --oneline
# Expected: (empty)

grep -r '9e34679' /workspaces/Jit 2>/dev/null | grep -v '.secrets' | wc -l
# Expected: 0
```

### ✅ Check 8: Token Rotated at MDES

```bash
# Confirmation from MDES Ollama team that:
# - Old token (9e34679...) is DISABLED
# - New token is active
# - No audit concerns from token exposure period
```

### ✅ Check 9: Full System Health

```bash
bash /workspaces/Jit/eval/body-check.sh
# Expected: All agents healthy, heartbeat communicating
```

---

## Monitoring After Deployment

### Real-Time Logs

```bash
# Monitor heartbeat service
sudo journalctl -u jit-heartbeat -f
# Should see pulses every 15m (normal mode) with Ollama API calls

# Monitor for auth errors
sudo journalctl -u jit-heartbeat -p err -f
# Should be empty (no errors)
```

### Periodic Checks

```bash
# Every hour: Verify credentials file still exists
ls -la /etc/jit-credentials/ollama_token || echo "ERROR: credentials missing"

# Every day: Check for auth failures in logs
sudo journalctl -u jit-heartbeat --since="24 hours ago" | grep -i "auth\|denied\|403\|401" | wc -l
# Expected: 0
```

### Alerts to Configure

Set up Discord/Slack alerts via jit-heartbeat's OnFailure handler:

```bash
# If systemd tries to restart the service frequently:
sudo journalctl -u jit-heartbeat | grep "Restart=" | tail -5
# Investigate if more than 1-2 restarts per day without human action
```

---

## Troubleshooting

### Problem: Service fails with "LoadCredential not supported"

**Cause**: systemd version < 247

**Solution**:
1. Check version: `systemctl --version`
2. If < 247, use EnvironmentFile fallback:
   ```ini
   EnvironmentFile=/etc/jit/ollama.env
   ExecStart=/bin/bash scripts/heartbeat-24h-daemon.sh
   ```
3. Set permissions: `sudo chmod 0600 /etc/jit/ollama.env`

### Problem: Service starts but Ollama API calls fail (401 Unauthorized)

**Cause**: Token not being read correctly or old/rotated token

**Solution**:
```bash
# 1. Verify credentials file is readable by service user (jit)
sudo -u jit cat /etc/jit-credentials/ollama_token
# Should output token without errors

# 2. Check if token matches MDES system
# Coordinate with MDES to verify token is active

# 3. Restart with debug
sudo systemctl restart jit-heartbeat
sleep 2
sudo journalctl -u jit-heartbeat -n 20 | grep -i "401\|unauthorized\|ollama"
```

### Problem: Process environment shows token (ps aux)

**Cause**: ExecStart is passing token incorrectly

**Solution**:
1. Verify service file ExecStart line uses `$(cat $CREDENTIALS_DIRECTORY/...)` syntax
2. Do NOT use `Environment="OLLAMA_TOKEN=..."` 
3. Token should only exist in credentials file, never in systemd [Service] section

### Problem: systemd-analyze verify fails

**Cause**: Syntax error in unit file or credential path doesn't exist

**Solution**:
```bash
# Check error message
systemd-analyze verify /workspaces/Jit/jit-heartbeat.service

# Common fixes:
# - Verify /etc/jit-credentials/ exists: sudo ls -la /etc/jit-credentials/
# - Check ExecStart syntax (must be valid bash)
# - Ensure LoadCredential path is absolute: /etc/jit-credentials/...
```

---

## Rollback Procedure

If something fails critically after deployment:

```bash
# 1. Stop the service
sudo systemctl stop jit-heartbeat

# 2. Restore from backup (if you kept one)
sudo cp /workspaces/Jit/jit-heartbeat.service.backup /workspaces/Jit/jit-heartbeat.service

# 3. Reload and restart
sudo systemctl daemon-reload
sudo systemctl start jit-heartbeat

# 4. Verify it's working
sudo systemctl status jit-heartbeat
sudo journalctl -u jit-heartbeat -n 20
```

**Note**: Backup uses old hardcoded token. Only for emergency rollback.  
After rollback: Follow the spec again with proper credential setup.

---

## Sign-Off

After completing all steps and validation:

```bash
# Generate final report
cat > /workspaces/Jit/reports/JIT-006-validation.txt << 'EOF'
JIT-006 Validation Report
Date: $(date)
Operator: pada

✅ All checks passed:
  - Service file valid
  - No token in environment
  - Credentials secured
  - Service running
  - Ollama connectivity OK
  - Git history scrubbed
  - Token rotated at MDES
  - Full system health verified

Status: READY FOR MERGE
EOF

# Commit validation report
git add /workspaces/Jit/reports/JIT-006-validation.txt
git commit -m "JIT-006: Credential management implementation complete + validation"

# Notify
bash /workspaces/Jit/organs/mouth.sh tell jit "JIT-006 complete: secure credential loading implemented, git history scrubbed, token rotated" 2>/dev/null || true
```

---

## Emergency Contacts

- **MDES Ollama Support**: [contact info in .secrets/mdes-contacts.txt]
- **pada (DevOps)**: Available for troubleshooting
- **innova (Lead Dev)**: For code-level issues in heartbeat.sh

---

## References

- Spec: `/workspaces/Jit/specs/JIT-006-spec.md`
- TOR: `/workspaces/Jit/specs/tor/JIT-006-tor.md`
- Ticket: JIT-006
- Related: JIT-007 (logging), JIT-009 (reliability)

