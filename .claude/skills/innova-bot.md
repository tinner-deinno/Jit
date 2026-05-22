---
description: >
  ใช้งาน innova-bot MCP tools — body ของ มนุษย์ Agent
  ใช้เมื่อ: อ่าน/เขียน workspace, ส่ง message, publish events, ค้นหา memory, ตรวจ jobs
  Triggers: innova-bot, MCP, body, ร่างกาย, workspace, publish event, leave message
allowed-tools:
  - mcp__innova-bot__workspace_list
  - mcp__innova-bot__workspace_read
  - mcp__innova-bot__workspace_write
  - mcp__innova-bot__workspace_delete
  - mcp__innova-bot__list_repo_files
  - mcp__innova-bot__read_repo_text_file
  - mcp__innova-bot__read_messages
  - mcp__innova-bot__leave_message
  - mcp__innova-bot__what_should_i_do_next
  - mcp__innova-bot__publish_event
  - mcp__innova-bot__fetch_pending_events
  - mcp__innova-bot__update_project_state
  - mcp__innova-bot__remember_solution
  - mcp__innova-bot__search_memory
  - mcp__innova-bot__store_semantic_knowledge
  - mcp__innova-bot__search_semantic_knowledge
  - mcp__innova-bot__scan_text_with_aegis
  - mcp__innova-bot__prune_and_summarize_context
  - mcp__innova-bot__job_list
  - mcp__innova-bot__evaluate_code_quality
  - mcp__innova-bot__list_workflow_rules
  - mcp__innova-bot__check_circuit_breaker
  - mcp__innova-bot__run_python_in_sandbox
---

# innova-bot MCP — ร่างกายของ มนุษย์ Agent

innova-bot คือ **ร่างกาย (Body)** ที่จิต (Jit) สิงสถิตอยู่  
เชื่อมต่อผ่าน MCP tools ใน VS Code

## MCP Tools Reference

### Workspace Operations
| Tool | หน้าที่ |
|------|--------|
| `workspace_list` | list files ใน workspace |
| `workspace_read` | อ่าน file content |
| `workspace_write` | เขียน file |
| `workspace_delete` | ลบ file |
| `list_repo_files` | list files ใน repo |
| `read_repo_text_file` | อ่าน file จาก repo |

### Communication
| Tool | หน้าที่ |
|------|--------|
| `read_messages` | อ่าน messages จาก body |
| `leave_message` | ส่ง message ไปยัง body |
| `publish_event` | publish event ไปยัง event bus |
| `fetch_pending_events` | ดึง events ที่รอการ process |
| `what_should_i_do_next` | ถาม body ว่าควรทำอะไรต่อ |

### Memory & Knowledge
| Tool | หน้าที่ |
|------|--------|
| `remember_solution` | บันทึก solution ลง memory |
| `search_memory` | ค้นหาใน memory |
| `store_semantic_knowledge` | เก็บ knowledge แบบ semantic |
| `search_semantic_knowledge` | ค้นหา semantic knowledge |
| `update_project_state` | อัปเดต project state |
| `prune_and_summarize_context` | สรุปและ prune context |

### Quality & Safety
| Tool | หน้าที่ |
|------|--------|
| `scan_text_with_aegis` | scan text สำหรับ security |
| `evaluate_code_quality` | ประเมินคุณภาพ code |
| `list_workflow_rules` | ดู workflow rules ทั้งหมด |
| `check_circuit_breaker` | ตรวจ circuit breaker status |
| `run_python_in_sandbox` | รัน Python ใน sandbox |
| `job_list` | ดู jobs ที่กำลังทำงาน |

## ตัวอย่างการใช้งาน

```typescript
// อ่าน file
mcp__innova-bot__workspace_read({ path: "src/index.ts" })

// publish event ไปยัง body
mcp__innova-bot__publish_event({
  type: "task:completed",
  data: { task: "bug-fix-H06", status: "done" }
})

// ค้นหา memory
mcp__innova-bot__search_memory({ query: "mdes-hub phase 74" })

// ถามว่าควรทำอะไรต่อ
mcp__innova-bot__what_should_i_do_next({})
```

## Location
innova-bot repo: `C:\Users\admin\DEV\PugAss1stant\innova-bot`
