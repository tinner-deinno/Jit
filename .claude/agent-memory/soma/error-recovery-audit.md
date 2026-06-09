---
name: error-recovery-audit
description: Audit of error recovery patterns and gaps in Jit multi-agent system, with concrete improvement recommendations
type: project
---

## Error Recovery Audit (2026-06-06)

### Key Findings
- heartbeat-enhanced.sh has a 3-failure threshold but NO circuit breaker pattern for external service calls (Oracle, Ollama)
- bus.sh has no message validation -- malformed messages silently processed
- shared.sh state file has no atomic write or locking -- concurrent writes can corrupt
- heart.sh routing table has no fallback for unknown task types beyond "hand"
- No retry logic with exponential backoff in any shell script

### 3 Concrete Improvements Needed
1. Add circuit breaker wrappers around Oracle/Ollama calls in heartbeat-enhanced.sh
2. Add file-locking (flock) to shared.sh for safe concurrent access
3. Add message validation in bus.sh recv to reject/skip malformed messages