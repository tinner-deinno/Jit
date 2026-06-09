# 🌳 Decision Tree: ล่าม COMMANDCODE — "Agent X เรียก LLM Call → เลือก Model ไหน"

> **คำสั่ง**: `ล่าม COMMANDCODE` — ตัวล่ามกลางที่ช่วย organ แต่ละตัวเลือก model ที่เหมาะสมที่สุด
> **เกณฑ์ตัดสิน**: (1) agent role, (2) prompt length, (3) urgency, (4) previous failures
> **ผลลัพธ์**: mermaid flowchart + table per agent

---

## 🧭 Mermaid Flowchart (ภาพรวม)

```mermaid
flowchart TD
    Start([🤖 Agent X เรียก LLM Call]) --> R{1️⃣ Agent Role<br/>คือใคร?}

    R -->|Tier 0: jit| JitPath
    R -->|Tier 1: soma| SomaPath
    R -->|Tier 2: innova/lak/neta| T2Path
    R -->|Tier 3 specialist| T3Path

    JitPath --> PL1{2️⃣ Prompt Length}
    SomaPath --> PL1
    T2Path --> PL1
    T3Path --> PL1

    PL1 -->|Short <200| Short
    PL1 -->|Medium 200-2000| Med
    PL1 -->|Long >2000| Long

    Short --> U1{3️⃣ Urgency}
    Med --> U1
    Long --> U1

    U1 -->|🔥 Critical| Crit
    U1 -->|⚡ Normal| Norm
    U1 -->|🌙 Low| Low

    Crit --> F1{4️⃣ Previous<br/>Failures >2?}
    Norm --> F1
    Low --> F1

    F1 -->|Yes ใช่| FailPath[🚨 Fallback Chain<br/>provider rotation]
    F1 -->|No ไม่| Choose[✅ เลือก Model]

    Choose --> M1[Claude Opus 4.8<br/>reasoning + critical]
    Choose --> M2[Claude Sonnet 4.6<br/>balanced default]
    Choose --> M3[Claude Haiku 4.5<br/>fast + cheap]
    Choose --> M4[Ollama gemma4:26b<br/>Thai language]
    Choose --> M5[Qwen3 Embed<br/>vector search]

    FailPath --> M1
    FailPath --> M2
    FailPath --> M3
    FailPath --> M4

    style Start fill:#4A148C,stroke:#fff,color:#fff
    style R fill:#1565C0,stroke:#fff,color:#fff
    style PL1 fill:#2E7D32,stroke:#fff,color:#fff
    style U1 fill:#EF6C00,stroke:#fff,color:#fff
    style F1 fill:#C62828,stroke:#fff,color:#fff
    style M1 fill:#6A1B9A,stroke:#fff,color:#fff
    style M2 fill:#283593,stroke:#fff,color:#fff
    style M3 fill:#00838F,stroke:#fff,color:#fff
    style M4 fill:#AD1457,stroke:#fff,color:#fff
    style M5 fill:#558B2F,stroke:#fff,color:#fff
```

---

## 📊 Mermaid Flowchart (แยกตาม Tier)

```mermaid
flowchart LR
    subgraph "🟣 Tier 0 — Master"
        jit[jit จิต<br/>Master Orchestrator]
    end

    subgraph "🔵 Tier 1 — Strategic"
        soma[soma สมอง<br/>Brain/Director]
    end

    subgraph "🟢 Tier 2 — Engineering"
        innova[innova จิตใจ<br/>Lead Dev]
        lak[lak กระดูก<br/>Architect]
        neta[neta เนตร<br/>Reviewer]
    end

    subgraph "🟡 Tier 3 — Specialists"
        vaja[vaja วาจา<br/>PA]
        chamu[chamu จมูก<br/>QA]
        mue[mue มือ<br/>Executor]
        netra[netra เนตร<br/>Observer]
        pada[pada บาท<br/>DevOps]
        pran[pran หัวใจ<br/>Heart]
        lung[lung ปอด<br/>Purifier]
        karn[karn หู<br/>Listener]
        rupa[rupa รูป<br/>Designer]
        sayan[sayanprasathan<br/>Nerve]
    end

    jit -->|Opus 4.8<br/>reasoning| J1[🎯 critical/strategic]
    jit -->|Sonnet 4.6<br/>default| J2[⚖️ normal synthesis]
    jit -->|Haiku 4.5<br/>quick| J3[⚡ quick route]

    soma -->|Opus 4.8| S1[🧠 deep analyze]
    soma -->|Sonnet 4.6| S2[📋 plan]

    innova -->|Sonnet 4.6| I1[💻 code]
    lak -->|Opus 4.8| L1[🏗️ architect]
    neta -->|Sonnet 4.6| N1[🔍 review]

    vaja -->|Haiku 4.5| V1[💬 chat/report]
    chamu -->|Sonnet 4.6| C1[🧪 test]
    mue -->|Haiku 4.5| MUE1[⚙️ execute]
    netra -->|Haiku 4.5| NT1[👁️ monitor]
    pada -->|Sonnet 4.6| P1[🚀 deploy]
    pran -->|Haiku 4.5| PR1[💓 heartbeat]
    lung -->|Haiku 4.5| LU1[🫁 filter]
    karn -->|Haiku 4.5| K1[👂 listen]
    rupa -->|Sonnet 4.6| R1[🎨 design]
    sayan -->|Haiku 4.5| SY1[⚡ signal]
```

---

## 📋 Decision Table — Per Agent (15 agents)

### 🟣 Tier 0: Master Orchestrator

| Agent | Role | Short <200 | Medium 200-2000 | Long >2000 | Critical | Normal | Low | Failures >2 |
|-------|------|-----------|-----------------|-----------|----------|--------|-----|-------------|
| **jit (จิต)** | Master Orchestrator | Sonnet 4.6 | **Opus 4.8** | **Opus 4.8** | **Opus 4.8** | Sonnet 4.6 | Haiku 4.5 | → Fallback chain |

> 💡 jit เป็น soul ของระบบ → ใช้ Opus 4.8 เป็นหลัก เพราะต้องตัดสินใจข้าม 15 organs

---

### 🔵 Tier 1: Strategic Lead

| Agent | Role | Short <200 | Medium 200-2000 | Long >2000 | Critical | Normal | Low | Failures >2 |
|-------|------|-----------|-----------------|-----------|----------|--------|-----|-------------|
| **soma (สมอง)** | Brain/Director | Sonnet 4.6 | **Opus 4.8** | **Opus 4.8** | **Opus 4.8** | Sonnet 4.6 | Haiku 4.5 | → Rotate Opus→Sonnet→Haiku |

> 💡 soma คิดเชิงกลยุทธ์ → Opus 4.8 สำหรับ architecture-level decisions

---

### 🟢 Tier 2: Core Engineering

| Agent | Role | Short <200 | Medium 200-2000 | Long >2000 | Critical | Normal | Low | Failures >2 |
|-------|------|-----------|-----------------|-----------|----------|--------|-----|-------------|
| **innova (จิตใจ)** | Lead Developer | Sonnet 4.6 | Sonnet 4.6 | **Opus 4.8** | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | → Ollama gemma4:26b (Thai) |
| **lak (กระดูก)** | Solution Architect | Sonnet 4.6 | **Opus 4.8** | **Opus 4.8** | **Opus 4.8** | Opus 4.8 | Sonnet 4.6 | → Sonnet 4.6 fallback |
| **neta (เนตร)** | Code Reviewer | Haiku 4.5 | Sonnet 4.6 | **Opus 4.8** | **Opus 4.8** | Sonnet 4.6 | Haiku 4.5 | → Re-review with Opus |

> 💡 innova เขียน code เป็นหลัก → Sonnet 4.6 เร็วและพอ / lak ออกแบบ → Opus 4.8 / neta รีวิว → Opus ตรวจ security

---

### 🟡 Tier 3: Specialists (12 agents)

| Agent | Organ | Short <200 | Medium 200-2000 | Long >2000 | Critical | Normal | Low | Failures >2 |
|-------|-------|-----------|-----------------|-----------|----------|--------|-----|-------------|
| **vaja (วาจา)** | ปาก / PA | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |
| **chamu (จมูก)** | จมูก / QA | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | **Opus 4.8** | Sonnet 4.6 | Haiku 4.5 | → Opus 4.8 retest |
| **mue (มือ)** | มือ / Executor | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |
| **netra (เนตร)** | ตา / Observer | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |
| **pada (บาท)** | ขา / DevOps | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | **Opus 4.8** | Sonnet 4.6 | Haiku 4.5 | → Ollama local |
| **pran (หัวใจ)** | หัวใจ / Heart | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |
| **lung (ปอด)** | ปอด / Purifier | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |
| **karn (หู)** | หู / Listener | Haiku 4.5 | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |
| **rupa (รูป)** | รูปลักษณ์ / Designer | Sonnet 4.6 | Sonnet 4.6 | **Opus 4.8** | **Opus 4.8** | Sonnet 4.6 | Haiku 4.5 | → Opus 4.8 |
| **sayanprasathan** | ระบบประสาท / Nerve | Haiku 4.5 | Haiku 4.5 | Sonnet 4.6 | Sonnet 4.6 | Haiku 4.5 | Haiku 4.5 | → Sonnet 4.6 |

> 💡 Tier 3 ส่วนใหญ่ใช้ **Haiku 4.5** เป็น default — เร็ว ถูก และ task ไม่ซับซ้อน / ยกเว้น **rupa** (visual) และ **chamu/pada** (critical path) ใช้ Opus

---

## 🔄 Model Pool & Fallback Chain

```mermaid
flowchart TD
    A[🤖 LLM Request] --> B[1️⃣ Try Primary<br/>per-agent table]
    B -->|✅ Success| OK[Done]
    B -->|❌ Fail| C[2️⃣ Track failure count]
    C -->|>2 failures| D[3️⃣ Rotate Provider]

    D --> D1[Anthropic Claude]
    D --> D2[Ollama gemma4:26b<br/>Thai language]
    D --> D3[Local Qwen3<br/>embeddings]
    D --> D4[Other gateway<br/>via limbs/llm.sh]

    D1 --> E[4️⃣ Try Sonnet 4.6]
    E -->|❌ Fail| F[5️⃣ Try Haiku 4.5]
    F -->|❌ Fail| G[🚨 Alert vaja + jit]

    style A fill:#4A148C,color:#fff
    style OK fill:#2E7D32,color:#fff
    style G fill:#C62828,color:#fff
```

### Fallback Order (เมื่อ failures > 2)

| Priority | Provider | Model | Use Case |
|----------|----------|-------|----------|
| 1 | Anthropic | **Opus 4.8** | reasoning, architecture, security |
| 2 | Anthropic | **Sonnet 4.6** | code, review, deploy |
| 3 | Anthropic | **Haiku 4.5** | chat, monitor, signal, execute |
| 4 | MDES Ollama | **gemma4:26b** | Thai language, Thai processing |
| 5 | Local | **Qwen3-Embed** | vector search, embeddings |
| 6 | Gateway | **limbs/llm.sh** | multi-provider rotation |

---

## 🎯 Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│  🧠 ล่าม COMMANDCODE — เลือก Model ใน 3 วินาที          │
├─────────────────────────────────────────────────────────┤
│  jit / soma / lak / neta (critical)  → Opus 4.8        │
│  innova / neta (normal code)         → Sonnet 4.6      │
│  vaja / mue / netra / pran / karn    → Haiku 4.5       │
│  lung / sayanprasathan               → Haiku 4.5       │
│  chamu / pada (critical path)        → Opus 4.8        │
│  rupa (design/visual)                → Opus 4.8        │
│  Thai language (ทุก agent)            → Ollama gemma4:26b│
│  Failures >2                         → Rotate provider │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Decision Pseudocode (สำหรับ implementation)

```python
def choose_model(agent: str, prompt: str, urgency: str, fail_count: int) -> str:
    # 1. Failover first
    if fail_count > 2:
        return rotate_provider(agent)  # Sonnet → Haiku → Ollama → local

    # 2. Critical → always Opus (or upgrade)
    if urgency == "critical":
        return "claude-opus-4-8"

    # 3. Length-based routing
    length = len(prompt)
    if length < 200:
        return SHORT_DEFAULT[agent]      # mostly Haiku
    elif length < 2000:
        return MEDIUM_DEFAULT[agent]     # mostly Sonnet
    else:
        return LONG_DEFAULT[agent]       # mostly Opus for complex

    # 4. Thai content → Ollama
    if is_thai(prompt):
        return "ollama/gemma4:26b"
```

---

## 📌 สรุปกฎเหล็ก 4 ข้อ

| # | กฎ | ตัวอย่าง |
|---|-----|---------|
| 1 | **Role สำคัญที่สุด** — Tier 0/1 ใช้ Opus, Tier 3 ใช้ Haiku เป็นหลัก | jit → Opus, mue → Haiku |
| 2 | **Prompt ยาว → model แรงขึ้น** | code review >2000 tokens → Opus |
| 3 | **Critical = ยกระดับทันที** | chamu/pada critical → Opus แม้ปกติใช้ Sonnet |
| 4 | **Failures >2 = rotate provider** | Anthropic ล้ม → Ollama → local |

🤖 Opus 4.8