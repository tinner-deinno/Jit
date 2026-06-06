---
pattern: A probe timeout under a service's cold-start lies ("dead" ≠ down); and overriding a backend without its model causes 404s + quota-burning retry storms.
date: 2026-06-03
source: "rrr: Jit"
concepts: [provider-routing, model-router, probing, reliability, multiagent, mother-engine]
---

# Provider probing & backend↔model coupling

Two hard-won rules from building the innomcp Mother dispatch loop, both rooted in
the same mistake: trusting a tidy mental model over measured provider behavior.

## 1. A probe timeout shorter than cold-start will declare live services dead
`ollama_mdes` (gemma4:26b, remote) **timed out at a 25s probe** but **answered at
~28s in the real dispatch**. Cold model load exceeded the probe window, so the
probe reported UNREACHABLE for a working lane. I nearly routed around a perfectly
good (and the only *cheap*) provider.

**Rule**: set probe timeouts above realistic cold-start (35s+ for remote ollama),
and before trusting a "dead" verdict, confirm with one real call. Cold-start ≠ down.

## 2. Backend and model are coupled — override both or neither
First hardening passed `overrideBackend: ollama_cloud` but kept the agent's
`gemma4:26b`. Cloud only has `gemma4:31b-cloud` → **404 model-not-found**, then the
router's rotation retried repeatedly and **helped exhaust the cloud's weekly
quota**. A partial fix damaged a scarce shared resource.

**Rule**: when routing to a different backend, source the model from that backend's
config (`routing.providers[backend].default_model`) and pass it too. Treat
provider+model as one unit. A 404-on-mismatch can cascade into quota loss via retries.

## Corollaries that fell out
- **Neutral defaults must sit at the midpoint, not the max.** A "no reliability data
  = 1.0" default let untested lanes outrank proven-99% ones. Use 0.5 so
  proven-good > untested > proven-bad.
- **Diverse-lens verify swarms earn their cost.** 3–5 cheap agents each attacking a
  distinct surface (injection, scale, concurrency, corruption, fidelity) caught a
  CSV-injection bypass, a missing-transaction 630× slowdown, an Infinity sink, a
  null-crash, and the gate inversion — none caught on first pass.
