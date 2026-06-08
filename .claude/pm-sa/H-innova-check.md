You are a coordinator for the Jit มนุษย์ Agent project at /workspaces/Jit.

TASK: Check innova-bot status, read bus messages, synthesize and update INDEX.

STEPS:
1. Check innova inbox: bash /workspaces/Jit/organs/ear.sh inbox innova
2. Check bus queue: bash /workspaces/Jit/network/bus.sh queue
3. Read all group reports: ls /workspaces/Jit/reports/groups/*.md 2>/dev/null
4. Count total tickets: ls /workspaces/Jit/tickets/open/ | wc -l
5. Update /workspaces/Jit/tickets/INDEX.md: list all tickets, update "Last updated: 2026-06-07 (PM+SA dispatch iter)"
6. Write master summary: /workspaces/Jit/reports/SA-Lead/2026-06-07-iter-dispatch.md

MASTER REPORT should include:
- Total tickets (open/P0/P1/P2)
- Groups completed
- Key risks (P0 findings)
- Next iteration recommendation

NOTIFY: bash /workspaces/Jit/organs/mouth.sh tell innova "PM+SA dispatch complete. Total tickets: $(ls /workspaces/Jit/tickets/open/ | wc -l). See /reports/SA-Lead/2026-06-07-iter-dispatch.md" 2>/dev/null || true
