#!/usr/bin/env node
'use strict';
/**
 * hermes-discord/test-openclaude.js
 * ═════════════════════════════════════════════════════════
 * Test OpenClaude integration with Jit multi-backend router
 */

const modelRouter = require('./model-router');
const openClaudeAdapter = require('./openclaude-adapter');

const SECTION = '═'.repeat(60);

console.log('\n' + SECTION);
console.log('  OpenClaude Backend Test for Jit System');
console.log(SECTION);

// Test 1: Health check
console.log('\n[TEST 1] OpenClaude Health Check');
console.log('─'.repeat(60));

openClaudeAdapter.checkHealth().then(function(health) {
  if (health.ok) {
    console.log('✅ OpenClaude online at', openClaudeAdapter.OPENCLAUDE_BASE_URL);
    console.log('   Model:', openClaudeAdapter.OPENCLAUDE_MODEL);
  } else {
    console.log('⚠️  OpenClaude offline:', health.message);
    console.log('   Start with: docker run -p 8000:8000 gitlawb/openclaude:latest');
  }

  // Test 2: Model router backends
  console.log('\n[TEST 2] Model Router Backend Status');
  console.log('─'.repeat(60));

  var status = modelRouter.status();
  console.log('Backend order:', status.order.join(' → '));
  console.log('');
  Object.entries(status.backends).forEach(function([name, info]) {
    var avail = info.available ? '✅' : '❌';
    if (name === 'openclaude') {
      console.log(avail + ' ' + name.padEnd(12) + info.host + ':' + info.port + ' (' + info.model + ')');
    } else if (name === 'copilot' || name === 'openai') {
      console.log(avail + ' ' + name.padEnd(12) + (info.available ? info.tokenSource || 'token set' : 'no token'));
    } else {
      console.log(avail + ' ' + name.padEnd(12) + info.url);
    }
  });

  // Test 3: Call model router (with preferred backend)
  console.log('\n[TEST 3] Model Router Call (preferring openclaude)');
  console.log('─'.repeat(60));

  var testMessages = [
    { role: 'user', content: 'In one sentence, what is OpenClaude?' }
  ];

  modelRouter.callModel(testMessages, { preferBackend: 'openclaude' }, function(err, result) {
    if (err) {
      console.log('❌ Model call failed:', err.message);
      console.log('\n[INFO] This is expected if:');
      console.log('  - OpenClaude server is not running');
      console.log('  - Backend fallback: will try next in order (' + status.order.join(' → ') + ')');
    } else {
      console.log('✅ Backend used:', result.backend);
      console.log('Reply:', result.reply.slice(0, 150) + (result.reply.length > 150 ? '...' : ''));
    }

    // Test 4: Direct adapter call
    console.log('\n[TEST 4] Direct OpenClaude Adapter Call');
    console.log('─'.repeat(60));

    if (!openClaudeAdapter.isAvailable()) {
      console.log('⚠️  OpenClaude not available (not configured or offline)');
    } else {
      console.log('Calling OpenClaude directly...');
      openClaudeAdapter.callOpenClaudePromise(
        [{ role: 'user', content: 'Respond with exactly one word: working' }],
        { model: 'claude-3.5-sonnet' }
      ).then(function(result) {
        console.log('✅ Direct call successful');
        console.log('   Model:', result.model);
        console.log('   Reply:', result.text);
        console.log('   Backend:', result.backend);
      }).catch(function(err) {
        console.log('❌ Direct call failed:', err.message);
      }).finally(function() {
        showSummary(health, status, err, result);
      });
    }
  });

  function showSummary(health, status, callErr, callResult) {
    console.log('\n' + SECTION);
    console.log('  Summary');
    console.log(SECTION);
    console.log('');
    console.log('OpenClaude Status:     ' + (health.ok ? '✅ Online' : '❌ Offline'));
    console.log('Model Router:          ✅ Configured');
    console.log('Backend Priority:      ' + status.order.join(' → '));
    console.log('OpenClaude Available:  ' + (openClaudeAdapter.isAvailable() ? '✅' : '❌'));
    console.log('');

    if (callErr) {
      console.log('⚠️  Model call result: Fallback to next backend');
      if (callResult && callResult.backend !== 'openclaude') {
        console.log('   Successfully used:', callResult.backend);
      }
    } else if (callResult && callResult.backend === 'openclaude') {
      console.log('✅ Model call result: OpenClaude working');
    }

    console.log('');
    console.log('Next steps:');
    if (!health.ok) {
      console.log('  1. Start OpenClaude: docker run -p 8000:8000 gitlawb/openclaude:latest');
      console.log('  2. Verify: curl http://localhost:8000/health');
      console.log('  3. Re-run this test');
    } else {
      console.log('  1. Test in Discord: !jit backend');
      console.log('  2. Spawn agent: !jit spawn openclaude <message>');
      console.log('  3. Use in team: !jit spawn chain soma+openclaude+innova <task>');
    }
    console.log('');
    console.log(SECTION + '\n');
  }
}).catch(function(err) {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
