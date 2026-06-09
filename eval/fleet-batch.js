#!/usr/bin/env node
'use strict';

/**
 * eval/fleet-batch.js - bounded multi-provider worker batch for Mother.
 *
 * Goals:
 * - run an honest 80+ worker fleet when requested
 * - keep GPT-5.5 out of the main worker lane
 * - notify innova-bot on partial progress without waiting for full-cycle end
 * - emit local progress artifacts for the heartbeat loop and reports
 */

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const crypto = require('crypto');
const childProcess = require('child_process');

const ROOT = path.join(__dirname, '..');
const LOOP_DIR = path.join(ROOT, 'network', 'loop');
const PROGRESS_PATH = path.join(LOOP_DIR, 'latest-fleet-progress.json');
const REGISTRY_PATH = path.join(ROOT, 'network', 'registry.json');
const ROUTING_PATH = path.join(ROOT, 'config', 'subagent-routing.json');
const PROVIDER_STATUS_PATH = path.join(ROOT, 'network', 'provider-status.json');

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
const { routingKey } = require('../hermes-discord/model-router');

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

function normalizeLane(value) {
  const v = String(value || '').trim().toLowerCase();
  if (v === 'mdes' || v === 'ollama' || v === 'ollama-mdes') return 'ollama_mdes';
  if (v === 'thai' || v === 'thai_llm' || v === 'thai-llm') return 'thaillm';
  if (v === 'local' || v === 'ollama-local') return 'ollama_local';
  if (v === 'cloud' || v === 'ollama-cloud') return 'ollama_cloud';
  if (v === 'innova' || v === 'innova-bot') return 'innova_bot';
  if (v === 'commandcode' || v === 'command_code' || v === 'evergreen') return 'commandcode';
  return v;
}

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return fallback;
  }
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

function uniqueList(values) {
  return Array.from(new Set((values || []).filter(Boolean)));
}

function safeSlug(value) {
  const slug = String(value || 'default')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
  return slug || 'default';
}

function shortText(text, limit = 200) {
  return String(text || '').replace(/\s+/g, ' ').trim().slice(0, limit);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function withTimeout(promise, timeoutMs, label) {
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timeout after ${timeoutMs}ms`)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => {
    if (timer) clearTimeout(timer);
  });
}

const COUNT = posInt(arg('--count', process.env.FLEET_BATCH_COUNT || 84), 84, 1, 200);
const CONCURRENCY = posInt(arg('--concurrency', process.env.FLEET_BATCH_CONCURRENCY || 8), 8, 1, 12);
const NOTIFY_EVERY = posInt(arg('--notify-every', process.env.FLEET_NOTIFY_EVERY || Math.max(4, Math.min(CONCURRENCY, 8))), Math.max(4, Math.min(CONCURRENCY, 8)), 1, 200);
const NOTIFY_MAX_REPLY = posInt(arg('--notify-max-reply', process.env.FLEET_NOTIFY_MAX_REPLY || 220), 220, 80, 800);
const DISCORD = !has('--no-discord');
const INNOVA_PROGRESS = !has('--no-innova-progress');
const DISCORD_INTERVAL_MS = posInt(arg('--discord-interval-ms', process.env.FLEET_DISCORD_INTERVAL_MS || 600000), 600000, 60000, 3600000);
const MAX_ATTEMPTS = posInt(arg('--attempts', process.env.FLEET_BATCH_ATTEMPTS || 2), 2, 1, 4);
const WORKER_TIMEOUT_MS = posInt(arg('--worker-timeout-ms', process.env.FLEET_WORKER_TIMEOUT_MS || 45000), 45000, 5000, 180000);
const REQUIRE_MIN_COUNT = posInt(arg('--require-min-count', process.env.FLEET_REQUIRE_MIN_COUNT || 0), 0, 0, 200);
const REQUIRE_MIN_OK = posInt(arg('--require-min-ok', process.env.FLEET_REQUIRE_MIN_OK || REQUIRE_MIN_COUNT), REQUIRE_MIN_COUNT, 0, 200);
const INCLUDE_OPENAI = has('--include-openai');
const INCLUDE_INNOVA_BOT = has('--include-innova-bot');
const INCLUDE_COMMANDCODE = has('--include-commandcode');
const REQUESTED_LANES = splitCsv(arg('--lanes', process.env.FLEET_BATCH_LANES || '')).map(normalizeLane);
const EXCLUDED_LANES = splitCsv(arg('--exclude-lanes', process.env.FLEET_BATCH_EXCLUDE_LANES || '')).map(normalizeLane);
const RUN_ID = 'fleet-batch-' + new Date().toISOString().replace(/[:.]/g, '-');
const ARTIFACT_DIR = path.join(ROOT, 'network', 'artifacts', RUN_ID);

function goalFromArgs() {
  const goalFile = arg('--goal-file', '');
  if (goalFile) {
    const resolved = path.resolve(ROOT, goalFile);
    return fs.readFileSync(resolved, 'utf8').trim();
  }
  return arg('--goal', 'Harden Jit Mother and innomcp tonight: find concrete risks, propose the next safe fix, and keep evidence concise.');
}
const GOAL = goalFromArgs();

const BACKEND_LIMITS = {
  ollama_mdes: 1,
  thaillm: 4,
  ollama_cloud: 2,
  ollama_local: 2,
  copilot: 1,
  openai: 1,
  openclaude: 1,
  innova_bot: 1,
  commandcode: 2,
};

const DEFAULT_ROUTE_ORDER = ['ollama_mdes', 'thaillm', 'commandcode', 'ollama_cloud', 'copilot', 'ollama_local'];
const DEFAULT_THAI_MODELS = [
  'openthaigpt-thaillm-8b-instruct-v7.2',
  'pathumma-thaillm-qwen3-8b-think-3.0.0',
  'typhoon-s-thaillm-8b-instruct',
  'thalle-0.2-thaillm-8b-fa',
];
const DEFAULT_PERSONAS = [
  'jit', 'innova', 'soma', 'lak', 'neta', 'chamu', 'vaja', 'mue',
  'pada', 'netra', 'karn', 'pran', 'sayanprasathan', 'agent-mdes',
  'agent-thaillm', 'agent-copilot', 'agent-commandcode',
];
const DEFAULT_PERSPECTIVES = ['coordinator', 'analyst', 'executor', 'verifier', 'observer', 'critic', 'scribe', 'router'];

function laneDefinitions() {
  const status = router.status();
  const routing = readJson(ROUTING_PATH, { policy: {}, providers: {} });
  const thaiModels = status.backends.thaillm?.models || routing.providers?.thaillm?.models || DEFAULT_THAI_MODELS;
  const cloudModels = splitCsv(process.env.OLLAMA_CLOUD_MODELS || 'gemma4:31b-cloud,nemotron-3-super:cloud');
  const definitions = {
    ollama_mdes: {
      backend: 'ollama_mdes',
      models: [status.backends.ollama_mdes?.model || routing.providers?.ollama_mdes?.default_model || 'gemma4:26b'],
      weight: 30,
      costTier: 'low',
      external: true,
    },
    thaillm: {
      backend: 'thaillm',
      models: thaiModels,
      weight: 26,
      costTier: 'medium',
      external: true,
    },
    commandcode: {
      backend: 'commandcode',
      models: splitCsv(process.env.COMMANDCODE_MODELS || routing.providers?.commandcode?.models?.join(',') || 'deepseek/deepseek-v4-flash,commandcode-1'),
      weight: 18,
      costTier: 'medium',
      external: true,
    },
    ollama_cloud: {
      backend: 'ollama_cloud',
      models: cloudModels,
      weight: 14,
      costTier: 'medium',
      external: true,
    },
    copilot: {
      backend: 'copilot',
      models: [routing.providers?.copilot?.default_model || 'claude-sonnet-4.6'],
      weight: 6,
      costTier: 'medium',
      external: true,
    },
    ollama_local: {
      backend: 'ollama_local',
      models: [status.backends.ollama_local?.model || routing.providers?.ollama_local?.default_model || 'qwen2.5-coder:7b'],
      weight: 6,
      costTier: 'low',
      external: false,
    },
    openai: {
      backend: 'openai',
      models: [status.backends.openai?.model || routing.policy?.advisor_model || 'gpt-5.5'],
      weight: 2,
      costTier: 'high',
      external: true,
    },
    innova_bot: {
      backend: 'innova_bot',
      models: [status.backends.innova_bot?.model || null],
      weight: 2,
      costTier: 'local',
      external: false,
    },
  };

  let ordered = REQUESTED_LANES.length
    ? REQUESTED_LANES
    : uniqueList([].concat((routing.policy && routing.policy.budget_order) || [], DEFAULT_ROUTE_ORDER).map(normalizeLane));
  if (!INCLUDE_OPENAI) ordered = ordered.filter(name => name !== 'openai');
  if (!INCLUDE_INNOVA_BOT) ordered = ordered.filter(name => name !== 'innova_bot');
  if (!INCLUDE_COMMANDCODE) ordered = ordered.filter(name => name !== 'commandcode');
  if (INCLUDE_OPENAI && !ordered.includes('openai')) ordered.push('openai');
  if (INCLUDE_INNOVA_BOT && !ordered.includes('innova_bot')) ordered.push('innova_bot');
  if (INCLUDE_COMMANDCODE && !ordered.includes('commandcode')) ordered.push('commandcode');
  if (EXCLUDED_LANES.length) ordered = ordered.filter(name => !EXCLUDED_LANES.includes(name));

  // Task #10: Filter out UNREACHABLE/ERROR lanes based on provider-status.json probe.
  // Lanes that are down get their weight redistributed to surviving lanes.
  const providerStatus = readJson(path.join(ROOT, 'network', 'provider-status.json'), { usable: [], results: {} });
  const aliveBackends = new Set((providerStatus.usable || []).filter(b => {
    const r = providerStatus.results && providerStatus.results[b];
    return r && r.status === 'ALIVE' && r.served_by === b;
  }));

  const unfilteredLanes = ordered
    .map(name => definitions[name])
    .filter(Boolean)
    .map(lane => ({
      ...lane,
      models: uniqueList(lane.models.length ? lane.models : [null]),
    }));

  // Filter: keep only ALIVE lanes; redistribute weight from dead lanes proportionally.
  let lanes = unfilteredLanes.filter(lane => aliveBackends.has(lane.backend));
  const deadWeight = unfilteredLanes
    .filter(lane => !aliveBackends.has(lane.backend))
    .reduce((sum, lane) => sum + lane.weight, 0);

  if (deadWeight > 0 && lanes.length > 0) {
    const liveWeight = lanes.reduce((sum, lane) => sum + lane.weight, 0);
    for (const lane of lanes) {
      lane.weight += Math.round(deadWeight * (lane.weight / liveWeight));
    }
  }

  // Log filtered lanes for observability.
  const deadNames = unfilteredLanes.filter(l => !aliveBackends.has(l.backend)).map(l => l.backend);
  if (deadNames.length) {
    console.log(`[fleet] provider-status filter: dropped ${deadNames.join(', ')} (not ALIVE), redistributed ${deadWeight} weight`);
  }

  if (!lanes.length) {
    throw new Error('No fleet lanes selected. Check --lanes/--exclude-lanes and provider-status.json.');
  }
  return lanes;
}

function loadPersonas() {
  const registry = readJson(REGISTRY_PATH, { agents: [] });
  const routing = readJson(ROUTING_PATH, { agents: {} });
  const merged = new Map();

  for (const item of Array.isArray(registry.agents) ? registry.agents : []) {
    if (!item || !item.name) continue;
    merged.set(item.name, {
      name: item.name,
      role: item.role || '',
      capabilities: Array.isArray(item.capabilities) ? item.capabilities : [],
      provider: item.provider || '',
      model: item.model || '',
    });
  }

  for (const [name, item] of Object.entries(routing.agents || {})) {
    const prev = merged.get(name) || { name, role: '', capabilities: [] };
    merged.set(name, {
      ...prev,
      role: prev.role || item.role || '',
      capabilities: uniqueList([].concat(prev.capabilities || [], item.capabilities || [])),
      provider: prev.provider || item.provider || '',
      model: prev.model || item.model || '',
    });
  }

  if (!merged.size) {
    return DEFAULT_PERSONAS.map(name => ({ name, role: '', capabilities: [] }));
  }

  return Array.from(merged.values())
    .sort((a, b) => a.name.localeCompare(b.name))
    .filter(item => item && item.name);
}

function perspectivesFor(persona) {
  const caps = new Set((persona.capabilities || []).map(String));
  const tags = [];
  if (caps.has('orchestrate') || caps.has('coordinate') || caps.has('delegate-tasks')) tags.push('coordinator');
  if (caps.has('reason') || caps.has('analyze') || caps.has('deep-engineering')) tags.push('analyst');
  if (caps.has('execute') || caps.has('write-files') || caps.has('implement')) tags.push('executor');
  if (caps.has('write-tests') || caps.has('regression-test') || caps.has('coverage-check') || caps.has('tests')) tags.push('verifier');
  if (caps.has('observe') || caps.has('monitor') || caps.has('watch')) tags.push('observer');
  if (caps.has('review') || caps.has('code-review') || caps.has('security-review')) tags.push('critic');
  if (caps.has('summarize') || caps.has('report') || caps.has('communicate')) tags.push('scribe');
  if (caps.has('route') || caps.has('signal-routing') || caps.has('navigate')) tags.push('router');
  return tags.length ? uniqueList(tags) : DEFAULT_PERSPECTIVES;
}

function buildWorkerRoster(targetCount) {
  const personas = loadPersonas();
  const roster = [];
  let round = 0;
  while (roster.length < targetCount) {
    for (const persona of personas) {
      const perspectives = perspectivesFor(persona);
      const perspective = perspectives[round % perspectives.length];
      const slot = Math.floor(roster.length / personas.length) + 1;
      roster.push({
        workerId: `${safeSlug(persona.name)}-${perspective}-${String(slot).padStart(2, '0')}`,
        agent: persona.name,
        role: persona.role || perspective,
        perspective,
      });
      if (roster.length >= targetCount) break;
    }
    round++;
  }
  return roster;
}

function buildJobs() {
  const lanes = laneDefinitions();
  const roster = buildWorkerRoster(COUNT);
  const weighted = [];
  const maxWeight = Math.max(...lanes.map(lane => lane.weight));
  for (let round = 0; round < maxWeight; round++) {
    for (const lane of lanes) {
      if (round < lane.weight) weighted.push(lane);
    }
  }

  const jobs = [];
  const modelCursor = {};
  for (let i = 0; i < COUNT; i++) {
    // TICKET-007a: deterministic lane selection via syllable-splitter routing key
    // Compute key from actual job content (worker context + goal) so ollama_local
    // and other backends route by prompt syllables, not by numeric index tokens.
    const worker = roster[i];
    const contentForRouting = [GOAL, worker.workerId, worker.agent, worker.perspective, worker.role].join(' ');
    const key = routingKey(contentForRouting);
    const laneIndex = key % weighted.length;
    const lane = weighted[laneIndex];
    const cursor = modelCursor[lane.backend] || 0;
    const model = lane.models[cursor % lane.models.length] || null;
    modelCursor[lane.backend] = cursor + 1;
    jobs.push({
      id: i + 1,
      backend: lane.backend,
      model,
      workerId: worker.workerId,
      agent: worker.agent,
      role: worker.role,
      perspective: worker.perspective,
      costTier: lane.costTier,
      external: lane.external,
      routingKey: key,
    });
  }
  return jobs;
}

function jobPrompt(job) {
  return [
    'Bounded Jit Mother worker. Reply concise and evidence-first in Thai or mixed Thai/English.',
    '',
    'Task:',
    GOAL,
    '',
    `Worker: ${job.workerId}`,
    `Base persona: ${job.agent}`,
    `Perspective: ${job.perspective}`,
    `Role hint: ${job.role}`,
    `Lane: ${job.backend}${job.model ? ' / ' + job.model : ' / default'}`,
    `Cost tier: ${job.costTier}`,
    'Give one actionable next step or one concrete risk with confidence 0-100.',
    'No file edits. No commands. No preamble.',
  ].join('\n');
}

function classifyReply(reply) {
  const text = String(reply || '').trim();
  if (!text) return { ok: false, score: 0 };
  const m = text.match(/\bconfidence\s*[:=]?\s*(\d{1,3})\b/i) || text.match(/\b(\d{1,3})\s*%/);
  const score = Math.max(1, Math.min(100, m ? Number(m[1]) : 70));
  return { ok: true, score };
}

async function runOne(job) {
  const started = Date.now();
  const attempts = [];
  let lastError = '';
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const attemptStarted = Date.now();
    try {
      const result = await withTimeout(
        router.callModelPromise(
          [{ role: 'user', content: jobPrompt(job) }],
          { preferBackend: job.backend, model: job.model, noRotate: true }
        ),
        WORKER_TIMEOUT_MS,
        `${job.backend}${job.model ? '/' + job.model : ''}`
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

async function runPool(jobs, onResult) {
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
      process.stdout.write(`[fleet] ${job.id}/${jobs.length} ${job.backend}${job.model ? '/' + job.model : ''} ${job.workerId} ... `);
      const release = await acquireBackend(job.backend);
      let result;
      try {
        result = await runOne(job);
      } finally {
        release();
      }
      results[idx] = result;
      console.log(result.ok ? `OK ${result.latencyMs}ms` : `FAIL ${result.latencyMs}ms ${result.error || ''}`);
      if (typeof onResult === 'function') await onResult(result, idx, results);
    }
  }

  const pool = [];
  for (let i = 0; i < Math.min(CONCURRENCY, jobs.length); i++) pool.push(worker());
  await Promise.all(pool);
  return results;
}

function summarize(results, startedAt, totalCount, jobs) {
  const completed = results.filter(r => r && !r.pending);
  const expectedCount = totalCount || completed.length;
  const byBackend = {};
  for (const r of completed) {
    const row = byBackend[r.backend] || (byBackend[r.backend] = {
      total: 0,
      ok: 0,
      fail: 0,
      latency: 0,
      models: {},
      workers: 0,
    });
    row.total++;
    if (r.ok) row.ok++; else row.fail++;
    row.latency += r.latencyMs || 0;
    row.workers++;
    const model = r.model || 'default';
    row.models[model] = (row.models[model] || 0) + 1;
  }
  for (const row of Object.values(byBackend)) {
    row.avgLatencyMs = row.total ? Math.round(row.latency / row.total) : 0;
    delete row.latency;
  }

  const planned = Array.isArray(jobs) && jobs.length ? jobs : completed;
  const plannedWorkers = uniqueList(planned.map(r => r.workerId || r.agent));
  const completedWorkers = uniqueList(completed.map(r => r.workerId || r.agent));
  const uniquePersonas = uniqueList(planned.map(r => r.agent));
  const perspectiveCounts = {};
  for (const row of planned) {
    const key = row.perspective || 'general';
    perspectiveCounts[key] = (perspectiveCounts[key] || 0) + 1;
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
    notifyEvery: NOTIFY_EVERY,
    byBackend,
    roster: {
      plannedWorkers: plannedWorkers.length,
      completedWorkers: completedWorkers.length,
      uniquePersonas: uniquePersonas.length,
      perspectives: perspectiveCounts,
      sampleWorkers: plannedWorkers.slice(0, 12),
    },
    proof: {
      requireMinCount: REQUIRE_MIN_COUNT,
      requireMinOk: REQUIRE_MIN_OK,
      minCountSatisfied: !REQUIRE_MIN_COUNT || expectedCount >= REQUIRE_MIN_COUNT,
      minCompletedSatisfied: !REQUIRE_MIN_COUNT || completed.length >= REQUIRE_MIN_COUNT,
      minOkSatisfied: !REQUIRE_MIN_OK || completed.filter(r => r.ok).length >= REQUIRE_MIN_OK,
      selectedLanes: uniqueList(planned.map(r => r.backend)),
      requestedLanes: REQUESTED_LANES,
      excludedLanes: EXCLUDED_LANES,
      backendLimits: BACKEND_LIMITS,
    },
  };
}

function latestResultForProgress(result) {
  return {
    id: result.id,
    workerId: result.workerId,
    agent: result.agent,
    perspective: result.perspective,
    backend: result.backend,
    model: result.model,
    ok: result.ok,
    latencyMs: result.latencyMs,
    error: result.error ? shortText(result.error, 180) : '',
    reply: result.reply ? shortText(result.reply, NOTIFY_MAX_REPLY) : '',
  };
}

function writeProgress(summary, extra) {
  const payload = {
    runId: summary.runId,
    goal: GOAL,
    updatedAt: new Date().toISOString(),
    label: extra.label,
    summary,
    latest: extra.latest || null,
    notify: extra.notify || null,
    artifacts: extra.artifacts || null,
  };
  writeJson(PROGRESS_PATH, payload);
  return payload;
}

function sha256(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function gitInfo() {
  function run(args) {
    try {
      return childProcess.execFileSync('git', args, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    } catch (_) {
      return '';
    }
  }
  return {
    branch: run(['rev-parse', '--abbrev-ref', 'HEAD']),
    commit: run(['rev-parse', 'HEAD']),
    statusShort: run(['status', '--short']),
  };
}

function writeProofManifest(summary, artifacts, startedAt, finishedAt) {
  const manifestPath = path.join(ARTIFACT_DIR, 'proof-manifest.json');
  const mdManifestPath = path.join(ARTIFACT_DIR, 'proof-manifest.md');
  const manifest = {
    runId: summary.runId,
    createdAt: new Date(finishedAt).toISOString(),
    command: process.argv.map(String),
    cwd: ROOT,
    node: process.version,
    git: gitInfo(),
    durationMs: finishedAt - startedAt,
    requirement: {
      requireMinCount: REQUIRE_MIN_COUNT,
      requireMinOk: REQUIRE_MIN_OK,
      count: summary.count,
      completed: summary.completed,
      ok: summary.ok,
      pass: summary.proof.minCountSatisfied && summary.proof.minCompletedSatisfied && summary.proof.minOkSatisfied,
    },
    lanes: summary.byBackend,
    roster: summary.roster,
    artifacts: {
      summaryJson: path.relative(ROOT, artifacts.jsonPath).replace(/\\/g, '/'),
      summaryMd: path.relative(ROOT, artifacts.mdPath).replace(/\\/g, '/'),
      summaryJsonSha256: sha256(artifacts.jsonPath),
      summaryMdSha256: sha256(artifacts.mdPath),
    },
    providerStatusPath: fs.existsSync(path.join(ROOT, 'network', 'provider-status.json'))
      ? 'network/provider-status.json'
      : null,
  };
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  fs.writeFileSync(mdManifestPath, [
    '# Fleet Proof Manifest',
    '',
    `Run: ${manifest.runId}`,
    `Command: ${manifest.command.join(' ')}`,
    `Requirement: count >= ${REQUIRE_MIN_COUNT || 0}, ok >= ${REQUIRE_MIN_OK || 0}`,
    `Observed: count ${summary.count}, completed ${summary.completed}, ok ${summary.ok}`,
    `Workers: planned ${summary.roster.plannedWorkers}, completed ${summary.roster.completedWorkers}, personas ${summary.roster.uniquePersonas}`,
    `Pass: ${manifest.requirement.pass ? 'yes' : 'no'}`,
    '',
    '## Artifact Hashes',
    '',
    `- summary.json: ${manifest.artifacts.summaryJsonSha256}`,
    `- summary.md: ${manifest.artifacts.summaryMdSha256}`,
    '',
    '## Lanes',
    '',
    ...Object.entries(summary.byBackend).map(([backend, row]) => `- ${backend}: ${row.ok}/${row.total} OK, avg ${row.avgLatencyMs}ms`),
    '',
  ].join('\n'));
  return { manifestPath, mdManifestPath };
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
    `Workers: planned ${summary.roster.plannedWorkers}, completed ${summary.roster.completedWorkers}, personas ${summary.roster.uniquePersonas}`,
    '',
    '## Backends',
    '',
  ];
  for (const [backend, row] of Object.entries(summary.byBackend)) {
    lines.push(`- ${backend}: ${row.ok}/${row.total} OK, avg ${row.avgLatencyMs}ms, models ${Object.keys(row.models).join(', ')}`);
  }
  lines.push('', '## Samples', '');
  for (const r of results.slice(0, 12)) {
    lines.push(`### ${r.id}. ${r.workerId} (${r.agent} :: ${r.backend}${r.model ? ' / ' + r.model : ''})`);
    lines.push(r.ok ? r.reply.slice(0, 800) : `FAILED: ${r.error}`);
    lines.push('');
  }
  fs.writeFileSync(mdPath, lines.join('\n'));
  return { jsonPath, mdPath };
}

function renderOpsSummary(summary, label, latest, artifactPath) {
  const lanes = Object.keys(summary.byBackend || {});
  const lines = [
    `Jit fleet ${label}`,
    `run=${summary.runId}`,
    `progress=${summary.completed}/${summary.count} ok=${summary.ok} fail=${summary.fail} pending=${summary.pending}`,
    `workers=${summary.roster.completedWorkers || summary.roster.plannedWorkers}/${summary.roster.plannedWorkers} personas=${summary.roster.uniquePersonas}`,
    `lanes=${lanes.length ? lanes.join(',') : 'none'}`,
  ];
  if (latest) {
    lines.push(`latest=${latest.workerId} ${latest.backend}${latest.model ? '/' + latest.model : ''} ${latest.ok ? 'OK' : 'FAIL'} ${latest.latencyMs}ms`);
    if (latest.reply) lines.push(`reply=${latest.reply}`);
    if (latest.error) lines.push(`error=${latest.error}`);
  }
  if (artifactPath) lines.push(`artifact=${artifactPath}`);
  return lines.join('\n').slice(0, 3500);
}

let innovaBridge = null;

async function getInnovaBridge() {
  if (!innovaBridge) {
    const InnovaBotBridge = require('../limbs/innova-bot-bridge');
    innovaBridge = new InnovaBotBridge();
    await innovaBridge.connect();
  }
  return innovaBridge;
}

async function closeInnovaBridge() {
  if (innovaBridge && innovaBridge.disconnect) {
    try {
      await innovaBridge.disconnect();
    } catch (_) {}
  }
  innovaBridge = null;
}

async function notifyInnovaBot(message) {
  if (!INNOVA_PROGRESS) return { ok: false, skipped: true, reason: 'disabled' };
  try {
    const bridge = await getInnovaBridge();
    await bridge.dispatchTask(message.slice(0, 3500));
    return { ok: true };
  } catch (error) {
    return { ok: false, error: shortText(error && error.message || error, 200) };
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
  fs.mkdirSync(LOOP_DIR, { recursive: true });
  const startedAt = Date.now();
  const jobs = buildJobs();
  if (REQUIRE_MIN_COUNT && jobs.length < REQUIRE_MIN_COUNT) {
    throw new Error(`Fleet proof requires at least ${REQUIRE_MIN_COUNT} jobs, but only ${jobs.length} were built.`);
  }

  console.log(`[fleet] run=${RUN_ID} count=${jobs.length} concurrency=${CONCURRENCY} notifyEvery=${NOTIFY_EVERY}`);
  console.log(`[fleet] goal=${GOAL}`);
  if (REQUESTED_LANES.length) console.log(`[fleet] requestedLanes=${REQUESTED_LANES.join(',')}`);
  if (EXCLUDED_LANES.length) console.log(`[fleet] excludedLanes=${EXCLUDED_LANES.join(',')}`);
  if (REQUIRE_MIN_COUNT || REQUIRE_MIN_OK) console.log(`[fleet] proof requireMinCount=${REQUIRE_MIN_COUNT} requireMinOk=${REQUIRE_MIN_OK}`);
  console.log(`[fleet] discord=${JSON.stringify(discordConfigStatus())}`);

  const partialResults = new Array(jobs.length);
  let lastInnovaCount = 0;
  let lastDiscordAt = 0;
  let progressQueue = Promise.resolve();

  const startSummary = summarize([], startedAt, jobs.length, jobs);
  writeProgress(startSummary, { label: 'start' });
  if (DISCORD) {
    const startMsg = renderOpsSummary(startSummary, 'start');
    await sendDiscord(startMsg);
    lastDiscordAt = Date.now();
  }
  if (INNOVA_PROGRESS) {
    const startMsg = renderOpsSummary(startSummary, 'start');
    const notify = await notifyInnovaBot(startMsg);
    writeProgress(startSummary, { label: 'start', notify });
  }

  const results = await runPool(jobs, async (result, idx) => {
    partialResults[idx] = result;
    const partial = summarize(partialResults, startedAt, jobs.length, jobs);
    const latest = latestResultForProgress(result);
    writeProgress(partial, { label: 'running', latest });

    const shouldNotifyInnova =
      partial.completed === jobs.length ||
      !result.ok ||
      (partial.completed - lastInnovaCount) >= NOTIFY_EVERY;
    const shouldNotifyDiscord =
      DISCORD &&
      (partial.completed === jobs.length || (Date.now() - lastDiscordAt) >= DISCORD_INTERVAL_MS);

    if (!shouldNotifyInnova && !shouldNotifyDiscord) return;

    const partialMsg = renderOpsSummary(partial, 'partial', latest);
    progressQueue = progressQueue.then(async () => {
      let notify = null;
      if (shouldNotifyInnova) {
        notify = await notifyInnovaBot(partialMsg);
        lastInnovaCount = partial.completed;
      }
      if (shouldNotifyDiscord) {
        await sendDiscord(partialMsg);
        lastDiscordAt = Date.now();
      }
      writeProgress(partial, { label: 'running', latest, notify });
    });
    await progressQueue;
  });

  await progressQueue;

  const summary = summarize(results, startedAt, results.length, jobs);
  const artifacts = writeArtifacts(results, summary);
  const proofArtifacts = writeProofManifest(summary, artifacts, startedAt, Date.now());
  const artifactPath = path.relative(ROOT, ARTIFACT_DIR).replace(/\\/g, '/');

  eventLog.record({
    phase: 'Fleet Batch',
    goal: GOAL,
    provider: 'multi-provider',
    squad: uniqueList(results.map(r => r.workerId || r.agent)).slice(0, 120),
    verdicts: results.map(r => r.score || 0),
    durationMs: summary.durationMs,
    committed: false,
    batch: summary,
  });

  const finalMsg = renderOpsSummary(summary, 'complete', null, artifactPath);
  const discordSent = await sendDiscord(finalMsg);
  const innovaSent = await notifyInnovaBot(finalMsg);
  writeProgress(summary, {
    label: 'complete',
    notify: { discordSent, innovaSent },
    artifacts: {
      dir: artifactPath,
      summaryJson: path.relative(ROOT, artifacts.jsonPath).replace(/\\/g, '/'),
      summaryMd: path.relative(ROOT, artifacts.mdPath).replace(/\\/g, '/'),
    },
  });

  await closeInnovaBridge();
  router.shutdownInnovaBot && router.shutdownInnovaBot();
  console.log('');
  console.log(JSON.stringify({ summary, artifacts: { ...artifacts, ...proofArtifacts }, discordSent, innovaSent }, null, 2));
  const ratioOk = summary.ok >= Math.ceil(summary.count * 0.75);
  const proofOk = summary.proof.minCountSatisfied && summary.proof.minCompletedSatisfied && summary.proof.minOkSatisfied;
  process.exit(ratioOk && proofOk ? 0 : 1);
}

main().catch(async (error) => {
  try {
    await closeInnovaBridge();
  } catch (_) {}
  router.shutdownInnovaBot && router.shutdownInnovaBot();
  console.error('[fleet] fatal:', error && error.message || error);
  process.exit(1);
});
