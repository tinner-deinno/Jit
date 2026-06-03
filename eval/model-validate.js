#!/usr/bin/env node
/**
 * eval/model-validate.js — validate code/diffs using the REAL model fleet as
 * reviewers (multi-brand validation), with GPT-5.5 (openai) as senior validator.
 *
 * Routes a review prompt through each backend via model-router (noRotate, so
 * each lane is tested in isolation) and prints per-model verdicts.
 *
 *   node eval/model-validate.js                 # validate current git diff
 *   node eval/model-validate.js --staged        # validate staged diff
 *   node eval/model-validate.js <file> [file..] # validate diff of specific files
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const envPath = path.join(ROOT, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
const router = require('../hermes-discord/model-router');

// Validator lanes (user directive: emphasize these brands; openai=GPT-5.5 senior).
const VALIDATORS = [
  { backend: 'ollama_mdes', label: 'MDES (gemma4)' },
  { backend: 'thaillm', label: 'ThaiLLM' },
  { backend: 'copilot', label: 'Copilot' },
  { backend: 'openai', label: 'GPT-5.5 ⭐SENIOR' },
];

function getDiff() {
  const args = process.argv.slice(2);
  const staged = args.includes('--staged');
  const files = args.filter(a => !a.startsWith('--'));
  let cmd = 'git diff' + (staged ? ' --cached' : '');
  if (files.length) cmd += ' -- ' + files.map(f => `"${f}"`).join(' ');
  try { return execSync(cmd, { cwd: ROOT, encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 }); }
  catch (e) { return ''; }
}

const SYSTEM = 'You are a strict senior code reviewer. Judge whether the diff is correct and safe. Be concise. End your reply with exactly one line: "VERDICT: PASS" or "VERDICT: FAIL".';

function review(v, diff) {
  const t0 = Date.now();
  const user = `Review this git diff. For each change, state whether it is correct and introduces no regression. Then give the final verdict line.\n\n\`\`\`diff\n${diff.slice(0, 12000)}\n\`\`\``;
  return router.callModelPromise(
    [{ role: 'system', content: SYSTEM }, { role: 'user', content: user }],
    { preferBackend: v.backend, noRotate: true }
  ).then(
    r => ({ ...v, ok: true, ms: Date.now() - t0, reply: String(r.reply || ''), verdict: (String(r.reply || '').match(/VERDICT:\s*(PASS|FAIL)/i) || [, '?'])[1].toUpperCase() }),
    e => ({ ...v, ok: false, ms: Date.now() - t0, error: String(e.message || e).slice(0, 90) })
  );
}

(async () => {
  const diff = getDiff();
  if (!diff.trim()) { console.log('[validate] no diff to review (clean tree / no match).'); process.exit(0); }
  console.log(`[validate] reviewing ${diff.split('\n').length} diff lines across ${VALIDATORS.length} model validators...\n`);

  const results = [];
  for (const v of VALIDATORS) {
    process.stdout.write(`→ ${v.label.padEnd(20)} `);
    const r = await review(v, diff);
    results.push(r);
    if (r.ok) console.log(`${r.verdict === 'PASS' ? '🟢' : r.verdict === 'FAIL' ? '🔴' : '⚪'} ${r.verdict}  (${r.ms}ms)`);
    else console.log(`⚠️  unavailable (${r.error})`);
  }

  console.log('\n=== VALIDATOR SUMMARY ===');
  const answered = results.filter(r => r.ok);
  const senior = results.find(r => r.backend === 'openai');
  for (const r of answered) {
    console.log(`\n● ${r.label} → ${r.verdict}`);
    const lastLines = r.reply.split('\n').filter(Boolean).slice(-4).join('\n  ');
    console.log('  ' + lastLines.slice(0, 500));
  }
  const passes = answered.filter(r => r.verdict === 'PASS').length;
  console.log(`\n[validate] ${answered.length}/${VALIDATORS.length} validators answered · ${passes} PASS`);
  if (senior && senior.ok) console.log(`[validate] SENIOR (GPT-5.5) verdict: ${senior.verdict}`);
  router.shutdownInnovaBot && router.shutdownInnovaBot();
  process.exit(0);
})();
