<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C06 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":180,"completion_tokens":2296,"total_tokens":2476} | 27s
 generated: 2026-06-12T19:29:15.718Z -->
```javascript
#!/usr/bin/env node
// Claude Code PreToolUse/PostToolUse hook (settings.json command hook)
// Reads context JSON from stdin, appends a JSONL line to ψ/memory/learnings/tool-observe.jsonl.
// Rotates file if >5MB. Never throws; exits 0 immediately after async operations finish.

const fs = require('fs');
const path = require('path');
const os = require('os');

const LOG_DIR = path.join(process.cwd(), 'ψ', 'memory', 'learnings');
const LOG_FILE = path.join(LOG_DIR, 'tool-observe.jsonl');
const MAX_SIZE = 5 * 1024 * 1024; // 5 MB

async function main() {
  try {
    // Read JSON context from stdin
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    const context = JSON.parse(Buffer.concat(chunks).toString());

    // Extract tool name and target
    const toolName = context.tool?.name || 'unknown';
    const input = context.input || {};
    const target = input.path || input.file || input.query || input.subject || JSON.stringify(input).slice(0, 100);

    // Build JSONL record
    const record = JSON.stringify({
      timestamp: new Date().toISOString(),
      tool: toolName,
      target: target
    }) + '\n';

    // Ensure directory exists
    await fs.promises.mkdir(LOG_DIR, { recursive: true });

    // Rotate if needed
    try {
      const stat = await fs.promises.stat(LOG_FILE);
      if (stat.size > MAX_SIZE) {
        const bakFile = LOG_FILE + '.bak';
        // Use os.tmpdir() for atomic rename? Not needed; just rename in place.
        await fs.promises.rename(LOG_FILE, bakFile).catch(() => {});
      }
    } catch (_) { /* file doesn't exist or stat failed - fine */ }

    // Append record
    await fs.promises.appendFile(LOG_FILE, record, 'utf8');
  } catch (_) {
    // Silently ignore any error – never throw
  }
  process.exit(0);
}

main();
```
