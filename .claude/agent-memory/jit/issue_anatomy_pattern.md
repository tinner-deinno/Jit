---
name: Anatomy Pattern Missing in Oracle
description: soul-check fails on anatomy query — Oracle returns unrelated results instead of body-map content
type: project
---

soul-check.sh reports ❌ on the anatomy stored check. When querying Oracle for "anatomy", it returns learning documents unrelated to the body-map organ structure.

**Why:** The body-map.md organ RACI data has not been explicitly stored in Oracle under a canonical "anatomy" key. The FTS search returns nearest-neighbor results which are not the expected anatomy record.

**How to apply:** Non-blocking — system is fully operational. To fix: run `bash limbs/oracle.sh learn "anatomy" "$(cat /workspaces/Jit/core/body-map.md | head -50)" "anatomy,organs,body-map,raci"` to store the canonical record.
