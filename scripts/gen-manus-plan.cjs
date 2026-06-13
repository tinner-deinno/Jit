'use strict';
// Manus-parity CC wave — additive, non-colliding building blocks ONLY.
// Does NOT touch conductor.ts/intentClassifier.ts (another session owns those).
// All outputs are NEW files the serial integrator (me) wires + runs.
const fs = require('fs');
const path = require('path');
const PRO = 'commandcode/deepseek/deepseek-v4-pro';
const FLASH = 'commandcode/deepseek/deepseek-v4-flash';

const CTX = 'innomcp: Next.js 14 app-router (innomcp-next, :3000) + Express/Node22 backend (innomcp-node, REST :3015->container:3011, WS). TypeScript strict. Goal: manus.im parity — autonomous agent that plans, runs tools, streams steps into a right-side workspace panel, emits artifacts. Existing (DO NOT EDIT, another session owns): src/services/{conductor,intentClassifier,parallelDispatch,motherDispatch,toolDispatch,orchestrator,providerManager}.ts. Your outputs are NEW standalone files with clean interfaces the integrator wires in later.';
const tasks = [];
const mk = (id, model, out, task) => tasks.push({ id, role: 'dev', model, status: 'pending', output: 'ψ\\outbox\\cc-team\\MANUS-' + out, task });

// ---- Group T: tool adapters (pure, uniform interface, unit-testable) ----
const toolIface = 'Uniform Tool interface: export interface Tool { name: string; description: string; inputSchema: object; run(input: any, ctx: { signal?: AbortSignal }): Promise<{ ok: boolean; output?: any; error?: string; artifacts?: {name:string,mime:string,content:string}[] }>; } Export a default instance. Pure (no global state), typed, no external deps beyond fetch. Include a top JSDoc + 2 usage examples in comments.';
mk('T1', PRO, 'T1-tool-weather.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/tools/weatherTool.ts — a Tool that fetches Thai weather. ' + toolIface + ' Use Open-Meteo (no key) for lat/lon and a Thai-province name->latlon lookup table for ~10 major provinces; return temp/humidity/condition; artifact = a small JSON summary. Handle abort + errors.');
mk('T2', PRO, 'T2-tool-websearch.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/tools/webSearchTool.ts — a Tool wrapping a generic search API via fetch (configurable SEARCH_API_URL env, graceful fallback returning a clear "not configured" error). ' + toolIface + ' Return top-N {title,url,snippet}; artifact = markdown list.');
mk('T3', FLASH, 'T3-tool-filewrite.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/tools/fileArtifactTool.ts — a Tool that writes a text/markdown/csv artifact to the workspace dir (WORKSPACE_ROOT env, default ./workspace) safely (no path traversal, sanitize filename). ' + toolIface + ' Returns the written path + artifact metadata.');
mk('T4', FLASH, 'T4-tool-codeexec.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/tools/codeExecTool.ts — a Tool that runs a short Node.js snippet in a child process with a hard timeout (default 10s), captured stdout/stderr, no network by default. ' + toolIface + ' SECURITY: refuse if snippet contains obvious fs-delete/network patterns unless ctx.allowUnsafe. artifact = stdout.');
mk('T5', PRO, 'T5-tool-registry.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/tools/registry.ts — a ToolRegistry: register(tool), get(name), list(), and toOpenAIToolSpecs() returning the array shape an LLM function-calling API expects (name/description/parameters from inputSchema). Import the Tool type from a shared ./types (define/export the Tool interface here too). Typed, no deps.');

// ---- Group L: agentic loop (NEW standalone module, clean interface) ----
mk('L1', PRO, 'L1-agentloop.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/services/agentLoop.ts — a STANDALONE plan-act-observe loop (NOT importing conductor). export async function* runAgentLoop(opts: { task: string; tools: ToolRegistry; llm: (messages, toolSpecs) => Promise<{content?:string, toolCalls?:{name,input}[]}>; maxSteps?: number; signal?: AbortSignal }): AsyncGenerator<AgentEvent>. AgentEvent union: {type:"plan"|"tool_call"|"tool_result"|"message"|"artifact"|"done"|"error", ...}. Each iteration: call llm with conversation + tool specs; if toolCalls, run them via registry, yield tool_call then tool_result events, feed results back; if content, yield message; stop on done or maxSteps (default 8). Pure/streaming via async generator. Define AgentEvent + import ToolRegistry type. Heavy JSDoc.');
mk('L2', PRO, 'L2-sse-route.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/routes/api/agentStream.ts — an Express Router exposing POST /api/agent/stream that takes {task, projectId?} and streams Server-Sent Events. Each AgentEvent from runAgentLoop becomes an SSE "data:" line (JSON). Set headers text/event-stream, no-cache, keep-alive; flush per event; handle client disconnect (abort the loop via AbortController); end with a done event. Import runAgentLoop + a registry factory (assume ../services/agentLoop and ../tools/registry). Export the router. Typed, comment where to mount in app.ts.');
mk('L3', FLASH, 'L3-event-types.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-next/src/app/lib/agentEvents.ts — the SHARED client-side TypeScript types + a parser for the SSE AgentEvent stream emitted by /api/agent/stream. export type AgentEvent (union matching plan/tool_call/tool_result/message/artifact/done/error), and export function parseSSELine(line:string): AgentEvent | null. Pure, no React, no deps.');

// ---- Group W: workspace panel streaming client (NEW hook + presentational) ----
mk('W1', PRO, 'W1-useAgentStream.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-next/src/app/hooks/useAgentStream.ts — a React hook (use client) that POSTs to `${BACKEND}/api/agent/stream` (import BACKEND from ../lib/backendUrl), reads the SSE stream via fetch + ReadableStream reader, parses lines with parseSSELine (../lib/agentEvents), and returns { events: AgentEvent[], running: boolean, start(task:string):void, stop():void, artifacts }. Clean up on unmount (abort). Strict TS, no extra deps.');
mk('W2', FLASH, 'W2-AgentStepList.tsx', 'Output ONLY raw TSX (no fences). ' + CTX + ' Write innomcp-next/src/app/components/chat/AgentStepList.tsx — a presentational React component (use client) that renders an AgentEvent[] as a vertical timeline for the workspace panel: plan=📋, tool_call=🔧 (name+args collapsed), tool_result=✅/❌, message=💬, artifact=📎 (download link), done=🏁. Tailwind, dark-mode aware, Thai labels, auto-scroll to latest. Props {events: AgentEvent[], running:boolean}. Import AgentEvent type from ../../lib/agentEvents.');
mk('W3', FLASH, 'W3-ArtifactCard.tsx', 'Output ONLY raw TSX (no fences). ' + CTX + ' Write innomcp-next/src/app/components/chat/ArtifactCard.tsx — renders one artifact {name,mime,content} with an icon by mime, a preview (text/markdown/csv inline, others a placeholder), and a download button (Blob download). Tailwind dark-mode, Thai. Props {artifact}.');

// ---- Group A: artifact service (backend) ----
mk('A1', FLASH, 'A1-artifactService.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/services/artifactService.ts — save/list/get artifacts under WORKSPACE_ROOT/artifacts (default ./workspace/artifacts), keyed by taskId. Functions: saveArtifact(taskId, {name,mime,content}), listArtifacts(taskId), getArtifact(taskId,name). Sanitize names (no traversal), typed, fs/promises only. Export types.');
mk('A2', FLASH, 'A2-artifact-route.ts', 'Output ONLY raw TypeScript (no fences). ' + CTX + ' Write innomcp-node/src/routes/api/artifacts.ts — Express Router: GET /api/tasks/:taskId/artifacts (list), GET /api/tasks/:taskId/artifacts/:name (download with correct Content-Type + Content-Disposition). Use artifactService. Export router, comment mount point.');

// ---- Group C: contract tests (RUN against live :3015 — verifiable) ----
const ctest = 'Output ONLY raw TypeScript (no fences). Write a node:test + node:assert/strict integration test that hits the LIVE backend at process.env.API_BASE || "http://localhost:3015". Use global fetch. Skip-with-clear-message (not fail) if the server is unreachable. ';
mk('C1', FLASH, 'C1-contract-health.test.ts', ctest + 'innomcp-node/tests/contract/health.contract.test.ts: GET /api/health returns 200 or 503 with JSON {status, services:[...]}; assert shape, each service has name+status.');
mk('C2', FLASH, 'C2-contract-auth.test.ts', ctest + 'innomcp-node/tests/contract/auth.contract.test.ts: POST /api/auth/login with bad creds returns 4xx + JSON error; GET /api/auth/me without cookie returns 401. Assert no 500s.');
mk('C3', FLASH, 'C3-contract-models.test.ts', ctest + 'innomcp-node/tests/contract/models.contract.test.ts: GET /api/mdes/models returns JSON (array or {models:[...]}); assert it parses and is non-empty OR returns a clear 404/501 if unimplemented (document which).');
mk('C4', FLASH, 'C4-contract-tasks.test.ts', ctest + 'innomcp-node/tests/contract/tasks.contract.test.ts: GET /api/tasks returns 200 JSON {tasks:[...]} or 401 for guest; assert shape when 200.');

// ---- Group D: docs/specs (additive) ----
mk('D1', FLASH, 'D1-agentloop-design.md', 'Output ONLY raw markdown. Write docs/architecture/agent-loop.md (Thai+English terms): how the new agentLoop.ts + agentStream SSE + useAgentStream + AgentStepList compose to deliver manus-style streaming; sequence diagram (ascii); how the integrator wires agentStream router into app.ts and AgentStepList into the workspace panel; how it coexists with the existing conductor (loop can call conductor as its llm step later). Under 90 lines.');
mk('D2', FLASH, 'D2-tool-authoring.md', 'Output ONLY raw markdown. Write docs/architecture/tool-authoring.md (Thai): how to author a new Tool implementing the uniform interface, register it, and have the agent loop discover it; the security rules (codeExec timeout, file traversal guards). Under 70 lines.');

const plan = {
  plan_id: 'CC-TEAM-2026-06-13-MANUS-PARITY',
  planned_by: 'jit (Fable 5)', sa_reviewer: 'jit', provider: 'commandcode-proxy-4322',
  created_at: new Date().toISOString(),
  context: 'Manus-parity building blocks — additive NEW files only, non-colliding with the conductor/intentClassifier work owned by another session. Integrator (Fable) wires + runs. Routed through proxy :4322 (deepseek only — qwen/minimax 400 there).',
  groups: [{ id: 'MANUS', mission: 'manus-parity scaffolds: tools, agent loop, SSE, workspace stream, artifacts, contract tests, docs', members: tasks }],
};
fs.writeFileSync(path.join(__dirname, '..', '.planning', 'cc-team-plan-manus.json'), JSON.stringify(plan, null, 2));
console.log('MANUS plan:', tasks.length, 'tasks ->', '.planning/cc-team-plan-manus.json');
