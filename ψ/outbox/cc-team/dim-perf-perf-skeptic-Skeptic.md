<!-- cc-team deliverable
 group: dim-perf (Performance Analysis)
 member: perf-skeptic role=Skeptic model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":21,"completion_tokens":1926,"total_tokens":1947,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":384,"image_tokens":0},"cache_creation_input_tokens":0} | 16s
 generated: 2026-06-12T10:28:50.878Z -->
This is an excellent request. The gap between a synthetic benchmark result and actual user pain is where most performance engineering effort is wasted.

First, a quick clarification: **perf-hunter** is not a standard, widely-known tool (unlike `perf`, `flamegraph`, `py-spy`). It sounds like either:
1.  An internal tool at your company.
2.  A custom script that wraps `perf` events (e.g., **perf** + **hunter** for specific events like cache misses).
3.  A misspelling (e.g., `perf` + `g-hunter`).

Assuming you have a list of bottlenecks from a performance profiler, the core skill is **triage**. Here is a structured framework to critically evaluate each finding and question its **real-world impact**.

---

### The Critical Questions Framework for Each Finding

For every bottleneck the tool identifies, you should challenge it with these five questions.

#### 1. Is the bottleneck on the **Critical Path**?
- **The Finding:** "Function `calculateHash()` takes 500ms."
- **The Question:** Is this 500ms *adding* to the user's wait time, or is it happening in the background?
    - **Real-World Impact (High):** If the user clicks "Save" and waits for a response, and this hash is blocking that response. This is *synchronous* and *latency-bound*.
    - **Real-World Impact (Low):** If this hash runs in a background worker queue after the response is sent, or a pre-fetch thread, the user never perceives that 500ms. It only matters if it causes resource starvation elsewhere.

#### 2. What is the **Frequency** of this code path?
- **The Finding:** "Cold cache miss rate is 40% for `dataLoader.load()`."
- **The Question:** How often does `dataLoader.load()` execute in a standard user session?
    - **Real-World Impact (High):** User loads a dashboard (1 request) that calls this 10,000 times. A 40% miss rate is catastrophic.
    - **Real-World Impact (Low):** User opens a rarely used dialog that calls this once. Even a 100% miss rate is a non-issue (a one-time cost of a few hundred microseconds). **N.B.** Profilers often amplify rare events.

#### 3. Is the synthetic workload representative of **Your Users**?
- **The Finding:** "95% CPU utilization in `applyFilter()`."
- **The Question:** What was the input data used for the profiler run?
    - **Scenario A (Synthetic Test):** The test used a dataset with 1 million rows and a complex regex filter. This is high CPU.
    - **Real-World Behavior:** The actual production dataset averages 100 rows, and filters are simple exact matches. The CPU time drops from 5 seconds to 10 microseconds. The finding is **irrelevant** to real users.
    - **Action:** Run the profiler on a production traffic replay or a real user session recording, not a synthetic load generator.

#### 4. What is the **Magnitude** vs. the **Context**?
- **The Finding:** "30,000 system calls per second."
- **The Question:** What is the total request latency? What is the service level objective (SLO)?
    - **Context A (High Impact):** The average request latency is 50ms. These syscalls (context switching) are the dominant cost (40ms).
    - **Context B (Low Impact):** The average request latency is 10 seconds (e.g., a large file upload or ML inference). 40ms of syscall overhead is ~0.4% of the time. Optimizing it offers negligible user benefit.
    - **Rule of Thumb:** "A 10% improvement on a 1ms bottleneck yields 0.1ms gain. A 1% improvement on a 10s bottleneck yields 100ms gain." Focus on the absolute time removed, not the relative percentage.

#### 5. Is it a **One-time Cost** or a **Recurring Tax**?
- **The Finding:** "1.2GB memory allocation in `init()`."
- **The Question:** Is this a startup/cold-start cost, or is it happening on every request?
    - **Real-World Impact (Low – for an always-on server):** A heavy startup (e.g., loading a model) that takes 5 seconds is irrelevant if the server stays up for weeks. Users never see it.
    - **Real-World Impact (High – for a Lambda/FaaS):** A 5-second cold start on a serverless function is the *entire* user experience. It kills the service.
    - **Best Practice:** Separate "startup" profiles from "steady-state" profiles.

---

### The "So What?" Triage Protocol

Go through each `perf-hunter` finding and apply this rubric:

| Severity | Criteria | Action |
| :--- | :--- | :--- |
| **Critical** | On critical path. Frequency > 1/request. Magnitude > 10% of total latency. | Investigate immediately. Focus on the **user-perceptible** latency. |
| **Important** | On critical path. Frequency > 1/request. Magnitude < 10% of latency. | Optimize if cheap. Otherwise, document as technical debt. |
| **Minor** | Not on critical path (async/background). High frequency but low cost. | Ignore for now. Monitor for resource exhaustion (e.g., memory leaks). |
| **Irrelevant** | Not on critical path. One-time cost. Synthetic-only workload. | Discard. The tool is creating noise. |

### Key Questions to ask the team / the report author:

1.  **"Can we reproduce this bottleneck with a production traffic replay (e.g., using GoReplay, tcpreplay, or a scaled-down production trace)?"**
    - *Why:* To rule out synthetic artifacts.
2.  **"What is the p99 latency impact of this specific bottleneck if removed?"**
    - *Why:* Forces quantification. A guess is acceptable, a vague "it's slow" is not.
3.  **"Is this a bottleneck in the application code, or is it a symptom of a configuration issue (e.g., too few threads, wrong I/O scheduler, small buffer size)?"**
    - *Why:* Many "perf-hunting" findings are easily solved with a `sysctl` tweak or a single line config change, not months of code refactoring.
4.  **"Did we measure the cost of *avoiding* this bottleneck (e.g., adding caching, complexity)? Is the trade-off worth it?"**
    - *Why:* A 5% performance gain that introduces a 20% increase in code complexity and maintenance burden is a net loss.

**To give you a specific, actionable answer**, please share a few examples from the `perf-hunter` output. Paste the function names, the resource type (CPU, I/O, Lock, Memory), and the metric (e.g., 20% CPU, 15% cache misses, 300ms lock contention). I can then apply this framework directly to your codebase.
