# Security Audit Report — Jit มนุษย์ Agent System

**Date**: 2026-06-07  
**Auditor**: Haiku 4.5 Security Agent  
**Scope**: Critical paths — agents/, scripts/, organs/, limbs/, network/

## Executive Summary

Audit identified **5 critical security vulnerabilities** (P0/P1) across shell scripts and Python integrations. Primary vectors: **shell injection** (3 findings), **code injection** (1), **credential exposure** (1). All issues are in orchestration/messaging layers — no data exfiltration observed. **Recommended immediate action**: Fix P0 injection bugs before next deployment.

## Findings Summary

| ID | Title | Priority | Category | Effort |
|-----|------|----------|----------|--------|
| JIT-019 | JSON Injection in discord-webhook.sh | P0 | JSON Injection | 3h |
| JIT-020 | Sed Injection in organs/hand.sh | P0 | Sed Injection | 2h |
| JIT-021 | Python Code Injection (bus.sh, heart.sh, mouth.sh) | P0 | Python Injection | 3h |
| JIT-022 | Token Exposure in Logs | P1 | Credential Exposure | 4h |
| JIT-023 | Message Bus Lacks Auth/Integrity | P1 | Authentication | 5h |

## Detailed Findings

### 1. JSON Injection (JIT-019) — scripts/discord-webhook.sh

**Risk**: Malformed Discord payloads; potential JSON structure injection via commit message escaping.

**Affected Code** (lines 73-108):
- Variables `$MESSAGE`, `$commit_msg`, `$STATUS` used unquoted in JSON heredoc
- JSON special chars (`, \, newline) break payload or enable field injection

**Mitigation**: Use `jq` to safely encode strings in JSON construction.

### 2. Sed Injection (JIT-020) — organs/hand.sh edit

**Risk**: Arbitrary text replacement via sed metacharacter injection; data corruption.

**Affected Code** (line 46):
- `sed -i "s|$OLD|$NEW|g" "$FILE"` — user-supplied $OLD/$NEW unescaped
- Attacker can inject sed address ranges or regex commands

**Mitigation**: Escape `$OLD` and `$NEW` using `sed -e` escaping, or use Perl.

### 3. Python Code Injection (JIT-021) — Three locations

**Risk**: Arbitrary Python code execution via path traversal; system compromise.

**Affected Code**:
- **network/bus.sh lines 27-32** — `$REGISTRY`, `$BUS_ROOT` in Python heredoc
- **organs/heart.sh lines 64-88** — same variables in Python subprocess
- **organs/mouth.sh lines 72-77** — `$REGISTRY` in embedded Python

**Mitigation**: Pass variables as Python `sys.argv` instead of string interpolation.

### 4. Token Exposure in Logs (JIT-022)

**Risk**: OLLAMA_TOKEN, GITHUB_TOKEN exposed in log files or stderr; credential compromise.

**Affected Code**:
- **scripts/pm-sa-dispatch.sh:33** — logs API key presence ("API key loaded: YES/NO")
- **limbs/ollama.sh:35** — curl header with Bearer token (verbose mode exposure)
- **organs/heart.sh:58** — curl header with token in unredacted logs

**Mitigation**: Mask token presence from logs; use curl -s (silent); redact credentials in log output.

### 5. Message Bus Auth/Integrity (JIT-023)

**Risk**: Forged agent messages; attackers impersonate jit or control organs (deploy, execute, etc.).

**Affected Code**:
- **network/bus.sh:52-60** — message creation with no signature
- **organs/mouth.sh:28-35** — no integrity field
- **organs/ear.sh:38-86** — no validation of sender identity

**Mitigation**: Add HMAC-SHA256 signatures to message protocol; validate on receive.

## CVSS Scores

- **JIT-019** (JSON Injection): CVSS 4.3 (Medium) — Integrity/Availability impact
- **JIT-020** (Sed Injection): CVSS 7.5 (High) — Confidentiality/Integrity/Availability
- **JIT-021** (Python Injection): CVSS 8.8 (High) — Code execution risk
- **JIT-022** (Token Exposure): CVSS 5.3 (Medium) — Credential disclosure
- **JIT-023** (Bus Auth): CVSS 9.1 (Critical) — Affects multi-agent control plane

## Timeline

- **P0 Fixes Target**: 2026-06-14 (1 week)
- **P1 Fixes Target**: 2026-06-21 (2 weeks)

---

**Next Step**: Review tickets JIT-019 through JIT-023 in /workspaces/Jit/tickets/open/ and assign to responsible organ owners for remediation.
