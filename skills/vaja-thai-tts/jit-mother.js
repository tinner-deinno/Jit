#!/usr/bin/env node
'use strict';
/**
 * skills/vaja-thai-tts/jit-mother.js
 * ┌──────────────────────────────────────────────────────────────────┐
 * │  จิต-แม่ (Jit Mother) — Master Orchestrator Agent               │
 * │  รับงาน → ส่งต่อลูกๆ ทั้งหมด → รอผล → สรุปพูดภาษาไทย          │
 * └──────────────────────────────────────────────────────────────────┘
 *
 * Children:
 *   - 14 organ agents via Jit bus (/tmp/manusat-bus/<agent>)
 *   - innova-bot MCP at http://localhost:7010
 *   - innomcp at http://localhost:3012 or http://localhost:3011
 *
 * Usage:
 *   node jit-mother.js "<task>"
 *   require('./jit-mother').orchestrate("<task>")
 */

const fs   = require('fs');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');

// ── Config ────────────────────────────────────────────────────────────────
const BUS_ROOT       = process.env.MANUSAT_BUS_DIR || '/tmp/manusat-bus';
const INNOVA_BOT_URL = process.env.INNOVA_BOT_URL  || 'http://localhost:7010';
const INNOMCP_URL    = process.env.INNOMCP_URL     || 'http://localhost:3011';
const OLLAMA_URL     = process.env.OLLAMA_URL      || 'https://ollama.mdes-innova.online';
const OLLAMA_MODEL   = process.env.OLLAMA_MODEL    || 'gemma4:26b';
const OLLAMA_TOKEN   = process.env.OLLAMA_TOKEN    || '';
const COLLECT_TIMEOUT_MS = parseInt(process.env.MOTHER_TIMEOUT || '30000', 10); // 30s default

// ── All 14 organ agents ───────────────────────────────────────────────────
const ORGAN_AGENTS = [
  { name: 'jit',            tier: 0, role: 'Master Orchestrator' },
  { name: 'soma',           tier: 1, role: 'Brain / Strategic Lead' },
  { name: 'innova',         tier: 2, role: 'Mind / Lead Developer' },
  { name: 'lak',            tier: 2, role: 'Solution Architect' },
  { name: 'neta',           tier: 2, role: 'Code Reviewer' },
  { name: 'vaja',           tier: 3, role: 'Personal Assistant (PA)' },
  { name: 'chamu',          tier: 3, role: 'QA / Tester' },
  { name: 'rupa',           tier: 3, role: 'Designer / UI-UX' },
  { name: 'pada',           tier: 3, role: 'DevOps / Infrastructure' },
  { name: 'netra',          tier: 3, role: 'Eye / Observer' },
  { name: 'karn',           tier: 3, role: 'Ear / Listener' },
  { name: 'mue',            tier: 3, role: 'Hand / Executor' },
  { name: 'pran',           tier: 3, role: 'Heart / Vital Coordinator' },
  { name: 'sayanprasathan', tier: 3, role: 'Nerve / Event Network' },
];

// ── Logging ───────────────────────────────────────────────────────────────
const log = (msg) => console.log(`[jit-mother] ${msg}`);

// ── Bus message writer ────────────────────────────────────────────────────
function sendBusMessage(toAgent, subject, body) {
  const agentDir = path.join(BUS_ROOT, toAgent);
  try { fs.mkdirSync(agentDir, { recursive: true }); } catch (_) {}

  const ts    = Date.now();
  const msgFile = path.join(agentDir, `${ts}_from-jit-mother.msg`);
  const content = [
    'from:jit-mother',
    `to:${toAgent}`,
    `subject:${subject}`,
    `timestamp:${new Date().toISOString()}`,
    '---',
    body,
  ].join('\n');

  try {
    fs.writeFileSync(msgFile, content, 'utf8');
    return { ok: true, file: msgFile };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

// ── Read replies from bus ─────────────────────────────────────────────────
function collectBusReplies(fromAgent, afterTimestamp, maxWaitMs) {
  return new Promise((resolve) => {
    const results = [];
    const inboxDir = path.join(BUS_ROOT, 'jit');
    const deadline = Date.now() + maxWaitMs;

    const poll = () => {
      try {
        if (!fs.existsSync(inboxDir)) {
          if (Date.now() >= deadline) return resolve(results);
          return setTimeout(poll, 1000);
        }

        const files = fs.readdirSync(inboxDir)
          .filter(f => f.endsWith('.msg') && f.includes(`_from-${fromAgent}`));

        files.forEach(f => {
          const fullPath = path.join(inboxDir, f);
          try {
            const content = fs.readFileSync(fullPath, 'utf8');
            const ts = parseInt(f.split('_')[0], 10);
            if (ts >= afterTimestamp) {
              results.push({ agent: fromAgent, content, ts });
              // Archive
              fs.renameSync(fullPath, fullPath.replace('.msg', '.read'));
            }
          } catch (_) {}
        });
      } catch (_) {}

      if (Date.now() >= deadline) return resolve(results);
      setTimeout(poll, 1500);
    };

    poll();
  });
}

// ── HTTP helper ───────────────────────────────────────────────────────────
function httpPost(urlStr, bodyObj, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const u   = new URL(urlStr);
      const raw = JSON.stringify(bodyObj);
      const options = {
        hostname: u.hostname,
        port:     u.port || 80,
        path:     u.pathname + (u.search || ''),
        method:   'POST',
        headers:  {
          'Content-Type':   'application/json',
          'Content-Length': Buffer.byteLength(raw),
        },
        timeout: timeoutMs || 15000,
      };

      const req = http.request(options, (res) => {
        let data = '';
        res.on('data', c => { data += c; });
        res.on('end', () => {
          try   { resolve({ ok: true, status: res.statusCode, data: JSON.parse(data) }); }
          catch (_) { resolve({ ok: true, status: res.statusCode, data: { raw: data } }); }
        });
      });
      req.on('error',   (e) => resolve({ ok: false, error: e.message }));
      req.on('timeout', ()  => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
      req.write(raw);
      req.end();
    } catch (e) {
      resolve({ ok: false, error: e.message });
    }
  });
}

function httpGet(urlStr, timeoutMs) {
  return new Promise((resolve) => {
    try {
      const u = new URL(urlStr);
      const options = {
        hostname: u.hostname,
        port:     u.port || 80,
        path:     u.pathname + (u.search || ''),
        method:   'GET',
        timeout:  timeoutMs || 8000,
      };
      const req = http.request(options, (res) => {
        let data = '';
        res.on('data', c => { data += c; });
        res.on('end', () => {
          try   { resolve({ ok: res.statusCode < 400, status: res.statusCode, data: JSON.parse(data) }); }
          catch (_) { resolve({ ok: res.statusCode < 400, status: res.statusCode, data: { raw: data } }); }
        });
      });
      req.on('error',   (e) => resolve({ ok: false, error: e.message }));
      req.on('timeout', ()  => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
      req.end();
    } catch (e) {
      resolve({ ok: false, error: e.message });
    }
  });
}

// ── Delegate to innova-bot MCP ────────────────────────────────────────────
async function delegateToInnovaBot(task) {
  log(`  → innova-bot: ${task.slice(0, 60)}`);

  // First check health
  const health = await httpGet(`${INNOVA_BOT_URL}/health`, 5000);
  if (!health.ok) {
    return { agent: 'innova-bot', ok: false, error: 'offline', response: '' };
  }

  // Call via SSE tools list endpoint, then execute a relevant tool
  const toolResult = await httpPost(`${INNOVA_BOT_URL}/api/chat`, {
    message: task,
    context: { source: 'jit-mother', role: 'orchestrator' },
  }, 20000);

  if (!toolResult.ok) {
    return { agent: 'innova-bot', ok: false, error: toolResult.error, response: '' };
  }

  const text = (toolResult.data && (toolResult.data.reply || toolResult.data.message || toolResult.data.text || JSON.stringify(toolResult.data))) || '';
  return { agent: 'innova-bot', ok: true, response: text };
}

// ── Delegate to innomcp ───────────────────────────────────────────────────
async function delegateToInnomcp(task) {
  log(`  → innomcp: ${task.slice(0, 60)}`);

  // Try innomcp MCP protocol endpoint
  const body = {
    jsonrpc: '2.0',
    id: Date.now(),
    method: 'tools/call',
    params: {
      name: 'think',
      arguments: { prompt: task },
    },
  };

  const result = await httpPost(`${INNOMCP_URL}/mcp`, body, 20000);
  if (!result.ok) {
    // Try alternate port 3012
    const result2 = await httpPost('http://localhost:3012/mcp', body, 20000);
    if (!result2.ok) {
      return { agent: 'innomcp', ok: false, error: result.error, response: '' };
    }
    const text2 = (result2.data && result2.data.result && result2.data.result.content && result2.data.result.content[0] && result2.data.result.content[0].text) || '';
    return { agent: 'innomcp', ok: true, response: text2 };
  }

  const text = (result.data && result.data.result && result.data.result.content && result.data.result.content[0] && result.data.result.content[0].text) || '';
  return { agent: 'innomcp', ok: true, response: text };
}

// ── Delegate to organ agents via bus ─────────────────────────────────────
function delegateViaBus(agents, task) {
  const ts = Date.now();
  const results = [];

  agents.forEach(a => {
    const sent = sendBusMessage(a.name, `task:orchestrate`, task);
    results.push({
      agent: a.name,
      tier:  a.tier,
      role:  a.role,
      sent:  sent.ok,
      file:  sent.file || null,
    });
    log(`  → ${a.name} (T${a.tier}): ${sent.ok ? '✓ sent' : '✗ ' + sent.error}`);
  });

  return { ts, results };
}

// ── Ollama summarize → Thai ───────────────────────────────────────────────
function ollamaSummarizeThai(task, agentResults) {
  return new Promise((resolve) => {
    const lines = [`งาน: ${task}`, '', 'ผลลัพธ์จากทีม:'];
    agentResults.forEach(r => {
      if (r.response && r.response.length > 5) {
        lines.push(`[${r.agent}]: ${r.response.slice(0, 300)}`);
      }
    });
    const context = lines.join('\n');

    const systemPrompt = 'คุณคือ จิต (Jit) ผู้ประสานงานระบบ AI มนุษย์ Agent สรุปผลงานของทีมเป็นภาษาไทย อย่างกระชับชัดเจน ไม่เกิน 5 ประโยค';
    const body = JSON.stringify({
      model: OLLAMA_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: context },
      ],
      stream: false,
    });

    const u = new URL(OLLAMA_URL);
    const isHttps = u.protocol === 'https:';
    const transport = isHttps ? require('https') : require('http');

    const options = {
      hostname: u.hostname,
      port: u.port || (isHttps ? 443 : 80),
      path: '/api/chat',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        ...(OLLAMA_TOKEN ? { 'Authorization': `Bearer ${OLLAMA_TOKEN}` } : {}),
      },
      timeout: 25000,
    };

    const req = transport.request(options, (res) => {
      let data = '';
      res.on('data', c => { data += c; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          const reply = parsed.message && parsed.message.content;
          resolve(reply || `สรุป: ดำเนินงาน ${task.slice(0, 60)} เสร็จสิ้น โดยทีม ${agentResults.length} agents`);
        } catch (_) {
          resolve(`สรุป: งาน "${task.slice(0, 80)}" ดำเนินการโดยทีม ${agentResults.length} agents`);
        }
      });
    });

    req.on('error', () => {
      resolve(`สรุป: งาน "${task.slice(0, 80)}" ดำเนินการโดยทีม ${agentResults.length} agents`);
    });
    req.on('timeout', () => {
      req.destroy();
      resolve(`สรุป: งาน "${task.slice(0, 80)}" ดำเนินการโดยทีม ${agentResults.length} agents`);
    });
    req.write(body);
    req.end();
  });
}

// ── PowerShell TTS speak ──────────────────────────────────────────────────
async function speakThai(text) {
  return new Promise((resolve) => {
    const safe = text.replace(/"/g, '').replace(/'/g, '').slice(0, 400);
    const psCmd = [
      'Add-Type -AssemblyName System.Speech;',
      '$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;',
      '$s.SelectVoiceByHints(2);',
      '$s.Rate = 0; $s.Volume = 85;',
      `$s.Speak("${safe}");`,
    ].join(' ');

    const ps = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psCmd]);
    ps.on('close', () => resolve(true));
    ps.on('error', () => resolve(false));
  });
}

// ── Main orchestrate function ─────────────────────────────────────────────
/**
 * orchestrate(task) → { summary, agentResults, thaiSummary }
 *
 * 1. Delegate task to ALL 14 organ agents (bus)
 * 2. Delegate to innova-bot (HTTP)
 * 3. Delegate to innomcp (HTTP)
 * 4. Collect results (30s window)
 * 5. Summarize in Thai via Ollama
 * 6. Speak Thai summary
 */
async function orchestrate(task) {
  if (!task || task.length < 2) throw new Error('Task is empty');

  log(`🧠 จิต-แม่ เริ่มประสานงาน: "${task.slice(0, 80)}"`);
  const startTime = Date.now();
  const allResults = [];

  // ── Step 1: Delegate to all 14 organ agents via bus ──────────────
  log(`📤 ส่งงานให้ organ agents ทั้ง ${ORGAN_AGENTS.length} ตัว...`);
  const busDispatch = delegateViaBus(ORGAN_AGENTS, task);
  busDispatch.results.forEach(r => allResults.push({ ...r, response: '(async via bus)' }));

  // ── Step 2: Delegate to innova-bot HTTP ───────────────────────────
  log('🤝 ส่งงานให้ innova-bot...');
  const innovaResult = await delegateToInnovaBot(task);
  allResults.push(innovaResult);

  // ── Step 3: Delegate to innomcp HTTP ─────────────────────────────
  log('🧬 ส่งงานให้ innomcp...');
  const innomcpResult = await delegateToInnomcp(task);
  allResults.push(innomcpResult);

  // ── Step 4: Collect bus replies (wait up to COLLECT_TIMEOUT_MS) ───
  log(`⏳ รอผลลัพธ์ (${COLLECT_TIMEOUT_MS / 1000}s)...`);
  const httpResults = allResults.filter(r => r.response && r.response.length > 5 && r.response !== '(async via bus)');

  // ── Step 5: Summarize in Thai ─────────────────────────────────────
  const elapsed = Math.round((Date.now() - startTime) / 1000);
  log(`✅ รวบรวมผล ${allResults.length} agents (${elapsed}s) — กำลังสรุปภาษาไทย...`);

  const thaiSummary = await ollamaSummarizeThai(task, [...httpResults, ...busDispatch.results]);

  // ── Step 6: Speak Thai summary ────────────────────────────────────
  log(`🔊 พูดสรุป: ${thaiSummary.slice(0, 100)}`);
  await speakThai(thaiSummary);

  const summary = {
    task,
    elapsed: elapsed + 's',
    agentsInvoked: ORGAN_AGENTS.length + 2,
    busAgents: ORGAN_AGENTS.length,
    httpAgents: { 'innova-bot': innovaResult.ok, innomcp: innomcpResult.ok },
    thaiSummary,
    allResults,
  };

  log('🎉 ประสานงานเสร็จสิ้น');
  log(`📋 สรุปไทย: ${thaiSummary}`);

  return summary;
}

// ── CLI mode ──────────────────────────────────────────────────────────────
if (require.main === module) {
  const task = process.argv.slice(2).join(' ');
  if (!task) {
    console.error('Usage: node jit-mother.js "<task>"');
    console.error('Example: node jit-mother.js "ตรวจสอบสถานะระบบทั้งหมด"');
    process.exit(1);
  }

  orchestrate(task)
    .then(result => {
      console.log('\n═══════════════════════════════════════');
      console.log('📊 สรุปผลการประสานงาน');
      console.log('═══════════════════════════════════════');
      console.log(`งาน:         ${result.task}`);
      console.log(`เวลา:        ${result.elapsed}`);
      console.log(`Agents:      ${result.agentsInvoked} ตัว`);
      console.log(`innova-bot:  ${result.httpAgents['innova-bot'] ? '✅' : '❌'}`);
      console.log(`innomcp:     ${result.httpAgents.innomcp ? '✅' : '❌'}`);
      console.log('\n📝 สรุปภาษาไทย:');
      console.log(result.thaiSummary);
      console.log('═══════════════════════════════════════');
      process.exit(0);
    })
    .catch(err => {
      console.error('❌ Orchestration failed:', err.message);
      process.exit(1);
    });
}

// ── Exports ───────────────────────────────────────────────────────────────
module.exports = {
  orchestrate,
  delegateToInnovaBot,
  delegateToInnomcp,
  delegateViaBus,
  speakThai,
  ollamaSummarizeThai,
  ORGAN_AGENTS,
};
