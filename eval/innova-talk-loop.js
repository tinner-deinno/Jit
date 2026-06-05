#!/usr/bin/env node
'use strict';

/**
 * Lightweight innova-bot heartbeat loop.
 *
 * The heavy Mother controller owns provider probes and >50-agent fleet batches.
 * This loop only reports the latest fleet state to innova-bot at a short cadence
 * so coordination stays alive even while a fleet batch takes longer than the
 * heartbeat interval.
 */

const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const LOOP_DIR = path.join(ROOT, 'network', 'loop');
const STATE_PATH = path.join(LOOP_DIR, 'innova-talk-loop-state.json');
const LATEST_JSON = path.join(LOOP_DIR, 'latest-report.json');
const LATEST_MD = path.join(LOOP_DIR, 'latest-report.md');
const PROVIDER_STATUS = path.join(ROOT, 'network', 'provider-status.json');
const INNOMCP_ROOT = process.env.INNOMCP_ROOT || 'C:\\Users\\USER-NT\\DEV\\innomcp';

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

function has(name) {
  return process.argv.includes(name);
}

function intArg(name, fallback, min, max) {
  const n = Math.floor(Number(arg(name, fallback)));
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

const INTERVAL_MS = intArg('--interval-ms', 240000, 30000, 3600000);
const MAX_CYCLES = intArg('--max-cycles', has('--once') ? 1 : 0, 0, 1000000);

function ensureDirs() {
  fs.mkdirSync(LOOP_DIR, { recursive: true });
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

function shortText(text, limit) {
  return String(text || '').replace(/\s+/g, ' ').trim().slice(0, limit);
}

function run(command, args, options = {}) {
  const r = childProcess.spawnSync(command, args, {
    cwd: options.cwd || ROOT,
    encoding: 'utf8',
    timeout: options.timeout || 15000,
  });
  return {
    ok: r.status === 0,
    status: r.status,
    stdout: String(r.stdout || '').trim(),
    stderr: String(r.stderr || '').trim(),
    error: r.error ? r.error.message : '',
  };
}

function latestFleetLine(report) {
  const summary = report && report.fleetSummary && report.fleetSummary.summary;
  if (!summary) return 'fleet=no-summary';
  return `fleet=${summary.ok}/${summary.completed} ok fail=${summary.fail} run=${summary.runId || 'unknown'}`;
}

function providerLine(provider) {
  const results = provider && provider.results ? provider.results : {};
  const usable = Array.isArray(provider.usable) ? provider.usable : [];
  const degraded = Object.entries(results)
    .filter(([, row]) => row && row.status && row.status !== 'ALIVE')
    .slice(0, 4)
    .map(([name, row]) => `${name}:${row.status}`);
  return [
    `usable=${usable.length ? usable.join(',') : 'none'}`,
    degraded.length ? `degraded=${degraded.join(',')}` : 'degraded=none',
  ].join(' ');
}

function innomcpLine() {
  if (!fs.existsSync(INNOMCP_ROOT)) return 'innomcp=missing';
  const status = run('git', ['status', '--short', '--branch'], { cwd: INNOMCP_ROOT, timeout: 10000 });
  const head = run('git', ['log', '--oneline', '-1'], { cwd: INNOMCP_ROOT, timeout: 10000 });
  const clean = status.ok && status.stdout.split(/\r?\n/).filter(line => line && !line.startsWith('##')).length === 0;
  return `innomcp=${clean ? 'clean' : 'dirty'} head=${shortText(head.stdout, 80)}`;
}

async function talk(message) {
  const InnovaBotBridge = require('../limbs/innova-bot-bridge');
  const bridge = new InnovaBotBridge();
  await bridge.connect();
  try {
    return await bridge.dispatchTask(message.slice(0, 3500));
  } finally {
    if (bridge.disconnect) bridge.disconnect();
  }
}

async function runHeartbeat(state) {
  const tick = Number(state.tick || 0) + 1;
  const startedAt = new Date().toISOString();
  const report = readJson(LATEST_JSON, {});
  const provider = readJson(PROVIDER_STATUS, {});
  const latestMd = fs.existsSync(LATEST_MD) ? shortText(fs.readFileSync(LATEST_MD, 'utf8'), 700) : '';
  const message = [
    `Jit/Codex innova-bot heartbeat ${tick}`,
    `time=${startedAt}`,
    `motherCycle=${report.cycle || 'unknown'} status=${report.status || 'unknown'} failureStreak=${report.failureStreak ?? 'unknown'}`,
    `lanes=${Array.isArray(report.selectedLanes) ? report.selectedLanes.join(',') : 'unknown'} advisor=${report.advisorUsed ? 'used' : 'off'}`,
    latestFleetLine(report),
    providerLine(provider),
    innomcpLine(),
    'instruction=continue innomcp ticket clearing; report blockers only with exact evidence.',
    latestMd ? `latestReport=${latestMd}` : '',
  ].filter(Boolean).join('\n');

  const result = await talk(message);
  const finishedAt = new Date().toISOString();
  const nextState = {
    tick,
    intervalMs: INTERVAL_MS,
    lastStartedAt: startedAt,
    lastFinishedAt: finishedAt,
    lastOk: true,
    lastCycle: report.cycle || null,
    lastInnomcp: innomcpLine(),
    lastResponse: shortText(JSON.stringify(result), 500),
  };
  writeJson(STATE_PATH, nextState);
  console.log(`[talk-loop] tick=${tick} ok cycle=${nextState.lastCycle} intervalMs=${INTERVAL_MS}`);
  return nextState;
}

async function main() {
  ensureDirs();
  let state = readJson(STATE_PATH, {});
  let cycles = 0;
  while (true) {
    try {
      state = await runHeartbeat(state);
    } catch (error) {
      state = {
        ...state,
        tick: Number(state.tick || 0) + 1,
        intervalMs: INTERVAL_MS,
        lastFinishedAt: new Date().toISOString(),
        lastOk: false,
        lastError: String(error && error.message || error).slice(0, 500),
      };
      writeJson(STATE_PATH, state);
      console.error(`[talk-loop] tick=${state.tick} failed: ${state.lastError}`);
    }
    cycles++;
    if (MAX_CYCLES && cycles >= MAX_CYCLES) break;
    await new Promise(resolve => setTimeout(resolve, INTERVAL_MS));
  }
}

main().catch(error => {
  ensureDirs();
  writeJson(STATE_PATH, {
    fatalAt: new Date().toISOString(),
    error: String(error && error.message || error).slice(0, 500),
  });
  console.error('[talk-loop] fatal:', error && error.message || error);
  process.exit(1);
});
