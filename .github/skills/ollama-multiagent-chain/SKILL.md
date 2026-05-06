---
name: ollama-multiagent-chain
description: "Use MDES Ollama models as chained sub-agents to accomplish tasks in stages. Each model plays a role (Discuss→Plan→Execute→Verify). Use when: multi-step tasks needing different model strengths, web reading pipelines, agent-to-agent delegation via MDES Ollama. Triggers: chain agents, ollama pipeline, sub-agent chain, ส่งงานระหว่าง agent, pipeline ollama, read-web-chain"
argument-hint: "Describe the task to chain through MDES Ollama sub-agents (e.g., 'read and summarize this URL', 'analyze and fix this code')"
---

# SKILL: ollama-multiagent-chain

ส่งงานเป็นทอดๆ ผ่าน MDES Ollama models หลายตัว โดยแต่ละ loop ใช้หลัก **Discuss → Plan → Execute → Verify**

## Available MDES Ollama Models

| Model | Best For |
|-------|----------|
| `gemma4:26b` | Thai language, general reasoning, creative |
| `qwen3.5:27b` | Deep analysis, complex reasoning |
| `qwen3.5:9b` | Fast reasoning, summaries |
| `qwen2.5-coder:32b` | Code generation, technical tasks |
| `deepseek-coder:33b` | Complex code review, debugging |
| `llama3.1:8b` | Fast Q&A, lightweight tasks |
| `qwen3-vl:32b` | Vision + language (images/web screenshots) |
| `qwen3-vl:8b` | Vision fast tasks |
| `phi3:medium` | Compact, efficient reasoning |

## Chain Architecture

```
Claude (Orchestrator)
    │
    ▼
[STEP 1: Discuss] ─── sub-agent1: qwen3.5:9b  ─── clarify task, expand context
    │
    ▼
[STEP 2: Plan]    ─── sub-agent2: gemma4:26b  ─── create detailed action plan
    │
    ▼
[STEP 3: Execute] ─── sub-agent3: qwen2.5-coder:32b ─── do the actual work
    │
    ▼
[STEP 4: Verify]  ─── sub-agent4: qwen3.5:27b ─── review, validate, grade
    │
    ▼
Oracle.learn() ─── persist output + lessons
```

## Core Helper

Use `limbs/ollama-chain.sh` for all chaining:

```bash
# Single model call
bash limbs/ollama-chain.sh call <model> "<prompt>"

# Run full Discuss→Plan→Execute→Verify chain
bash limbs/ollama-chain.sh chain "<task>" [model1] [model2] [model3] [model4]

# Web reading chain (fetch URL → summarize → analyze → verify)
bash limbs/ollama-chain.sh web-read "<url>" "<question>"
```

## Pattern: Web Reading Chain

```
Claude → fetch_webpage → 
  sub-agent1: qwen3.5:9b  [Discuss: What is this page about?]
  sub-agent2: gemma4:26b  [Plan: What key info is needed?]
  sub-agent3: qwen2.5-coder:32b  [Execute: Extract structured data]
  sub-agent4: qwen3.5:27b [Verify: Is the extraction correct and complete?]
→ Oracle.learn() → return to Claude
```

## How to Use This Skill

### 1. Web Page Reading (Recommended)

```bash
# Read and analyze a web page through 4-model chain
bash limbs/ollama-chain.sh web-read "https://example.com" "สรุปสาระสำคัญ"
```

### 2. Custom Task Chain

```bash
# Chain any task through custom models
bash limbs/ollama-chain.sh chain \
  "วิเคราะห์โค้ดนี้และหาบัก: $(cat myfile.py)" \
  "qwen3.5:9b" \
  "gemma4:26b" \
  "deepseek-coder:33b" \
  "qwen3.5:27b"
```

### 3. Quick 2-Model Pipeline

```bash
# Think → Verify (lightweight)
bash limbs/ollama-chain.sh pipe "your prompt" "llama3.1:8b" "qwen3.5:27b"
```

### 4. Parallel Sub-Agents (independent tasks)

```bash
# Run models in parallel, combine results
bash limbs/ollama-chain.sh parallel "analyze this data:" \
  "qwen3.5:9b" "gemma4:26b" "deepseek-coder:33b"
```

## Loop Structure (Discuss→Plan→Execute→Verify)

Each step wraps the previous output:

**Discuss** — `qwen3.5:9b`
> "Given this task: [TASK], discuss what is being asked, any ambiguities, and key requirements."

**Plan** — `gemma4:26b`
> "Given this discussion: [DISCUSS_OUTPUT], create a step-by-step plan to accomplish the task."

**Execute** — `qwen2.5-coder:32b` or task-specific model
> "Given this plan: [PLAN_OUTPUT], execute and produce the actual output/result."

**Verify** — `qwen3.5:27b`
> "Given task: [TASK] and result: [EXECUTE_OUTPUT], verify correctness, completeness, and quality. Score 1-10 and suggest improvements."

## Integration with Oracle

After any chain, always learn the result:

```bash
curl -s -X POST http://localhost:47778/api/learn \
  -H "Content-Type: application/json" \
  -d "{\"pattern\":\"chain-result-$(date +%s)\",\"content\":\"$RESULT\",\"concepts\":[\"ollama-chain\",\"multiagent\"],\"agent\":\"jit\"}"
```

## Example: Research & Summarize Webpage

```bash
# Full example — read Oracle README and extract key API endpoints
bash limbs/ollama-chain.sh web-read \
  "https://github.com/Soul-Brews-Studio/arra-oracle-v3" \
  "สรุป MCP tools และ API endpoints ที่สำคัญทั้งหมด"
```

Expected chain:
1. **Discuss** (qwen3.5:9b): "This is a GitHub README for Oracle V3 MCP server. Key questions: what tools exist? what endpoints?"
2. **Plan** (gemma4:26b): "1) List all MCP tools 2) Extract API table 3) Group by category"  
3. **Execute** (qwen2.5-coder:32b): Returns structured JSON/markdown with all tools and endpoints
4. **Verify** (qwen3.5:27b): "Completeness: 9/10. Found 22 MCP tools and 55 endpoints. ✓"

## Notes

- ทุก model ใช้ `OLLAMA_TOKEN` จาก `/workspaces/Jit/.env`
- Base URL: `https://ollama.mdes-innova.online`
- Timeout default: 60s per model call
- Output ของแต่ละ step ส่งต่อเป็น input ของ step ถัดไปเสมอ
- บันทึก chain log ไว้ที่ `/tmp/ollama-chain-<timestamp>.log`
