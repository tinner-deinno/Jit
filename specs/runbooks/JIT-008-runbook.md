# JIT-008 Operational Runbook
## Add Deploy Rollback and Pinned Artifact Version to bootstrap.sh

**Audience**: pada (DevOps operator), innova (code reviewer)  
**Status**: COMPLETE  
**Execution Time**: ~30 minutes  
**Priority**: P1 (Critical infrastructure)

---

## Overview

JIT-008 adds deploy rollback capability and pinned artifact versioning to the Jit Oracle deployment pipeline. This ensures:

1. **Reproducible deploys** — Oracle pinned to known-good tag before install
2. **Fast rollback** — One-command recovery to last known good state
3. **Migration safety** — Pre-deploy hook blocks destructive migrations

---

## Quick Start

### Deploy with Pinned Version

```bash
# Standard deploy (auto-pins to latest tag)
bash /workspaces/Jit/scripts/bootstrap.sh

# Deploy specific version
export ARRA_ORACLE_VERSION=v1.2.3
bash /workspaces/Jit/scripts/bootstrap.sh
```

### Rollback (Emergency)

```bash
# Immediate rollback to last known good
sudo bash /workspaces/Jit/scripts/rollback.sh

# Dry-run first (recommended)
sudo bash /workspaces/Jit/scripts/rollback.sh --dry-run

# Force rollback (skip commit existence check)
sudo bash /workspaces/Jit/scripts/rollback.sh --force
```

---

## Architecture

### Bootstrap Flow (with JIT-008)

```
┌─────────────────────────────────────────────────────────────┐
│  bootstrap.sh Execution Flow                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Step 0: Snapshot current commit                            │
│          git rev-parse HEAD > /var/lib/jit/last-known-      │
│          good.txt                                           │
│                                                             │
│  Step 1: Install Bun runtime                                │
│                                                             │
│  Step 2: Clone Arra Oracle V3 (if needed)                   │
│                                                             │
│  Step 3: PIN TO KNOWN GOOD VERSION ← JIT-008               │
│          git fetch --tags                                   │
│          git checkout ${ARRA_ORACLE_VERSION:-latest-tag}    │
│                                                             │
│  Step 4: bun install                                        │
│                                                             │
│  Step 5: Pre-deploy migration check ← JIT-008              │
│          bash check-migrations.sh                           │
│          └─ Blocks if DROP TABLE/COLUMN detected            │
│                                                             │
│  Step 6: db:push (safe migrations only)                     │
│                                                             │
│  Step 7: Start Oracle server                                │
│                                                             │
│  Step 8: Run soul-check.sh                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Rollback Flow

```
┌─────────────────────────────────────────────────────────────┐
│  rollback.sh Recovery Flow                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Step 1: Stop services                                      │
│          systemctl stop jit-heartbeat hermes-discord        │
│                                                             │
│  Step 2: Checkout last known good                           │
│          git checkout $(cat /var/lib/jit/last-known-        │
│          good.txt)                                          │
│                                                             │
│  Step 3: Reinstall dependencies                             │
│          bun install                                        │
│                                                             │
│  Step 4: Restart services                                   │
│          systemctl start jit-heartbeat hermes-discord       │
│                                                             │
│  Step 5: Health check                                       │
│          curl http://localhost:47778/api/health             │
│          bash eval/soul-check.sh                            │
│                                                             │
│  Step 6: Send Discord notification                          │
│          (success/failure webhook)                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Files Changed

| File | Purpose | Size |
|------|---------|------|
| `scripts/bootstrap.sh` | Added Steps 0, 3, 5b for snapshot + pin + migration check | +50 lines |
| `scripts/rollback.sh` | New — Full recovery flow | 240 lines |
| `scripts/check-migrations.sh` | New — Pre-deploy safety hook | 90 lines |
| `specs/runbooks/JIT-008-runbook.md` | This document | — |

---

## Step-by-Step Procedure

### Step 1: Verify Prerequisites

```bash
# Ensure state directory exists
sudo mkdir -p /var/lib/jit
sudo chown jit:jit /var/lib/jit 2>/dev/null || true

# Verify Oracle directory
ls -la /workspaces/arra-oracle-v3/.git
# Expected: git directory exists

# Check current tags available
git -C /workspaces/arra-oracle-v3 tag -l
# Expected: List of version tags (v1.0.0, v1.1.0, etc.)
```

### Step 2: Review Current bootstrap.sh

```bash
# Verify pinned version step exists
grep -A5 "Step 3/7" /workspaces/Jit/scripts/bootstrap.sh

# Expected output:
# [ Step 3/7 ] Pinning Oracle to known good version...
# cd "$ORACLE_DIR"
# git fetch --tags --quiet 2>/dev/null || true
# PINNED_VERSION="${ARRA_ORACLE_VERSION:-$(git describe --tags --abbrev=0 ...)}"
```

### Step 3: Verify Rollback Script

```bash
# Check script exists and is executable
ls -la /workspaces/Jit/scripts/rollback.sh
# Expected: -rwxrwxrwx ... rollback.sh

# Review key functions
grep -A3 "send_discord_webhook" /workspaces/Jit/scripts/rollback.sh | head -10
```

### Step 4: Test Dry-Run Rollback

```bash
# First, ensure a snapshot exists (run bootstrap if needed)
bash /workspaces/Jit/scripts/bootstrap.sh innova

# Then test rollback dry-run
sudo bash /workspaces/Jit/scripts/rollback.sh --dry-run

# Expected output:
# 🔄 Starting rollback procedure...
# [INFO] DRY RUN MODE — No changes will be made
# [INFO] Found snapshot: <commit-hash>
# [ Step 1/5 ] Stopping services...
# [INFO] Would stop: jit-heartbeat.service
# ...
# [INFO] DRY RUN COMPLETE — No changes were made
```

### Step 5: Test Migration Check

```bash
# Run migration check (should pass on stable repo)
bash /workspaces/Jit/scripts/check-migrations.sh

# Expected output:
# 🔍 Checking migrations for destructive operations...
# [INFO] No migration changes detected — safe to proceed
# ✅ Migrations safe to apply
```

### Step 6: Deploy to Staging (If Available)

```bash
# Set staging version
export ARRA_ORACLE_VERSION=v1.0.0-staging

# Run bootstrap
bash /workspaces/Jit/scripts/bootstrap.sh staging

# Verify pinned version
git -C /workspaces/arra-oracle-v3 describe --tags
# Expected: v1.0.0-staging
```

### Step 7: Production Deploy

```bash
# Clear any staging overrides
unset ARRA_ORACLE_VERSION

# Run production bootstrap
bash /workspaces/Jit/scripts/bootstrap.sh innova

# Verify deployment
curl http://localhost:47778/api/health
# Expected: {"status": "ok", "version": "..."}

bash /workspaces/Jit/eval/soul-check.sh
# Expected: All agents healthy
```

### Step 8: Verify Snapshot Created

```bash
# Check last-known-good file
cat /var/lib/jit/last-known-good.txt
# Expected: 40-character commit hash

# Verify it matches current Oracle commit
git -C /workspaces/arra-oracle-v3 rev-parse HEAD
# Should match the file content
```

---

## Validation Checklist

### ✅ Pre-Deploy Checks

```bash
# 1. Scripts exist and are executable
test -x /workspaces/Jit/scripts/bootstrap.sh && echo "✅ bootstrap.sh"
test -x /workspaces/Jit/scripts/rollback.sh && echo "✅ rollback.sh"
test -x /workspaces/Jit/scripts/check-migrations.sh && echo "✅ check-migrations.sh"

# 2. State directory ready
test -d /var/lib/jit && echo "✅ /var/lib/jit exists"

# 3. Oracle repo has tags
git -C /workspaces/arra-oracle-v3 tag -l | wc -l | xargs -I{} test {} -gt 0 && echo "✅ Oracle tags exist"
```

### ✅ Post-Deploy Checks

```bash
# 1. Snapshot file created
test -f /var/lib/jit/last-known-good.txt && echo "✅ Snapshot exists"

# 2. Oracle pinned correctly
git -C /workspaces/arra-oracle-v3 describe --tags --abbrev=0
# Should show pinned version

# 3. Services running
systemctl is-active jit-heartbeat && echo "✅ jit-heartbeat running"
systemctl is-active hermes-discord && echo "✅ hermes-discord running"

# 4. Oracle healthy
curl -sf http://localhost:47778/api/health && echo "✅ Oracle healthy"

# 5. Soul integrity
bash /workspaces/Jit/eval/soul-check.sh >/dev/null 2>&1 && echo "✅ Soul check passed"
```

### ✅ Rollback Capability

```bash
# 1. Dry-run succeeds
sudo bash /workspaces/Jit/scripts/rollback.sh --dry-run
# Expected: Exit code 0

# 2. Migration check works
bash /workspaces/Jit/scripts/check-migrations.sh
# Expected: Exit code 0
```

---

## Configuration

### Environment Variables

```bash
# In .env or shell before deploy

# Pin to specific Oracle version (optional)
ARRA_ORACLE_VERSION="v1.2.3"

# Discord webhook for rollback notifications
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

# State directory (default: /var/lib/jit)
STATE_DIR="/var/lib/jit"

# Oracle directory (default: /workspaces/arra-oracle-v3)
ORACLE_DIR="/workspaces/arra-oracle-v3"
```

### Rollback Flags

```bash
# --dry-run: Show what would happen without making changes
sudo bash /workspaces/Jit/scripts/rollback.sh --dry-run

# --force: Skip commit existence verification
sudo bash /workspaces/Jit/scripts/rollback.sh --force
```

---

## Monitoring After Deployment

### Daily Health Check

```bash
# Add to cron: 0 6 * * * (daily at 6am)
curl -sf http://localhost:47778/api/health || echo "⚠️ Oracle unhealthy"
```

### Weekly Rollback Test

```bash
# Add to cron: 0 5 * * 0 (weekly on Sunday)
# Verify rollback capability without executing
test -f /var/lib/jit/last-known-good.txt || echo "⚠️ No rollback snapshot!"
```

### Disk Space Alert

```bash
# Alert if state directory exceeds 10M
if [ "$(du -s /var/lib/jit/ | awk '{print $1}')" -gt 10000 ]; then
  echo "⚠️ Jit state directory exceeds 10M" | mail -s "Disk Space Alert" pada@example.com
fi
```

---

## Troubleshooting

### Problem: No tags found in Oracle repo

**Cause**: Fresh clone or tags not fetched

**Solution**:
```bash
# Manually fetch tags
git -C /workspaces/arra-oracle-v3 fetch --tags

# Verify tags exist
git -C /workspaces/arra-oracle-v3 tag -l

# If still empty, check remote
git -C /workspaces/arra-oracle-v3 remote -v
# Should show Soul-Brews-Studio/arra-oracle-v3
```

### Problem: Snapshot file missing

**Cause**: bootstrap.sh Step 0 failed or state directory cleared

**Solution**:
```bash
# Manually create snapshot
mkdir -p /var/lib/jit
git -C /workspaces/arra-oracle-v3 rev-parse HEAD > /var/lib/jit/last-known-good.txt

# Verify
cat /var/lib/jit/last-known-good.txt
```

### Problem: Rollback fails with "Commit not found"

**Cause**: Snapshot references commit from different branch or shallow clone

**Solution**:
```bash
# Option 1: Use --force to skip check
sudo bash /workspaces/Jit/scripts/rollback.sh --force

# Option 2: Fetch full history
git -C /workspaces/arra-oracle-v3 fetch --unshallow 2>/dev/null || true
git -C /workspaces/arra-oracle-v3 fetch --all

# Then retry rollback
sudo bash /workspaces/Jit/scripts/rollback.sh
```

### Problem: Migration check false positive

**Cause**: Pattern matches non-destructive change (e.g., comment contains "DROP")

**Solution**:
```bash
# Review the diff
cat /var/lib/jit/migration-check.log

# If safe, bypass check
export SKIP_MIGRATION_CHECK=1
bash /workspaces/Jit/scripts/bootstrap.sh

# Or fix check-migrations.sh patterns to be more specific
```

### Problem: Discord webhook fails

**Cause**: Network issue or invalid webhook URL

**Solution**:
```bash
# Test webhook manually
curl -X POST "$DISCORD_WEBHOOK_URL" -H "Content-Type: application/json" -d '{"content":"test"}'

# If fails, check URL and firewall
# Webhook failure is non-fatal — rollback continues
```

---

## Rollback Procedures

### Emergency Rollback (P1 Incident)

```bash
# 1. Stop everything immediately
sudo systemctl stop jit-heartbeat hermes-discord

# 2. Execute rollback
sudo bash /workspaces/Jit/scripts/rollback.sh

# 3. Verify recovery
curl http://localhost:47778/api/health
bash /workspaces/Jit/eval/soul-check.sh

# 4. Notify team
bash /workspaces/Jit/organs/mouth.sh tell vaja "P1 rollback complete — system restored to $(cat /var/lib/jit/last-known-good.txt)"
```

### Scheduled Rollback (Maintenance)

```bash
# 1. Notify team
bash /workspaces/Jit/organs/mouth.sh tell vaja "Scheduled rollback starting at $(date)"

# 2. Dry-run first
sudo bash /workspaces/Jit/scripts/rollback.sh --dry-run

# 3. Execute rollback
sudo bash /workspaces/Jit/scripts/rollback.sh

# 4. Document in Oracle
bash /workspaces/Jit/limbs/oracle.sh learn "rollback-$(date +%Y%m%d)" "Rollback executed: $(cat /var/lib/jit/last-known-good.txt)" "devops,rollback,maintenance"
```

---

## Sign-Off

After validation:

```bash
cat > /workspaces/Jit/reports/JIT-008-validation.txt << 'EOF'
JIT-008 Validation Report
Date: $(date)
Operator: pada

✅ All checks passed:
  - bootstrap.sh pins Oracle version before bun install
  - Snapshot created at /var/lib/jit/last-known-good.txt
  - rollback.sh executable with full recovery flow
  - check-migrations.sh blocks destructive migrations
  - Dry-run rollback succeeds
  - Discord webhook integration working
  - Full system health OK

Status: READY FOR PRODUCTION
EOF

# Notify completion
bash /workspaces/Jit/organs/mouth.sh tell jit "JIT-008 complete: deploy rollback and pinned artifact versioning implemented" 2>/dev/null || true
```

---

## References

- Spec: `/workspaces/Jit/tickets/open/JIT-008-deploy-rollback.yaml`
- Bootstrap: `/workspaces/Jit/scripts/bootstrap.sh`
- Rollback: `/workspaces/Jit/scripts/rollback.sh`
- Migration Check: `/workspaces/Jit/scripts/check-migrations.sh`
- Related: JIT-006 (heartbeat), JIT-007 (log rotation)
