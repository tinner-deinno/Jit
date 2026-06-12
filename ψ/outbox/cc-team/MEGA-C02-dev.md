<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C02 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":184,"completion_tokens":3531,"total_tokens":3715} | 78s
 generated: 2026-06-12T19:30:59.058Z -->
#!/usr/bin/env node
/**
 * .claude/hooks/pre-compact.js
 * PreCompact hook: snapshots session state to ψ/inbox/handoff/auto-compact-<timestamp>.md
 * Timestamp source: hook stdin JSON (field "timestamp") or first CLI argument.
 * No Date.now fallback – fails if timestamp cannot be determined.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Synchronous read of all data from stdin (fd 0)
function readStdinSync() {
  const fd = process.stdin.fd;
  const buf = Buffer.alloc(4096);
  let result = '';
  let bytesRead;
  while ((bytesRead = fs.readSync(fd, buf, 0, buf.length, null)) !== 0) {
    result += buf.toString('utf8', 0, bytesRead);
  }
  return result;
}

function parseTimestamp() {
  // Try hook-provided JSON via stdin
  try {
    const raw = readStdinSync();
    if (raw && raw.trim()) {
      const data = JSON.parse(raw);
      if (data.timestamp && typeof data.timestamp === 'string') return data.timestamp;
    }
  } catch (_) { /* ignore */ }
  // Fallback to CLI argument
  if (process.argv[2]) return process.argv[2];
  throw new Error('No timestamp provided via stdin JSON or first argument');
}

// Make timestamp safe for filenames (Windows-safe)
function sanitizeFilename(ts) {
  return ts.replace(/[:\\/*?"<>|]/g, '-');
}

function runGitCommand(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', cwd: process.cwd() }).trim();
  } catch (e) {
    return `(error: ${e.message.split('\n')[0]})`;
  }
}

try {
  const timestamp = parseTimestamp();
  const safeName = sanitizeFilename(timestamp);
  const handoffDir = path.join(process.cwd(), 'ψ', 'inbox', 'handoff');
  fs.mkdirSync(handoffDir, { recursive: true });
  const filePath = path.join(handoffDir, `auto-compact-${safeName}.md`);

  const gitStatus = runGitCommand('git status --short');
  const gitLog = runGitCommand('git log --oneline -5');

  const content = `# Pre-compact Snapshot: ${timestamp}

## Git status (short)
\`\`\`
${gitStatus}
\`\`\`

## Last 5 commits
\`\`\`
${gitLog}
\`\`\`

## Model Notes
_Add analysis here_
`;

  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`Snapshot written to ${filePath}`);
  process.exit(0);
} catch (err) {
  console.error('pre-compact hook error:', err.message);
  process.exit(1);
}
