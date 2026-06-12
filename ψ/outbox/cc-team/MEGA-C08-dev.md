<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C08 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":195,"completion_tokens":3780,"total_tokens":3975} | 39s
 generated: 2026-06-12T19:33:53.681Z -->
#!/usr/bin/env node
// .claude/hooks/gateguard.js — GateGuard: PreToolUse(Edit) hook
// Forces an investigation step before the very first edit to any file in a session.
// Tracks seen files per session via os.tmpdir(). Set ECC_GATEGUARD=off to bypass.
// Configure in .claude/settings.json as a PreToolUse hook with matcher "Edit*".

const fs = require('fs').promises;
const path = require('path');
const os = require('os');

async function getSeen(sessionFile) {
  try {
    const raw = await fs.readFile(sessionFile, 'utf8');
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

async function addSeen(sessionFile, filePath) {
  const seen = await getSeen(sessionFile);
  seen.push(filePath);
  await fs.writeFile(sessionFile, JSON.stringify(seen), 'utf8');
}

async function run(context) {
  if (process.env.ECC_GATEGUARD === 'off') {
    return { continue: true };
  }

  const { toolName, toolInput, sessionId, cwd } = context;

  // Only act on tools that modify a file (Edit, Write, MultiEdit, …)
  if (!/^(Edit|Write|MultiEdit|Replace)/.test(toolName)) {
    return { continue: true };
  }

  const rawPath = toolInput?.path;
  if (!rawPath) {
    return { continue: true };
  }
  const fileAbs = path.resolve(cwd, rawPath);

  const sessionFile = path.join(os.tmpdir(), `gateguard-${sessionId}.json`);
  const seen = await getSeen(sessionFile);

  if (seen.includes(fileAbs)) {
    return { continue: true };
  }

  // First edit to this file in this session → block with fact‑forcing demand
  await addSeen(sessionFile, fileAbs);
  const msg = `GateGuard blocked your first edit to "${fileAbs}" in this session.\n` +
    `Please first investigate: importers, callers, or the schema of this file.\n` +
    `After investigation, retry the edit – it will be allowed.`;
  return { continue: false, exitCode: 2, message: msg };
}

module.exports = { run };
