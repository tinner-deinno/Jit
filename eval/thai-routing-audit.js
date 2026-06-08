#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const router = require('../hermes-discord/model-router');

const ROOT = path.join(__dirname, '..');
const CORPUS_PATH = path.join(ROOT, 'eval/thai-routing-corpus.md');
const OUTPUT_PATH = path.join(ROOT, 'ψ/memory/learnings/thai-routing-audit-2026-06-08.md');

async function runAudit() {
  console.log('[Audit] Starting Thai Knowledge Routing Audit (Phase 10.14)...');

  if (!fs.existsSync(CORPUS_PATH)) {
    console.error('Corpus file not found at ' + CORPUS_PATH);
    process.exit(1);
  }

  const content = fs.readFileSync(CORPUS_PATH, 'utf8');
  const lines = content.split(/\r?\n/).filter(l => l.trim() && !l.startsWith('#') && !l.startsWith('###'));
  const prompts = lines
    .filter(l => /^\d+\./.test(l))
    .map(l => l.replace(/^\d+\.\s*/, '').trim());

  if (!prompts.length) {
    console.error('No valid prompts found in corpus.');
    process.exit(1);
  }

  console.log(`[Audit] Found ${prompts.length} prompts. Testing routing...`);

  const results = [];
  let thaiOkCount = 0;

  for (let i = 0; i < prompts.length; i++) {
    const prompt = prompts[i];
    console.log(`[${i+1}/${prompts.length}] Probing: ${prompt.slice(0, 50)}...`);

    try {
      // Test 1: Force thaillm
      const resThai = await router.callModelPromise([{ role: 'user', content: prompt }], {
        preferBackend: 'thaillm',
        noRotate: true,
      });

      // Test 2: Force ollama_mdes
      const resMdes = await router.callModelPromise([{ role: 'user', content: prompt }], {
        preferBackend: 'ollama_mdes',
        noRotate: true,
      });

      const isThaiCoherent = /\b(จิต|มนุษย์|อวัยวะ|ภาษาไทย)\b/i.test(resThai.reply);
      if (isThaiCoherent) thaiOkCount++;

      results.push({
        prompt,
        thaillm: {
          backend: resThai.backend,
          reply: resThai.reply.slice(0, 100).replace(/\\n/g, ' '),
          ok: resThai.backend === 'thaillm'
        },
        ollama_mdes: {
          backend: resMdes.backend,
          reply: resMdes.reply.slice(0, 100).replace(/\\n/g, ' '),
          ok: resMdes.backend === 'ollama_mdes'
        }
      });
    } catch (e) {
      console.error(`  Error probing prompt ${i+1}: ${e.message}`);
    }
  }

  const determinism = (results.filter(r => r.thaillm.ok && r.ollama_mdes.ok).length / prompts.length) * 100;
  const quality = (thaiOkCount / prompts.length) * 100;

  const report = [
    '# Thai Knowledge Routing Audit Report (Phase 10.14)',
    `Date: ${new Date().toISOString()}`,
    `Corpus Size: ${prompts.length} prompts`,
    `Routing Determinism: ${determinism.toFixed(2)}%`,
    `Thai Coherence Rate: ${quality.toFixed(2)}%`,
    '',
    '## Detailed Results',
    '| Prompt | ThaiLLM Backend | MDES Backend | Verdict |',
    '|---|---|---|---|',
    ...results.map(r => `| ${r.prompt.slice(0, 30)}... | ${r.thaillm.backend} | ${r.ollama_mdes.backend} | ${r.thaillm.ok && r.ollama_mdes.ok ? 'PASS' : 'FAIL'} |`),
    '',
    '## Conclusion',
    determinism >= 95 ? '✅ Routing is deterministic. Thai queries hit the correct lanes.' : '❌ Routing drift detected. Need to refine routing keys.',
    quality >= 80 ? '✅ Response quality is coherent.' : '❌ Response quality is low. Need model fine-tuning.',
  ].join('\n');

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(OUTPUT_PATH, report);
  console.log(`\n[Audit] Report written to ${OUTPUT_PATH}`);
  console.log(`Determinism: ${determinism.toFixed(2)}% | Quality: ${quality.toFixed(2)}%`);
}

runAudit().catch(console.error);
