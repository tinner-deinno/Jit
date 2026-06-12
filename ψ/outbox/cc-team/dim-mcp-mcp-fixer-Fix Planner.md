<!-- cc-team deliverable
 group: dim-mcp (MCP Server Logic Analysis)
 member: mcp-fixer role=Fix Planner model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":36,"completion_tokens":1486,"total_tokens":1522,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":605,"image_tokens":0},"cache_creation_input_tokens":0} | 20s
 generated: 2026-06-12T10:28:21.790Z -->
I understand you want exact code diffs to fix MCP server bugs in `C:\Users\USER-NT\DEV\innomcp\innomcp-server-node`. However, without specific error logs or bug descriptions, I have to infer from common issues in Node.js MCP servers. Typically, bugs are:

- Missing or mismatched dependencies (e.g., `@modelcontextprotocol/sdk`, `uuid`, `zod`).
- Incorrect transport setup (STDIO vs SSE).
- Server not exposing tools/resources properly.
- Configuration file errors (e.g., `mcp.json` not found or malformed).

Below is a **generic diff** that addresses the most frequent issue: the server crashing because of outdated or missing dependencies and a faulty `package.json`. If this does not match your actual bug, please provide the error message or describe the behaviour (e.g., “server fails to start”, “tools not visible in Claude Desktop”). Then I can give you a precise, verified diff.

---

### Assumed file: `package.json`  
**Bug:** Missing `uuid` dependency causes `Error: Cannot find module 'uuid'` when tools are called.

**Diff:**
```diff
--- a/package.json
+++ b/package.json
@@ -11,6 +11,7 @@
   "dependencies": {
     "@modelcontextprotocol/sdk": "0.5.0",
     "express": "^4.18.2",
+    "uuid": "^9.0.0",
     "zod": "^3.22.4"
   },
   "devDependencies": {
```

---

### Assumed file: `src/server.ts` (or `server.js`)  
**Bug:** The server uses `Server` from the wrong import path, causing `TypeError: Server is not a constructor`.

**Diff:**
```diff
--- a/src/server.ts
+++ b/src/server.ts
@@ -1,5 +1,5 @@
-import { Server } from 'mcp-server';
+import { Server } from '@modelcontextprotocol/sdk/server/index.js';
 import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
-import { CallToolRequestSchema, ListToolsRequestSchema } from 'mcp-server/types';
+import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
 
 // ... rest of your server code
```

---

### Assumed file: `src/index.ts` (entry point)  
**Bug:** The server is not started or exported incorrectly, leading to an exit with code 0 immediately.

**Diff:**
```diff
--- a/src/index.ts
+++ b/src/index.ts
@@ -1,8 +1,11 @@
 import { server } from './server.js';
-// Starting the server was missing
+import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
 
-server.listen(3000); // INCORRECT for MCP stdio
+async function main() {
+  const transport = new StdioServerTransport();
+  await server.connect(transport);
+  console.error('MCP server running via stdio');
+}
 
-console.log('Server started'); // Not how MCP servers work
+main().catch(console.error);
```

---

### If you are using SSE transport instead of STDIO (less common):  
**Bug:** Server failing to listen on correct host/port or CORS issues.

**Diff (SSE fix):**
```diff
--- a/src/sse-server.ts
+++ b/src/sse-server.ts
@@ -5,7 +5,7 @@ const app = express();
 
 const transport = new SSEServerTransport('/messages', app);
 app.get('/sse', async (req, res) => {
-  await transport.handleRequest(req, res);
+  await transport.start();
 });
 
 app.post('/messages', async (req, res) => {
```

---

**Please run your server with `node --inspect-brk` or check the exact error message.**  
Once you share it, I will adjust the diffs to fix **your specific** bug.
