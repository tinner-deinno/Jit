const InnovaBotBridge = require('../limbs/innova-bot-bridge');

async function run() {
    console.log('Connecting to innova-bot bridge...');
    const bridge = new InnovaBotBridge();
    
    try {
        await bridge.connect();
        console.log('Connected! Handing off task to Cross...');
        
        const taskDescription = `ปัญหา:
ตัวเลือกและปุ่มตั้งค่าต่างๆ (ChatModeSelector, ToolsTypeSelector, ProviderMode) รกอยู่ที่ typing composer ใน ChatInput.tsx ทำให้ผู้ใช้สับสนและบังช่องพิมพ์, Starter prompts หายไปทันทีหลังจากเริ่มคุย, และคำว่า "Thinking report" ใน MultiAgentPanel ดูดิบและหุ่นยนต์เกินไป

ไฟล์ที่เกี่ยวข้อง:
- StarterPromptsGrid.tsx [NEW]: C:/Users/USER-NT/DEV/innomcp/innomcp-next/src/app/components/chat/StarterPromptsGrid.tsx
- ChatPage.tsx [MODIFY]: C:/Users/USER-NT/DEV/innomcp/innomcp-next/src/app/components/chat/ChatPage.tsx
- ChatInput.tsx [MODIFY]: C:/Users/USER-NT/DEV/innomcp/innomcp-next/src/app/components/chat/ChatInput.tsx
- ChatSidebar.tsx [MODIFY]: C:/Users/USER-NT/DEV/innomcp/innomcp-next/src/app/components/chat/ChatSidebar.tsx
- multiAgentExperience.ts [MODIFY]: C:/Users/USER-NT/DEV/innomcp/innomcp-next/src/app/components/chat/multiAgentExperience.ts

เงื่อนไขผ่านงาน (Definition of Done):
1. สร้างไฟล์ StarterPromptsGrid.tsx เป็นคอมโพเนนต์แยกตามแบบร่างใน C:/Users/USER-NT/Jit/scratch/chat_components_audit.md
2. แก้ไข ChatPage.tsx ให้นำเข้าและแสดงผล StarterPromptsGrid ทั้งในหน้าว่าง (Empty state) และในโหมดเริ่มต้นแชท 1-3 ข้อความแรก (Reduced mode) และส่งต่อ props ที่จำเป็นให้ ChatSidebar.tsx
3. แก้ไข ChatInput.tsx เพื่อดึงตัวเลือก mode/tool และปุ่ม toggle provider ออกจาก composer โดยตรง ปล่อยให้ปุ่มแชทมีแค่ input, attach, send/stop เท่านั้น ดึงสถานะการเชื่อมต่อออกจากปุ่มส่ง
4. แก้ไข ChatSidebar.tsx เพื่อเพิ่ม toggle เลือกผู้ให้บริการ (Ollama Local / MDES Cloud) ภายใต้ Settings section
5. ปรับปรุงข้อความใน multiAgentExperience.ts ให้แสดงผลเป็นภาษาไทยที่เป็นมิตรต่อผู้ใช้งาน เช่น "AI กำลังวิเคราะห์ 3 ส่วน" และ "วิเคราะห์ร่วมกัน 3 ส่วนเสร็จสิ้น"
6. บิวด์ผ่านโดยไม่มีข้อผิดพลาดทาง Typescript

test ที่ต้องผ่าน:
- ตรวจสอบไทป์เซฟตี้ผ่านคำสั่ง: pnpm --filter innomcp-next exec tsc --noEmit
- รันและผ่าน e2e visual validation ทั้งหมด: node C:/Users/USER-NT/Jit/automation_scripts/verify_all_views.js`;

        const result = await bridge.callTool('handoff_to_persona', {
            target_persona: 'คร๊อส',
            task_description: taskDescription,
            meta: { project: 'innomcp-next-refactor' }
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
