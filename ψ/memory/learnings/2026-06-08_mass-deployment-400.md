---
name: 2026-06-08-mass-deployment-400
description: 400+ agent mass deployment for innomcp backlog - 8 departments, each with 50+ workers
metadata:
  type: learning
---

# Mass Deployment Architecture: 8 Departments for innomcp

**What**: 400+ subagents deployed across 8 departments to complete TICKET-001 through TICKET-010

**Department Structure**:
1. **CommandCode Bridge** (TICKET-001) - Wire commandcode.ai as provider
2. **Thai NLP** (TICKET-006a, 006b) - Syllable splitter + test corpus
3. **Routing Core** (TICKET-007a, 007b, 008) - Routing refactor + symmetry + proxy
4. **QA & Determinism** (TICKET-004, 009) - Test suite + regression
5. **Knowledge & Memory** (TICKET-002, 005) - Thai knowledge audit + memory symmetry
6. **GeoTools** (TICKET-003) - Thai address parsing + geocoding
7. **Performance** (TICKET-010) - Latency benchmarks + optimization
8. **Integration & E2E** (ALL) - Full system integration + release

**Rules from innova**:
- Department heads MUST be Opus model (cross-provider or GPT5.5)
- Every agent must communicate with innova-bot
- Be economical with Ollama (only ollama_mdes + thaillm alive)
- Don't die while developing innomcp
- innomcp and Jit are the ONLY company products
- Jit must use all organs + innova-bot 100%
- innova sleeping → autonomous loop running

[[innomcp]] [[mass-deployment]] [[agent-orchestration]]