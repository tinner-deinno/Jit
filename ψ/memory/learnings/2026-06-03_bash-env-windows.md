---
pattern: Avoid wrapping bash scripts in PowerShell for env var setting on Windows
date: 2026-06-03
source: rrr: Jit
concepts: [environment, bash, powershell, windows, crlf]
---

# Bash Execution on Windows

When working in a Windows environment with a Bash-based toolset:
- Avoid using PowerShell to launch Bash scripts, even for simple tasks like setting environment variables.
- PowerShell's interpretation of line endings and its interaction with the underlying shell can lead to `$\r': command not found` errors.
- **Correct Pattern**: Use the Bash tool directly and chain commands: `export AGENT_NAME=xxx; bash organs/ear.sh inbox`.
