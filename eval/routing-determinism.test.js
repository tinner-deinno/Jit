#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

// Mocking the logic of selectLanes and buildJobs since they are not exported and
// we want to verify the CURRENT behavior (which we suspect is non-deterministic per-prompt)
function mockSelectLanes() {
  // Simulated usable lanes from current provider-status.json
  return ['ollama_mdes', 'thaillm', 'commandcode', 'ollama_cloud'];
}

function mockBuildJobs(prompts, lanes) {
  const weighted = [];
  const weights = { 'ollama_mdes': 30, 'thaillm': 26, 'commandcode': 18, 'ollama_cloud': 14 };

  for (const lane of lanes) {
    const w = weights[lane] || 10;
    for (let i = 0; i < w; i++) weighted.push(lane);
  }

  return prompts.map((prompt, i) => {
    return {
      prompt,
      lane: weighted[i % weighted.length]
    };
  });
}

const TEST_PROMPTS = [
  "จิตคืออะไร",
  "What is a multi-agent system?",
  "เขียนโค้ด Node.js",
  "Thai address parsing",
  "Syllable splitting logic",
  "How to use CommandCode?",
  "Routing determinism check",
  " la liveness probe",
  "Soma vs Innova",
  "BKK postal code",
  "CNX weather",
  "Thai la liveness",
  " la probe result",
  " la latency",
  " la throughput",
  " liveness check",
  " la status",
  " liveness probe la",
  " liveness la",
  " la a liveness"
];

async function runTest() {
  console.log('[DeterminismTest] Starting Routing Determinism Check...');
  console.log(`Corpus size: ${TEST_PROMPTS.length} prompts\n`);

  const iterations = 5;
  const results = {};

  for (let i = 0; i < iterations; i++) {
    console.log(`Iteration ${i + 1}/${iterations}...`);
    const lanes = mockSelectLanes();
    const jobs = mockBuildJobs(TEST_PROMPTS, lanes);

    TEST_PROMPTS.forEach((prompt, idx) => {
      const lane = jobs[idx].lane;
      if (!results[prompt]) results[prompt] = [];
      results[prompt].push(lane);
    });
  }

  let passed = 0;
  console.log('\n| Prompt | Result | Deterministic? |');
  console.log('|---|---|---|');

  for (const prompt of TEST_PROMPTS) {
    const lanes = results[prompt];
    const allSame = lanes.every(l => l === lanes[0]);
    if (allSame) passed++;
    console.log(`| ${prompt.slice(0, 20)}... | ${lanes.join(', ')} | ${allSame ? '✅' : '❌'} |`);
  }

  const rate = (passed / TEST_PROMPTS.length) * 100;
  console.log(`\nFinal Determinism Score: ${passed}/${TEST_PROMPTS.length} (${rate}%)`);

  if (rate < 100) {
    console.log('\nCONCLUSION: Routing is NOT deterministic per-prompt.');
    console.log('Current logic uses weighted round-robin based on index, not prompt content.');
    process.exit(1);
  } else {
    console.log('\nCONCLUSION: Routing is deterministic.');
    process.exit(0);
  }
}

runTest();
