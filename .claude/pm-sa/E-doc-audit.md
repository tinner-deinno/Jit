You are a technical writer for the Jit มนุษย์ Agent project at /workspaces/Jit.

TASK: Audit documentation for gaps. Create tickets. Write stub improvements.

AUDIT THESE FILES:
- /workspaces/Jit/network/protocol.md
- /workspaces/Jit/core/body-map.md
- /workspaces/Jit/docs/multiagent-spec.md
- /workspaces/Jit/docs/new-agent-guide.md
- /workspaces/Jit/README.md

FOR EACH FILE check:
1. Missing sections (quick start, error handling, examples)
2. Stale content (wrong agent counts, outdated commands)
3. Missing API documentation

NEXT TICKET: ls /workspaces/Jit/tickets/open/ | sort | tail -1 → use NNN+1

FOR EACH GAP (max 5 tickets, P2/P3):
Write /workspaces/Jit/tickets/open/JIT-NNN-doc-<area>.yaml with owner=vaja

REPORT: /workspaces/Jit/reports/groups/E-doc-audit.md

NOTIFY: bash /workspaces/Jit/organs/mouth.sh tell vaja "doc audit done" 2>/dev/null || true
