#!/usr/bin/env node
'use strict';

/**
 * eval/fleet-batch.js - bounded multi-provider worker batch for Mother.
 *
 * Exercises 50+ real model-lane workers without promoting GPT-5.5 to the main
 * worker lane. Outputs artifacts and appends one Mother event for continuity.
 */
const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

const ROOT = path.join(__dirname, '..');
const envPath = path.join(ROOT, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const router = require('../hermes-discord/model-router');
const eventLog = require('../limbs/event-log');
const leaderboardDB = require('../limbs/leaderboard-db');

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

function has(name) {
  return process.argv.includes(name);
}

function posInt(value, fallback, min, max) {
  const n = Math.floor(Number(value));
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

function splitCsv(value) {
  return String(value || '').split(',').map(s => s.trim()).filter(Boolean);
}

const COUNT = posInt(arg('--count', process.env.FLEET_BATCH_COUNT || 56), 56, 1, 200);
const CONCURRENCY = posInt(arg('--concurrency', process.env.FLEET_BATCH_CONCURRENCY || 6), 6, 1, 12);
function goalFromArgs() {
  const goalFile = arg('--goal-file', '');
  if (goalFile) {
    const resolved = path.resolve(ROOT, goalFile);
    return fs.readFileSync(resolved, 'utf8').trim();
  }
  return arg('--goal', 'Harden Jit Mother and innomcp tonight: find concrete risks, propose the next safe fix, and keep evidence concise.');
}
const GOAL = goalFromArgs();
const INCLUDE_OPENAI = has('--include-openai');
const DISCORD = !has('--no-discord');
const DISCORD_INTERVAL_MS = posInt(arg('--discord-interval-ms', process.env.FLEET_DISCORD_INTERVAL_MS || 600000), 600000, 60000, 3600000);
const MAX_ATTEMPTS = posInt(arg('--attempts', process.env.FLEET_BATCH_ATTEMPTS || 2), 2, 1, 4);
const RUN_ID = 'fleet-batch-' + new Date().toISOString().replace(/[:.]/g, '-');
const ARTIFACT_DIR = path.join(ROOT, 'network', 'artifacts', RUN_ID);
const BACKEND_LIMITS = {
  ollama_mdes: 1,
  thaillm: 4,
  ollama_cloud: 4,
  copilot: 2,
  openai: 1,
};

const AGENTS = [
  'jit', 'innova', 'soma', 'lak', 'neta', 'chamu', 'vaja', 'mue',
  'pada', 'netra', 'karn', 'pran', 'sayanprasathan', 'agent-mdes',
  'agent-thaillm', 'agent-copilot',
];

function laneDefinitions() {
  const status = router.status();
  const thaiModels = status.backends.thaillm?.models || [
    'openthaigpt-thaillm-8b-instruct-v7.2',
    'pathumma-thaillm-qwen3-8b-think-3.0.0',
    'typhoon-s-thaillm-8b-instruct',
    'thalle-0.2-thaillm-8b-fa',
  ];
  const cloudModels = splitCsv(process.env.OLLAMA_CLOUD_MODELS || 'gemma4:31b-cloud,nemotron-3-super:cloud');
  const lanes = [
    { backend: 'ollama_mdes', models: [status.backends.ollama_mdes?.model || 'gemma4:26b'], weight: 18 },
    { backend: 'thaillm', models: thaiModels, weight: 16 },
    { backend: 'ollama_cloud', models: cloudModels, weight: 16 },
    { backend: 'copilot', models: ['claude-sonnet-4.6', null], weight: 10 },
  ];
  if (INCLUDE_OPENAI) lanes.push({ backend: 'openai', models: [status.backends.openai?.model || null], weight: 2 });
  return lanes;
}

function buildJobs() {
  const lanes = laneDefinitions();
  const weighted = [];
  const maxWeight = Math.max(...lanes.map(l => l.weight));
  for (let round = 0; round < maxWeight; round++) {
    for (const lane of lanes) {
      if (round < lane.weight) weighted.push(lane);
    }
  }
  const jobs = [];
  const modelCursor = {};
  for (let i = 0; i < COUNT; i++) {
    const lane = weighted[i % weighted.length];
    const cursorKey = lane.backend;
    const cursor = modelCursor[cursorKey] || 0;
    const model = lane.models[cursor % lane.models.length] || null;
    modelCursor[cursorKey] = cursor + 1;
    const agent = AGENTS[i % AGENTS.length];
    jobs.push({ id: i + 1, backend: lane.backend, model, agent });
  }
  return jobs;
}

function jobPrompt(job) {
  return [
    'You are a bounded Jit Mother worker.',
    'Return concise evidence-first output in Thai or mixed Thai/English.',
    'No file edits. No commands. One paragraph plus 2 bullets maximum.',
    '',
    'Task:',
    GOAL,
    '',
    'Worker lens: ' + job.agent,
    'Provider lane: ' + job.backend + (job.model ? ' / ' + job.model : ' / default'),
    'Find one actionable risk or next fix for Mother/Jit/innomcp, and include a confidence 0-100.',
  ].join('\n');
}

function classifyReply(reply) {
  const text = String(reply || '').trim();
  if (!text) return { ok: false, score: 0 };
  const m = text.match(/\bconfidence\s*[:=]?\s*(\d{1,3})\b/i) || text.match(/\b(\d{1,3})\s*%/);
  const score = Math.max(1, Math.min(100, m ? Number(m[1]) : 70));
  return { ok: true, score };
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runOne(job) {
  const started = Date.now();
  const attempts = [];
  let lastError = '';
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const attemptStarted = Date.now();
    try {
      const result = await router.callModelPromise(
        [{ role: 'user', content: jobPrompt(job) }],
        { preferBackend: job.backend, model: job.model, noRotate: true }
      );
      const verdict = classifyReply(result.reply);
      const attemptLatency = Date.now() - attemptStarted;
      attempts.push({ attempt, ok: verdict.ok, latencyMs: attemptLatency, backend: result.backend });
      leaderboardDB.recordProviderResult(job.backend, verdict.ok, attemptLatency);
      if (verdict.ok || attempt === MAX_ATTEMPTS) {
        return {
          ...job,
          ok: verdict.ok,
          score: verdict.score,
          usedBackend: result.backend,
          latencyMs: Date.now() - started,
          attempts,
          reply: String(result.reply || '').trim(),
          error: verdict.ok ? undefined : 'empty reply',
        };
      }
      lastError = 'empty reply';
    } catch (error) {
      const attemptLatency = Date.now() - attemptStarted;
      lastError = String(error && error.message || error).slice(0, 300);
      attempts.push({ attempt, ok: false, latencyMs: attemptLatency, error: lastError });
      leaderboardDB.recordProviderResult(job.backend, false, attemptLatency);
    }
    if (attempt < MAX_ATTEMPTS) await sleep(500 * attempt);
  }
  return {
    ...job,
    ok: false,
    score: 0,
    latencyMs: Date.now() - started,
    attempts,
    error: lastError || 'failed',
  };
}

async function runPool(jobs) {
  const results = new Array(jobs.length);
  let next = 0;
  const activeByBackend = {};
  const waitersByBackend = {};

  function acquireBackend(backend) {
    const limit = BACKEND_LIMITS[backend] || CONCURRENCY;
    if ((activeByBackend[backend] || 0) < limit) {
      activeByBackend[backend] = (activeByBackend[backend] || 0) + 1;
      return Promise.resolve(() => releaseBackend(backend));
    }
    return new Promise(resolve => {
      (waitersByBackend[backend] || (waitersByBackend[backend] = [])).push(resolve);
    }).then(() => {
      activeByBackend[backend] = (activeByBackend[backend] || 0) + 1;
      return () => releaseBackend(backend);
    });
  }

  function releaseBackend(backend) {
    activeByBackend[backend] = Math.max(0, (activeByBackend[backend] || 0) - 1);
    const queue = waitersByBackend[backend] || [];
    const nextWaiter = queue.shift();
    if (nextWaiter) nextWaiter();
  }

  async function worker() {
    while (next < jobs.length) {
      const idx = next++;
      const job = jobs[idx];
      process.stdout.write(`[fleet] ${job.id}/${jobs.length} ${job.backend}${job.model ? '/' + job.model : ''} ${job.agent} ... `);
      const release = await acquireBackend(job.backend);
      let result;
      try {
        result = await runOne(job);
      } finally {
        release();
      }
      results[idx] = result;
      console.log(result.ok ? `OK ${result.latencyMs}ms` : `FAIL ${result.latencyMs}ms ${result.error || ''}`);
    }
  }
  const pool = [];
  for (let i = 0; i < Math.min(CONCURRENCY, jobs.length); i++) pool.push(worker());
  await Promise.all(pool);
  return results;
}

function summarize(results, startedAt, totalCount) {
  const completed = results.filter(r => r && !r.pending);
  const expectedCount = totalCount || completed.length;
  const byBackend = {};
  for (const r of completed) {
    const row = byBackend[r.backend] || (byBackend[r.backend] = { total: 0, ok: 0, fail: 0, latency: 0, models: {} });
    row.total++;
    if (r.ok) row.ok++; else row.fail++;
    row.latency += r.latencyMs || 0;
    const model = r.model || 'default';
    row.models[model] = (row.models[model] || 0) + 1;
  }
  for (const row of Object.values(byBackend)) {
    row.avgLatencyMs = row.total ? Math.round(row.latency / row.total) : 0;
    delete row.latency;
  }
  return {
    runId: RUN_ID,
    goal: GOAL,
    count: expectedCount,
    completed: completed.length,
    pending: Math.max(0, expectedCount - completed.length),
    ok: completed.filter(r => r.ok).length,
    fail: completed.filter(r => !r.ok).length,
    concurrency: CONCURRENCY,
    durationMs: Date.now() - startedAt,
    byBackend,
  };
}

function writeArtifacts(results, summary) {
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
  const jsonPath = path.join(ARTIFACT_DIR, 'summary.json');
  const mdPath = path.join(ARTIFACT_DIR, 'summary.md');
  fs.writeFileSync(jsonPath, JSON.stringify({ summary, results }, null, 2));
  const lines = [
    '# Fleet Batch',
    '',
    `Run: ${summary.runId}`,
    `Goal: ${summary.goal}`,
    `Result: ${summary.ok}/${summary.completed} completed OK, ${summary.fail} failed, ${summary.pending} pending, total ${summary.count}, duration ${summary.durationMs}ms`,
    '',
    '## Backends',
    '',
  ];
  for (const [backend, row] of Object.entries(summary.byBackend)) {
    lines.push(`- ${backend}: ${row.ok}/${row.total} OK, avg ${row.avgLatencyMs}ms, models ${Object.keys(row.models).join(', ')}`);
  }
  lines.push('', '## Samples', '');
  for (const r of results.slice(0, 12)) {
    lines.push(`### ${r.id}. ${r.agent} (${r.backend}${r.model ? ' / ' + r.model : ''})`);
    lines.push(r.ok ? r.reply.slice(0, 800) : `FAILED: ${r.error}`);
    lines.push('');
  }
  fs.writeFileSync(mdPath, lines.join('\n'));
  return { jsonPath, mdPath };
}

async function summarizeForDiscord(summary, label) {
  const compact = {
    label,
    runId: summary.runId,
    ok: summary.ok,
    fail: summary.fail,
    count: summary.count,
    completed: summary.completed,
    pending: summary.pending,
    byBackend: summary.byBackend,
  };
  try {
    const result = await router.callModelPromise(
      [
        { role: 'system', content: 'Summarize this fleet status for Discord in Thai, under 900 characters, concise and operational.' },
        { role: 'user', content: JSON.stringify(compact) },
      ],
      { preferBackend: 'ollama_cloud', model: process.env.OLLAMA_CLOUD_MODEL || 'gemma4:31b-cloud', noRotate: true }
    );
    return String(result.reply || '').trim().slice(0, 1500);
  } catch (error) {
    return `[fleet] ${label}: ${summary.ok}/${summary.count} OK, ${summary.fail} failed. ${String(error.message || error).slice(0, 120)}`;
  }
}

function postJson(targetUrl, headers, payload, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const parsed = new URL(targetUrl);
      const transport = parsed.protocol === 'https:' ? https : http;
      const body = JSON.stringify(payload);
      const request = transport.request(parsed, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
          ...headers,
        },
        timeout: timeoutMs || 30000,
      }, response => {
        let responseBody = '';
        response.on('data', chunk => { responseBody += chunk; });
        response.on('end', () => {
          resolve({
            ok: response.statusCode >= 200 && response.statusCode < 300,
            status: response.statusCode || 0,
            body: responseBody.slice(0, 200),
          });
        });
      });
      request.on('error', error => resolve({ ok: false, status: 0, error: error.message }));
      request.on('timeout', () => request.destroy(new Error('timeout')));
      request.write(body);
      request.end();
    } catch (error) {
      resolve({ ok: false, status: 0, error: String(error && error.message || error) });
    }
  });
}

function discordConfigStatus() {
  return {
    token: !!process.env.DISCORD_TOKEN,
    channel: !!(process.env.JIT_REPORT_CHANNEL_ID || process.env.DISCORD_CHANNEL_ID),
    webhook: !!process.env.DISCORD_WEBHOOK_URL,
  };
}

async function sendDiscord(message) {
  if (!DISCORD) return false;
  const webhook = process.env.DISCORD_WEBHOOK_URL || '';
  if (webhook) {
    const result = await postJson(webhook, {}, { content: message, username: 'Jit Mother' }, 30000);
    if (result.ok) return true;
  }
  const token = process.env.DISCORD_TOKEN || '';
  const channel = process.env.JIT_REPORT_CHANNEL_ID || process.env.DISCORD_CHANNEL_ID || '';
  if (!(token && channel)) return false;
  const result = await postJson(
    `https://discord.com/api/v10/channels/${encodeURIComponent(channel)}/messages`,
    { Authorization: `Bot ${token}`, 'User-Agent': 'JitFleetBatch/1.0' },
    { content: message },
    30000
  );
  return result.ok;
}

async function main() {
  const startedAt = Date.now();
  const jobs = buildJobs();
  console.log(`[fleet] run=${RUN_ID} count=${jobs.length} concurrency=${CONCURRENCY}`);
  console.log(`[fleet] goal=${GOAL}`);
  console.log(`[fleet] discord=${JSON.stringify(discordConfigStatus())}`);
  if (DISCORD) {
    const startSummary = { runId: RUN_ID, goal: GOAL, count: jobs.length, completed: 0, pending: jobs.length, ok: 0, fail: 0, concurrency: CONCURRENCY, durationMs: 0, byBackend: {} };
    const startMsg = await summarizeForDiscord(startSummary, 'start');
    await sendDiscord(startMsg);
  }

  let lastDiscord = Date.now();
  const timer = setInterval(async () => {
    const partial = summarize(partialResults, startedAt, jobs.length);
    const msg = await summarizeForDiscord(partial, 'interval');
    await sendDiscord(msg);
    lastDiscord = Date.now();
  }, DISCORD_INTERVAL_MS);
  timer.unref();

  const partialResults = [];
  const originalRunOne = runOne;
  runOne = async function(job) {
    const r = await originalRunOne(job);
    partialResults[job.id - 1] = r;
    if (Date.now() - lastDiscord >= DISCORD_INTERVAL_MS) {
      const partial = summarize(partialResults, startedAt, jobs.length);
      const msg = await summarizeForDiscord(partial, 'interval');
      await sendDiscord(msg);
      lastDiscord = Date.now();
    }
    return r;
  };

  const results = await runPool(jobs);
  clearInterval(timer);
  const summary = summarize(results, startedAt, results.length);
  const artifacts = writeArtifacts(results, summary);
  eventLog.record({
    phase: 'Fleet Batch',
    goal: GOAL,
    provider: 'multi-provider',
    squad: Array.from(new Set(results.map(r => r.agent))),
    verdicts: results.map(r => r.score || 0),
    durationMs: summary.durationMs,
    committed: false,
    batch: summary,
  });
  const finalMsg = await summarizeForDiscord(summary, 'complete');
  const discordSent = await sendDiscord(finalMsg);
  router.shutdownInnovaBot && router.shutdownInnovaBot();
  console.log('');
  console.log(JSON.stringify({ summary, artifacts, discordSent }, null, 2));
  process.exit(summary.ok >= Math.ceil(summary.count * 0.75) ? 0 : 1);
}

main().catch(error => {
  router.shutdownInnovaBot && router.shutdownInnovaBot();
  console.error('[fleet] fatal:', error && error.message || error);
  process.exit(1);
});
