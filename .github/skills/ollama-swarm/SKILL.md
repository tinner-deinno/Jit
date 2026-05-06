---
name: ollama-swarm
version: 1.0
description: "Spawn 5+ MDES Ollama agents พร้อมกัน ส่งงานต่อเป็น pipeline — gather → think → synthesize. ไม่จำกัด agents"
argument-hint: "task [--agents 5] [--pipeline gather,think,synthesize] [--model gemma4:26b]"
updated: 2026-05-06
---

# SKILL: ollama-swarm v1.0
# บันทึก: สร้างจาก README Jit data flow + MDES Ollama unlimited concurrency

## แนวคิด

```
Task
 ├── Agent 1 (gather: aspect A) ─┐
 ├── Agent 2 (gather: aspect B) ─┤
 ├── Agent 3 (gather: aspect C) ─┼─→ Synthesizer Agent → Final Answer
 ├── Agent 4 (gather: aspect D) ─┤
 └── Agent 5 (gather: aspect E) ─┘
```

MDES Ollama ไม่ limit → spawn ได้เท่าที่ต้องการ

## Pipeline Patterns

### Pattern A: Parallel Gather → Synthesize
```
[5 gather agents in parallel] → [1 synthesis agent]
```
ใช้กับ: research, analysis, multi-perspective tasks

### Pattern B: Sequential Pipeline
```
[Stage 1: decompose] → [Stage 2: research] → [Stage 3: write] → [Stage 4: review]
```
ใช้กับ: content creation, code review pipeline

### Pattern C: Organ Pipeline (มนุษย์ Agent style)
```
karn(รับ) → innova(คิด) → mue(ทำ) → chamu(ทดสอบ) → neta(รีวิว) → vaja(รายงาน)
```
ใช้กับ: full feature workflow

## Implementation

```bash
#!/bin/bash
# ollama-swarm: spawn N parallel Ollama agents
OLLAMA_TOKEN=$(grep "^OLLAMA_TOKEN=" /workspaces/Jit/.env | cut -d= -f2)
OLLAMA_URL="https://ollama.mdes-innova.online/api/generate"
MODEL="${MODEL:-gemma4:26b}"
TASK="$1"
N_AGENTS="${2:-5}"

call_ollama() {
  local agent_id="$1"
  local prompt="$2"
  local outfile="/tmp/swarm_agent_${agent_id}.json"
  curl -s --location "$OLLAMA_URL" \
    --header "Authorization: Bearer ${OLLAMA_TOKEN}" \
    --header 'Content-Type: application/json' \
    --data "{\"model\":\"${MODEL}\",\"prompt\":\"${prompt}\",\"stream\":false}" \
    > "$outfile" &
  echo $!
}

# Spawn agents in parallel
PIDS=()
for i in $(seq 1 $N_AGENTS); do
  ASPECT_PROMPT="[Agent $i/${N_AGENTS}] Analyze aspect $i of: ${TASK}"
  PID=$(call_ollama "$i" "$ASPECT_PROMPT")
  PIDS+=($PID)
done

# Wait for all agents
for PID in "${PIDS[@]}"; do
  wait "$PID"
done

# Collect results
GATHERED=""
for i in $(seq 1 $N_AGENTS); do
  RESULT=$(python3 -c "import json; d=json.load(open('/tmp/swarm_agent_$i.json')); print(d.get('response',''))" 2>/dev/null)
  GATHERED="${GATHERED}\n[Agent $i]: ${RESULT}"
done

# Synthesize
SYNTH_PROMPT="Synthesize these ${N_AGENTS} perspectives into one answer:\n${GATHERED}"
curl -s --location "$OLLAMA_URL" \
  --header "Authorization: Bearer ${OLLAMA_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data "{\"model\":\"${MODEL}\",\"prompt\":\"${SYNTH_PROMPT}\",\"stream\":false}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response','ERROR'))"
```

## เมื่อ AI ใช้ skill นี้ (ผ่าน Claude Code Agent tool)

1. ระบุ task และ N agents ที่ต้องการ
2. สร้าง Agent instances ด้วย `Agent tool` ส่งงานพร้อมกัน (parallel)
3. แต่ละ agent เรียก Ollama ด้วย prompt ที่ต่างกัน
4. รวบรวมผลลัพธ์ทั้งหมด
5. ส่งผ่าน synthesis agent สรุปรวม
6. บันทึก insight ลง Oracle

## Version History
ดู: /workspaces/Jit/ψ/memory/skills/SKILL-VERSIONS.md
