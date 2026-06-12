<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C07 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":132,"completion_tokens":1487,"total_tokens":1619} | 16s
 generated: 2026-06-12T19:29:11.612Z -->
```markdown
# orch-pipeline

Orchestration skill adapting everything-claude-code gated workflow to the Jit 14-organ system.
Task sizing (small / standard / large) gates which phases execute and whether human approval is required.

## Phase → Organ Map

| Phase      | Organ    | Role                          |
|------------|----------|-------------------------------|
| Research   | drishti  | Gather context, scope intent  |
| Plan       | yojana   | Produce step plan, estimates  |
| Gate       | (human)  | Jit/human approval checkpoint |
| Implement  | innova   | Generate code, apply changes  |
| Test       | chamu    | Validate outputs, run checks  |
| Review     | neta     | Confidence gate, sign-off     |
| Deploy     | pada     | Ship artifact, release        |
| Report     | vaja     | Summarise, handoff, close     |

## Task Sizing

| Size     | Phases                                        | Gates         |
|----------|-----------------------------------------------|---------------|
| small    | Plan → Implement → Report                     | none (auto)   |
| standard | Research → Plan → Implement → Test → Review → Report | pre-Implement (optional) |
| large    | Research → Plan → [GATE] → Implement → Test → Review → [GATE] → Deploy → Report | required before Implement + Deploy |

## Dispatch Protocol

All organ invocations route through the bus:

```
organs/mouth.sh tell <organ> "<payload>"
```

Payload is a JSON fragment with keys: `task_id`, `context` (prior phase output), `directive` (what to do), `sizing`.

## Pipeline Flow

### 1. Research (drishti)
```
organs/mouth.sh tell drishti '{"task_id":"$ID","directive":"scope & gather","sizing":"$SIZE"}'
```
Output: context blob (intent, constraints, references).

### 2. Plan (yojana)
```
organs/mouth.sh tell yojana '{"task_id":"$ID","context":<drishti_output>,"sizing":"$SIZE"}'
```
Output: ordered step plan with estimates.

### 3. Gate (human/jit)
For standard/large tasks: surface plan to user for approval.
Large tasks **must** receive explicit `approve` before dispatch to innova.
Standard tasks may auto-proceed with confidence threshold.

### 4. Implement (innova)
```
organs/mouth.sh tell innova '{"task_id":"$ID","context":<yojana_output>}'
```
Produces the artifact (code, config, doc).

### 5. Test (chamu)
```
organs/mouth.sh tell chamu '{"task_id":"$ID","context":<innova_output>}'
```
Runs validation; returns pass/fail + evidence.

### 6. Review (neta, confidence gate)
```
organs/mouth.sh tell neta '{"task_id":"$ID","context":<chamu_output>,"threshold":0.9}'
```
Confidence gate. If score < threshold, loops back to Implement with feedback.
On pass, emits signed review blob.

### 7. Deploy (pada) — large tasks only
```
organs/mouth.sh tell pada '{"task_id":"$ID","context":<neta_output>}'
```
Ships the artifact. Requires prior gate approval.

### 8. Report (vaja) — always final
```
organs/mouth.sh tell vaja '{"task_id":"$ID","context":<final_phase_output>}'
```
Produces summary, changelog entry, and handoff note. Closes the task loop.

## Gate Logic

- **small**: auto-pass all gates (no human interrupt).
- **standard**: optional pre-Implement gate; auto-proceed if neta confidence ≥ 0.9.
- **large**: mandatory gates before Implement AND Deploy. Human or Jit must explicitly approve.

## Loopback

If chamu fails or neta confidence below threshold, return to innova with feedback payload. Max 3 loops before escalating to human.
```
