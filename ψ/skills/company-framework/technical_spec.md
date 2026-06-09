# 🛠️ Technical Specification: The Company Skill-Chain (Opus-Sourced)
**Focus**: Multi-Agent Orchestration & High-Fidelity Execution

## 1. Skeleton: `multiagent_parallel_call`
Instead of sequential chatting, this skeleton implements a **"Fan-out / Fan-in"** pattern.

- **Fan-out**: The `Deputy` (Kimi) triggers $N$ agents (e.g., SA, PA, DEV) simultaneously with the same `Shared Blackboard` context.
- **Processing**: Each agent works on a specific sub-dimension of the task.
- **Fan-in**: Results are aggregated into a `Candidate_Solution` file.
- **Audit**: The `Candidate_Solution` is sent to `GPT-5.5` for a single, holistic review.

## 2. The "Shared Blackboard" System
Implemented as a JSON state machine in `ψ/projects/[id]/state.json`.

```json
{
  "project_id": "innomcp",
  "tor_version": "1.0",
  "current_phase": "Sprinting",
  "artifacts": {
    "design_doc": "path/to/design.md",
    "impl_plan": "path/to/plan.md"
  },
  "audit_history": [
    { "cycle": 1, "status": "FAILED", "reason": "Missing error handling in module X" }
  ],
  "blockers": [],
  "completed_requirements": ["REQ-01", "REQ-02"]
}
```

## 3. Skill Chain: `Sovereign_Delivery_Loop`
A high-level chain that ensures no human sees un-audited code.

`Sovereign_Delivery_Loop` $\rightarrow$ `Skill_Execute( la-team )` $\rightarrow$ `Skill_Audit( GPT-5.5 )` $\rightarrow$ `Decision(Pass/Fail)`
- If `Fail` $\rightarrow$ `Skill_Analyze_Defect( Opus )` $\rightarrow$ `Skill_Execute`
- If `Pass` $\rightarrow$ `Skill_Deliver( Ollama Proxy )`

## 4. Agent Registry Update
To support this, the `/network/registry.json` must be updated to include the `Company_Hub` and `Audit_Gate` agents with their respective provider overrides.
