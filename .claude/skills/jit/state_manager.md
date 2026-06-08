# Skill: State Manager (Tier 3 Worker)

**Purpose:** CRUD operations on task `.json` state files

**Trigger phrase:** "manage state", "update task", "read task state"

**Provider:** `--provider ollama --model small` (Tier 3: Gemma/Haiku)
**Fallback:** `--provider claude --model haiku`

**Contract:**
- Input: `{action: "read"|"write"|"update", path: "task.json", data?: {...}}`
- Output: `{status: "ok"|"error", content: {...}}`

**Capabilities:**
1. Create new task JSON from template
2. Read task JSON + parse fields
3. Update status, audit_log, deliverables
4. Validate against schema

**Error Handling:**
- Malformed JSON → escalate to Tier 2 Orchestrator
- File not found → create template
- Permission denied → report + exit

**Example Invocation:**
```bash
bash limbs/llm.sh call "Skill: state_manager. Read task_01.json and show current status" \
  --provider ollama --model small
```
