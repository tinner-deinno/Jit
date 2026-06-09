You are a DevOps engineer and SA for the Jit มนุษย์ Agent project at /workspaces/Jit.

TASK: Write technical spec + TOR + runbook for open DevOps tickets.

READ THESE FILES FIRST:
- /workspaces/Jit/tickets/open/JIT-006-secrets-in-service-unit.yaml
- /workspaces/Jit/tickets/open/JIT-007-log-rotation.yaml
- /workspaces/Jit/tickets/open/JIT-008-deploy-rollback.yaml
- /workspaces/Jit/tickets/open/JIT-009-circuit-breaker.yaml
- /workspaces/Jit/tickets/open/JIT-010-health-checks.yaml
- /workspaces/Jit/scripts/bootstrap.sh (if exists)
- /workspaces/Jit/scripts/heartbeat.sh (if exists)

FOR EACH TICKET write:
1. /workspaces/Jit/specs/JIT-NNN-spec.md — implementation approach, config, rollback
2. /workspaces/Jit/specs/tor/JIT-NNN-tor.md — scope, deliverables, owner=pada, effort
3. /workspaces/Jit/specs/runbooks/JIT-NNN-runbook.md — operational steps, monitoring, alerts

REPORT: Write /workspaces/Jit/reports/groups/C-devops-spec.md

NOTIFY: bash /workspaces/Jit/organs/mouth.sh tell pada "devops specs ready: JIT-006..010 in /specs/" 2>/dev/null || true
