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

module.exports = { persist, hydrate, count, DB_PATH, COLS };
