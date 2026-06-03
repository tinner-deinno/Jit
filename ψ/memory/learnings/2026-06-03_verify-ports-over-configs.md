---
pattern: Verify active ports over config defaults
date: 2026-06-03
source: rrr: Jit
concepts: [infrastructure, debugging, networking]
---

# Verify Active Ports Over Config Defaults

In complex local multi-agent environments where services are launched via various scripts (`.bat`, `.cmd`, `.sh`), the configuration files or `process.env` defaults in the code are often deceptive. 

**The Pattern**: A service may be "up" but listening on a port different from the one the client expects, leading to a "Connection Refused" error that looks like a service crash.

**The Rule**: Before diagnosing a service as "down" or "offline," use system-level tools to find the actual listener:
- Windows: `Get-NetTCPConnection -LocalPort <expected_port>` or `netstat -ano | findstr :<port>`
- Unix: `lsof -i :<port>` or `netstat -tulnp | grep <port>`

**Why**: This eliminates the "config-drift" variable and confirms the actual state of the "body" before attempting to fix the "mind" (the code).
