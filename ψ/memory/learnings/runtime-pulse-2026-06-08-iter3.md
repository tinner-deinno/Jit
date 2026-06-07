# Jit Runtime Pulse Notebook - 2026-06-08 (Iter 3)
## Technical Trace: Deterministic Thai Routing
- **Problem**: Thai language tokenization is inconsistent across different LLM backends. If the Router uses token counts or token-hashes to decide which model to use, the routing becomes non-deterministic (flaky).
- **Solution Pattern**: Introduce a "Syllable-Splitter" (Deterministic Pre-processor). By splitting Thai text into syllables *before* it hits the router, we create a consistent "canonical form" of the input.
- **Implementation Path**: `limbs/thai-splitter.js` $\rightarrow$ `Routing Logic` $\rightarrow$ `Verification Corpus`.

## Efficiency Note (Sufficiency)
Instead of a massive refactor, I have broken the work into "micro-tickets" (006a, 006b, etc.). This allows the CommandCode fleet to execute in parallel without overlapping, minimizing token waste and maximizing a-priori verification.

## System Health
- CPU: Still peaking on one Ollama process. I am continuing to monitor this to ensure it's not a memory leak.
- Bus: Transitioning from "Status Noise" to "Task-Driven" flow.
