# InnoMCP Chat Components UX/UI Audit
**Aligning with `docs/4Opus/09_AI_CHAT_WORLD_CLASS_FRONTEND_HANDOFF.md`**

This document details the precise lines of code and changes required in the following Next.js components to simplify the composer, streamline system status feedback, keep starter prompts persistent, and collapse the multi-agent pipeline details by default.

---

## 1. `src/app/components/chat/ChatPage.tsx`

### Proposed Changes:
1. **Extract `STARTER_PROMPTS` and `StarterPromptsGrid`:**
   - Move the `STARTER_PROMPTS` array (currently lines 145–174) and `StarterPromptsGrid` component (currently lines 305–389) into a separate modular component file: [StarterPromptsGrid.tsx](file:///C:/Users/USER-NT/DEV/innomcp/innomcp-next/src/app/components/chat/StarterPromptsGrid.tsx).
   - Import `StarterPromptsGrid` at the top of `ChatPage.tsx`.

2. **Sync Settings with `ChatSidebar`:**
   - Currently, `ChatSidebar` receives settings props but they are not passed when instantiated in `ChatPage.tsx`. Pass the required states and handlers.

3. **Simplify Empty State Layout:**
   - Replace the inline map of starter prompts (lines 1993–2042) with the modular `<StarterPromptsGrid>` component.

4. **Keep Starter Prompts Persistent in Conversation State:**
   - Render the compact (`reduced`) version of `<StarterPromptsGrid>` in the sticky composer area when a conversation starts (first few turns).

### Exact Code Mappings:

#### Changes in Imports & Definitions (Lines 26 & 145–174, 305–389)
```diff
-import MultiAgentPanel from "@/app/components/chat/MultiAgentPanel";
+import MultiAgentPanel from "@/app/components/chat/MultiAgentPanel";
+import StarterPromptsGrid from "@/app/components/chat/StarterPromptsGrid";
```
*Remove the inline definitions of `STARTER_PROMPTS` and `StarterPromptsGrid` from `ChatPage.tsx` entirely.*

#### Passing Props to `ChatSidebar` (Lines 1812–1823)
```diff
         <ChatSidebar
           summaries={chatSummaries}
           activeId={activeSummaryId}
           isCollapsed={isSidebarCollapsed}
           onToggle={() => setIsSidebarCollapsed((v) => !v)}
           onLoad={loadSummary}
           onNewChat={handleNewChat}
           onRename={handleRename}
           onDelete={handleDeleteSummary}
           theme={theme}
           motherActive={chatMode === "multiagent"}
+          chatMode={chatMode}
+          onChatModeChange={setChatMode}
+          selectedToolType={selectedToolType}
+          onToolTypeChange={setSelectedToolType}
+          providerMode={providerMode}
+          onProviderModeChange={setProviderMode}
         />
```

#### Empty State Starter Prompts Replacement (Lines 1984–2044)
```diff
-                  {/* Starter prompts — premium card design with hover accent + arrow CTA */}
-                  <div className="mt-1">
-                    <div className="mb-2 flex items-center justify-between">
-                      <h2 className="text-[11px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
-                        ตัวอย่างคำถาม
-                      </h2>
-                      <span className="text-[11.5px] text-muted-foreground/85">คลิกเพื่อเริ่มต้น</span>
-                    </div>
-                    <div className="grid gap-2 sm:grid-cols-2">
-                      {STARTER_PROMPTS.map((prompt) => (
-                        <button
-                          ...
-                        </button>
-                      ))}
-                    </div>
-                  </div>
+                  {/* Modular Starter Prompts Grid (Empty Mode) */}
+                  <StarterPromptsGrid
+                    onSelect={setInput}
+                    textareaRef={textareaRef}
+                  />
```

#### Persistent Reduced Starter Prompts in Conversation Mode (Lines 2325–2326)
```diff
               <TypingIndicator typingUsers={typingUsers} />
+              {/* Keep starter prompts in compact mode after conversation starts */}
+              {messages.length > 0 && messages.length <= 4 && (
+                <StarterPromptsGrid
+                  onSelect={(query) => {
+                    setInput(query);
+                    textareaRef.current?.focus();
+                  }}
+                  textareaRef={textareaRef}
+                  reduced
+                />
+              )}
               <ChatInput
                 input={input}
```

---

## 2. `src/app/components/chat/ChatInput.tsx`

### Proposed Changes:
1. **Remove Mode and Tool Selectors:**
   - Remove unused props/parameters relating to `ChatModeSelector` and `ToolsTypeSelector` (lines 61–63, 66–67, 105–107, 110–111).
2. **Remove `ProviderMode` Toggle:**
   - Remove the `ProviderMode` toggle button and its local state (lines 115–129, 445–468) as it is being moved to the sidebar settings list.
3. **Consolidate Composer Primitives:**
   - Keep only three controls inside the composer body: text input textarea, attachment clip button, and send/stop button.
4. **Remove Duplicated Connection Status:**
   - Simplify the send button logic. Remove the offline/connecting state indicator (`DotsAnimation` and text "เชื่อมต่อ...") since it's already shown in `StatusRibbon` at the top of the page.
5. **Adjust Character Counter:**
   - Show the char counter only when the user is close to the soft-limit (e.g. `charCount >= 3200` out of 4000).

### Exact Code Mappings:

#### Prop Cleanup in `ChatInputProps` (Lines 61–67)
```diff
   theme: string;
   layoutMode?: "empty" | "conversation";
-  onToolTypeChange?: (type: ToolType) => void;
-  chatMode?: ChatMode;
-  onChatModeChange?: (mode: ChatMode) => void;
   onFocus?: () => void;
   onBlur?: () => void;
-  providerMode?: ProviderMode;
-  onProviderModeChange?: (mode: ProviderMode) => void;
   onAddArtifact?: (artifact: Artifact) => void;
```

#### Removing Local Provider States (Lines 115–130)
```diff
-  // Provider mode — read from localStorage on first render; sync back on toggle
-  const [providerMode, setProviderMode] = useState<ProviderMode>(() => providerModeProp ?? "remote");
-  useEffect(() => {
-    const stored = readProviderMode();
-    ...
-  }
```
*Remove `providerMode` state and `toggleProviderMode` function entirely.*

#### Simplifying Composer Buttons (Lines 442–485)
```diff
-          {/* Right-aligned: provider badge + voice + send */}
-          <div className="ml-auto flex flex-1 items-center justify-end gap-2 sm:flex-none">
-            {/* Provider mode badge — MDES Cloud vs Ollama Local */}
-            <button
-              type="button"
-              onClick={toggleProviderMode}
-              ...
-            </button>
-
-            {/* Phase 5 — Thai voice input button */}
-            {typeof window !== 'undefined' && ... && (
-              <button
-                ...
-              </button>
-            )}
```
*Remove the Provider mode toggle badge and voice input button from the inline composer bar to clean up secondary controls.*

#### Send Button Simplicity (Lines 487–530)
```diff
             <button
               onClick={isWaitingForResponse ? handleStop : handleSendWithCsv}
-              disabled={!isSocketReady || (!isWaitingForResponse && !input.trim() && !csvMeta)}
+              disabled={!isSocketReady || (!isWaitingForResponse && !input.trim() && !csvMeta)}
               className={`relative inline-flex h-9 items-center justify-center gap-1.5 overflow-hidden rounded-md px-3.5 ...`}
               data-testid="send-btn"
-              title={
-                isWaitingForResponse
-                  ? "หยุดการตอบ (Esc)"
-                  : isSocketReady
-                  ? "ส่งข้อความ (Enter)"
-                  : "กำลังเชื่อมต่อ AI"
-              }
+              title={isWaitingForResponse ? "หยุดการตอบ (Esc)" : "ส่งข้อความ (Enter)"}
             >
               {isWaitingForResponse && (
                 ...
               )}
               {isWaitingForResponse ? (
                 <>
                   <FontAwesomeIcon icon={faStop} className="relative" />
                   <span className="relative">หยุด</span>
                 </>
-              ) : isSocketReady ? (
+              ) : (
                 <>
                   <span>ส่ง</span>
                   <FontAwesomeIcon icon={faArrowUp} />
                 </>
-              ) : (
-                <span>
-                  เชื่อมต่อ
-                  <DotsAnimation />
-                </span>
               )}
             </button>
```

#### Adjust Character Counter Threshold (Lines 288)
```diff
-  const showCharCounter = charCount >= 600;
+  const showCharCounter = charCount >= 3200; // Only warn close to limit
```

---

## 3. `src/app/components/chat/ChatSidebar.tsx`

### Proposed Changes:
1. **Add Provider Mode Toggle to Settings:**
   - Add the Ollama Local vs MDES Cloud provider selector inside the sidebar settings section (so the controls remain accessible but moved out of the typing composer).
2. **Accept and Handle Provider Props:**
   - Accept `providerMode` and `onProviderModeChange` as props.

### Exact Code Mappings:

#### Props Extensions (Lines 72–73)
```diff
   chatMode?: ChatMode;
   onChatModeChange?: (mode: ChatMode) => void;
   selectedToolType?: ToolType;
   onToolTypeChange?: (type: ToolType) => void;
+  providerMode?: "remote" | "local";
+  onProviderModeChange?: (mode: "remote" | "local") => void;
 };
```

#### Adding Settings Toggle (Lines 1109–1114)
```diff
             <div className="flex items-center justify-between gap-2">
               <span className="text-[12px] text-muted-foreground">เครื่องมือ</span>
               <ToolsTypeSelector
                 onToolTypeChange={(t) => onToolTypeChange?.(t)}
                 theme={safeTheme}
               />
             </div>
+            <div className="flex items-center justify-between gap-2 pt-1 border-t border-border/20">
+              <span className="text-[12px] text-muted-foreground">ผู้ให้บริการ</span>
+              <button
+                type="button"
+                onClick={() => onProviderModeChange?.(providerMode === "remote" ? "local" : "remote")}
+                className={`h-7 items-center gap-1 rounded-full border px-2.5 text-[11px] font-medium transition-all ${
+                  providerMode === "local"
+                    ? "border-amber-500/45 bg-amber-500/10 text-amber-800 dark:text-amber-200"
+                    : "border-sky-500/40 bg-sky-500/8 text-sky-800 dark:text-sky-200"
+                }`}
+              >
+                {providerMode === "local" ? "Ollama Local" : "MDES Cloud"}
+              </button>
+            </div>
```

---

## 4. `src/app/components/chat/MultiAgentPanel.tsx` (and `multiAgentExperience.ts`)

### Proposed Changes:
1. **Verify Default Collapsed State:**
   - Confirm that the default state is initialized to collapsed. (The component already uses `defaultCollapsed = true` which initializes `open = false`, so no structural line changes are needed here).
2. **Translate Report Header to Human Language:**
   - Change the header summary label from "Thinking report" to a human-friendly title detailing the action. E.g. `AI กำลังวิเคราะห์ {agentCount} ส่วน` or `ผลการวิเคราะห์จากทีม AI`.

### Exact Code Mappings:

#### Humanizing Report Summary in `multiAgentExperience.ts` (Lines 20–65)
```diff
 export function resolveThinkingReportSummary(input: ThinkingReportSummaryInput): ThinkingReportSummary {
   const { streamStatus, agentCount, doneCount, recoveringCount, errorCount } = input;
 
   if (agentCount === 0) {
     return {
-      title: "Thinking report",
+      title: "กำลังเริ่มวิเคราะห์",
       statusText: streamStatus === "streaming" ? "กำลังเรียกทีม" : "พร้อมทำงาน",
       digest: "คำตอบหลักจะยังรวมเป็นข้อความเดียว ส่วนบันทึกทีมเปิดดูได้เมื่อจำเป็น",
       tone: streamStatus === "streaming" ? "working" : "ready",
     };
   }
 
   if (errorCount > 0) {
     return {
-      title: "Thinking report",
+      title: "สลับช่องทางวิเคราะห์",
       statusText: "สำรองช่องทาง",
       digest: "บางตัวแทนสลับช่องทางสำรอง คำตอบหลักยังรวมข้อมูลที่ตรวจสอบได้ครบ",
       tone: "recovering",
     };
   }
 
   if (recoveringCount > 0) {
     return {
-      title: "Thinking report",
+      title: "กำลังจัดสรรผู้ช่วยเสริม",
       statusText: `กำลังสำรอง ${recoveringCount}`,
       digest: "ทีมกำลังสลับทางเรียกโมเดลหรือเครื่องมือ โดยไม่แตกคำตอบหลักเป็นหลายช่อง",
       tone: "recovering",
     };
   }
 
   if (streamStatus === "streaming") {
     return {
-      title: "Thinking report",
+      title: `AI กำลังวิเคราะห์ ${agentCount} ส่วน`,
       statusText: `${doneCount}/${agentCount} เสร็จ`,
       digest: `ลูกทีม ${agentCount} ตัวกำลังตรวจข้อมูลและส่งต่อให้บริกรร้อยเป็นคำตอบเดียว`,
       tone: "working",
     };
   }
 
   return {
-    title: "Thinking report",
+    title: `วิเคราะห์ร่วมกัน ${agentCount} ส่วนเสร็จสิ้น`,
     statusText: "เสร็จแล้ว",
     digest: `เก็บบันทึกจากลูกทีม ${agentCount} ตัวไว้ใต้คำตอบเดียว`,
     tone: "complete",
   };
 }
```

---

## 5. New Component: `src/app/components/chat/StarterPromptsGrid.tsx`

This component is newly created to modularize the starter prompts grid, keeping imports clean and code highly maintainable.

```typescript
"use client";

import React from "react";

export const STARTER_PROMPTS = [
  {
    icon: "🧭",
    title: "วิเคราะห์ข้อมูลภัยพิบัติ",
    description: "สรุปข้อมูลประกาศเตือนภัยพิบัติ ล่าสุดจากกรมอุตุนิยมวิทยา",
    query: "วิเคราะห์ข้อมูลภัยพิบัติล่าสุดจากประกาศกรมอุตุนิยมวิทยาให้หน่อย",
    accent: "from-sky-500/16 via-sky-500/8 to-transparent",
  },
  {
    icon: "📊",
    title: "วิเคราะห์ตารางสถิติและข้อมูลทั่วไป",
    description: "ส่งไฟล์ตารางหรือ CSV และให้วิเคราะห์ความสอดคล้องหรือคำนวณเบื้องต้น",
    query: "วิเคราะห์ไฟล์ตารางสถิติที่แนบนี้เพื่อหาข้อมูลเชิงลึกเด่นๆ 3 จุดให้หน่อย [แนบไฟล์ก่อนรัน]",
    accent: "from-emerald-500/16 via-emerald-500/8 to-transparent",
  },
  {
    icon: "🎨",
    title: "สร้างและปรับแต่งรูปภาพด้วย AI",
    description: "ช่วยร่าง concept, style, หรือคำสั่งปรับปรุงรูปภาพสำหรับ DALL-E/Midjourney",
    query: "ขอไอเดียเขียน prompt วาดภาพแนวไซไฟย้อนยุคไทยสไตล์ หน่อย ขอเป็นแบบ cinematic สวยงาม",
    accent: "from-pink-500/16 via-pink-500/8 to-transparent",
  },
  {
    icon: "🗺️",
    title: "วางแผนจัดการเส้นทางพื้นที่",
    description: "ค้นหาพิกัดและคำนวณขอบเขตหรือเส้นทางขนส่งด้วย Thai Geo Tool",
    query: "ช่วยวางแผนจัดการพื้นที่เขตเกษตรในจังหวัดเชียงใหม่และค้นหาแหล่งน้ำที่ใกล้ที่สุดให้ที",
    accent: "from-amber-500/16 via-amber-500/8 to-transparent",
  },
] as const;

interface StarterPromptsGridProps {
  onSelect: (query: string) => void;
  textareaRef: React.RefObject<HTMLTextAreaElement | null>;
  reduced?: boolean;
}

const StarterPromptsGrid: React.FC<StarterPromptsGridProps> = ({
  onSelect,
  textareaRef,
  reduced = false,
}) => {
  const focusComposer = (query: string) => {
    onSelect(query);
    requestAnimationFrame(() => {
      const el = textareaRef.current;
      if (!el) return;
      el.focus();
      try {
        el.setSelectionRange(query.length, query.length);
      } catch {}
      if (!reduced) {
        el.scrollIntoView({ block: "nearest", behavior: "smooth" });
      }
    });
  };

  if (reduced) {
    return (
      <div className="mb-3 flex flex-wrap items-center gap-2 px-1">
        <span className="text-[11px] text-muted-foreground/60 shrink-0">ตัวอย่าง:</span>
        {STARTER_PROMPTS.slice(0, 3).map((prompt) => (
          <button
            key={prompt.query}
            onClick={() => focusComposer(prompt.query)}
            data-testid="starter-prompt"
            className="inline-flex items-center gap-1.5 rounded-full border border-border/60 bg-card px-2.5 py-1 text-[12px] font-medium text-foreground transition-all hover:border-primary/40 hover:bg-primary/5"
          >
            <span aria-hidden="true">{prompt.icon}</span>
            <span>{prompt.title}</span>
          </button>
        ))}
      </div>
    );
  }

  return (
    <div className="mt-1">
      <div className="mb-2 flex items-center justify-between">
        <h2 className="text-[11px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
          ตัวอย่างคำถาม
        </h2>
        <span className="text-[11.5px] text-muted-foreground/85">คลิกเพื่อเริ่มต้น</span>
      </div>
      <div className="grid gap-2 sm:grid-cols-2">
        {STARTER_PROMPTS.map((prompt) => (
          <button
            key={prompt.query}
            onClick={() => focusComposer(prompt.query)}
            data-testid="starter-prompt"
            className="group relative flex min-w-0 items-start gap-3 overflow-hidden rounded-lg border border-border/70 bg-card p-3.5 text-left transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md"
          >
            <span
              aria-hidden="true"
              className={`pointer-events-none absolute inset-x-0 top-0 h-12 bg-gradient-to-b ${prompt.accent} opacity-0 transition-opacity duration-300 group-hover:opacity-100`}
            />
            <span
              className="relative inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-muted/60 text-lg leading-none ring-1 ring-border/60 transition-colors group-hover:bg-primary/8 group-hover:ring-primary/30"
              aria-hidden="true"
            >
              {prompt.icon}
            </span>
            <span className="relative min-w-0 flex-1">
              <span className="flex items-center gap-1.5">
                <span className="block truncate text-[13.5px] font-semibold text-foreground transition-colors group-hover:text-primary">
                  {prompt.title}
                </span>
                <span
                  aria-hidden="true"
                  className="opacity-0 transition-opacity text-primary text-[12px] group-hover:opacity-100"
                >
                  →
                </span>
              </span>
              <span className="mt-0.5 line-clamp-2 block text-[12.5px] leading-5 text-muted-foreground">
                {prompt.description}
              </span>
            </span>
          </button>
        ))}
      </div>
    </div>
  );
};

export default StarterPromptsGrid;
```
