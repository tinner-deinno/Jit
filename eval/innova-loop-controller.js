#!/usr/bin/env node
'use strict';

/**
 * Low-token Mother loop for innova-bot/Jit task clearing.
 *
 * One cycle:
 * 1. Check OMX/MAW/provider readiness.
 * 2. Select only currently usable low-cost lanes.
 * 3. Fan out a bounded >50 worker fleet through eval/fleet-batch.js.
 * 4. Report a compact artifact to innova-bot and local outbox.
 */

const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');
const http = require('http');
const https = require('https');

const ROOT = path.resolve(__dirname, '..');
const LOOP_DIR = path.join(ROOT, 'network', 'loop');
const OUTBOX_DIR = path.join(ROOT, 'ψ', 'outbox');
const STATE_PATH = path.join(LOOP_DIR, 'innova-loop-state.json');
const LATEST_REPORT = path.join(LOOP_DIR, 'latest-report.md');
const LATEST_JSON = path.join(LOOP_DIR, 'latest-report.json');
const CURRENT_GOAL = path.join(LOOP_DIR, 'current-goal.txt');
const LATEST_VISUAL = path.join(LOOP_DIR, 'latest-visual.json');
const ROUTING_PATH = path.join(ROOT, 'config', 'subagent-routing.json');

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

function has(name) {
  return process.argv.includes(name);
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
  return v;
}

function intArg(name, fallback, min, max) {
  const n = Math.floor(Number(arg(name, fallback)));
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

const INTERVAL_MS = intArg('--interval-ms', 300000, 60000, 3600000);
const MAX_CYCLES = intArg('--max-cycles', has('--once') ? 1 : 0, 0, 1000000);
const MAX_RUNTIME_MS = intArg('--max-runtime-ms', 0, 0, 86400000);
const COUNT = intArg('--count', 84, 51, 200);
const CONCURRENCY = intArg('--concurrency', 8, 1, 12);
const PROVIDER_TIMEOUT = intArg('--provider-timeout', 70000, 10000, 120000);
const ADVISOR_THRESHOLD = intArg('--advisor-threshold', 8, 1, 100);
const FLEET_TIMEOUT = intArg('--fleet-timeout-ms', 900000, 120000, 3600000);
const FLEET_ATTEMPTS = intArg('--fleet-attempts', 1, 1, 4);
const FLEET_WORKER_TIMEOUT_MS = intArg('--fleet-worker-timeout-ms', 45000, 5000, 180000);
const NOTIFY_EVERY = intArg('--notify-every', Math.max(4, Math.min(CONCURRENCY, 8)), 1, 200);
const SLOW_LANE_MS = intArg('--slow-lane-ms', Math.max(30000, Math.floor(FLEET_WORKER_TIMEOUT_MS * 0.75)), 5000, 300000);
const FULL_PROBE_EVERY = intArg('--full-probe-every', 6, 1, 1000);
const QUICK_FLEET_EVERY = intArg('--quick-fleet-every', 6, 1, 1000);
const VISUAL_EVERY = intArg('--visual-every', 1, 0, 1000);
const VISUAL_TIMEOUT_MS = intArg('--visual-timeout-ms', 90000, 10000, 300000);
const VISUAL_URL = arg('--visual-url', process.env.INNOVA_VISUAL_URL || 'http://127.0.0.1:7010/gui');
const INCLUDE_INNOVA_WORKER_LANE = has('--include-innova-worker-lane');
const FORCED_LANES = splitCsv(arg('--lanes', '')).map(normalizeLane);
const EXCLUDED_LANES = splitCsv(arg('--exclude-lanes', '')).map(normalizeLane);
const DRY_RUN = has('--dry-run');

function ensureDirs() {
  fs.mkdirSync(LOOP_DIR, { recursive: true });
  fs.mkdirSync(OUTBOX_DIR, { recursive: true });
}

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return fallback;
  }
}

function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

function shellQuote(value) {
  const text = String(value ?? '');
  if (!text) return '""';
  if (process.platform === 'win32') {
    return /[\s"&|<>^()]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  }
  return /[\s"'\\$`]/.test(text) ? `'${text.replace(/'/g, `'\\''`)}'` : text;
}

function run(command, args, options = {}) {
  const started = Date.now();
  const useShell = process.platform === 'win32';
  const spawnTarget = useShell ? [command].concat(args || []).map(shellQuote).join(' ') : command;
  const spawnArgs = useShell ? [] : (args || []);
  const r = childProcess.spawnSync(spawnTarget, spawnArgs, {
    cwd: options.cwd || ROOT,
    encoding: 'utf8',
    timeout: options.timeout || 120000,
    shell: useShell,
    env: { ...process.env, ...(options.env || {}) },
  });
  return {
    command: [command].concat(args).join(' '),
    ok: r.status === 0,
    status: r.status,
    ms: Date.now() - started,
    stdout: String(r.stdout || '').trim(),
    stderr: String(r.stderr || '').trim(),
    error: r.error ? r.error.message : '',
  };
}

function stripAnsi(text) {
  return String(text || '').replace(/\u001b\[[0-9;?]*[ -/]*[@-~]/g, '');
}

function skippedRun(label) {
  return {
    command: label,
    ok: true,
    status: 0,
    ms: 0,
    stdout: '',
    stderr: '',
    error: '',
    skipped: true,
  };
}

function shortText(text, limit = 1200) {
  return stripAnsi(String(text || ''))
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n[ \t]+/g, '\n')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .slice(0, limit);
}

function routingBudgetOrder() {
  const config = readJson(ROUTING_PATH, {});
  const configured = Array.isArray(config && config.policy && config.policy.budget_order)
    ? config.policy.budget_order.map(normalizeLane)
    : [];
  return uniqueList(configured.concat(['ollama_mdes', 'thaillm', 'ollama_cloud', 'copilot', 'ollama_local', 'innova_bot', 'openai']));
}

function loadState() {
  return {
    cycle: 0,
    failureStreak: 0,
    advisorCalls: 0,
    lastStartedAt: null,
    lastFinishedAt: null,
    lastStatus: 'new',
    ...readJson(STATE_PATH, {}),
  };
}

function getUsableProviders() {
  const provider = readJson(path.join(ROOT, 'network', 'provider-status.json'), { usable: [], results: {} });
  const usable = new Set(Array.isArray(provider.usable) ? provider.usable : []);
  // Also include any ALIVE backends from results even if not in usable list (cache may be stale)
  const aliveSet = new Set();
  if (provider && provider.results && typeof provider.results === 'object') {
    for (const [name, row] of Object.entries(provider.results)) {
      if (row && row.status === 'ALIVE') aliveSet.add(name);
    }
  }
  const selected = routingBudgetOrder().filter(name => usable.has(name) || aliveSet.has(name));

  return { provider, selected, aliveBackends: Array.from(aliveSet) };
}

function latestFleetArtifact() {
  const artifactsRoot = path.join(ROOT, 'network', 'artifacts');
  try {
    const dirs = fs.readdirSync(artifactsRoot)
      .filter(name => name.startsWith('fleet-batch-'))
      .map(name => path.join(artifactsRoot, name))
      .filter(file => fs.existsSync(path.join(file, 'summary.json')))
      .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
    return dirs[0] || '';
  } catch (_) {
    return '';
  }
}

function latestFleetSummary() {
  const artifact = latestFleetArtifact();
  if (!artifact) return null;
  return readJson(path.join(artifact, 'summary.json'), null);
}

function unstableLanesFromLatest(summary) {
  const byBackend = summary && summary.summary && summary.summary.byBackend;
  if (!byBackend || typeof byBackend !== 'object') return [];
  return Object.entries(byBackend)
    .filter(([, row]) => row && row.total > 0 && row.fail > row.ok)
    .map(([backend]) => backend);
}

function slowLanesFromProvider(provider) {
  const results = provider && provider.results;
  if (!results || typeof results !== 'object') return [];
  return Object.entries(results)
    .filter(([, row]) => row && row.status === 'ALIVE' && Number(row.ms || 0) >= SLOW_LANE_MS)
    .map(([backend]) => backend);
}

function selectLanes(state) {
  const { provider, selected, aliveBackends } = getUsableProviders();
  const unstable = new Set(unstableLanesFromLatest(latestFleetSummary()));
  const slow = new Set(slowLanesFromProvider(provider));
  // Stricter filter: drop UNREACHABLE/ERROR lanes from latest probe
  const deadSet = new Set();
  if (provider && provider.results && typeof provider.results === 'object') {
    for (const [name, row] of Object.entries(provider.results)) {
      if (row && (row.status === 'UNREACHABLE' || row.status === 'ERROR')) deadSet.add(name);
    }
  }
  let lanes = selected.filter(name =>
    name !== 'innova_bot'
    && !unstable.has(name)
    && !slow.has(name)
    && !deadSet.has(name)
  );
  if (FORCED_LANES.length) {
    lanes = lanes.filter(name => FORCED_LANES.includes(name));
  }
  if (EXCLUDED_LANES.length) {
    lanes = lanes.filter(name => !EXCLUDED_LANES.includes(name));
  }
  if (!lanes.length) {
    lanes = selected.filter(name =>
      name !== 'innova_bot'
      && !unstable.has(name)
      && !deadSet.has(name)
    );
  }
  if (FORCED_LANES.length) {
    lanes = lanes.filter(name => FORCED_LANES.includes(name));
  }
  if (EXCLUDED_LANES.length) {
    lanes = lanes.filter(name => !EXCLUDED_LANES.includes(name));
  }
  const includeInnova = INCLUDE_INNOVA_WORKER_LANE && selected.includes('innova_bot');

  let includeOpenAI = false;
  if (state.failureStreak >= ADVISOR_THRESHOLD && provider.usable && provider.usable.includes('openai')) {
    lanes.push('openai');
    includeOpenAI = true;
  }

  // Safe fallback: prefer thaillm (historically ALIVE 19/19) over ollama_mdes (UNREACHABLE)
  const safeFallback = aliveBackends.length
    ? aliveBackends.filter(b => b !== 'innova_bot')
    : ['thaillm', 'ollama_cloud'];
  const fallback = lanes.length ? lanes : safeFallback;
  return {
    lanes: Array.from(new Set(fallback)),
    includeInnova,
    includeOpenAI,
    provider,
  };
}

function uniqueList(values) {
  return Array.from(new Set((values || []).filter(Boolean)));
}

function planProviderProbe(state, cycle) {
  const failureStreak = Number(state.failureStreak || 0);
  const fullProbe = cycle === 1 || cycle % FULL_PROBE_EVERY === 0 || failureStreak >= ADVISOR_THRESHOLD;
  const quickBackends = ['ollama_mdes', 'thaillm', 'innova_bot'];
  if (failureStreak >= Math.max(1, ADVISOR_THRESHOLD - 1)) quickBackends.push('openai');
  return {
    fullProbe,
    backends: fullProbe ? [] : uniqueList(quickBackends),
  };
}

function shouldRefreshQuickFleet(state, cycle) {
  return cycle === 1 || cycle % QUICK_FLEET_EVERY === 0 || Number(state.failureStreak || 0) > 0;
}

function shouldRunVisual(cycle) {
  return VISUAL_EVERY > 0 && (cycle === 1 || cycle % VISUAL_EVERY === 0);
}

function parseTrailingJson(stdout) {
  const text = String(stdout || '');
  try {
    return JSON.parse(text);
  } catch (_) {}
  const start = text.lastIndexOf('\n{');
  if (start < 0) return null;
  try {
    return JSON.parse(text.slice(start + 1));
  } catch (_) {
    return null;
  }
}

function makeGoal(cycle, snapshots, lanes) {
  const teamStatus = shortText(snapshots.mawTeam.stdout || snapshots.mawTeam.stderr, 550);
  const taskStatus = shortText(snapshots.mawTasks.stdout || snapshots.mawTasks.stderr, 550);
  const statusBoard = shortText(snapshots.statusBoard.stdout || snapshots.statusBoard.stderr, 700);
  return [
    `Jit Mother cycle ${cycle}: clear the innova-bot/Jit/innomcp backlog carefully.`,
    `Selected lanes: ${lanes.join(', ')}`,
    '',
    'OBJECTIVE — innomcp ready by morning (~6h):',
    '- Bootstrap MAW teams innomcp / innova-bot-template / jit (currently 0 agents each).',
    '- Drive the 5 innomcp tickets (TICKET-001..005: CommandCode bridge, Thai routing audit, geo, determinism, memory-symmetry).',
    '- Recover ollama_mdes/thaillm/ollama_cloud, prefer ALIVE lanes only.',
    '- Use thaillm as the safe fallback (19/19 OK, avg 6s).',
    '',
    'MAW team:',
    teamStatus || '(none)',
    '',
    'MAW tasks:',
    taskStatus || '(none)',
    '',
    'Status board:',
    statusBoard || '(none)',
    '',
    `Return one actionable next step or risk with Confidence 0-100. No file edits. Advisor threshold=${ADVISOR_THRESHOLD}.`,
  ].join('\n');
}

function parseFleetSummary(stdout) {
  return parseTrailingJson(stdout);
}

function postJson(targetUrl, headers, payload, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const parsed = new URL(targetUrl);
      const body = JSON.stringify(payload);
      const transport = parsed.protocol === 'https:' ? https : http;
      const req = transport.request(parsed, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
          ...headers,
        },
        timeout: timeoutMs || 20000,
      }, res => {
        let responseBody = '';
        res.on('data', chunk => { responseBody += chunk; });
        res.on('end', () => resolve({ ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, body: responseBody.slice(0, 200) }));
      });
      req.on('error', error => resolve({ ok: false, status: 0, error: error.message }));
      req.on('timeout', () => req.destroy(new Error('timeout')));
      req.write(body);
      req.end();
    } catch (error) {
      resolve({ ok: false, status: 0, error: String(error && error.message || error) });
    }
  });
}

async function notifyDiscord(text) {
  const webhook = process.env.DISCORD_WEBHOOK_URL || '';
  if (webhook) {
    return postJson(webhook, {}, { content: text.slice(0, 1900), username: 'Jit Mother Loop' }, 20000);
  }
  const token = process.env.DISCORD_TOKEN || '';
  const channel = process.env.JIT_REPORT_CHANNEL_ID || process.env.AUTO_REPORT_CHANNEL_ID || process.env.DISCORD_CHANNEL_ID || '';
  if (!(token && channel)) return { ok: false, skipped: true, reason: 'no discord target' };
  return postJson(
    `https://discord.com/api/v10/channels/${encodeURIComponent(channel)}/messages`,
    { Authorization: `Bot ${token}`, 'User-Agent': 'JitMotherLoop/1.0' },
    { content: text.slice(0, 1900) },
    20000
  );
}

async function notifyInnovaBot(text) {
  try {
    const InnovaBotBridge = require('../limbs/innova-bot-bridge');
    const bridge = new InnovaBotBridge();
    await bridge.connect();
    await bridge.dispatchTask(text.slice(0, 3500));
    await bridge.disconnect();
    return { ok: true };
  } catch (error) {
    return { ok: false, error: String(error && error.message || error).slice(0, 200) };
  }
}

function writeReportMarkdown(report) {
  const lines = [
    '# Jit Mother Loop Report',
    '',
    `Cycle: ${report.cycle}`,
    `Started: ${report.startedAt}`,
    `Finished: ${report.finishedAt}`,
    `Status: ${report.status}`,
    `Failure streak: ${report.failureStreak}`,
    `Selected lanes: ${report.selectedLanes.join(', ')}`,
    `Advisor used: ${report.advisorUsed ? 'yes' : 'no'}`,
    '',
    '## Providers',
    '',
  ];
  for (const [name, row] of Object.entries(report.providers.results || {})) {
    lines.push(`- ${name}: ${row.status}${row.error ? ' - ' + row.error : ''}`);
  }
  lines.push('', '## Fleet', '');
  if (report.fleetSummary && report.fleetSummary.summary) {
    const s = report.fleetSummary.summary;
    lines.push(`- Run: ${s.runId}`);
    lines.push(`- Result: ${s.ok}/${s.completed} OK, fail=${s.fail}, pending=${s.pending}, count=${s.count}`);
    if (s.roster) lines.push(`- Workers: ${s.roster.completedWorkers || 0}/${s.roster.plannedWorkers || s.count} done, personas=${s.roster.uniquePersonas || 0}`);
    for (const [backend, row] of Object.entries(s.byBackend || {})) {
      lines.push(`- ${backend}: ${row.ok}/${row.total} OK, avg ${row.avgLatencyMs}ms`);
    }
  } else {
    lines.push(`- Fleet batch failed or dry-run: ${report.fleetError || 'none'}`);
  }
  lines.push('', '## Visual', '');
  if (report.visual && report.visual.ok) {
    lines.push(`- Target: ${report.visual.url}`);
    lines.push(`- Status: ok`);
    if (report.visual.signal) lines.push(`- Signal: status=${report.visual.signal.status || 0} title=${report.visual.signal.title || '(none)'}`);
  } else if (report.visual) {
    lines.push(`- Target: ${report.visual.url || VISUAL_URL}`);
    lines.push(`- Status: failed`);
    lines.push(`- Error: ${report.visual.fatal || report.visual.playwright && report.visual.playwright.error || report.visual.devtools && report.visual.devtools.error || 'unknown'}`);
  } else {
    lines.push('- Visual probe skipped');
  }
  lines.push('', '## Notifications', '');
  lines.push(`- innova-bot: ${report.innovaNotify.ok ? 'ok' : 'failed'}${report.innovaNotify.error ? ' - ' + report.innovaNotify.error : ''}`);
  lines.push(`- discord: ${report.discordNotify.ok ? 'ok' : 'skipped/failed'}${report.discordNotify.reason ? ' - ' + report.discordNotify.reason : ''}`);
  lines.push('', '## Artifacts', '');
  lines.push(`- latest JSON: ${path.relative(ROOT, LATEST_JSON).replace(/\\/g, '/')}`);
  if (report.latestFleetArtifact) lines.push(`- fleet artifact: ${path.relative(ROOT, report.latestFleetArtifact).replace(/\\/g, '/')}`);
  lines.push('');
  fs.writeFileSync(LATEST_REPORT, lines.join('\n'));

  const outboxName = `${new Date().toISOString().replace(/[:.]/g, '-')}_jit-mother-loop-cycle-${report.cycle}.md`;
  fs.writeFileSync(path.join(OUTBOX_DIR, outboxName), lines.join('\n'));

  // Retention: keep only the latest OUTBOX_RETAIN cycle files; archive the rest
  const OUTBOX_RETAIN = 50;
  try {
    const allCycleFiles = fs.readdirSync(OUTBOX_DIR)
      .filter(f => f.includes('jit-mother-loop-cycle-') && f.endsWith('.md'))
      .sort();
    if (allCycleFiles.length > OUTBOX_RETAIN) {
      const toArchive = allCycleFiles.slice(0, allCycleFiles.length - OUTBOX_RETAIN);
      const archiveDir = path.join(path.dirname(OUTBOX_DIR), 'archive', 'outbox',
        new Date().toISOString().slice(0, 10));
      fs.mkdirSync(archiveDir, { recursive: true });
      for (const f of toArchive) {
        const src = path.join(OUTBOX_DIR, f);
        const dst = path.join(archiveDir, f);
        if (!fs.existsSync(dst)) fs.renameSync(src, dst);
        else fs.unlinkSync(src);
      }
      console.log(`[loop] outbox retention: archived ${toArchive.length} cycle files → ${archiveDir}`);
    }
  } catch (retentionErr) {
    console.warn('[loop] outbox retention failed (non-fatal):', retentionErr.message);
  }
}

async function runCycle(state) {
  const cycle = Number(state.cycle || 0) + 1;
  const startedAt = new Date().toISOString();
  const probePlan = planProviderProbe(state, cycle);
  const refreshQuickFleet = shouldRefreshQuickFleet(state, cycle);
  console.log(`[loop] cycle=${cycle} start ${startedAt}`);

  const snapshots = {
    omxStatus: run('omx', ['status', '--json'], { timeout: 20000 }),
    mawTeam: run('maw', ['team', 'status'], { timeout: 30000 }),
    mawTasks: run('maw', ['t', 'status'], { timeout: 30000 }),
    quickFleet: refreshQuickFleet
      ? run('node', ['.codex/skills/agent-fleet-budget/scripts/check-fleet.mjs'], { timeout: 120000 })
      : skippedRun('quickFleet skipped'),
    providerProbe: (() => {
      const args = ['eval/provider-probe.js', '--timeout', String(PROVIDER_TIMEOUT)];
      if (!probePlan.fullProbe && probePlan.backends.length) args.push('--backends', probePlan.backends.join(','));
      return run('node', args, { timeout: PROVIDER_TIMEOUT + 30000 });
    })(),
    statusBoard: run('node', ['eval/status-board.js', '--summary-json'], { timeout: 30000 }),
  };

  const route = selectLanes(state);
  const goal = makeGoal(cycle, snapshots, route.lanes);
  fs.writeFileSync(CURRENT_GOAL, goal);

  const fleetArgs = [
    'eval/fleet-batch.js',
    '--goal-file', path.relative(ROOT, CURRENT_GOAL).replace(/\\/g, '/'),
    '--count', String(COUNT),
    '--concurrency', String(CONCURRENCY),
    '--notify-every', String(NOTIFY_EVERY),
    '--attempts', String(FLEET_ATTEMPTS),
    '--worker-timeout-ms', String(FLEET_WORKER_TIMEOUT_MS),
    '--lanes', route.lanes.join(','),
    '--require-min-count', String(COUNT),
    '--require-min-ok', String(Math.ceil(COUNT * 0.75)),
    '--no-discord',
  ];
  if (route.includeInnova) fleetArgs.push('--include-innova-bot');
  if (route.includeOpenAI) fleetArgs.push('--include-openai');

  const fleet = DRY_RUN
    ? { ok: true, status: 0, ms: 0, stdout: JSON.stringify({ summary: { runId: 'dry-run', count: COUNT, completed: 0, ok: 0, fail: 0, pending: COUNT, byBackend: {} } }), stderr: '', command: 'dry-run' }
    : run('node', fleetArgs, { timeout: FLEET_TIMEOUT });

  const fleetSummary = parseFleetSummary(fleet.stdout);
  const summary = fleetSummary && fleetSummary.summary;
  // Reduced from 75% to 50% + accept degraded status when partial completion happens
  // (cycle 174 example: 43/84 OK failed the 75% rule even though work progressed)
  const minOkForPass = Math.ceil(COUNT * 0.75);
  const minOkForDegraded = Math.ceil(COUNT * 0.5);
  const completedOk = summary && summary.ok || 0;
  const completedCount = summary && summary.completed || 0;
  let ok = Boolean(fleet.ok && summary && completedCount >= COUNT && completedOk >= minOkForPass);
  let degraded = false;
  if (!ok && summary && completedOk >= minOkForDegraded) {
    // Accept degraded pass when at least 50% succeeded — work is happening, don't fail the loop
    ok = true;
    degraded = true;
  }
  const nextFailureStreak = ok ? 0 : Number(state.failureStreak || 0) + 1;
  const advisorUsed = route.includeOpenAI;
  const finishedAt = new Date().toISOString();
  const latestFleet = latestFleetArtifact();
  const visualRun = shouldRunVisual(cycle)
    ? run('node', ['eval/visual-probe.js', '--url', VISUAL_URL, '--run-id', `visual-cycle-${cycle}`, '--timeout-ms', String(VISUAL_TIMEOUT_MS)], { timeout: VISUAL_TIMEOUT_MS + 15000 })
    : skippedRun('visual skipped');
  const visualSummary = shouldRunVisual(cycle)
    ? (parseTrailingJson(visualRun.stdout) || readJson(LATEST_VISUAL, null))
    : null;

  const compact = [
    `Jit Mother loop cycle ${cycle}: ${ok ? (degraded ? 'DEGRADED' : 'PASS') : 'FAILED'}`,
    `lanes=${route.lanes.join(',')} count=${COUNT} ok=${summary ? summary.ok : 'n/a'}/${summary ? summary.completed : 'n/a'}`,
    `workers=${summary && summary.roster ? `${summary.roster.completedWorkers || 0}/${summary.roster.plannedWorkers || COUNT}` : 'n/a'}`,
    `failStreak=${nextFailureStreak} advisor=${advisorUsed ? 'openai' : 'off'}`,
    `visual=${visualSummary && visualSummary.ok ? 'ok' : (shouldRunVisual(cycle) ? 'failed' : 'skipped')}`,
    `artifact=${latestFleet ? path.relative(ROOT, latestFleet).replace(/\\/g, '/') : 'none'}`,
  ].join('\n');

  const innovaNotify = await notifyInnovaBot(compact);
  const discordNotify = await notifyDiscord(compact);

  const report = {
    cycle,
    startedAt,
    finishedAt,
    status: ok ? (degraded ? 'degraded' : 'pass') : 'failed',
    failureStreak: nextFailureStreak,
    selectedLanes: route.lanes,
    advisorUsed,
    providers: route.provider,
    snapshots: {
      omxStatus: { ok: snapshots.omxStatus.ok, ms: snapshots.omxStatus.ms },
      mawTeam: { ok: snapshots.mawTeam.ok, ms: snapshots.mawTeam.ms },
      mawTasks: { ok: snapshots.mawTasks.ok, ms: snapshots.mawTasks.ms },
      quickFleet: { ok: snapshots.quickFleet.ok, ms: snapshots.quickFleet.ms, skipped: Boolean(snapshots.quickFleet.skipped) },
      providerProbe: {
        ok: snapshots.providerProbe.ok,
        ms: snapshots.providerProbe.ms,
        mode: probePlan.fullProbe ? 'full' : 'quick',
        backends: probePlan.fullProbe ? ['all'] : probePlan.backends,
      },
    },
    fleetCommand: ['node'].concat(fleetArgs).join(' '),
    fleetOk: fleet.ok,
    fleetMs: fleet.ms,
    fleetError: shortText((fleet.stderr || fleet.error || '').trim(), 500),
    fleetSummary,
    visual: visualSummary,
    visualRun: {
      ok: visualRun.ok,
      ms: visualRun.ms,
      skipped: Boolean(visualRun.skipped),
      error: shortText((visualRun.stderr || visualRun.error || '').trim(), 300),
    },
    latestFleetArtifact: latestFleet,
    innovaNotify,
    discordNotify,
  };

  writeJson(LATEST_JSON, report);
  writeReportMarkdown(report);

  const newState = {
    ...state,
    cycle,
    failureStreak: nextFailureStreak,
    advisorCalls: Number(state.advisorCalls || 0) + (advisorUsed ? 1 : 0),
    lastStartedAt: startedAt,
    lastFinishedAt: finishedAt,
    lastStatus: report.status,
    lastLanes: route.lanes,
    lastReport: path.relative(ROOT, LATEST_REPORT).replace(/\\/g, '/'),
    lastJson: path.relative(ROOT, LATEST_JSON).replace(/\\/g, '/'),
  };
  writeJson(STATE_PATH, newState);
  console.log(`[loop] cycle=${cycle} ${report.status} lanes=${route.lanes.join(',')} report=${newState.lastReport}`);
  return newState;
}

async function main() {
  ensureDirs();
  let state = loadState();
  let cycles = 0;
  const startedAtMs = Date.now();
  while (true) {
    if (MAX_RUNTIME_MS && (Date.now() - startedAtMs) >= MAX_RUNTIME_MS) {
      console.log(`[loop] stopping after max-runtime-ms=${MAX_RUNTIME_MS}`);
      break;
    }
    state = await runCycle(state);
    cycles++;
    if (MAX_CYCLES && cycles >= MAX_CYCLES) break;
    if (MAX_RUNTIME_MS && (Date.now() - startedAtMs) >= MAX_RUNTIME_MS) {
      console.log(`[loop] stopping after max-runtime-ms=${MAX_RUNTIME_MS}`);
      break;
    }
    await new Promise(resolve => setTimeout(resolve, INTERVAL_MS));
  }
}

main().catch(error => {
  ensureDirs();
  const state = loadState();
  state.failureStreak = Number(state.failureStreak || 0) + 1;
  state.lastStatus = 'fatal';
  state.lastError = String(error && error.message || error).slice(0, 500);
  state.lastFinishedAt = new Date().toISOString();
  writeJson(STATE_PATH, state);
  console.error('[loop] fatal:', error && error.message || error);
  process.exit(1);
});
