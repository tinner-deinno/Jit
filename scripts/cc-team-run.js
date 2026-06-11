#!/usr/bin/env node
/**
 * cc-team-run.js — Autonomous CommandCode worker team orchestrator (TICKET-007b)
 *
 * Reads .planning/cc-team-plan.json, runs every pending member task against
 * the commandcode.ai API directly (zero Claude-provider tokens), writes each
 * deliverable to ψ/outbox/cc-team/, and updates task status in the plan file.
 * Retries failures, survives partial runs (re-run = resume), exits 0 when all done.
 *
 * Usage: node scripts/cc-team-run.js [--concurrency 2] [--max-tokens 6000]
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');

const REPO = path.resolve(__dirname, '..');
const PLAN_PATH = path.join(REPO, '.planning', 'cc-team-plan.json');
const OUT_DIR = path.join(REPO, 'ψ', 'outbox', 'cc-team');

// ── env ──────────────────────────────────────────────────────────────
function loadDotEnv() {
  const p = path.join(REPO, '.env');
  if (!fs.existsSync(p)) return;
  for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
loadDotEnv();

const CC_KEY = process.env.COMMANDCODE_API_KEY || '';
const CC_BASE = (process.env.COMMANDCODE_BASE_URL || 'https://api.commandcode.ai/provider/v1').replace(/\/$/, '');
if (!CC_KEY) { console.error('FATAL: COMMANDCODE_API_KEY not set'); process.exit(1); }

const args = process.argv.slice(2);
function argVal(name, dflt) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : dflt;
}
const CONCURRENCY = parseInt(argVal('--concurrency', '2'), 10);
const MAX_TOKENS = parseInt(argVal('--max-tokens', '6000'), 10);
const MAX_RETRIES = 2;

// ── commandcode call ─────────────────────────────────────────────────
function callCC(model, prompt) {
  const body = JSON.stringify({
    model,
    max_tokens: MAX_TOKENS,
    temperature: 0.2,
    messages: [{ role: 'user', content: prompt }],
  });
  const url = new URL(CC_BASE + '/chat/completions');
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + CC_KEY,
        // Cloudflare 403s default library UAs
        'User-Agent': 'cc-team-run/1.0',
        'Content-Length': Buffer.byteLength(body),
      },
      timeout: 300000,
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 300)}`));
        try {
          const j = JSON.parse(data);
          const msg = j.choices && j.choices[0] && j.choices[0].message;
          const text = (msg && msg.content) || '';
          const finish = j.choices && j.choices[0] && j.choices[0].finish_reason;
          if (!text.trim()) return reject(new Error(`empty content (finish_reason=${finish})`));
          resolve({ text, finish, usage: j.usage || {} });
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout 300s')); });
    req.write(body);
    req.end();
  });
}

// ── plan state ───────────────────────────────────────────────────────
function loadPlan() { return JSON.parse(fs.readFileSync(PLAN_PATH, 'utf8')); }
function savePlan(plan) { fs.writeFileSync(PLAN_PATH, JSON.stringify(plan, null, 2)); }

function allMembers(plan) {
  const out = [];
  for (const g of plan.groups) for (const m of g.members) out.push({ g, m });
  return out;
}

// ── worker ───────────────────────────────────────────────────────────
async function runMember(plan, g, m) {
  const label = `${g.id}/${m.id} [${m.role}:${m.model}]`;
  for (let attempt = 1; attempt <= MAX_RETRIES + 1; attempt++) {
    try {
      console.log(`[cc-team] → ${label} attempt ${attempt}`);
      const t0 = Date.now();
      const r = await callCC(m.model, m.task);
      const secs = Math.round((Date.now() - t0) / 1000);
      const file = path.join(OUT_DIR, `${g.id}-${m.id}-${m.role}.md`);
      const header = [
        `<!-- cc-team deliverable`,
        ` group: ${g.id} (${g.mission})`,
        ` member: ${m.id} role=${m.role} model=${m.model}`,
        ` finish_reason: ${r.finish} | tokens: ${JSON.stringify(r.usage)} | ${secs}s`,
        ` generated: ${new Date().toISOString()} -->`,
        '',
      ].join('\n');
      fs.writeFileSync(file, header + r.text + '\n');
      m.status = 'done';
      m.output = path.relative(REPO, file);
      m.finished_at = new Date().toISOString();
      savePlan(plan);
      console.log(`[cc-team] ✓ ${label} done in ${secs}s → ${m.output}`);
      return true;
    } catch (e) {
      console.log(`[cc-team] ✗ ${label} attempt ${attempt} failed: ${e.message}`);
      if (attempt > MAX_RETRIES) {
        m.status = 'failed';
        m.error = e.message;
        savePlan(plan);
        return false;
      }
      await new Promise((r) => setTimeout(r, 5000 * attempt));
    }
  }
}

// ── main ─────────────────────────────────────────────────────────────
(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const plan = loadPlan();
  const queue = allMembers(plan).filter(({ m }) => m.status !== 'done');
  console.log(`[cc-team] plan ${plan.plan_id}: ${queue.length} tasks pending (concurrency ${CONCURRENCY})`);

  let idx = 0, ok = 0, fail = 0;
  async function lane() {
    while (idx < queue.length) {
      const { g, m } = queue[idx++];
      (await runMember(plan, g, m)) ? ok++ : fail++;
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, queue.length) }, lane));

  const final = loadPlan();
  const total = allMembers(final).length;
  const done = allMembers(final).filter(({ m }) => m.status === 'done').length;
  console.log(`\n[cc-team] ═══ COMPLETE: ${done}/${total} done (this run: +${ok} ok, ${fail} failed) ═══`);
  console.log(`[cc-team] deliverables in: ${path.relative(REPO, OUT_DIR)}`);
  process.exit(done === total ? 0 : 1);
})();
