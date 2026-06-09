# 📖 Corporate Operation Manual (COM)
**Version**: 1.0 | **Context**: Event-Driven & Shared-Blackboard

## 1. The "Blackboard" Protocol (Sovereign Memory)
To prevent the "Telephone Game" (information loss), the company uses a **Project Blackboard** (`ψ/projects/[project_id]/state.json`).

- **Rule**: No agent shall rely on a message sent by another agent to understand the *current state* of the project.
- **Action**: Before starting any task, an agent MUST read the `state.json`. After completing a task, an agent MUST update the `state.json` with a timestamped entry.

## 2. Workflow: The Life of a Ticket
When a ticket (e.g., `innomcp`) is assigned:

1. **The Intake (Sovereign $\rightarrow$ Hub)**:
   - `Ollama Proxy` pushes the TOR and Ticket to the `Company Hub`.
   - `Hub` creates the Project Folder and initializes the `state.json`.

2. **The Strategic Brief (Hub $\rightarrow$ Dept Head)**:
   - `President` breaks the TOR into specific departmental tasks.
   - `Dept Heads` (Sonnet) allocate resources to their `Deputies` (Kimi).

3. **The Execution Loop (Deputy $\rightarrow$ Team)**:
   - ` la-team` (SA/PA/DEV) work in a tight loop.
   - They use the **Skill Chain** (provided by Opus) to execute tasks.
   - Every commit/output is linked to a specific TOR requirement.

4. **The Audit Gate (Team $\rightarrow$ Auditor)**:
   - Once a task is "complete", it is sent to **GPT-5.5 (Internal Auditor)**.
   - `GPT-5.5` performs a **Scrutinize** pass.
   - **Decision**:
     - `PASS` $\rightarrow$ Work moves to the next department or to delivery.
     - `FAIL` $\rightarrow$ Work is sent back to the `Deputy` with a "Defect Report". (Limit: 3 loops before Departmental Reset).

5. **The Delivery (Auditor $\rightarrow$ Sovereign)**:
   - The verified output is sent to `Ollama Proxy`.
   - `Ollama Proxy` presents the final result to `innova` with the Auditor's seal.

## 3. Crisis Management (The Opus Trigger)
If any department reports a "Blocker" that lasts more than 2 cycles:
- The `Head` invokes **Claude Opus**.
- `Opus` enters the project as a **"Special Envoy"**.
- `Opus` analyzes the `state.json` and the `Audit Reports` to identify the root cause.
- `Opus` rewrites the a-la-carte skill or the implementation plan.

## 4. Skill Evolution (The Lab)
- The **Skill Lab** continuously monitors the "Defect Reports" from GPT-5.5.
- If a recurring mistake is found, the Lab creates a new **G-SKLL** to automate the fix.
- The new skill is pushed to all agents' available toolsets.
