'use strict';
/**
 * limbs/leaderboard-db.js — Phase 36.5: durable leaderboard persistence.
 *
 * Scores previously lived only in network/leaderboard.json (a working-tree file
 * that resets if reverted/overwritten). This adds a SQLite store
 * (network/leaderboard.db) as the durable source of truth, with the JSON kept
 * as a human-readable mirror.
 *
 *   const db = require('./leaderboard-db');
 *   db.persist(fleetObj);            // memory -> DB (upsert)
 *   const fleet = db.hydrate();      // DB -> memory ({} if empty)
 *
 * Uses Node's built-in node:sqlite (no external dependency). The experimental
 * warning it prints on first require is suppressed below.
 */
const path = require('path');

// Suppress only the node:sqlite ExperimentalWarning, nothing else.
const _origEmit = process.emitWarning;
process.emitWarning = function (w, ...rest) {
  if (String(w).includes('SQLite is an experimental')) return;
  return _origEmit.call(process, w, ...rest);
};
const { DatabaseSync } = require('node:sqlite');
process.emitWarning = _origEmit;

const DB_PATH = path.join(__dirname, '..', 'network', 'leaderboard.db');

const COLS = ['completed_tasks', 'correctness_score', 'success_rate', 'rank', 'provisional'];

/** Coerce to a finite number (rejects NaN/Infinity), else default. */
function _finite(x, d = 0) { const n = Number(x); return Number.isFinite(n) ? n : d; }

function _isBusyError(error) {
  return /database is locked|SQLITE_BUSY/i.test(String(error && error.message || error || ''));
}

function _open() {
  const db = new DatabaseSync(DB_PATH);
  // WAL + busy_timeout: tolerate concurrent writers instead of failing with
  // SQLITE_BUSY ("database is locked") under multi-process access.
  try { db.exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;'); } catch (_) { /* best-effort */ }
  db.exec(`CREATE TABLE IF NOT EXISTS fleet (
    name TEXT PRIMARY KEY,
    completed_tasks INTEGER DEFAULT 0,
    correctness_score REAL DEFAULT 0,
    success_rate REAL DEFAULT 0,
    rank INTEGER,
    provisional INTEGER DEFAULT 1,
    updated TEXT
  )`);
  // Provider reliability: learned from real dispatches so the engine can route
  // to lanes that actually succeed, not just ones a point-in-time probe liked.
  db.exec(`CREATE TABLE IF NOT EXISTS provider_stats (
    name TEXT PRIMARY KEY,
    calls INTEGER DEFAULT 0,
    successes INTEGER DEFAULT 0,
    total_latency_ms REAL DEFAULT 0,
    last_ok_ts TEXT,
    last_fail_ts TEXT,
    updated TEXT
  )`);
  return db;
}

/** persist(fleet) — upsert every agent row. fleet = { name: {fields...} }. */
function persist(fleet) {
  if (!fleet || typeof fleet !== 'object') return 0;
  const db = _open();
  try {
    const now = new Date().toISOString();
    const stmt = db.prepare(`INSERT INTO fleet (name, completed_tasks, correctness_score, success_rate, rank, provisional, updated)
      VALUES (@name, @completed_tasks, @correctness_score, @success_rate, @rank, @provisional, @updated)
      ON CONFLICT(name) DO UPDATE SET
        completed_tasks=excluded.completed_tasks,
        correctness_score=excluded.correctness_score,
        success_rate=excluded.success_rate,
        rank=excluded.rank,
        provisional=excluded.provisional,
        updated=excluded.updated`);
    let n = 0;
    // Single transaction: without it every stmt.run() auto-commits (one fsync
    // per agent), which is ~1600x slower at scale. Roll back on any error.
    db.exec('BEGIN');
    try {
      for (const [name, v] of Object.entries(fleet)) {
        stmt.run({
          name,
          completed_tasks: Math.trunc(_finite(v.completed_tasks)),
          correctness_score: _finite(v.correctness_score),
          success_rate: _finite(v.success_rate),
          rank: v.rank === undefined || v.rank === null || !Number.isFinite(Number(v.rank)) ? null : Math.trunc(Number(v.rank)),
          provisional: v.provisional ? 1 : 0,
          updated: now,
        });
        n++;
      }
      db.exec('COMMIT');
    } catch (e) {
      try { db.exec('ROLLBACK'); } catch (_) {}
      throw e;
    }
    return n;
  } finally {
    db.close();
  }
}

/** hydrate() — read all rows into a fleet object. Returns {} if empty/missing. */
function hydrate() {
  const db = _open();
  try {
    const rows = db.prepare('SELECT * FROM fleet').all();
    const fleet = {};
    for (const r of rows) {
      fleet[r.name] = {
        completed_tasks: r.completed_tasks,
        correctness_score: r.correctness_score,
        success_rate: r.success_rate,
        rank: r.rank,
        provisional: !!r.provisional,
      };
    }
    return fleet;
  } finally {
    db.close();
  }
}

/** count() — number of agents stored. */
function count() {
  const db = _open();
  try { return db.prepare('SELECT COUNT(*) AS c FROM fleet').get().c; }
  finally { db.close(); }
}

/**
 * recordProviderResult(name, ok, latencyMs) — accumulate one dispatch outcome
 * for a provider. Upserts into provider_stats.
 */
function recordProviderResult(name, ok, latencyMs) {
  if (!name) return;
  const db = _open();
  try {
    const now = new Date().toISOString();
    db.prepare(`INSERT INTO provider_stats (name, calls, successes, total_latency_ms, last_ok_ts, last_fail_ts, updated)
      VALUES (@name, 1, @s, @lat, @okts, @failts, @now)
      ON CONFLICT(name) DO UPDATE SET
        calls = calls + 1,
        successes = successes + @s,
        total_latency_ms = total_latency_ms + @lat,
        last_ok_ts = CASE WHEN @s = 1 THEN @now ELSE last_ok_ts END,
        last_fail_ts = CASE WHEN @s = 0 THEN @now ELSE last_fail_ts END,
        updated = @now`).run({
      name, s: ok ? 1 : 0, lat: _finite(latencyMs), okts: ok ? now : null, failts: ok ? null : now, now,
    });
    return true;
  } catch (error) {
    // Provider stats are advisory telemetry. If another process still holds the
    // SQLite write lock during a hot loop restart, do not fail the entire fleet
    // batch over metrics only.
    if (_isBusyError(error)) return false;
    throw error;
  } finally {
    db.close();
  }
}

/**
 * getProviderStats() — { name: {calls, successes, success_rate, avg_latency_ms} }.
 */
function getProviderStats() {
  const db = _open();
  try {
    const rows = db.prepare('SELECT * FROM provider_stats').all();
    const out = {};
    for (const r of rows) {
      out[r.name] = {
        calls: r.calls,
        successes: r.successes,
        success_rate: r.calls ? r.successes / r.calls : 0,
        avg_latency_ms: r.calls ? Math.round(r.total_latency_ms / r.calls) : 0,
        last_ok_ts: r.last_ok_ts,
        last_fail_ts: r.last_fail_ts,
      };
    }
    return out;
  } finally {
    db.close();
  }
}

module.exports = { persist, hydrate, count, recordProviderResult, getProviderStats, DB_PATH, COLS };
