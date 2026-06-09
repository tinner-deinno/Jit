# Skill: Innova-Bot Bridge (System Executor)

**Purpose:** Call innova-bot commands (think, act, execute) from agents

**Trigger phrase:** "execute", "run command", "innova-bot"

**Provider:** Passthrough (innova-bot is the executor, no LLM)

**Contract:**
- Input: `{command: "think"|"act"|"execute", args: [...]}`
- Output: `{status, result: stderr/stdout}`

**Capabilities:**
1. `think.sh` — mindfulness logging
2. `act.sh` — action execution
3. `limbs/llm.sh` — multi-provider LLM calls
4. File read/write via organs/hand.sh

**Error Handling:**
- Command not found → fallback to shell
- Permission denied → report + escalate to operator

**Example:**
```
innova-bot think "About to update state files"
innova-bot act "Update task_01.json status to complete"
```
