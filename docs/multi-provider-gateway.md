# Multi-Provider LLM Gateway (ปัญญากลาง)

> สัมมาทิฏฐิ — เห็นทางที่ถูก เลือกเครื่องมือให้เหมาะกับงาน
> **One entrypoint. Any provider. Any model. Automatic failover. No collisions.**

ระบบ มนุษย์ Agent ให้ทุก agent เรียก LLM ผ่าน **ประตูเดียว** คือ `limbs/llm.sh`
แต่ละ agent จะรันบน provider/model อะไรก็ได้ — Claude, GPT (OpenAI), MDES Ollama,
Codex CLI — และถ้า provider หลักล่ม gateway จะไล่ **fallback chain** ให้อัตโนมัติ

---

## 1. ปัญหาเดิม (ทำไมต้องมีสิ่งนี้)

ก่อนหน้านี้ LLM execution ถูกแยกเป็น 2 เส้นทาง **ที่ไม่มีตัวเชื่อม**:

| เดิม | ผูกกับ | ปัญหา |
|------|--------|-------|
| `limbs/prompt_proxy.sh` | `claude` CLI + `COMMANDCODE_API_KEY` เท่านั้น | เรียก provider อื่นไม่ได้ |
| `limbs/ollama.sh` | MDES Ollama `gemma4:26b` เท่านั้น | แยก code path คนละโลก |

`network/registry.json` มี field `model` ต่อ agent แต่ **ไม่มีใครอ่านไปใช้จริง** และ
ไม่มี `provider`, ไม่มี fallback, ไม่มี lock → อาการที่เจอคือ launch ผ่าน Ollama
แล้วเรียก Claude / `maw` / loop ข้าม provider ไม่ได้ และ agent หลายตัวยิงพร้อมกันชนกัน

## 2. สถาปัตยกรรม

```
                          ┌─────────────────────────────┐
   agent / organ ───────► │        limbs/llm.sh         │  ◄── config/providers.json
   (vaja, soma, ...)      │        (the Gateway)        │      (routing + fallback + concurrency)
                          ├─────────────────────────────┤
                          │ 1. resolve  provider+model  │
                          │ 2. lock     per-agent flock │
                          │ 3. call     first available │
                          │ 4. fallback walk the chain  │
                          │ 5. log      ledger / journal│
                          └───────────┬─────────────────┘
                ┌─────────────────────┼─────────────────────┬─────────────────────┐
                ▼                     ▼                     ▼                     ▼
       providers/claude.sh   providers/ollama.sh   providers/openai.sh   providers/codex.sh
       (Anthropic / CC)      (MDES gemma)          (GPT / compatible)    (codex CLI)
```

**Adapter contract** (ทุกตัวใน `limbs/providers/` พูดภาษาเดียวกัน):

```bash
adapter available                       # exit 0 ถ้าใช้งานได้ตอนนี้ (มี key/CLI/endpoint)
adapter call <model_id> <system> <user> # พิมพ์คำตอบออก stdout; exit≠0 ถ้าล้มเหลว
```

Gateway เป็น "สมอง" ที่อ่าน config แล้วฉีดค่าที่ resolve แล้วให้ adapter ผ่าน env
(`PROVIDER_API_KEY`, `PROVIDER_BASE_URL`, `PROVIDER_CLI`, `PROVIDER_TIMEOUT`)
adapter เป็นแค่ "มือ" ที่ยิงจริง → เพิ่ม provider ใหม่ = เพิ่มไฟล์เดียว

## 3. ลำดับการ resolve (อ้างอิงสไตล์ LiteLLM)

เรียงความสำคัญจากบนลงล่าง:

1. `--provider P [--model M]` — ระบุตรงๆ
2. **model-string** `provider/model` เช่น `claude/sonnet`, `ollama/gemma4:26b`
   - bare id เดาจาก prefix: `claude-*→claude`, `gpt-*/o3*→openai`, `gemma*/llama*/qwen*→ollama`
3. `--agent NAME` → entry ใน `config/providers.json › agents`
4. `default_agent`

ถ้า provider ที่เลือก **ไม่พร้อม/ล้มเหลว** → ไล่ `fallback` chain ของ agent นั้น
(ปิดด้วย `--no-fallback`) แม้ระบุ provider ตรงๆ ก็ยังได้ resilience จาก `default_chain`

## 4. ใช้งาน (CLI)

```bash
# เรียกแบบ agent (ใช้ provider/model + fallback ตาม config + ใส่ role filter ให้)
bash limbs/llm.sh call "วิเคราะห์ repo นี้" --agent soma

# ระบุ provider/model ตรงๆ
bash limbs/llm.sh call "hello" --model ollama/gemma4:26b
bash limbs/llm.sh call "fix bug" --provider claude --model haiku
bash limbs/llm.sh call "explain" --model gpt-4o-mini      # เดา provider = openai

# ตรวจสอบ/ดีบั๊ก (ไม่ยิงจริง)
bash limbs/llm.sh route "งาน" --agent innova   # dry-run: ดูแผน + availability
bash limbs/llm.sh chain soma                    # ดู candidate chain ทั้งหมด
bash limbs/llm.sh agents                        # ตาราง routing ทุก agent
bash limbs/llm.sh providers                     # health ของทุก provider
bash limbs/llm.sh status                        # = providers
```

> **stdout = คำตอบ model ล้วนๆ** เสมอ — trace/log ออก stderr ทั้งหมด
> ทำให้ agent อื่น `RESULT=$(llm.sh call ... 2>/dev/null)` ได้ผลสะอาดเอาไปต่อได้ทันที

## 5. ตั้งค่าต่อ agent — `config/providers.json`

```jsonc
"agents": {
  "soma":  { "provider": "claude", "model": "opus",  "fallback": ["claude:sonnet", "ollama"] },
  "lung":  { "provider": "ollama", "model": "small", "fallback": ["claude:haiku"] },  // non-Claude primary
  "mue":   { "provider": "claude", "model": "haiku", "fallback": ["codex", "ollama"] }
}
```

- `model` = alias ใน provider block (`opus`/`sonnet`/`haiku`/`small`/`default`) หรือ id เต็มก็ได้
- `fallback` รับได้ทั้ง `"providerName"` (ใช้ default model) และ `"provider:model"`
- สลับ agent ทั้งตัวไปอีก provider = แก้บรรทัดเดียว ไม่ต้องแตะโค้ด

## 6. กัน multiagent ชนกัน (Concurrency)

ใช้ `flock` ผ่าน `jit_with_lock` ใน `limbs/lib.sh`:

- **per-agent lock** — agent เดียวกันยิง 2 call พร้อมกัน → serialize (ไม่ชน inbox/state)
- **คนละ agent → รันขนานได้เสรี** (นี่คือ "ทำงานร่วมกันโดยไม่ชนกัน")
- **global slot cap** (`concurrency.global_max`) — จำกัดจำนวน call รวมทั้งระบบกัน stampede

```bash
# ใช้ซ้ำได้ทั่วระบบ:
source limbs/lib.sh
jit_with_lock "innova" 30 -- bash organs/hand.sh build ...   # งานนี้ของ innova ห้ามซ้อน
```

## 7. เพิ่ม provider / ใส่ key

**เปิดใช้ GPT (OpenAI):**
```bash
echo 'OPENAI_API_KEY=sk-...' >> .env      # provider 'openai' จะขึ้น ● ready ทันที
bash limbs/llm.sh providers
```

**เปิดใช้ Codex CLI ("codecommand"):**
```bash
npm i -g @openai/codex                     # + OPENAI_API_KEY ใน .env
```

**เพิ่ม provider ใหม่ทั้งตัว** (เช่น Gemini / OpenRouter):
1. สร้าง `limbs/providers/<name>.sh` ตาม contract (ก็อป `openai.sh` มาแก้ base_url ได้เลย — OpenRouter/vLLM/LM Studio เข้ากันได้กับ OpenAI schema)
2. เพิ่ม block ใน `config/providers.json › providers`
3. อ้างใน `fallback`/`agents` ของ agent ที่ต้องการ

## 8. Backward compatibility

`limbs/prompt_proxy.sh` ยังใช้ได้เหมือนเดิมทุกคำสั่ง (`call`/`format`/`route`/`status`)
แต่ตอนนี้ delegate ไป `llm.sh` → ได้ fallback (Claude ล่ม → Ollama) ฟรี
โดยยังคง structured-prompt + Thai-summary เดิมไว้ครบ

## 9. ทดสอบ

```bash
python3 -m pytest tests/test_llm_gateway.py -q                 # 14 offline (deterministic)
JIT_LIVE_TESTS=1 python3 -m pytest tests/test_llm_gateway.py -q # +3 live (claude/ollama/fallback) = 17
```

ครอบคลุม: resolution, prefix inference, fallback ordering, availability flags,
**regression ของ TSV empty-field delimiter bug**, และ lock serialization/parallelism

## 10. อ้างอิงแพทเทิร์น (proven on GitHub)

| Pattern | ที่มา |
|---------|-------|
| Unified interface + `provider/model` strings + fallback list | **BerriAI/litellm** — `github.com/BerriAI/litellm` |
| Provider routing + automatic failover | **OpenRouter** — `openrouter.ai/docs` |
| Pluggable per-provider CLI adapters | **simonw/llm** — `github.com/simonw/llm` |
| Per-agent model override | **Claude Code subagents** — `docs.claude.com` (agent frontmatter `model:`) |
| Shell mutual exclusion via fd lock | **util-linux `flock(1)`** — POSIX advisory locks |

---

*Files:* `limbs/llm.sh` · `limbs/providers/{claude,ollama,openai,codex}.sh` ·
`config/providers.json` · `limbs/lib.sh` (`jit_with_lock`) · `tests/test_llm_gateway.py`
