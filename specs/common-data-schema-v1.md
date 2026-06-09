# Common Data Schema v1 — Task State Format

**Effective:** 2026-06-08  
**Owner:** Tier 2 Orchestrator (innova)  
**Reference:** my-Plan.md §2.2 + Opus Review

This schema defines the SINGLE format all agents use to read/write task state. No deviations.

## JSON Structure

```json
{
  "metadata": {
    "schema_version": "1.0",
    "task_id": "uuid-or-slug",
    "created_at": "2026-06-08T10:00:00Z",
    "last_updated_at": "2026-06-08T10:30:00Z"
  },
  "task": {
    "project_name": "string",
    "title": "string",
    "description": "string",
    "status": "pending|in_progress|blocked|completed|failed",
    "priority": "critical|high|normal|low",
    "owner_agent": "string (e.g., 'soma', 'innova', 'chamu')",
    "assigned_tier": "1|2|3|utility",
    "due_date": "ISO8601 or null"
  },
  "requirements": {
    "inputs": ["description of expected inputs"],
    "outputs": ["expected deliverable structure"],
    "constraints": ["technical/business constraints"]
  },
  "deliverables": {
    "design_doc": "path/to/file.md or null",
    "code": "path/to/file.py or null",
    "test_report": "path/to/report.md or null",
    "other": "any other artifacts"
  },
  "audit_log": [
    {
      "timestamp": "2026-06-08T10:00:00Z",
      "agent": "agent_name",
      "action": "task_created|status_change|deliverable_added|error",
      "details": "free text describing what happened"
    }
  ],
  "comments": [
    {
      "timestamp": "2026-06-08T10:00:00Z",
      "author": "agent_name or human",
      "text": "free text comment"
    }
  ]
}
```

## Usage Rules

**Rule 1: Read First, Act Second**
Before any agent modifies a task, it MUST read the entire JSON to understand the full context.

**Rule 2: Atomic Updates**
Each agent updates only the fields relevant to its tier:
- **Tier 3:** `status`, `audit_log` (only its own entry)
- **Tier 2:** `requirements`, `deliverables`, `status`, `audit_log`
- **Tier 1:** `comments`, `status` (final review), `audit_log`

**Rule 3: Immutable Trace**
`audit_log` is APPEND-ONLY. Never delete or edit past entries.

**Rule 4: Status Transitions**
```
pending 
  → in_progress (agent accepted)
    → blocked (escalation needed)
    → in_progress (resolved)
  → completed (agent finished)
  → failed (unrecoverable error)
```

**Rule 5: No Orphaned Tasks**
If a task reaches `blocked` or `failed`, the agent MUST add a comment explaining why + which agent to escalate to.

## Validation

Every state file must pass this checklist:
- [ ] `task_id` is unique
- [ ] `status` is in allowed set
- [ ] `owner_agent` is a valid agent name
- [ ] `audit_log` entries are chronological
- [ ] All file paths are accessible or marked `null`
- [ ] No circular task dependencies

## Examples

### Example 1: New Task (Created by Tier 1 Advisor)

```json
{
  "metadata": {
    "schema_version": "1.0",
    "task_id": "oracle-schema-v1",
    "created_at": "2026-06-08T10:00:00Z",
    "last_updated_at": "2026-06-08T10:00:00Z"
  },
  "task": {
    "project_name": "jit-core",
    "title": "Define Common Data Schema v1",
    "description": "Establish unified JSON format for all task state files",
    "status": "in_progress",
    "priority": "critical",
    "owner_agent": "innova",
    "assigned_tier": 2,
    "due_date": "2026-06-15"
  },
  "requirements": {
    "inputs": ["my-Plan.md §2.2", "Opus review guidance"],
    "outputs": ["specs/common-data-schema-v1.md", "example-task-state.json"],
    "constraints": ["Must align with Jit's 'nothing is deleted' principle"]
  },
  "deliverables": {
    "design_doc": "specs/common-data-schema-v1.md",
    "code": null,
    "test_report": null
  },
  "audit_log": [
    {
      "timestamp": "2026-06-08T10:00:00Z",
      "agent": "opus",
      "action": "task_created",
      "details": "Created as critical foundation for 2-week sprint"
    }
  ],
  "comments": []
}
```

## Tool Support

**State Manager Skill** reads/writes this schema.  
**Tier 3 Worker** validates structure before committing.  
**Tier 1 Advisor** reviews semantics (logic).

---

**Questions for innova:**
1. Are there fields missing?
2. Should we version tasks (v1.0, v1.1, ...)?
3. How to handle task dependencies (task_x blocks task_y)?

See implementation in `.claude/skills/jit/state_manager.md`.
