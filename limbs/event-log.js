'use strict';
/**
 * limbs/event-log.js — Phase 38: Mother dispatch event log + JSON/CSV export.
 *
 * Append-only event log (aligns with "Nothing is Deleted"): every Mother phase
 * appends one JSON line to network/mother-events.jsonl. Exporters render the log
 * to JSON (full fidelity) and CSV (flat, spreadsheet-safe).
 *
 *   const log = require('./event-log');
 *   log.record({ phase, goal, provider, squad, verdicts, durationMs, committed });
 *   log.exportAll();           // writes mother-events.json + mother-events.csv
 *   const csv = log.toCSV(log.readAll());
 */
const fs = require('fs');
const path = require('path');

const NETWORK_DIR = path.join(__dirname, '..', 'network');
const JSONL_PATH = path.join(NETWORK_DIR, 'mother-events.jsonl');
const JSON_OUT = path.join(NETWORK_DIR, 'mother-events.json');
const CSV_OUT = path.join(NETWORK_DIR, 'mother-events.csv');

// Flat CSV columns. Nested detail stays in the JSON export.
const CSV_COLUMNS = ['ts', 'phase', 'goal', 'provider', 'squad', 'squad_size', 'avg_score', 'min_score', 'max_score', 'committed', 'duration_ms'];

/**
 * record(event) — append one event as a JSON line. `ts` is auto-stamped if absent.
 * Never throws into the caller's hot path; logs and swallows write errors.
 */
function record(event) {
  try {
    const ev = Object.assign({ ts: new Date().toISOString() }, event);
    fs.mkdirSync(NETWORK_DIR, { recursive: true });
    fs.appendFileSync(JSONL_PATH, JSON.stringify(ev) + '\n');
    return ev;
  } catch (e) {
    console.warn('[event-log] record failed: ' + e.message);
    return null;
  }
}

/** readAll() — parse the JSONL log into an array. Skips malformed lines. */
function readAll() {
  if (!fs.existsSync(JSONL_PATH)) return [];
  const out = [];
  for (const line of fs.readFileSync(JSONL_PATH, 'utf8').split(/\r?\n/)) {
    if (!line.trim()) continue;
    try { out.push(JSON.parse(line)); } catch (_) { /* skip corrupt line */ }
  }
  return out;
}

/**
 * Escape a single CSV field per RFC 4180, with a formula-injection guard:
 * a leading = + - @ (or tab/CR) is neutralized with a leading apostrophe so
 * spreadsheets don't execute it as a formula.
 */
function escapeCSVField(value) {
  let s = (value === null || value === undefined) ? '' : String(value);
  // Formula-injection guard (CSV injection / "Excel macro" attacks).
  // Use \s* so a leading-whitespace bypass (" =1+1", "\t=1") is also caught —
  // spreadsheets trim leading whitespace before evaluating the formula.
  if (/^\s*[=+\-@]/.test(s)) s = "'" + s;
  // RFC 4180: quote if it contains comma, double-quote, CR or LF; double quotes.
  if (/[",\r\n]/.test(s)) s = '"' + s.replace(/"/g, '""') + '"';
  return s;
}

/** Flatten one event to the scalar CSV column shape. */
function _flatten(ev) {
  const verdicts = Array.isArray(ev.verdicts) ? ev.verdicts.map(Number).filter(n => !isNaN(n)) : [];
  const avg = verdicts.length ? (verdicts.reduce((a, b) => a + b, 0) / verdicts.length) : '';
  return {
    ts: ev.ts || '',
    phase: ev.phase || '',
    goal: ev.goal || '',
    provider: ev.provider || '',
    squad: Array.isArray(ev.squad) ? ev.squad.join(';') : (ev.squad || ''),
    squad_size: Array.isArray(ev.squad) ? ev.squad.length : '',
    avg_score: avg === '' ? '' : avg.toFixed(2),
    min_score: verdicts.length ? Math.min(...verdicts) : '',
    max_score: verdicts.length ? Math.max(...verdicts) : '',
    committed: ev.committed === undefined ? '' : !!ev.committed,
    duration_ms: ev.durationMs === undefined ? (ev.duration_ms ?? '') : ev.durationMs,
  };
}

/** toCSV(rows) — render events to an RFC-4180 CSV string (header + rows). */
function toCSV(rows) {
  const lines = [CSV_COLUMNS.join(',')];
  for (const ev of rows) {
    const flat = _flatten(ev);
    lines.push(CSV_COLUMNS.map(col => escapeCSVField(flat[col])).join(','));
  }
  return lines.join('\r\n') + '\r\n'; // CRLF per RFC 4180
}

/** toJSON(rows) — pretty JSON array (full fidelity). */
function toJSON(rows) {
  return JSON.stringify(rows, null, 2);
}

/** exportAll() — write both JSON and CSV from the current log. Returns paths+count. */
function exportAll() {
  const rows = readAll();
  fs.writeFileSync(JSON_OUT, toJSON(rows));
  fs.writeFileSync(CSV_OUT, toCSV(rows));
  return { count: rows.length, json: JSON_OUT, csv: CSV_OUT };
}

module.exports = {
  record, readAll, toCSV, toJSON, exportAll, escapeCSVField,
  JSONL_PATH, JSON_OUT, CSV_OUT, CSV_COLUMNS,
};
