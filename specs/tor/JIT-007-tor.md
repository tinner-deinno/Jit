# JIT-007 Terms of Reference (TOR)
## Add Log Rotation for Daemon Logs

**Ticket ID**: JIT-007  
**Title**: Add Log Rotation for Daemon Logs  
**Type**: DevOps / Observability  
**Owner**: pada (DevOps Engineer)  
**Created**: 2026-06-06  
**Target Completion**: 2026-06-08 (2 days)

---

## Scope

### In Scope
- Configure systemd `LogsDirectory=jit` and `RuntimeDirectory=jit` in jit-heartbeat.service
- Create `/etc/logrotate.d/jit-heartbeat` with daily rotation, 14-day retention, compression
- Refactor `scripts/heartbeat.sh` to forward logs to journalctl via `systemd-cat`
- Create `/var/log/jit/` directory with proper ownership (jit:jit)
- Remove `/tmp/` logging dependencies from daemon scripts
- Add log rotation test suite
- Validate that `journalctl -u jit-heartbeat` returns logs for last 24h
- Update documentation (CLAUDE.md, runbook)

### Out of Scope
- Centralized logging system (ELK, Loki, etc.) — future ticket
- Log aggregation across multiple machines — future ticket
- Journal persistence configuration (journald.conf tuning) — separate concern
- Hermes Discord bot logging refactor (scope for JIT-010)
- Other daemon scripts beyond jit-heartbeat

### Dependencies
- JIT-006 must be merged first (systemd service unit changes)
- systemd v235+ (assumed available on current systems)
- sudo access to create `/var/log/jit/` and `/etc/logrotate.d/`
- logrotate package (standard on most Linux distributions)

---

## Deliverables

1. **Updated systemd unit**: `/workspaces/Jit/jit-heartbeat.service`
   - Adds `LogsDirectory=jit`, `RuntimeDirectory=jit`
   - Updates `StandardOutput=journal`, `StandardError=journal`
   - Adds `SyslogIdentifier=jit-heartbeat`

2. **logrotate configuration**: `/etc/logrotate.d/jit-heartbeat`
   - Daily rotation schedule
   - 14-day retention policy
   - Automatic compression

3. **Refactored heartbeat script**: `scripts/heartbeat.sh`
   - Uses `systemd-cat` for journal forwarding
   - Removes `/tmp/` log file references
   - Sets up `/var/log/jit/` as primary log directory

4. **Test suite**: `tests/test_log_rotation.sh`
   - Validates logrotate configuration syntax
   - Tests rotation behavior
   - Verifies disk usage constraints

5. **Documentation**: Updated CLAUDE.md + runbook
   - How to query logs via journalctl
   - Disk usage monitoring
   - Troubleshooting log issues

6. **Validation report**: `/workspaces/Jit/reports/JIT-007-validation.txt`
   - Service starts successfully
   - Logs appear in journal
   - Logrotate configuration valid
   - No logs accumulate in /tmp/
   - Log age/retention verified

---

## Success Criteria

| Criterion | Validation |
|-----------|-----------|
| Log directory created | `ls -la /var/log/jit/` shows drwxr-xr-x jit:jit |
| systemd unit valid | `systemd-analyze verify jit-heartbeat.service` = OK |
| Logs in journal | `journalctl -u jit-heartbeat -n 5` returns recent entries |
| No /tmp logs | `ls /tmp/innova-heartbeat* 2>/dev/null \| wc -l` = 0 |
| Logrotate config valid | `logrotate -d /etc/logrotate.d/jit-heartbeat` succeeds |
| Rotation happens daily | Logs show .1.gz, .2.gz, etc. after 24h+ |
| Retention policy enforced | Only 14 compressed + 1 current log file present |
| 24h log history available | `journalctl -u jit-heartbeat --since "24 hours ago" \| wc -l` > 0 |
| Full system health | `bash eval/body-check.sh` passes |

---

## Effort Estimation

| Task | Hours | Notes |
|------|-------|-------|
| Design & spec review | 0.5 | Already done |
| Update systemd unit | 0.5 | Add LogsDirectory, StandardOutput=journal directives |
| Create logrotate config | 0.5 | Standard configuration |
| Refactor heartbeat.sh | 1.0 | Replace /tmp logging with systemd-cat |
| Create test suite | 0.75 | test_log_rotation.sh validation |
| Setup /var/log/jit/ | 0.25 | mkdir + chown |
| Validation & testing | 1.0 | Full checklist, 24h+ verification |
| Documentation updates | 0.5 | CLAUDE.md, runbook, comments |
| **Total** | **4.5 hours** | |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| systemd LogsDirectory not available (old OS) | MEDIUM | Check systemd v235+, fallback to StandardOutput=file |
| Logrotate package not installed | LOW | Standard on most distros, documented as dependency |
| Disk fills during rotation | LOW | 200M limit configured, ~5KB/day log volume |
| Journal becomes large | LOW | RuntimeMaxUse=200M limits volatile journal size |
| Logs lost on reboot (volatile) | LOW | Persistent logs in /var/log/jit/ via LogsDirectory |
| Service fails to start if /var/log/jit/ missing | MEDIUM | Automation: systemd creates LogsDirectory automatically |

---

## Communication Plan

- **Kickoff**: PM-SA async to innova
- **Testing**: pada runs 24h+ test (monitor /var/log/jit/ growth)
- **Completion**: Report to jit with disk usage metrics

---

## Acceptance by pada

### Pre-Implementation Checklist
- [ ] Verify systemd version: `systemctl --version | grep -o 'systemd [0-9]*' | awk '{print $2}'` ≥ 235
- [ ] Confirm logrotate available: `which logrotate`
- [ ] Confirm sudo access: `sudo -n systemctl status` (no password)
- [ ] Check disk space: `df -h /var/log` (has > 1GB free)

### Implementation Checklist
- [ ] Update jit-heartbeat.service with LogsDirectory directives
- [ ] Create /etc/logrotate.d/jit-heartbeat config
- [ ] Refactor scripts/heartbeat.sh (remove /tmp logging, add systemd-cat)
- [ ] Create tests/test_log_rotation.sh
- [ ] Create /var/log/jit/ with proper permissions
- [ ] Test service startup: `systemctl restart jit-heartbeat`
- [ ] Verify logs in journal: `journalctl -u jit-heartbeat -n 20`
- [ ] Validate logrotate config: `logrotate -d /etc/logrotate.d/jit-heartbeat`
- [ ] Update documentation

### Post-Implementation Checklist
- [ ] Validate: Service logs appear in journalctl
- [ ] Validate: No logs in /tmp/
- [ ] Validate: logrotate config valid
- [ ] Monitor: /var/log/jit/ disk usage for 24h
- [ ] Validate: 24h log history available via journal
- [ ] Run: bash eval/body-check.sh (full system health)
- [ ] Generate: validation report to /workspaces/Jit/reports/JIT-007-validation.txt
- [ ] Sign off: Complete

---

## Approval Gates

1. **DevOps Approval**: pada confirms all acceptance criteria met
2. **Code Review**: neta reviews refactored heartbeat.sh for style/efficiency
3. **Master Merge**: jit decides whether to merge to main

---

## References

- Spec: `/workspaces/Jit/specs/JIT-007-spec.md`
- Runbook: `/workspaces/Jit/specs/runbooks/JIT-007-runbook.md`
- Audit Source: DEVOPS-002
- Related Tickets: JIT-006 (credentials), JIT-008 (deploy), JIT-010 (health)

