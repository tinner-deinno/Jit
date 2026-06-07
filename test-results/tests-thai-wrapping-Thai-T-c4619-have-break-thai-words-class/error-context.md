# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: tests\thai-wrapping.spec.js >> Thai Text Wrapping Validation >> ChatMessage and ArtifactPanel should have break-thai-words class
- Location: tests\thai-wrapping.spec.js:4:3

# Error details

```
Error: expect(received).toBeGreaterThan(expected)

Expected: > 0
Received:   0
```

# Page snapshot

```yaml
- generic [ref=e1]:
  - banner [ref=e2]:
    - generic [ref=e3]: 🚀 Innova Bot — Realtime Control Center
    - generic "Agent avatars" [ref=e4]:
      - generic "BigBoss" [ref=e5]: BB
      - generic "System Analyst" [ref=e6]: SA
      - generic "Developer" [ref=e7]: DV
      - generic "Quality Evaluator" [ref=e8]: QE
    - generic [ref=e9]:
      - button "Expand Ribbon" [pressed] [ref=e10] [cursor=pointer]
      - button "TH" [ref=e11] [cursor=pointer]
      - generic "New events" [ref=e12]: 0 new
      - button "Light theme" [ref=e13] [cursor=pointer]
      - generic [ref=e14]: connected
  - generic [ref=e17]:
    - generic [ref=e18]: "Status: connected"
    - generic [ref=e19]: "Theme: dark"
    - generic [ref=e20]:
      - 'generic "Error Count: 0" [ref=e21]': 🟢 AWAKENED
      - 'generic "Applied TAM: Constructive/Curiosity" [ref=e22]': "[ECS: Constructive/Curiosity]"
      - generic "Waiting for pulse..." [ref=e23]
  - region "Top ribbon navigation panel" [ref=e24]:
    - button "Toggle navigation" [ref=e25] [cursor=pointer]:
      - generic [ref=e26]: ◀
      - generic [ref=e27]: Hide
    - generic [ref=e28]:
      - generic [ref=e29]: Navigation
      - generic [ref=e30]: General / Chat
    - button "Toggle control panel" [ref=e31] [cursor=pointer]:
      - generic [ref=e32]: ▶
      - generic [ref=e33]: Hide
  - main [ref=e34]:
    - complementary [ref=e35]:
      - generic [ref=e36]:
        - heading "🧭 Navigation" [level=2] [ref=e37]
        - generic [ref=e38]: คลิกไม่กี่ครั้งเพื่อเข้าถึงหมวดงานหลัก ใช้ได้ทั้งทีม dev/test/design และผู้ใช้ทั่วไป
        - navigation "Center workspace navigation" [ref=e39]:
          - generic [ref=e40]:
            - button "General ▾" [expanded] [ref=e41] [cursor=pointer]:
              - generic [ref=e42]: General
              - generic [ref=e43]: ▾
            - generic [ref=e44]:
              - button "💬 Live Workspace แชตกับ AI และดูสถานะล่าสุดแบบเรียลไทม์" [ref=e45] [cursor=pointer]
              - button "🗨️ Chat โหมดแชตโดยตรงสำหรับสั่งงาน AI และดู timeline การคุย" [active] [ref=e46] [cursor=pointer]
          - generic [ref=e47]:
            - button "Workspace & Dev ▾" [ref=e48] [cursor=pointer]:
              - generic [ref=e49]: Workspace & Dev
              - generic [ref=e50]: ▾
            - generic:
              - 'button "💻 Dev IDE Split-pane IDE: file explorer + live code view + action terminal"'
          - generic [ref=e51]:
            - button "Monitoring & Logs ▾" [ref=e52] [cursor=pointer]:
              - generic [ref=e53]: Monitoring & Logs
              - generic [ref=e54]: ▾
            - generic:
              - 'button "📊 Dashboard Beszel-style dashboard: system vitals, agent state, cognitive stream"'
              - button "🤖 AI Swarm & Tokens ดูรายชื่อ agents, ทักษะ/งานที่ทำล่าสุด, กราฟ และ token ที่ใช้ไป"
              - button "📡 Activity ดูเหตุการณ์ทั้งหมดจาก MCP, Copilot และโปรเจกต์อื่น"
              - button "🧾 Raw Stream ตรวจ raw event/JSON stream และ diagnostics แบบละเอียด"
              - button "📈 Telemetry Live CPU/Memory และ AI Mind State ของเซิร์ฟเวอร์แบบเรียลไทม์"
              - button "🌐 Agent Network ดูการสื่อสารระหว่าง agents และ workflow topology"
              - button "🎯 Project Progress ติดตามความคืบหน้าแยกตาม project และงานที่กำลังรัน"
          - generic [ref=e55]:
            - button "StarMap Suite ▾" [ref=e56] [cursor=pointer]:
              - generic [ref=e57]: StarMap Suite
              - generic [ref=e58]: ▾
            - generic:
              - button "🌌 Agent Map 3D Star Map — visualize agent orbits, Ralph Loop beams, and Citta state in real-time"
              - button "🧠 Knowledge Universe เปิด Knowledge Universe ใน StarMap shell เดียวกัน"
              - button "🛠 MCP Manager เปิด MCP Manager ภายใน StarMap shell"
              - button "📚 Reference Repos เปิด Reference Repositories ภายใน StarMap shell"
          - generic [ref=e59]:
            - button "Knowledge ▾" [ref=e60] [cursor=pointer]:
              - generic [ref=e61]: Knowledge
              - generic [ref=e62]: ▾
            - generic:
              - button "🧠 MCP Knowledge ศูนย์รวม MCP Knowledge, Solution Memory และ Security Audit"
              - button "📊 Insights ภาพรวมโปรเจกต์ ทีม และสุขภาพการทำงาน"
    - generic [ref=e63]:
      - tablist "Center workspace tabs" [ref=e64]:
        - tab "💬 Live Workspace" [ref=e65] [cursor=pointer]
        - tab "🗨️ Chat" [selected] [ref=e66] [cursor=pointer]
      - generic [ref=e67]:
        - generic [ref=e68]:
          - heading "💬 Chat Interface" [level=2] [ref=e69]
          - generic [ref=e70]:
            - button "Direct AI Chat" [ref=e71] [cursor=pointer]
            - button "AI Swarm Timeline" [ref=e72] [cursor=pointer]
        - generic [ref=e73]:
          - generic [ref=e74]: พิมพ์คำสั่งภาษาคนธรรมดาได้เลย ระบบจะช่วยสรุปและแนะนำขั้นตอนถัดไป
          - generic [ref=e75]:
            - button "Daily Brief" [ref=e76] [cursor=pointer]
            - button "Risk Check" [ref=e77] [cursor=pointer]
            - button "Action Plan" [ref=e78] [cursor=pointer]
            - generic [ref=e79]: Ready
          - generic [ref=e81]:
            - generic [ref=e82]:
              - generic [ref=e83]: Input Control Panel
              - generic [ref=e84]: "mode: realtime command"
            - generic [ref=e85]:
              - generic [ref=e86]: Message
              - textbox "Message" [ref=e87]:
                - /placeholder: Type a prompt…
            - generic [ref=e88]:
              - button "Send" [ref=e89] [cursor=pointer]
              - button "Clear" [ref=e90] [cursor=pointer]
              - button "Attach Context" [ref=e91] [cursor=pointer]
              - button "Simulate Command" [ref=e92] [cursor=pointer]
          - generic [ref=e93]: If ask_local_ai isn’t configured, you’ll see an error response.
    - complementary [ref=e94]:
      - generic [ref=e95]:
        - heading "🎛️ Control Hub" [level=2] [ref=e96]
        - generic [ref=e97]: รวม control/options/settings สำหรับผู้ใช้ทุกระดับ พร้อมคำแนะนำแบบอ่านง่าย
        - tablist "Control categories" [ref=e98]:
          - button "Connection จัดการการเชื่อมต่อและสถานะระบบ" [ref=e99] [cursor=pointer]
          - button "Tools เรียกใช้เครื่องมือ MCP และตั้งค่า arguments" [ref=e100] [cursor=pointer]
          - button "Ops หน่วยความจำ, workflow และ approval queue" [ref=e101] [cursor=pointer]
        - generic [ref=e102]:
          - generic [ref=e103]: Quick Categories
          - generic [ref=e104]:
            - button "Connection" [ref=e105] [cursor=pointer]
            - button "Tool Runner" [ref=e106] [cursor=pointer]
            - button "Memory / Workflow / HITL" [ref=e107] [cursor=pointer]
        - generic [ref=e108]:
          - generic [ref=e109]: Primary Actions
          - generic [ref=e110]:
            - button "Run Tool" [ref=e111] [cursor=pointer]
            - button "Clear Tool Draft" [ref=e112] [cursor=pointer]
            - button "Open Stream" [ref=e113] [cursor=pointer]
        - generic [ref=e114]: "Tools mode: เลือก tool + args แล้วกด Submit เพื่อเรียกทันที"
      - generic [ref=e115]:
        - heading "🛠️ Tool Runner" [level=2] [ref=e116]
        - generic [ref=e117]:
          - generic [ref=e118]: Tool
          - combobox "Tool" [ref=e119]:
            - option "ask_local_ai" [selected]
            - option "run_command"
            - option "run_command_shell"
            - option "run_background_task"
            - option "workspace_list"
            - option "workspace_read"
            - option "workspace_write"
            - option "workspace_delete"
            - option "workspace_apply_patch"
            - option "publish_event"
            - option "fetch_pending_events"
            - option "transmit_telepathy"
            - option "handoff_to_persona"
            - option "update_project_state"
            - option "delegate_to_bigboss"
            - option "what_should_i_do_next"
            - option "delegate_to_cli_runner"
            - option "check_cli_delegation_status"
            - option "maw_doctor"
            - option "maw_agent_status"
            - option "maw_contact_agents"
            - option "hermes_cheam_jit"
            - option "jit_check_replies"
            - option "jit_bridge_status"
            - option "jit_runtime_snapshot"
            - option "query_inno_mcp"
            - option "list_repo_files"
            - option "read_repo_text_file"
            - option "job_start"
            - option "job_status"
            - option "job_output"
        - generic [ref=e120]:
          - generic [ref=e121]: Arguments (JSON)
          - code [ref=e123]:
            - generic [ref=e124]:
              - generic [ref=e134]: "{"
              - textbox "Editor content;Press Alt+F1 for Accessibility Options." [ref=e139]
        - generic:
          - button "Call Tool" [ref=e141] [cursor=pointer]
          - button "Pretty JSON" [ref=e142] [cursor=pointer]
  - generic [ref=e144]:
    - alert
    - alert
```

# Test source

```ts
  1  | const { test, expect } = require('@playwright/test');
  2  | 
  3  | test.describe('Thai Text Wrapping Validation', () => {
  4  |   test('ChatMessage and ArtifactPanel should have break-thai-words class', async ({ page }) => {
  5  |     await page.goto('http://127.0.0.1:7010/gui');
  6  | 
  7  |     // 1. Validate ChatMessage (if available)
  8  |     const chatMessages = page.locator('.card--chat .break-thai-words');
  9  |     // Since we might not have a message yet, we check the definition or a sample
  10 |     // For this test, we'll check if the class exists in the DOM when content is present.
  11 | 
  12 |     // 2. Validate ArtifactPanel
  13 |     // Trigger artifact panel (assuming we can navigate to a view that has it)
  14 |     await page.click('[data-center-view="chat"]');
  15 | 
  16 |     // We check for the existence of the class in the ArtifactPanel's content areas
  17 |     const artifactContent = page.locator('.card--artifact .break-thai-words');
  18 |     // Note: I'll use a more general selector since the card id might be different
  19 | 
  20 |     // Actually, let's just check if any element on the page that should wrap Thai text has the class
  21 |     const elementsWithThaiClass = page.locator('.break-thai-words');
  22 |     const count = await elementsWithThaiClass.count();
  23 | 
  24 |     console.log(`Found ${count} elements with break-thai-words class.`);
> 25 |     expect(count).toBeGreaterThan(0);
     |                   ^ Error: expect(received).toBeGreaterThan(expected)
  26 |   });
  27 | 
  28 |   test('Thai text should not overflow container', async ({ page }) => {
  29 |     await page.goto('http://127.0.0.1:7010/gui');
  30 | 
  31 |     // This is a more complex test requiring actual Thai content
  32 |     // In a real scenario, we would inject a long Thai string into the UI
  33 |     // and check if the element's scrollWidth is <= its clientWidth.
  34 | 
  35 |     await page.evaluate(() => {
  36 |       const div = document.createElement('div');
  37 |       div.id = 'thai-test-wrap';
  38 |       div.className = 'break-thai-words w-[100px] bg-red-500';
  39 |       div.innerText = 'นี่คือข้อความทดสอบการตัดคำภาษาไทยที่ยาวมากๆ เพื่อตรวจสอบว่าระบบสามารถตัดคำได้อย่างถูกต้องโดยไม่ล้นออกจากกรอบที่กำหนดไว้';
  40 |       document.body.appendChild(div);
  41 |     });
  42 | 
  43 |     const element = page.locator('#thai-test-wrap');
  44 |     const rect = await element.boundingBox();
  45 |     const scrollWidth = await element.evaluate(el => el.scrollWidth);
  46 | 
  47 |     expect(scrollWidth).toBeLessThanOrEqual(rect.width);
  48 |   });
  49 | });
  50 | 
```