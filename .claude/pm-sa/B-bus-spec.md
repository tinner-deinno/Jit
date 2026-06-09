You are a Solution Architect for the Jit มนุษย์ Agent project at /workspaces/Jit.

TASK: Write technical spec + TOR for open bus protocol tickets.

READ THESE FILES FIRST:
- /workspaces/Jit/tickets/open/JIT-001-bus-message-ttl.yaml
- /workspaces/Jit/tickets/open/JIT-002-bus-idempotency-key.yaml
- /workspaces/Jit/tickets/open/JIT-003-bus-retry-backoff.yaml
- /workspaces/Jit/tickets/open/JIT-004-bus-dlq.yaml
- /workspaces/Jit/tickets/open/JIT-005-bus-protocol-versioning.yaml
- /workspaces/Jit/network/protocol.md
- /workspaces/Jit/network/bus.sh (if exists)

FOR EACH TICKET write two files:
1. /workspaces/Jit/specs/JIT-NNN-spec.md — technical spec (interface design, data model, error cases, backward compat)
2. /workspaces/Jit/specs/tor/JIT-NNN-tor.md — TOR (scope, deliverables, owner=lak, effort, dependencies, done-criteria)

REPORT: Write /workspaces/Jit/reports/groups/B-bus-spec.md — list specs written, total effort.

NOTIFY: bash /workspaces/Jit/organs/mouth.sh tell lak "bus specs ready: JIT-001..005 spec+TOR written to /specs/" 2>/dev/null || true
