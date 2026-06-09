You are a code reviewer (neta) for the Jit มนุษย์ Agent project at /workspaces/Jit.

TASK: Review all organ and limb scripts for code quality issues. Create fix tickets.

READ AND REVIEW EACH FILE:
Organs: ear.sh, mouth.sh, eye.sh, hand.sh, heart.sh, lung.sh, nerve.sh, leg.sh, vitals.sh, pran.sh
(all in /workspaces/Jit/organs/)

Limbs: think.sh, act.sh, speak.sh, oracle.sh, ollama.sh, lib.sh, index.sh
(all in /workspaces/Jit/limbs/)

FOR EACH FILE check:
1. Missing error handling (no exit codes, silent failures)
2. Unquoted variables → injection risk
3. Missing features the organ/limb should have based on its role
4. Dead code or TODO comments
5. Missing logging/tracing

NEXT TICKET: ls /workspaces/Jit/tickets/open/ | sort | tail -1 → use NNN+1

FOR EACH ISSUE (max 10 tickets, P0-P2):
Write /workspaces/Jit/tickets/open/JIT-NNN-<organ>-<issue>.yaml

REPORT: /workspaces/Jit/reports/groups/G-organ-health.md with per-organ score (0-10)

NOTIFY: bash /workspaces/Jit/organs/mouth.sh tell neta "organ health review done" 2>/dev/null || true
