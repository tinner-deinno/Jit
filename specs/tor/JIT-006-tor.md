# JIT-006 Terms of Reference (TOR)

**Ticket ID**: JIT-006  
**Title**: Remove Hardcoded OLLAMA_TOKEN from jit-heartbeat.service  
**Type**: Security Fix + DevOps  
**Owner**: pada (DevOps Engineer)  
**Created**: 2026-06-06  
**Target Completion**: 2026-06-07 (1 day)

---

## Scope

### In Scope
- Remove hardcoded OLLAMA_TOKEN from `/workspaces/Jit/jit-heartbeat.service`
- Implement secure credential passing using systemd LoadCredential
- Create `/etc/jit-credentials/ollama_token` with proper file permissions (0600)
- Update `scripts/heartbeat.sh` to read OLLAMA_TOKEN from environment
- Scrub git history to remove all instances of exposed token (`9e34679`)
- Rotate token with MDES Ollama team (acknowledge public exposure)
- Validate credential mechanism end-to-end
- Update documentation (CLAUDE.md, deployment-guide.md)

### Out of Scope
- Implementing full secrets management system (HashiCorp Vault, AWS Secrets Manager)
- Retroactive audit of other potential hardcoded credentials (separate ticket: DEVOPS-001)
- Modifying bootstrap.sh or Oracle startup procedure (in scope for JIT-008)
- Changing how other agents access secrets (scope for future tickets)

### Dependencies
- systemd v247+ (assumed available on current systems)
- sudo access to create `/etc/jit-credentials/` directory
- Git force-push permission on main branch (after history scrub)
- Coordination with MDES Ollama team for token rotation

---

## Deliverables

1. **Modified systemd unit**: `/workspaces/Jit/jit-heartbeat.service`
   - Removes OLLAMA_TOKEN environment variable
   - Adds LoadCredential mechanism
   - Includes comments explaining credential loading

2. **Credentials setup script**: `/workspaces/Jit/scripts/setup-credentials.sh`
   - Creates `/etc/jit-credentials/` directory with proper permissions
   - Provides template for token storage
   - Includes validation checks

3. **Git history scrub**: Force-push to heartbeat-1 branch after BFG/git-filter-repo
   - Verify no token appears in any commit
   - Document in commit message: "Remove OLLAMA_TOKEN from git history (security audit JIT-006)"

4. **Documentation**: Updated CLAUDE.md + deployment-guide.md
   - Credential management procedure
   - Token rotation process
   - Validation steps for production deployment

5. **Validation report**: `/workspaces/Jit/reports/JIT-006-validation.txt`
   - `systemctl show` output confirming no token in environment
   - `git log -S` results showing no token in history
   - `ls -la /etc/jit-credentials/` output showing file permissions
   - Service status and Ollama connectivity test results

---

## Success Criteria

| Criterion | Validation |
|-----------|-----------|
| Token removed from unit file | Manual inspection + grep repo |
| Credentials stored securely | `ls -la /etc/jit-credentials/ollama_token` shows 0600 mode |
| Service starts cleanly | `systemctl status jit-heartbeat` = active |
| Service can reach Ollama | `journalctl -u jit-heartbeat` shows successful API calls |
| No token in environment | `ps aux \| grep heartbeat` contains no OLLAMA_TOKEN |
| No token in git history | `git log -S '9e34679'` returns empty |
| Token rotated at MDES | Confirmation from MDES team, old token disabled |

---

## Effort Estimation

| Task | Hours | Notes |
|------|-------|-------|
| Design & spec review | 0.5 | Already done (this doc) |
| Implement LoadCredential | 1.0 | Update .service file, create setup script |
| Git history scrub | 0.5 | BFG or git-filter-repo, force-push |
| Token rotation coordination | 0.5 | Coordinate with MDES, new token setup |
| Validation & testing | 0.75 | Full validation checklist from spec |
| Documentation updates | 0.25 | CLAUDE.md, deployment-guide.md |
| **Total** | **3.5 hours** | |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| systemd LoadCredential not available (old OS) | HIGH | Fallback to EnvironmentFile with mode 0600 + pre-check systemd version |
| Git force-push breaks team workflow | MEDIUM | Communicate before scrub, ensure all team members pull first |
| Service fails after credential change | HIGH | Rollback plan: revert .service file, test in dev environment first |
| MDES token rotation creates auth errors | MEDIUM | Have both old and new tokens available during transition period |
| Credentials file accidentally deleted | MEDIUM | Document setup procedure, add to bootstrap.sh automated setup |

---

## Communication Plan

- **Kickoff**: PM-SA async message to innova
- **Git history scrub**: Notify all developers of force-push requirement
- **Token rotation**: Coordinate with MDES Ollama team lead
- **Completion**: Report completion status to jit (master orchestrator)

---

## Acceptance by pada

### Pre-Implementation Checklist
- [ ] Verify systemd version supports LoadCredential: `systemctl --version | head -1`
- [ ] Confirm sudo access: `sudo -n systemctl status` (no password)
- [ ] Check git permissions: `git branch -a | grep -c main`
- [ ] Get MDES contact for token rotation

### Implementation Checklist
- [ ] Create `/workspaces/Jit/scripts/setup-credentials.sh` script
- [ ] Update `/workspaces/Jit/jit-heartbeat.service`
- [ ] Test in dev environment (user systemd unit)
- [ ] Scrub git history with BFG
- [ ] Coordinate token rotation with MDES
- [ ] Update `/etc/jit-credentials/ollama_token` with new token
- [ ] Restart service and verify
- [ ] Update documentation

### Post-Implementation Checklist
- [ ] Validate: `systemctl show jit-heartbeat.service -p Environment` (empty)
- [ ] Validate: `ps aux | grep heartbeat` (no token visible)
- [ ] Validate: `git log -S '9e34679'` (no results)
- [ ] Validate: `journalctl -u jit-heartbeat -n 50` (successful Ollama connections)
- [ ] Run full test suite: `bash eval/body-check.sh`
- [ ] Generate validation report to `/workspaces/Jit/reports/JIT-006-validation.txt`
- [ ] Sign off as complete

---

## Approval Gates

1. **Security Review**: neta (code reviewer) signs off on credential mechanism
2. **DevOps Approval**: pada (owner) confirms all acceptance criteria met
3. **Master Merge**: jit decides whether to merge to main or keep on heartbeat-1

---

## References

- Spec: `/workspaces/Jit/specs/JIT-006-spec.md`
- Runbook: `/workspaces/Jit/specs/runbooks/JIT-006-runbook.md`
- Security Audit: DEVOPS-001
- Related Tickets: JIT-007 (logging), JIT-008 (bootstrap), JIT-009 (reliability)

