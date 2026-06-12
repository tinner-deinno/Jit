# TICKET-MANUS-REBIRTH: The Great Integration
**Goal**: Transform innomcp into a "Beautiful & Complete" system aligned with Manus.ai philosophy and MDES branding.

## 🎯 Success Criteria
- [ ] **UI**: 3-column layout (Nav | Chat | Context) with full MDES Branding.
- [ ] **Engine**: 100% powered by `mdes.ollama` with deterministic routing.
- [ ] **Observability**: Full Request ID Tracing from UI $\rightarrow$ Orchestrator $\rightarrow$ Organ $\rightarrow$ Ollama.
- [ ] **Standard**: All responses follow the `{ ok, request_id, data, error }` wrapper.

---

## 🗺️ Execution Roadmap

### Phase 1: Foundation & Tracing (The Skeleton)
- **Core Task**: Standardize the communication layer.
- **Items**:
  - [ ] Implement standard response wrapper in all 14 organs.
  - [ ] Inject `request_id` into every call stack for end-to-end traceability.
  - [ ] Configure `mdes.ollama` as the primary provider with robust fallback.
  - [ ] Audit and fix all "Ugly" routing bugs identified by Antigravity.

### Phase 2: Manus-Style UI (The Skin)
- **Core Task**: Build the high-end interface.
- **Items**:
  - [ ] Implement 3-column layout (Navigation $\rightarrow$ Main Workspace $\rightarrow$ Detail/Context Panel).
  - [ ] Apply MDES Design System (Colors, Typography, Components).
  - [ ] Integrate `request_id` into the UI for "Live Trace" views.
  - [ ] Implement a "Workspace State" manager to persist context per session.

### Phase 3: Integration & Hardening (The Spirit)
- **Core Task**: Verify and polish until "Symmetric".
- **Items**:
  - [ ] Run the full Playwright test suite (from MEGA burn) against the new UI.
  - [ ] Execute a 10-wave Mantra burn on critical paths (Auth $\rightarrow$ Routing $\rightarrow$ Response).
  - [ ] Perform a final "Symmetry Audit" with Antigravity to ensure zero-divergence.
  - [ ] Deploy as a "Production Ready" gold build.

---

## 🛠️ CommandCode Team Instructions
1. **Zero-Idle**: Work in parallel waves.
2. **Mantra-First**: Any bug fix must be burned 10 times before being marked 'Done'.
3. **Standard-Strict**: No code without `request_id` will be merged.
4. **Visual-Driven**: UI changes must be accompanied by a screenshot/comparison.

---

## 💎 Symmetry Evidence (Refined Deliverables)
*These items have passed the 10x Mantra-burn and are ready for Final Assembly.*

### 🧠 Cognitive & Coordination (A-D Series)
- [x] **API Contract v2.3.0**: Full REST spec with pagination and standard error wrappers (`MEGA-B06`).
- [x] **Nerve System (Sayanprasathan)**: Pure Conduit routing with Priority-based Shedding (`MEGA-D14`).
- [x] **Hearing System (Karn)**: High-precision signal relay with formal State Machine (`MEGA-D11`).
- [x] **Release & Recovery**: Production-ready Release Checklist and Rollback Plan v2.0 (`MEGA-B01`, `MEGA-B03`).

### 🎨 Sensory & Experience (E-F Series)
- [x] **Error Toast Taxonomy**: Unified 5-category error system with Dynamic Dismissal and Anti-spam logic (`MEGA-E03`).
- [x] **A11y Gold Standard**: Full accessibility audit and remediation path for Chat UI (`MEGA-E04`).
- [x] **Symmetric Testing**: Comprehensive Playwright suites for Login and Living Chat (`MEGA-A01`, `MEGA-A02`).

