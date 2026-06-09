const InnovaBotBridge = require('../limbs/innova-bot-bridge');

async function run() {
    console.log('Connecting to innova-bot bridge...');
    const bridge = new InnovaBotBridge();
    
    try {
        await bridge.connect();
        console.log('Connected! Handing off task to Cross...');
        
        const taskDescription = `ปัญหา:
จากการทำ Swarm Agent Audit และสรุปผลใน C:/Users/USER-NT/Jit/scratch/clean_audit_findings.md พบจุดบกพร่องวิกฤต (Syntax errors, Runtime crashes, Command Injection, SSRF, Directory Traversal, Memory/FD leaks) รวม 10 ไฟล์ในระบบ Jit และ innova-bot ซึ่งทำให้ระบบทำงานผิดพลาดและไม่เสถียร

ไฟล์ที่เกี่ยวข้อง:
1. JS - Jit Core Engine:
   - C:/Users/USER-NT/Jit/limbs/mother-engine.js (Syntax error ใน regex/runGoal, missing methods, JSON parsing crash)
   - C:/Users/USER-NT/Jit/hermes-discord/model-router.js (splitThaiSyllables ReferenceError, BackendManager fake true, circuit breaker unused, missing exports)
   - C:/Users/USER-NT/Jit/limbs/innova-bot-bridge.js (Unbounded reconnect, EventSource race condition, memory/socket leak)
2. Python - Innova-bot Modules:
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/utils/model_router.py (Routing local ignore, URL parse bug)
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/tools/ask_tools.py (Command Injection, SSRF, Log leak, missing subprocess timeouts)
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/utils/event_watcher.py (JSONL rewrite race condition, Python <3.11 datetime.UTC crash, Directory traversal)
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/agents/bigboss_agent.py (Syntax error unclosed except, logger NameError)
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/utils/swarm_manager.py (Tmux command injection, claim bypass, task submission overwrite)
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/utils/supervisor_loop.py (ValueError in env parse, busy-wait CPU 100% spin, blocking I/O)
   - C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/innova_bot/gui/rpg_tui.py (Syntax error code truncated, tail_lines always empty, fd leak)

เงื่อนไขผ่านงาน (Definition of Done):
1. ทำการแก้ไขและไล่เก็บจุดบกพร่องตามที่วิเคราะห์ไว้ใน C:/Users/USER-NT/Jit/scratch/clean_audit_findings.md ทุกหัวข้อในทั้ง 10 ไฟล์ให้ครบถ้วน 100%
2. ปิดช่องโหว่ Command Injection, SSRF และ Directory Traversal ในระบบฝั่ง Python ด้วยการเพิ่ม Validation ที่รัดกุมและกำหนด Timeout
3. ปรับปรุง loop และ daemon timer ใน Python และการเรียกใช้งาน Ollama ในเทสเคสเพื่อไม่ให้การรัน pytest เกิดการ hang หรือค้างนานเกินไป

test ที่ต้องผ่าน:
- รันและผ่านการทดสอบ regression gate suite: node eval/check-all.js ใน Jit (ต้องผ่าน 100%)
- รัน pytest suite ใน devtools (C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot/) และต้องผ่านโดยไม่มีการ hang หรือ timeout`;

        const result = await bridge.callTool('handoff_to_persona', {
            target_persona: 'คร๊อส',
            task_description: taskDescription,
            meta: { project: 'jit-innova-bugfix' }
        });
        
        console.log('Handoff successful! Result:', JSON.stringify(result, null, 2));
    } catch (e) {
        console.error('Error in bridge communication:', e);
    } finally {
        await bridge.disconnect();
        process.exit(0);
    }
}

run();
