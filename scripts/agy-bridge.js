#!/usr/bin/env node
/**
 * agy-bridge.js — zero‑dependency Node.js wrapper for Google Antigravity CLI (Windows)
 *
 * Usage:
 *   node agy-bridge.js --prompt "text" [--model id] [--timeout 10m0s] [--cwd dir]
 *                      [--skip-permissions] [--add-dir dir ...] [--continue-id id]
 *                      [--models] [--json] [--help]
 */
'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// ––– CLI parsing –––
const argv = process.argv.slice(2);
const opts = {
  prompt: null,
  model: null,
  timeout: '10m0s',
  cwd: process.cwd(),
  skipPermissions: false,
  addDirs: [],
  continueId: null,
  models: false,
  json: false,
};

let i = 0;
while (i < argv.length) {
  const arg = argv[i];
  switch (arg) {
    case '--prompt':
      opts.prompt = argv[++i];
      break;
    case '--model':
      opts.model = argv[++i];
      break;
    case '--timeout':
      opts.timeout = argv[++i];
      break;
    case '--cwd':
      opts.cwd = argv[++i];
      break;
    case '--skip-permissions':
      opts.skipPermissions = true;
      break;
    case '--add-dir':
      opts.addDirs.push(argv[++i]);
      break;
    case '--continue-id':
      opts.continueId = argv[++i];
      break;
    case '--models':
      opts.models = true;
      break;
    case '--json':
      opts.json = true;
      break;
    case '--help':
      console.log(`Usage: node agy-bridge.js [options]

Options:
  --prompt <text>          Required prompt (unless --models or --continue-id)
  --model <id>             Model identifier
  --timeout <duration>     Go-style duration (default 10m0s)
  --cwd <dir>              Working directory for agy (default current)
  --skip-permissions       Adds --dangerously-skip-permissions
  --add-dir <dir>          Additional directory for context (repeatable)
  --continue-id <id>       Conversation ID to resume
  --models                 Run 'agy models' subcommand
  --json                   Output JSON envelope
  --help                   Show this help`);
      process.exit(0);
    default:
      console.error(`Unknown option: ${arg}`);
      process.exit(1);
  }
  i++;
}

// Validation — print mode always needs a prompt; --continue-id only picks
// which conversation the new prompt lands in
if (!opts.models && !opts.prompt) {
  console.error('--prompt is required unless --models is given');
  process.exit(1);
}

// ––– Go duration parsing –––
function parseGoDuration(s) {
  let ms = 0;
  const re = /(\d+)(h|m|s|ms)/g;
  let m;
  while ((m = re.exec(s)) !== null) {
    const val = parseInt(m[1], 10);
    switch (m[2]) {
      case 'h': ms += val * 3600000; break;
      case 'm': ms += val * 60000; break;
      case 's': ms += val * 1000; break;
      case 'ms': ms += val; break;
    }
  }
  return ms || 10 * 60 * 1000; // fallback 10 min
}

const timeoutMs = parseGoDuration(opts.timeout);
const killAfterMs = timeoutMs + 30000; // +30s grace

// ––– Locate agy.exe –––
let agyBin = process.env.AGY_BIN;
if (!agyBin) {
  const localAppData = process.env.LOCALAPPDATA;
  if (localAppData) {
    const cand = path.join(localAppData, 'agy', 'bin', 'agy.exe');
    if (fs.existsSync(cand)) agyBin = cand;
  }
}
if (!agyBin) agyBin = 'agy';
if (path.isAbsolute(agyBin) && !fs.existsSync(agyBin)) {
  console.error(`agy binary not found at ${agyBin}`);
  process.exit(1);
}

// ––– Build arguments –––
const agyArgs = [];
if (opts.models) {
  agyArgs.push('models');
} else {
  agyArgs.push('-p', opts.prompt, '--print-timeout', opts.timeout);
  if (opts.model) agyArgs.push('--model', opts.model);
  if (opts.continueId) agyArgs.push('--conversation', opts.continueId);
  if (opts.skipPermissions) agyArgs.push('--dangerously-skip-permissions');
  opts.addDirs.forEach(d => agyArgs.push('--add-dir', d));
}

// ––– Spawn –––
const child = spawn(agyBin, agyArgs, {
  cwd: opts.cwd,
  windowsHide: true,
  stdio: ['ignore', 'pipe', 'pipe'],
});

let stdout = '';
let stderr = '';
child.stdout.setEncoding('utf8').on('data', d => (stdout += d));
child.stderr.setEncoding('utf8').on('data', d => (stderr += d));

let timedOut = false;
const startTime = Date.now();
const killTimer = setTimeout(() => {
  timedOut = true;
  child.kill('SIGTERM');
  setTimeout(() => {
    if (child.exitCode === null && child.signal === null) child.kill('SIGKILL');
  }, 5000);
}, killAfterMs);

child.on('error', err => {
  clearTimeout(killTimer);
  console.error('Failed to spawn agy:', err.message);
  process.exit(1);
});

// ––– Response recovery from conversation DB –––
// agy 1.0.7 print mode renders via its TUI layer, which goes silent when
// stdout is not a TTY — the reply only lands in the per-conversation SQLite
// store. Steps of type 15 carry it as protobuf field 20.1 (20.3 = thinking).
function readVarint(buf, o) {
  let r = 0n, s = 0n, i = o;
  for (;;) {
    const x = buf[i++];
    r |= BigInt(x & 0x7f) << s;
    if (!(x & 0x80)) break;
    s += 7n;
  }
  return [r, i];
}

function pbField(buf, wantField) {
  const out = [];
  let o = 0;
  while (o < buf.length) {
    let key;
    try { [key, o] = readVarint(buf, o); } catch { return out; }
    const field = Number(key >> 3n), wire = Number(key & 7n);
    if (wire === 0) { [, o] = readVarint(buf, o); }
    else if (wire === 2) {
      let len; [len, o] = readVarint(buf, o); len = Number(len);
      if (o + len > buf.length) return out;
      if (field === wantField) out.push(buf.subarray(o, o + len));
      o += len;
    }
    else if (wire === 5) o += 4;
    else if (wire === 1) o += 8;
    else return out;
  }
  return out;
}

function recoverFromDb(sinceMs) {
  try {
    const { DatabaseSync } = require('node:sqlite');
    const convDir = path.join(
      process.env.USERPROFILE || process.env.HOME || '', '.gemini', 'antigravity-cli', 'conversations');
    if (!fs.existsSync(convDir)) return null;
    const dbs = fs.readdirSync(convDir)
      .filter(f => f.endsWith('.db'))
      .map(f => ({ f, m: fs.statSync(path.join(convDir, f)).mtimeMs }))
      .filter(x => x.m >= sinceMs - 2000)
      .sort((a, b) => b.m - a.m);
    if (!dbs.length) return null;
    const conversationId = dbs[0].f.replace(/\.db$/, '');
    const db = new DatabaseSync(path.join(convDir, dbs[0].f), { readOnly: true });
    const rows = db.prepare('SELECT step_payload FROM steps WHERE step_type = 15 ORDER BY idx').all();
    const parts = [];
    for (const row of rows) {
      const buf = Buffer.from(String(row.step_payload).split(',').map(Number));
      for (const msg of pbField(buf, 20)) {
        for (const str of pbField(msg, 1)) {
          const t = str.toString('utf8').trim();
          if (t) parts.push(t);
        }
      }
    }
    db.close();
    return { conversationId, response: parts.join('\n\n') || null };
  } catch {
    return null;
  }
}

child.on('close', (code, signal) => {
  clearTimeout(killTimer);
  const durationMs = Date.now() - startTime;
  const exitCode = timedOut ? 124 : (code != null ? code : 1);

  let response = stdout.trim() || null;
  let conversationId = null;
  let source = response ? 'stdout' : null;
  if (!opts.models && !response) {
    const rec = recoverFromDb(startTime);
    if (rec) {
      response = rec.response;
      conversationId = rec.conversationId;
      source = rec.response ? 'db' : null;
    }
  }

  if (opts.json) {
    const envelope = JSON.stringify({
      ok: exitCode === 0,
      exitCode,
      model: opts.model || null,
      durationMs,
      response,
      conversationId,
      source,
      stdout,
      stderr: stderr.slice(0, 2000),
    });
    console.log(envelope);
  } else {
    if (response) process.stdout.write(response + '\n');
    else if (stdout) process.stdout.write(stdout);
    if (stderr) process.stderr.write(stderr);
  }
  process.exit(exitCode);
});
