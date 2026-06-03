#!/usr/bin/env node
/**
 * eval/mother-phase-live.js — Prove the Mother loop runs end-to-end on LIVE
 * providers and produces REAL (non-seeded) leaderboard scores.
 *
 * Runs ONE small real phase via MotherEngine.executePhase:
 *   selectSquad -> spawnAgentParallel (live provider) -> verifier squad ->
 *   updateLeaderboard (real verdicts) -> atomicCommit.
 *
 * Snapshots leaderboard correctness_score before/after and asserts a real delta.
 * Usage: node eval/mother-phase-live.js
 */
const fs = require('fs');
const path = require('path');
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const MotherEngine = require('../limbs/mother-engine');
const LB = path.join(__dirname, '..', 'network', 'leaderboard.json');

function snapshot() {
  const lb = JSON.parse(fs.readFileSync(LB, 'utf8'));
  const out = {};
  for (const [k, v] of Object.entries(lb.fleet || {})) {
    out[k] = { score: v.correctness_score, tasks: v.completed_tasks };
  }
  return out;
}

(async () => {
  const t0 = Date.now();
  const before = snapshot();
  const engine = new MotherEngine();
  if (!engine.liveProvider) {
    console.error('[live] ABORT: no live provider in provider-status.json — run eval/provider-probe.js first.');
    process.exit(2);
  }
  console.log(`[live] live provider = ${engine.liveProvider.backend} (model=${engine.liveProvider.model || 'default'})`);

  const phase = 'LiveProof';
  const goal = 'Summarize in ONE sentence what a multi-agent orchestration leaderboard is for.';

  let results;
  try {
    results = await engine.executePhase(phase, goal);
  } catch (e) {
    console.error(`[live] executePhase threw: ${e.message}`);
    process.exit(1);
  }

  const after = snapshot();

  // Report squad outputs (truncated) and score deltas.
  console.log(`\n[live] === PHASE RESULT (${Date.now() - t0}ms) ===`);
  if (Array.isArray(results)) {
    results.forEach(r => console.log(`  • ${r.agent} via ${r.backend}: "${String(r.reply || '').slice(0, 80).replace(/\s+/g, ' ')}"`));
  } else {
    console.log(`  results: ${JSON.stringify(results).slice(0, 200)}`);
  }

  console.log(`\n[live] === LEADERBOARD DELTA ===`);
  let changed = 0;
  for (const k of Object.keys(after)) {
    const b = before[k], a = after[k];
    if (!b) continue;
    if (b.score !== a.score || b.tasks !== a.tasks) {
      changed++;
      console.log(`  ${k}: score ${b.score?.toFixed?.(2) ?? b.score} -> ${a.score?.toFixed?.(2) ?? a.score} | tasks ${b.tasks} -> ${a.tasks}`);
    }
  }
  console.log(`\n[live] agents with REAL score movement: ${changed}`);
  console.log(`[live] VERDICT: ${changed > 0 ? 'PASS — loop produced real leaderboard updates' : 'FAIL — no score moved (verifier parse or dispatch issue)'}`);
  process.exit(changed > 0 ? 0 : 1);
})();
