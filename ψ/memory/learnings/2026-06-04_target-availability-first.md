---
pattern: Verify the target is alive before debugging the tool.
date: 2026-06-04
source: rrr: Jit
concepts: [debugging, automation, environment, target-verification]
---

# Target Availability First

When using a complex diagnostic tool (like a Chrome DevTools MCP server), it is easy to mistake a target failure (`ERR_CONNECTION_REFUSED`) for a tool failure. 

**Rule**: Always perform a basic connectivity check (e.g., `curl` or a simple `fetch`) on the target URL before investing time in configuring or troubleshooting the diagnostic harness. a "dead" target makes the most perfect tool useless.
