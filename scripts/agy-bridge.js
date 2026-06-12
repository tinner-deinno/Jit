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

child.on('close', (code, signal) => {
  clearTimeout(killTimer);
  const durationMs = Date.now() - startTime;
  const exitCode = timedOut ? 124 : (code != null ? code : 1);

  if (opts.json) {
    const envelope = JSON.stringify({
      ok: exitCode === 0,
      exitCode,
      model: opts.model || null,
      durationMs,
      stdout,
      stderr: stderr.slice(0, 2000),
    });
    console.log(envelope);
  } else {
    if (stdout) process.stdout.write(stdout);
    if (stderr) process.stderr.write(stderr);
  }
  process.exit(exitCode);
});
