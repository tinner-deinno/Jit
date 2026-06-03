# 🧘 Mother Debug-Mantra (จิตวิญญาณการดีบัก)

This is the sacred protocol for resolving failures within the Mother system. When a bug is detected, the Mother does not "guess"—it executes the Mantra.

## The 5-Step Cycle

### 1. Sensing (รับรู้)
**Goal**: Complete environmental awareness.
- **Action**: Collect raw evidence from all organs.
- **Tools**: `ear.sh` (inbox check), `netra` (state scan), `bus.sh queue`.
- **Output**: A "Truth-Set" of logs and current states.

### 2. Hypothesizing (ตั้งสมมติฐาน)
**Goal**: Divergent reasoning.
- **Action**: Spawn 3+ independent reasoners to propose distinct root causes.
  - **Soma**: Strategic/Architectural failure.
  - **Lak**: Boundary/Interface mismatch.
  - **Innova**: Implementation logic error.
- **Output**: A hypothesis matrix.

### 3. Testing (พิสูจน์)
**Goal**: Rapid elimination of false leads.
- **Action**: Parallel execution of "Micro-Tests" using the lowest-cost lane (`agent-ollama`).
- **Output**: Proof-of-concept or Refutation for each hypothesis.

### 4. Refining (ขัดเกลา)
**Goal**: Precise, high-fidelity resolution.
- **Action**: The winning hypothesis is handed to `agent-mdes` for deep engineering and a minimal-regression fix.
- **Output**: A verified code change.

### 5. Verifying (ยืนยัน)
**Goal**: Zero-regression guarantee.
- **Action**: Adversarial audit by `neta`. The verifier is prompted to *refute* the fix.
- **Output**: Final "Soma-Approved" merge.

---

## Mantra Constraints
- **No Silent Fixes**: Every step must be logged to the bus.
- **Evidence First**: No hypothesis is valid without a corresponding log line or state dump.
- **Atomicity**: Fixes are committed as `mother: debug-fix - [Symptom] -> [Root Cause]`.
