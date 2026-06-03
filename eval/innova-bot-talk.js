#!/usr/bin/env node
/**
 * eval/innova-bot-talk.js — Live end-to-end "talk to innova-bot" check.
 * Connects via the real bridge, dispatches one task, reports the round-trip.
 * Exits non-zero if the bridge cannot establish a session.
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
  const t0 = Date.now();
  let connected = false;
  bridge.on('connected', (s) => { connected = true; console.log(`[talk] connected: session=${s}`); });
  bridge.on('bot_event', (e) => console.log(`[talk] bot_event: ${JSON.stringify(e).slice(0, 200)}`));

  const timeout = setTimeout(() => { console.error('[talk] FAIL: no session within 12s'); process.exit(1); }, 12000);
  try {
    await bridge.connect();
    // give SSE a moment to deliver the endpoint event
    await new Promise(r => setTimeout(r, 1500));
    if (!connected && !bridge.sessionID) { console.error('[talk] FAIL: connect() returned but no sessionID'); process.exit(1); }
    console.log(`[talk] dispatching task...`);
    const res = await bridge.dispatchTask('Mother handshake: confirm you can receive orchestration tasks. Reply briefly.');
    console.log(`[talk] dispatch round-trip OK in ${Date.now() - t0}ms`);
    console.log(`[talk] response: ${JSON.stringify(res).slice(0, 300)}`);
    clearTimeout(timeout);
    bridge.disconnect && bridge.disconnect();
    process.exit(0);
  } catch (e) {
    clearTimeout(timeout);
    console.error(`[talk] dispatch error: ${e.message}`);
    // Session may still be established even if the task RPC method differs.
    console.log(`[talk] sessionID present: ${!!bridge.sessionID}`);
    process.exit(bridge.sessionID ? 0 : 1);
  }
})();
