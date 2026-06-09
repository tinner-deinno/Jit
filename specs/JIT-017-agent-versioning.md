# JIT-017: Add Capability Versioning to Agent Registry

**Date**: 2026-06-07  
**Status**: completed (2026-06-07)  
**Author**: lak (Solution Architect)

## Context

ระบบ multi-agent ขาด mechanism ในการติดตาม version ของ agent capabilities ทำให้:
- ไม่สามารถตรวจสอบความเข้ากันได้ของ message protocol ระหว่าง agents
- ไม่ทราบวา agent ใดยังไม่ได้ update capability ล่าสุด
- ยากต่อการ debug ปัญหาจาก version mismatch

## Decision

เพิ่ม capability versioning system ดังนี้:

1. **registry.json**: เพิ่ม `version` field (semver) ในทุก agent entry
2. **.agent.md files**: เพิ่ม `## Version` section ทุกไฟล์
3. **Bus messages**: เพิ่ม `x-agent-version` header
4. **router.sh filtering**: ตรวจสอบ `MANUSAT_MIN_AGENT_VER` environment variable
5. **Version mismatch logging**: บันทึก `BUS_VERSION_MISMATCH` (non-fatal by default)

## Semver Strategy

| Version | Meaning |
|---------|---------|
| MAJOR | Breaking changes to capabilities or protocol |
| MINOR | New capabilities added (backward compatible) |
| PATCH | Bug fixes, no capability changes |

Initial version: `1.0.0` for all agents (baseline)

## Message Header Format

```
from:<agent>
to:<agent>
subject:<subject>
x-agent-version: 1.0.0
timestamp:...
---
<body>
```

## Version Check Logic

```bash
check_version() {
  local msg_version="$1"
  local min_version="${MANUSAT_MIN_AGENT_VER:-0.0.0}"
  if version_lt "$msg_version" "$min_version"; then
    log_action "BUS_VERSION_MISMATCH" "Agent version $msg_version < $min_version"
    [ "${MANUSAT_STRICT_VERSION:-0}" = "1" ] && return 1
  fi
  return 0
}
```

## Consequences

### Positive
- สามารถติดตาม agent capability versions ได้
- ป้องกัน incompatibility จาก protocol changes
- Debug ง่ายขึ้นเมื่อมี version mismatch

### Negative
- เพิ่ม complexity ให้ bus protocol
- ต้อง maintain version ใน 2 ที่ (registry + .agent.md)

### Mitigation
- ใช้ script automate version sync ระหว่าง registry และ .agent.md
- Default เป็น non-strict mode (log แต่ไม่ reject)
