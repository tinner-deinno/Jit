#!/usr/bin/env node
/**
 * eval/export-events.js — Phase 38 CLI: export the Mother event log.
 *
 *   node eval/export-events.js          # write network/mother-events.{json,csv}
 *   node eval/export-events.js --print  # also print CSV to stdout
 */
const log = require('../limbs/event-log');

const res = log.exportAll();
console.log(`[export] ${res.count} event(s)`);
console.log(`[export] JSON -> ${res.json}`);
console.log(`[export] CSV  -> ${res.csv}`);
if (process.argv.includes('--print')) {
  console.log('\n' + log.toCSV(log.readAll()));
}
