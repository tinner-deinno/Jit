'use strict';
// harvest-mega.cjs — route MEGA-<ID>-dev.md deliverables to their destinations,
// stripping the 5-line cc-team header. Additive files only; tests/hooks validated
// separately. Prints a placement report. Does NOT commit.
const fs = require('fs');
const path = require('path');

const JIT = path.resolve(__dirname, '..');
const INNOMCP = 'C:/Users/USER-NT/DEV/innomcp';
const SRC = path.join(JIT, 'ψ', 'outbox', 'cc-team');

const ORGAN = { D01: 'jit', D02: 'soma', D03: 'innova', D04: 'lak', D05: 'neta', D06: 'vaja', D07: 'chamu', D08: 'rupa', D09: 'pada', D10: 'netra', D11: 'karn', D12: 'mue', D13: 'pran', D14: 'sayanprasathan' };

const MAP = {
  // Stream A — innomcp playwright specs + node unit tests
  A01: [INNOMCP, 'tests/e2e/tests/mega-auth.spec.ts'], A02: [INNOMCP, 'tests/e2e/tests/mega-chat.spec.ts'],
  A03: [INNOMCP, 'tests/e2e/tests/mega-modelselector.spec.ts'], A04: [INNOMCP, 'tests/e2e/tests/mega-leaderboard.spec.ts'],
  A05: [INNOMCP, 'tests/e2e/tests/mega-dashboard.spec.ts'], A06: [INNOMCP, 'tests/e2e/tests/mega-workspace.spec.ts'],
  A07: [INNOMCP, 'tests/e2e/tests/mega-memory.spec.ts'], A08: [INNOMCP, 'tests/e2e/tests/mega-providerhealth.spec.ts'],
  A09: [INNOMCP, 'tests/e2e/tests/mega-ws-reconnect.spec.ts'], A10: [INNOMCP, 'tests/e2e/tests/mega-guestbanner.spec.ts'],
  A11: [INNOMCP, 'tests/e2e/tests/mega-mobile.spec.ts'], A12: [INNOMCP, 'tests/e2e/tests/mega-theme.spec.ts'],
  A13: [INNOMCP, 'innomcp-node/tests/unit/mega-ratelimiter.test.ts'], A14: [INNOMCP, 'innomcp-node/tests/unit/mega-healthagg.test.ts'],
  // Stream B — innomcp release docs
  B01: [INNOMCP, 'docs/release/RELEASE-CHECKLIST.md'], B02: [INNOMCP, 'docs/release/DEPLOYMENT-RUNBOOK.md'],
  B03: [INNOMCP, 'docs/release/ROLLBACK-PLAN.md'], B04: [INNOMCP, 'scripts/smoke-test.sh'],
  B05: [INNOMCP, 'docs/release/ENV-MATRIX.md'], B06: [INNOMCP, 'docs/release/API-CONTRACT.md'],
  B07: [INNOMCP, 'docs/release/MONITORING.md'], B08: [INNOMCP, 'docs/release/KNOWN-ISSUES.md'],
  // Stream C — Jit hooks/skills
  C01: [JIT, '.claude/hooks/session-start.js'], C02: [JIT, '.claude/hooks/pre-compact.js'],
  C03: [JIT, '.claude/hooks/stop-format-typecheck.sh'], C04: [JIT, '.claude/hooks/config-protection.js'],
  C05: [JIT, '.claude/skills/confidence-gate/SKILL.md'], C06: [JIT, '.claude/hooks/observe.js'],
  C07: [JIT, '.claude/skills/orch-pipeline/SKILL.md'], C08: [JIT, '.claude/hooks/gateguard.js'],
  C09: [JIT, '.claude/hooks.mega.json'], C10: [JIT, 'docs/token-economy.md'],
  // Stream E — innomcp UX specs
  E01: [INNOMCP, 'docs/ux/loading-skeletons.md'], E02: [INNOMCP, 'docs/ux/empty-states.md'],
  E03: [INNOMCP, 'docs/ux/error-toasts.md'], E04: [INNOMCP, 'docs/ux/a11y-audit.md'],
  E05: [INNOMCP, 'docs/ux/i18n-coverage.md'], E06: [INNOMCP, 'docs/ux/keyboard-shortcuts.md'],
  // Stream F — Jit security docs
  F01: [JIT, 'docs/security/bus-guardrail.md'], F02: [JIT, 'docs/security/hybrid-ipc-snapshot.md'],
  F03: [JIT, 'docs/security/rbac-matrix.md'], F04: [JIT, 'docs/security/supplychain-sbom.md'],
};
for (const [id, organ] of Object.entries(ORGAN)) MAP[id] = [JIT, 'docs/organs/' + organ + '.md'];

function stripHeader(text) {
  // remove leading <!-- cc-team deliverable ... --> block
  const m = text.match(/^<!--[\s\S]*?-->\s*\n/);
  let body = m ? text.slice(m[0].length) : text;
  // strip a whole-doc code fence if present
  body = body.replace(/^\s*```[a-zA-Z]*\s*\n/, '').replace(/\n```\s*$/, '\n');
  return body.trimStart();
}

const report = { placed: [], skipped: [], missing: [] };
for (const [id, [root, rel]] of Object.entries(MAP)) {
  const candidates = [path.join(SRC, 'MEGA-' + id + '-dev.md'), path.join(SRC, 'MEGA-' + id + '-writer.md')];
  const src = candidates.find(f => fs.existsSync(f));
  if (!src) { report.missing.push(id); continue; }
  const body = stripHeader(fs.readFileSync(src, 'utf8'));
  if (body.length < 40) { report.skipped.push(id + ' (too short)'); continue; }
  const dest = path.join(root, rel);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, body);
  report.placed.push(rel + (root === INNOMCP ? '  [innomcp]' : '  [jit]'));
}

console.log('PLACED', report.placed.length);
report.placed.forEach(p => console.log('  +', p));
if (report.skipped.length) { console.log('SKIPPED', report.skipped.length); report.skipped.forEach(s => console.log('  ~', s)); }
if (report.missing.length) console.log('MISSING (not yet generated):', report.missing.join(','));
