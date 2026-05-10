#!/usr/bin/env node
'use strict';
/**
 * hermes-discord/test-thai-tts.js
 * Thai TTS Test - Verify Vaja can speak Thai
 */

const spawner = require('./agent-spawner');

console.log('\n' + '='.repeat(50));
console.log('  Vaja Thai TTS Test Suite');
console.log('='.repeat(50) + '\n');

// Test 1: Direct Thai speech
console.log('[TEST 1] Direct Thai Speech');
console.log('-'.repeat(50));
spawner.speakThai('สวัสดีครับ ผมคือวาจา', function(err, result) {
  if (err) console.log('  ✗ Error:', err.message);
  else console.log('  ✓ Spoke successfully');
});

// Test 2: Translate and speak
console.log('\n[TEST 2] Translate + Speak');
console.log('-'.repeat(50));
spawner.speakAsVaja('Hello, I am your personal assistant', function(err, result) {
  if (err) console.log('  ✗ Error:', err.message);
  else console.log('  ✓ Translated and spoke');
});

// Test 3: List agents
console.log('\n[TEST 3] Agent Registry');
console.log('-'.repeat(50));
var agents = spawner.listAgents();
agents.forEach(function(a) {
  console.log('  ' + a.tier + ' | ' + a.name + ' (' + a.organ + ')');
});

console.log('\n' + '='.repeat(50));
console.log('  All tests complete - listen for Thai speech');
console.log('='.repeat(50) + '\n');