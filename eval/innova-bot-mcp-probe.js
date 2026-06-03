#!/usr/bin/env node
/**
 * eval/innova-bot-mcp-probe.js — Discover the innova-bot MCP interface.
 *
 * The bot is MCP-over-SSE: POST /messages returns 202, the JSON-RPC *response*
 * arrives on the SSE channel. This probe does the MCP handshake (initialize ->
 * notifications/initialized -> tools/list) and prints what the bot exposes, so
 * Mother knows which methods/tools it can actually call.
 */
const path = require('path');
const fs = require('fs');
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
const InnovaBotBridge = require('../limbs/innova-bot-bridge');

(async () => {
  const bridge = new InnovaBotBridge();
  const responses = [];
  bridge.on('bot_event', (e) => { responses.push(e); console.log('[SSE] ' + JSON.stringify(e).slice(0, 400)); });

  await bridge.connect();
  await new Promise(r => setTimeout(r, 1200));

  async function call(method, params) {
    console.log(`\n>>> ${method}`);
    try { const ack = await bridge.sendCommand(method, params || {}); console.log('  ack: ' + JSON.stringify(ack).slice(0, 120)); }
    catch (e) { console.log('  POST err: ' + e.message); }
    await new Promise(r => setTimeout(r, 1500)); // let the SSE response arrive
  }

  await call('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'Mother-Orchestrator', version: '1.0' },
  });
  await call('tools/list', {});
  await call('resources/list', {});
  await call('prompts/list', {});

  console.log(`\n=== captured ${responses.length} SSE responses ===`);
  // Surface any tools list found.
  for (const r of responses) {
    if (r && r.result && Array.isArray(r.result.tools)) {
      console.log('TOOLS: ' + r.result.tools.map(t => t.name).join(', '));
    }
  }
  await bridge.disconnect();
  process.exit(0);
})();
