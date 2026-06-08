# 🔒 Security & Secrets Management

This document explains how to securely manage secrets (tokens, API keys, credentials) in the Jit multiagent system.

## Critical Principle: Never Commit Secrets

**Buddhist principle ศีล (Integrity)**: No secrets in code. No hidden credentials that could harm the system or users.

---

## Setup Instructions

### 1. Create Your Local .env File

```bash
cp .env.example .env
```

### 2. Add Your Secrets to .env

Edit `.env` and add your actual tokens:

```bash
# Your MDES Ollama token (get from MDES-Innova)
OLLAMA_TOKEN=your_actual_token_here

# Other configuration
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
ORACLE_PORT=47778
```

### 3. Load Environment Variables Before Running

```bash
# Load .env file
export $(cat .env | grep -v '#' | xargs)

# Then run scripts
bash scripts/bootstrap.sh
bash eval/soul-check.sh
bash eval/security-check.sh
```

### 4. Verify .env is NOT Committed

```bash
# Should return nothing - .env is protected
git status | grep ".env"

# Verify it's in .gitignore
grep "^\.env" .gitignore
```

---

## How Secrets Are Used in Code

### ✅ CORRECT: Environment Variables

```bash
#!/bin/bash
# Read from environment
TOKEN="${OLLAMA_TOKEN}"
curl -H "Authorization: Bearer $TOKEN" ...
```

```json
{
  "token": "${OLLAMA_TOKEN}",
  "_comment": "Loaded from environment at runtime"
}
```

```python
import os
token = os.getenv('OLLAMA_TOKEN')
```

### ❌ WRONG: Hardcoded Secrets

```bash
# DON'T DO THIS - NEVER HARDCODE TOKENS
curl -H "Authorization: Bearer YOUR_REAL_TOKEN_HERE" ...
```

```json
{
  "token": "<your-actual-token>"
}
```

---

## Files Protected from Commit

The `.gitignore` file protects these from accidental commits:

```
.env                          # Local configuration (PRIMARY)
.env.local                    # Local overrides
.env.*.local                  # Environment-specific
secrets.json                  # Manual secrets file
credentials.json              # Auth credentials
tokens.json                   # Token storage
```

---

## Continuous Security Monitoring

### Run Security Audit

```bash
# Full security check
bash eval/security-check.sh

# Fail on issues (for CI/CD)
bash eval/security-check.sh --ci

# Continuous monitoring (watch mode - TODO)
bash eval/security-check.sh --watch
```

### What It Checks

✅ Looks for exposed tokens and hardcoded credentials  
✅ Verifies .env is in .gitignore  
✅ Checks file permissions on secret files  
✅ Validates environment variable usage  
✅ Scans shell scripts for security issues  

### Output

```
🔒 Security Audit — Jit Multiagent System
═══════════════════════════════════════════════════════

[1/5] Checking for exposed tokens...
  ✅ No exposed tokens found

[2/5] Checking file permissions...
  ✅ No unsafe file permissions found

[3/5] Checking .gitignore...
  ✅ .env is properly in .gitignore

[4/5] Checking environment variables...
  ✅ Found environment variable references

[5/5] Checking shell scripts...
  ✅ Shell scripts checked

════════════════════════════════════════════════════════
✅ SECURITY AUDIT PASSED - System is secure
```

---

## Agent Responsibilities

### pada (บาท/DevOps) — Secret Manager

- Ensures secrets are never in code
- Validates .gitignore protections
- Manages environment-specific configs
- Alerts on exposed credentials
- Rotates tokens periodically

### neta (เนตร/Code Reviewer) — Security Gate

- Blocks PRs with hardcoded secrets
- Reviews for credential exposure
- Enforces security patterns
- Catches violations before commit

---

## What If a Secret Gets Committed?

If you accidentally commit a secret:

### 1. Immediately Rotate the Secret

Contact MDES-Innova to rotate the OLLAMA_TOKEN.

### 2. Remove from Git History

```bash
# Install git-filter-repo (one-time)
pip install git-filter-repo

# Remove the secret from all history
git filter-repo --replace-text <(echo "old_token==>XXX")

# Force push (only if you control the repo)
git push --force
```

### 3. Force-Fetch Latest

All team members must:
```bash
git fetch --all
git reset --hard origin/main
```

---

## Pre-Commit Hook (Optional)

Create `.git/hooks/pre-commit` to prevent accidental commits:

```bash
#!/bin/bash
# Prevent committing secrets

PATTERNS="^Bearer\s|api.key|secret\s*=|password\s*="

if git diff --cached | grep -E "$PATTERNS"; then
  echo "❌ ERROR: Detected potential secrets in commit"
  exit 1
fi
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## Environment Variable Reference

| Variable | Purpose | Example | Required |
|----------|---------|---------|----------|
| `OLLAMA_TOKEN` | MDES Ollama API token | `<your-token>` | ✅ Yes |
| `OLLAMA_BASE_URL` | Ollama service URL | `https://ollama.mdes-innova.online` | No |
| `ORACLE_PORT` | Oracle knowledge base port | `47778` | No |
| `GITHUB_TOKEN` | GitHub API access | `ghp_xxxx` | No (if using GitHub) |

---

## Incident Response

If you suspect a security breach:

1. **Alert immediately**: Contact your security team
2. **Rotate all credentials**: Change all tokens and passwords
3. **Audit logs**: Check git history for what was exposed
4. **Notify users**: If user data could be affected
5. **Document lessons**: Update security procedures

---

## Security Checklist

Before deploying to production:

- [ ] No hardcoded tokens in any file
- [ ] .env.example exists with placeholder values
- [ ] .env file is in .gitignore
- [ ] Environment variables are used in all scripts
- [ ] Security audit passes: `bash eval/security-check.sh --ci`
- [ ] .gitignore protects all secret files
- [ ] Team is trained on secret management
- [ ] Rotation schedule is documented

---

## Resources

- **OWASP Secrets Management**: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
- **Git Secrets Prevention**: https://github.com/awslabs/git-secrets
- **MDES-Innova Security Policy**: [Internal documentation]

---

## Questions?

Contact the security team or pada (DevOps agent) for guidance.

**Remember**: Secrets in code are not just technical debt—they're a direct threat to everyone who depends on this system. ศีล (Integrity) means protecting the system and its users.

🔒 **Keep it secure. Keep it safe.**
