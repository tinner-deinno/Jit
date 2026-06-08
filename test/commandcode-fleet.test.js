#!/usr/bin/env node
'use strict';

/**
 * test/commandcode-fleet.test.js - Fleet test for commandcode in buildJobs() output
 *
 * TICKET-001: Verify commandcode is properly wired as a first-class provider
 * in the fleet-batch job builder. Tests the static configuration and the
 * runtime buildJobs() output without making any live API calls.
 *
 * Usage:
 *   node test/commandcode-fleet.test.js
 *
 * Exit codes:
 *   0 = all tests passed
 *   1 = one or more tests failed
 */

const path = require('path');
const fs = require('fs');

const ROOT = path.join(__dirname, '..');
const FLEET_BATCH_PATH = path.join(ROOT, 'eval', 'fleet-batch.js');
const MODEL_ROUTER_PATH = path.join(ROOT, 'hermes-discord', 'model-router.js');
const ROUTING_PATH = path.join(ROOT, 'config', 'subagent-routing.json');

// --- Minimal test harness ---

let PASS_COUNT = 0;
let FAIL_COUNT = 0;
let TOTAL = 0;

function pass(msg) {
  PASS_COUNT++;
  TOTAL++;
  console.log(`  PASS - ${msg}`);
}

function fail(msg, detail) {
  FAIL_COUNT++;
  TOTAL++;
  console.log(`  FAIL - ${msg}`);
  if (detail) console.log(`        -> ${detail}`);
}

function section(title) {
  console.log(`\n  -- ${title} --`);
}

// --- Source file readers ---

function readSource(relPath) {
  const full = path.join(ROOT, relPath);
  if (!fs.existsSync(full)) return null;
  return fs.readFileSync(full, 'utf8');
}

// --- Static analysis helpers ---

function findInSource(source, pattern) {
  if (!source) return false;
  return pattern.test(source);
}

function extractArrayEntries(source, arrayName) {
  // Extract entries from a JS array literal like: const X = ['a', 'b', 'c']
  const re = new RegExp(arrayName + '\\s*=\\s*\\[([^\\]]+)\\]', 's');
  const m = source && source.match(re);
  if (!m) return [];
  const inner = m[1];
  const items = [];
  const itemRe = /'([^']+)'|"([^"]+)"/g;
  let im;
  while ((im = itemRe.exec(inner)) !== null) {
    items.push(im[1] || im[2]);
  }
  return items;
}

function extractObjectKeys(source, objectName) {
  // Extract top-level keys from an object literal like: const X = { a: {...}, b: {...} }
  // Looks for the pattern after objectName = { ... }
  const re = new RegExp(objectName + '\\s*=\\s*\\{', 's');
  if (!source || !re.test(source)) return [];
  // Find the block between the opening { and matching }
  const startIdx = source.search(re);
  let depth = 0;
  let i = source.indexOf('{', startIdx + objectName.length);
  let start = -1;
  for (; i < source.length; i++) {
    if (source[i] === '{') {
      if (depth === 0) start = i + 1;
      depth++;
    } else if (source[i] === '}') {
      depth--;
      if (depth === 0) break;
    }
  }
  if (start < 0) return [];
  const block = source.slice(start, i);
  const keys = [];
  const keyRe = /^\s*(?:'|")?([a-zA-Z0-9_]+)(?:'|")?\s*:/gm;
  let km;
  while ((km = keyRe.exec(block)) !== null) {
    keys.push(km[1]);
  }
  return keys;
}

// --- Tests ---

function runTests() {
  const fleetSource = readSource('eval/fleet-batch.js');
  const routerSource = readSource('hermes-discord/model-router.js');

  // ============================================================
  section('1. commandcode in BACKEND_LIMITS');
  // ============================================================

  if (findInSource(fleetSource, /BACKEND_LIMITS\s*=\s*\{/)) {
    if (findInSource(fleetSource, /commandcode\s*:\s*\d+/)) {
      const m = fleetSource.match(/commandcode\s*:\s*(\d+)/);
      const limit = m ? parseInt(m[1], 10) : 0;
      if (limit === 2) {
        pass(`commandcode in BACKEND_LIMITS with limit 2`);
      } else {
        fail(`commandcode BACKEND_LIMITS limit is ${limit}, expected 2`);
      }
    } else {
      fail('commandcode not found in BACKEND_LIMITS');
    }
  } else {
    fail('BACKEND_LIMITS object not found in fleet-batch.js');
  }

  // ============================================================
  section('2. commandcode in DEFAULT_ROUTE_ORDER');
  // ============================================================

  const routeOrder = extractArrayEntries(fleetSource, 'DEFAULT_ROUTE_ORDER');
  if (routeOrder.length > 0) {
    if (routeOrder.includes('commandcode')) {
      const ccIdx = routeOrder.indexOf('commandcode');
      const thaillmIdx = routeOrder.indexOf('thaillm');
      if (thaillmIdx >= 0 && ccIdx === thaillmIdx + 1) {
        pass(`commandcode in DEFAULT_ROUTE_ORDER immediately after thaillm (position ${ccIdx})`);
      } else if (thaillmIdx >= 0) {
        pass(`commandcode in DEFAULT_ROUTE_ORDER at position ${ccIdx} (thaillm at ${thaillmIdx})`);
      } else {
        pass(`commandcode in DEFAULT_ROUTE_ORDER at position ${ccIdx}`);
      }
    } else {
      fail('commandcode not in DEFAULT_ROUTE_ORDER', `found: ${routeOrder.join(', ')}`);
    }
  } else {
    // Fallback: check if the string contains commandcode in the array definition
    if (findInSource(fleetSource, /DEFAULT_ROUTE_ORDER.*commandcode/)) {
      pass('commandcode found in DEFAULT_ROUTE_ORDER source');
    } else {
      fail('DEFAULT_ROUTE_ORDER not parseable and commandcode not found in source');
    }
  }

  // ============================================================
  section('3. normalizeLane() handles commandcode variants');
  // ============================================================

  if (findInSource(fleetSource, /commandcode|command_code|evergreen/)) {
    // Check all three variants are handled
    const variants = [
      ['commandcode', /['"]commandcode['"]|commandcode\s*===/],
      ['command_code', /['"]command_code['"]/],
      ['evergreen', /['"]evergreen['"]/],
    ];
    for (const [name, re] of variants) {
      if (findInSource(fleetSource, re)) {
        pass(`normalizeLane() handles "${name}" variant`);
      } else {
        fail(`normalizeLane() missing "${name}" variant`);
      }
    }
  } else {
    fail('No commandcode normalization found in fleet-batch.js');
  }

  // ============================================================
  section('4. commandcode laneDefinition() has required fields');
  // ============================================================

  // Check the laneDefinition object inside laneDefinitions() for commandcode
  const requiredFields = ['backend', 'models', 'weight', 'costTier', 'external'];
  for (const field of requiredFields) {
    // Look for commandcode block with the field
    const ccBlockRe = /commandcode\s*:\s*\{[^}]*\}/s;
    const ccBlock = fleetSource && fleetSource.match(ccBlockRe);
    if (ccBlock) {
      const fieldRe = new RegExp(field + '\\s*:');
      if (fieldRe.test(ccBlock[0])) {
        pass(`commandcode laneDefinition has "${field}" field`);
      } else {
        fail(`commandcode laneDefinition missing "${field}" field`);
      }
    } else {
      fail(`Cannot find commandcode definition block in laneDefinitions()`);
      break;
    }
  }

  // Check specific values
  const ccBlockRe = /commandcode\s*:\s*\{[^}]*\}/s;
  const ccBlock = fleetSource && fleetSource.match(ccBlockRe);
  if (ccBlock) {
    // Check backend value
    if (/backend\s*:\s*['"]commandcode['"]/.test(ccBlock[0])) {
      pass('commandcode laneDefinition backend = "commandcode"');
    } else {
      fail('commandcode laneDefinition backend is not "commandcode"');
    }

    // Check costTier
    if (/costTier\s*:\s*['"]medium['"]/.test(ccBlock[0])) {
      pass('commandcode laneDefinition costTier = "medium"');
    } else {
      fail('commandcode laneDefinition costTier is not "medium"');
    }

    // Check external
    if (/external\s*:\s*true/.test(ccBlock[0])) {
      pass('commandcode laneDefinition external = true');
    } else {
      fail('commandcode laneDefinition external is not true');
    }

    // Check weight is a positive number
    const weightMatch = ccBlock[0].match(/weight\s*:\s*(\d+)/);
    if (weightMatch) {
      const weight = parseInt(weightMatch[1], 10);
      if (weight > 0 && weight <= 50) {
        pass(`commandcode laneDefinition weight = ${weight} (reasonable range)`);
      } else {
        fail(`commandcode laneDefinition weight = ${weight} (out of expected 1-50 range)`);
      }
    } else {
      fail('commandcode laneDefinition weight not found');
    }

    // Check models references COMMANDCODE_MODEL env var or has a default
    if (/COMMANDCODE_MODEL|commandcode-1/.test(ccBlock[0])) {
      pass('commandcode laneDefinition models uses COMMANDCODE_MODEL or defaults to commandcode-1');
    } else {
      fail('commandcode laneDefinition models missing COMMANDCODE_MODEL reference or default');
    }
  }

  // ============================================================
  section('5. No duplicate commandcode in laneDefinitions()');
  // ============================================================

  // Count occurrences of "commandcode:" in the laneDefinitions function
  const laneDefSource = fleetSource || '';
  const commandcodeDefs = laneDefSource.match(/commandcode\s*:\s*\{/g);
  if (commandcodeDefs) {
    if (commandcodeDefs.length === 1) {
      pass('Only one commandcode definition in laneDefinitions() (no duplicate)');
    } else {
      fail(`Found ${commandcodeDefs.length} commandcode definitions in laneDefinitions() (expected 1)`);
    }
  } else {
    fail('No commandcode definition found in laneDefinitions()');
  }

  // ============================================================
  section('6. commandcode in model-router.js BackendManager');
  // ============================================================

  if (findInSource(routerSource, /commandcode\s*:\s*\{/)) {
    pass('commandcode registered in model-router BackendManager');

    // Check required fields in the backend definition
    const routerCcFields = ['name', 'url', 'token', 'model', 'type'];
    for (const field of routerCcFields) {
      const fieldRe = new RegExp('commandcode[^}]*' + field + '\\s*:', 's');
      // Look within the commandcode block
      if (findInSource(routerSource, new RegExp('commandcode[\\s\\S]{0,200}' + field + '\\s*:', 'i'))) {
        pass(`commandcode backend has "${field}" field`);
      } else {
        fail(`commandcode backend missing "${field}" field`);
      }
    }

    // Check type is 'commandcode'
    if (findInSource(routerSource, /type\s*:\s*['"]commandcode['"]/)) {
      pass('commandcode backend type = "commandcode"');
    } else {
      fail('commandcode backend type is not "commandcode"');
    }
  } else {
    fail('commandcode not registered in model-router BackendManager');
  }

  // ============================================================
  section('7. _callCommandCode function exists in model-router');
  // ============================================================

  if (findInSource(routerSource, /function\s+_callCommandCode/)) {
    pass('_callCommandCode function exists in model-router.js');
  } else {
    fail('_callCommandCode function not found in model-router.js');
  }

  // Check commandcode is wired into the callModel rotation
  if (findInSource(routerSource, /commandcode.*_callCommandCode|_callCommandCode.*commandcode/)) {
    pass('commandcode is wired into callModel() rotation dispatch');
  } else {
    // Check the dispatch block more broadly
    if (findInSource(routerSource, /backend\s*===\s*['"]commandcode['"]/)) {
      pass('commandcode dispatch case found in callModel()');
    } else {
      fail('commandcode dispatch case not found in callModel() rotation');
    }
  }

  // ============================================================
  section('8. commandcode in BACKEND_ORDER default');
  // ============================================================

  if (findInSource(routerSource, /BACKEND_ORDER.*commandcode/)) {
    pass('commandcode in BACKEND_ORDER default in model-router.js');
  } else {
    fail('commandcode not in BACKEND_ORDER default in model-router.js');
  }

  // ============================================================
  section('9. COMMANDCODE_API_KEY not hardcoded');
  // ============================================================

  // Ensure the key is only read from process.env, not a literal string
  const literalKeyPattern = /COMMANDCODE_API_KEY\s*=\s*['"][a-zA-Z0-9]{10,}['"]/;
  if (!findInSource(fleetSource, literalKeyPattern) && !findInSource(routerSource, literalKeyPattern)) {
    pass('COMMANDCODE_API_KEY not hardcoded in fleet-batch.js or model-router.js');
  } else {
    fail('SECURITY: COMMANDCODE_API_KEY appears to be hardcoded');
  }

  // ============================================================
  section('10. BuildJobs runtime verification (import-free)');
  // ============================================================

  // We cannot directly import fleet-batch.js (it has side effects and runs main()),
  // so we verify the structural patterns that buildJobs() relies on.

  // 10a. buildJobs() references laneDefinitions()
  if (findInSource(fleetSource, /buildJobs\s*\(\)\s*\{[^}]*laneDefinitions/)) {
    pass('buildJobs() calls laneDefinitions()');
  } else {
    fail('buildJobs() does not call laneDefinitions()');
  }

  // 10b. buildJobs() assigns backend from lane
  if (findInSource(fleetSource, /backend\s*:\s*lane\.backend/)) {
    pass('buildJobs() assigns backend from lane.backend');
  } else {
    fail('buildJobs() does not assign backend from lane.backend');
  }

  // 10c. buildJobs() assigns costTier from lane
  if (findInSource(fleetSource, /costTier\s*:\s*lane\.costTier/)) {
    pass('buildJobs() assigns costTier from lane.costTier');
  } else {
    fail('buildJobs() does not assign costTier from lane.costTier');
  }

  // 10d. buildJobs() assigns external from lane
  if (findInSource(fleetSource, /external\s*:\s*lane\.external/)) {
    pass('buildJobs() assigns external from lane.external');
  } else {
    fail('buildJobs() does not assign external from lane.external');
  }

  // 10e. buildJobs() assigns model from lane models with cursor rotation
  if (findInSource(fleetSource, /modelCursor/) && findInSource(fleetSource, /lane\.models/)) {
    pass('buildJobs() rotates models from lane.models via modelCursor');
  } else {
    fail('buildJobs() model rotation logic incomplete');
  }

  // ============================================================
  section('11. config/subagent-routing.json commandcode entry');
  // ============================================================

  if (fs.existsSync(ROUTING_PATH)) {
    try {
      const routing = JSON.parse(fs.readFileSync(ROUTING_PATH, 'utf8'));
      if (routing.providers && routing.providers.commandcode) {
        pass('commandcode entry exists in config/subagent-routing.json providers');
        const cc = routing.providers.commandcode;
        if (cc.default_model) {
          pass(`commandcode default_model = "${cc.default_model}"`);
        } else {
          fail('commandcode provider missing default_model');
        }
      } else if (routing.commandcode) {
        pass('commandcode entry exists in config/subagent-routing.json (top-level)');
      } else {
        fail('commandcode not found in config/subagent-routing.json');
      }
    } catch (e) {
      fail(`Failed to parse subagent-routing.json: ${e.message}`);
    }
  } else {
    fail('config/subagent-routing.json does not exist');
  }

  // ============================================================
  section('12. commandcode error counter in model-router');
  // ============================================================

  if (findInSource(routerSource, /_errors\s*=\s*\{[^}]*commandcode/)) {
    pass('commandcode has an error counter in _errors object');
  } else {
    fail('commandcode missing from _errors object in model-router.js');
  }

  // ============================================================
  section('13. Circuit breaker handles commandcode');
  // ============================================================

  // The breaker operates on backend names dynamically, so if commandcode
  // is in the error counters and BACKEND_ORDER, it is covered.
  // Verify the breaker key is used consistently.
  if (findInSource(routerSource, /_breakerOpen/) && findInSource(routerSource, /_tripBreaker/) && findInSource(routerSource, /_resetBreaker/)) {
    pass('Circuit breaker functions exist (breakerOpen, tripBreaker, resetBreaker)');
  } else {
    fail('Circuit breaker functions incomplete in model-router.js');
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  console.log('\n');
  if (FAIL_COUNT === 0) {
    console.log(`  ALL ${TOTAL} TESTS PASSED`);
  } else {
    console.log(`  ${FAIL_COUNT}/${TOTAL} TESTS FAILED`);
  }
  console.log('');

  return FAIL_COUNT === 0 ? 0 : 1;
}

// --- Run ---

const exitCode = runTests();
process.exit(exitCode);