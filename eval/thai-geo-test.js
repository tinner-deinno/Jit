#!/usr/bin/env node
'use strict';

const { geocode } = require('../limbs/thai-geo');

const TEST_CASES = [
  { query: 'กรุงเทพมหานคร', expected: 'กรุงเทพมหานคร' },
  { query: 'เชียงใหม่', expected: 'เชียงใหม่' },
  { query: 'ภูเก็ต', expected: 'ภูเก็ต' },
  { query: 'เมืองขอนแก่น', expected: 'ขอนแก่น' },
  { query: 'อำเภอเมืองเชียงใหม่', expected: 'เชียงใหม่' },
];

async function main() {
  console.log('[ThaiGeoTest] Verifying Thai GeoTool...');
  let passed = 0;

  for (const { query, expected } of TEST_CASES) {
    const result = geocode(query);
    const isOk = result.province === expected;
    if (isOk) passed++;
    console.log(`${isOk ? '✅' : '❌'} Query: ${query} -> Result: ${result.province} (Expected: ${expected})`);
  }

  const rate = (passed / TEST_CASES.length) * 100;
  console.log(`\nFinal Score: ${passed}/${TEST_CASES.length} (${rate}%)`);
  process.exit(rate === 100 ? 0 : 1);
}

main();
