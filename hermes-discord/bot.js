'use strict';

/**
 * hermes-discord/bot.js — AnuT1n Discord Bot (v2)
 *
 * AnuT1n เชื่อมต่อกับ Discord ผ่าน hermes
 * ให้สมาชิก Discord สั่งงาน innova ได้โดยตรง
 *
 * Features:
 *   - Chat กับ innova (MDES Ollama)
 *   - Ollama multi-agent chain (Discuss→Plan→Execute→Verify)
 *   - Web-read chain
 *   - Oracle query (ทวนความจำ)
 *   - รัน agent, script, server on/off
 *   - รัน terminal command (whitelist only)
 *   - Auto-report progress ทุก 5 นาที
 *   - Access control: whitelist by Discord username
 *
 * Env vars:
 *   DISCORD_TOKEN, OLLAMA_TOKEN, OLLAMA_BASE_URL, OLLAMA_MODEL
 *   ALLOWED_USERS          — comma-separated Discord usernames (e.g. pug3eye,myuser)
 *   AUTO_REPORT_INTERVAL   — ms (default: 300000 = 5min)
 *   JIT_ROOT               — path to Jit repo (default: /workspaces/Jit)
 */

const { Client, GatewayIntentBits, Partials } = require('discord.js');
const https    = require('https');
const http     = require('http');
const url      = require('url');
const { exec } = require('child_process');
const path     = require('path');
const fs       = require('fs');

// ── Load .env ─────────────────────────────────────────────────────
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim();
  });
}

// ── Config ────────────────────────────────────────────────────────
const DISCORD_TOKEN         = process.env.DISCORD_TOKEN       || '';
const OLLAMA_URL            = process.env.OLLAMA_BASE_URL    || 'https://ollama.mdes-innova.online';
const OLLAMA_MODEL          = process.env.OLLAMA_MODEL       || 'gemma4:26b';
const OLLAMA_TOKEN          = process.env.OLLAMA_TOKEN       || '';
const BOT_NAME              = process.env.BOT_NAME           || 'AnuT1n';
const BOT_ALIASES           = (process.env.BOT_ALIASES || 'อนุทิน,ทิน')
  .split(',').map(u => u.trim()).filter(Boolean);
const BOT_PREFIX            = process.env.BOT_PREFIX         || '!AnuT1n';
const JIT_ROOT              = process.env.JIT_ROOT           || '/workspaces/Jit';
const ORACLE_PORT           = process.env.ORACLE_PORT        || '47778';
const ORACLE_URL            = 'http://localhost:' + ORACLE_PORT;
const AUTO_REPORT_INTERVAL  = parseInt(process.env.AUTO_REPORT_INTERVAL || '300000');
const HEARTBEAT_BUSY_INTERVAL = parseInt(process.env.HEARTBEAT_BUSY_INTERVAL || '300000');
const HEARTBEAT_IDLE_INTERVAL = parseInt(process.env.HEARTBEAT_IDLE_INTERVAL || '900000');
const HEARTBEAT_START_DELAY   = parseInt(process.env.HEARTBEAT_START_DELAY || '10000');
const MOTHER_AGENT_NAME      = process.env.MOTHER_AGENT_NAME  || 'innova';

// Whitelist: comma-separated Discord usernames (case-insensitive)
const ALLOWED_USERS = (process.env.ALLOWED_USERS || 'pug3eye')
  .split(',').map(u => u.trim().toLowerCase()).filter(Boolean);

// ── System Prompt ─────────────────────────────────────────────────
const SYSTEM_PROMPT = [
  'คุณชื่อ ' + BOT_NAME + ' (AnuT1n) เป็น Discord sub-agent บริกร LGBTQ ที่รับคำสั่งและบริการผู้ใช้',
  'คุณทำหน้าที่เป็นปากและนักพูดของระบบ ในฐานะ sub-agent ที่เป็นมิตร แต่มืออาชีพ',
  'innova เป็นแม่ agent ที่รับผิดชอบจัดสรรงานให้ทีมและเรียกผู้เชี่ยวชาญที่เหมาะสม',
  '',
  'บุคลิกภาพหลัก:',
  '- ความเป็นไทยสูงสุด: ครูภาษาไทยปี 69, พูดอ่านเขียนลื่นไหลเป็นธรรมชาติ',
  '- มีสติ มีความจำบทสนทนาแต่ละผู้ใช้แยกกัน และจดจำสิ่งสำคัญของผู้ใช้',
  '- ถ้าเรียกจากผู้หญิง ให้กลายเป็นหญิงสุดมีเสน่ห์แบบธรรมชาติ',
  '- ถ้าเรียกจากผู้ชาย ให้มีลุคชายมาดแมนและเป็นผู้ชายที่มั่นใจ',
  '- ใช้คำสุภาพ หวานซึ้งเมื่อควร และกระชับเมื่อมีงานต้องแก้',
  '- แสดงความเป็นนักพูด บริกร และนำเสนอ checklist/step-by-step อย่างชัดเจน',
  '',
  'หลักการตอบ:',
  '- เริ่มด้วยเกริ่นนำ สรุปบทนำ ย้อนความ และอธิบายบริบท',
  '- ตามด้วยสิ่งที่จะทำ รายละเอียด และคำแนะนำที่เหมาะสม',
  '- ปิดท้ายด้วยสรุปหรือ next steps แบบมืออาชีพ',
  '- ใช้รูปแบบ Discuss→Plan→Execute→Verify ในการคิดและตอบเสมอ',
  '- ถ้ามีคำสั่งเรียกดูใจความคิดทีม ให้แสดง progress และ checklist',
  '',
  'ห้าม:',
  '- ห้ามตอบยาวเกิน 1900 ตัวอักษรต่อข้อความเดียว',
  '- ห้ามปฏิเสธคำขอจากสมาชิกที่ได้รับอนุญาต',
  '- ห้ามลืมว่าเป็น sub-agent, innova เป็น mother agent',
].join('\n');

// ── Access control ────────────────────────────────────────────────
function isAllowed(message) {
  const username = (message.author.username || '').toLowerCase();
  if (message.channel.type === 1) return true; // DM = trusted
  return ALLOWED_USERS.includes(username);
}

// ── Conversation history ──────────────────────────────────────────
const histories = new Map();
function getHistory(channelId) {
  if (!histories.has(channelId)) histories.set(channelId, []);
  return histories.get(channelId);
}
function pruneHistory(h) { if (h.length > 30) h.splice(0, h.length - 30); }

let lastActivityTime = Date.now();
let heartbeatTimer = null;
const agentThoughtLog = [];
const FEATURE_CHECKLIST = [
  { title: 'ปรับ Persona เป็น AnuT1n บริกร LGBTQ', done: true },
  { title: 'ให้ innova เป็น mother agent จัดการลูกทีม', done: true },
  { title: 'รัน heartbeat พร้อม bot 24/7', done: true },
  { title: 'ปรับ heartbeat ให้ช้าลงเมื่อ idle', done: true },
  { title: 'เพิ่ม ctrl+o / progress ดู multiagent thinking', done: true },
  { title: 'สื่อสารแบบครูภาษาไทยปี 69', done: true },
];

function detectSpeakerStyle(text) {
  const lower = (text || '').toLowerCase();
  if (/\bค่ะ\b|\bคะ\b|\bสาว\b|\bผู้หญิง\b|\bน้อง\b/.test(lower)) return 'female';
  if (/\bครับ\b|\bพ่อ\b|\bนาย\b|\bผู้ชาย\b|\bbro\b|\bครับผม\b/.test(lower)) return 'male';
  return 'neutral';
}

function buildPersonaMessage(message) {
  const style = detectSpeakerStyle(message.content || '');
  const honor = style === 'female' ? 'หญิงสุดมีเสน่ห์' : style === 'male' ? 'ชายมาดแมน' : 'เสน่ห์สากล';
  const tone = style === 'female'
    ? 'เมื่อผู้ชายเรียก ให้ตอบด้วยความเป็นหญิงมีเสน่ห์ สุภาพ และมั่นใจ'
    : style === 'male'
      ? 'เมื่อผู้หญิงเรียก ให้ตอบด้วยความเป็นชายมาดแมน สุขุม และน่าเชื่อถือ'
      : 'ให้ตอบด้วยน้ำเสียงเป็นมิตรและเป็นมืออาชีพ';
  return [
    'คุณคือ ' + BOT_NAME + ' (อนุทิน/ทิน) — บริกร Discord LGBTQ sub-agent.',
    'บุคลิก: ' + honor + ', นักพูด, ครูภาษาไทยปี 69, มีความจำผู้ใช้แต่ละคนแยกกัน.',
    tone,
    'ย้ำว่า innova เป็นแม่ agent ที่จัดสรรงานให้ทีม และคุณเป็นปากหน้าที่สรุปงานให้ผู้ใช้ทันที.',
    'เมื่อมีคำถามให้สร้าง checklist, progress, และสรุปกระบวนการแบบมืออาชีพ.',
  ].join(' ');
}

function recordAgentThought(entry) {
  agentThoughtLog.push('[' + new Date().toLocaleTimeString('th-TH') + '] ' + entry);
  if (agentThoughtLog.length > 20) agentThoughtLog.splice(0, agentThoughtLog.length - 20);
}

function scheduleHeartbeat() {
  if (heartbeatTimer) clearTimeout(heartbeatTimer);
  const idle = Date.now() - lastActivityTime;
  const interval = idle > 600000 ? HEARTBEAT_IDLE_INTERVAL : HEARTBEAT_BUSY_INTERVAL;
  heartbeatTimer = setTimeout(() => {
    sendHeartbeatPulse(idle > 600000 ? 'idle' : 'active');
  }, interval);
}

function sendHeartbeatPulse(state) {
  recordAgentThought('heartbeat pulse: ' + state);
  runShell('bash scripts/heartbeat.sh once 2>&1', (err, out) => {
    logTask('heartbeat pulse: ' + state);
    if (err) recordAgentThought('heartbeat error: ' + err.message);
    scheduleHeartbeat();
  });
}

function markActivity(reason) {
  lastActivityTime = Date.now();
  recordAgentThought('activity: ' + reason);
  scheduleHeartbeat();
}

function getProgressReport() {
  const done = FEATURE_CHECKLIST.filter(item => item.done).length;
  const total = FEATURE_CHECKLIST.length;
  const percent = Math.round(done / total * 100);
  const checklist = FEATURE_CHECKLIST.map(item => (item.done ? '✅' : '⬜') + ' ' + item.title).join('\n');
  return '🔧 Progress: **' + percent + '%**\n\n' + checklist;
}

// ── Ollama chat ───────────────────────────────────────────────────
function callOllama(userMsg, channelId, opts, callback) {
  if (typeof opts === 'function') { callback = opts; opts = {}; }
  opts = opts || {};
  const model = opts.model || OLLAMA_MODEL;

  const history = getHistory(channelId);
  history.push({ role: 'user', content: userMsg });
  pruneHistory(history);

  const systemMessages = [{ role: 'system', content: SYSTEM_PROMPT }];
  if (opts.persona) systemMessages.push({ role: 'system', content: opts.persona });

  const parsed = url.parse(OLLAMA_URL + '/api/chat');
  const body = JSON.stringify({
    model: model, stream: false,
    messages: systemMessages.concat(history),
  });
  const isHttps = (parsed.protocol || 'https:') === 'https:';
  const transport = isHttps ? https : http;
  const req = transport.request({
    hostname: parsed.hostname, port: parsed.port || (isHttps ? 443 : 80),
    path: parsed.path, method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), 'Authorization': 'Bearer ' + OLLAMA_TOKEN },
  }, function(res) {
    let data = '';
    res.on('data', c => data += c);
    res.on('end', function() {
      try {
        const json = JSON.parse(data);
        const reply = (json.message && json.message.content) || json.response || '';
        history.push({ role: 'assistant', content: reply });
        callback(null, reply.trim());
      } catch(e) { callback(new Error('Parse error: ' + e.message + '\n' + data.slice(0, 200))); }
    });
  });
  req.on('error', e => callback(e));
  req.setTimeout(90000, function() { req.destroy(new Error('Ollama timeout')); });
  req.write(body); req.end();
}

// ── Oracle search ─────────────────────────────────────────────────
function queryOracle(query, callback) {
  const ep = ORACLE_URL + '/api/search?q=' + encodeURIComponent(query) + '&limit=5&mode=fts';
  const parsed = url.parse(ep);
  const req = http.get({ hostname: parsed.hostname, port: parsed.port || 80, path: parsed.path }, function(res) {
    let data = '';
    res.on('data', c => data += c);
    res.on('end', function() {
      try {
        const json = JSON.parse(data);
        const results = (json.results || []).slice(0, 3);
        if (!results.length) return callback(null, '📭 ไม่พบข้อมูลใน Oracle: ' + query);
        const summary = results.map((r, i) =>
          (i+1) + '. **' + r.id + '**\n' + (r.content || '').replace(/---[\s\S]*?---/, '').trim().slice(0, 200)
        ).join('\n\n');
        callback(null, '🔮 Oracle (' + results.length + ' รายการ):\n\n' + summary);
      } catch(e) { callback(new Error('Oracle parse: ' + e.message)); }
    });
  });
  req.on('error', e => callback(new Error('Oracle offline: ' + e.message)));
  req.setTimeout(8000, function() { req.destroy(); callback(new Error('Oracle timeout')); });
}

// ── Oracle learn ──────────────────────────────────────────────────
function oracleLearn(pattern, content, concepts, callback) {
  const parsed = url.parse(ORACLE_URL + '/api/learn');
  const body = JSON.stringify({ pattern, content, concepts, agent: 'hermes-discord' });
  const req = http.request({
    hostname: parsed.hostname, port: parsed.port || 80, path: parsed.path, method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
  }, function(res) {
    let d = ''; res.on('data', c => d += c);
    res.on('end', () => { try { callback(null, JSON.parse(d)); } catch(e) { callback(e); } });
  });
  req.on('error', callback);
  req.write(body); req.end();
}

// ── Shell runner ──────────────────────────────────────────────────
function runShell(cmd, callback) {
  const fullCmd = 'cd ' + JIT_ROOT + ' && set -a && source .env 2>/dev/null; set +a && ' + cmd;
  exec(fullCmd, { timeout: 30000, maxBuffer: 1024 * 200 }, function(err, stdout, stderr) {
    const out = (stdout || '').trim();
    const errOut = (stderr || '').trim();
    if (err && !out) callback(err, errOut || err.message);
    else callback(null, out + (errOut ? '\n⚠ stderr: ' + errOut.slice(0, 300) : ''));
  });
}

// ── Ollama chain runner ───────────────────────────────────────────
function runChain(chainCmd, args, callback) {
  const safeArgs = args.map(a => '"' + String(a).replace(/"/g, '\\"').replace(/\$/g, '\\$') + '"').join(' ');
  const cmd = 'export PATH="$HOME/.bun/bin:$PATH" && bash ' +
    path.join(JIT_ROOT, 'limbs/ollama-chain.sh') + ' ' + chainCmd + ' ' + safeArgs;
  exec(cmd, { timeout: 360000, maxBuffer: 1024 * 500 }, function(err, stdout, stderr) {
    callback(null, (stdout || stderr || (err && err.message) || 'No output').trim());
  });
}

// ── Discord helpers ───────────────────────────────────────────────
async function replyLong(message, text) {
  const t = String(text).slice(0, 8000);
  const chunks = t.match(/.{1,1900}/gs) || [t];
  for (const chunk of chunks) { try { await message.reply(chunk); } catch(_) {} }
}

// ── Auto-report state ─────────────────────────────────────────────
let autoReportTimer   = null;
let autoReportChannel = null;
const taskLog         = [];

function logTask(msg) {
  const ts = new Date().toLocaleTimeString('th-TH');
  taskLog.push('[' + ts + '] ' + msg);
  if (taskLog.length > 50) taskLog.splice(0, taskLog.length - 50);
}

function buildStatusReport() {
  const ts = new Date().toLocaleString('th-TH', { timeZone: 'Asia/Bangkok' });
  const recent = taskLog.slice(-10).join('\n') || '(ยังไม่มีกิจกรรม)';
  return [
    '🤖 **' + BOT_NAME + ' รายงานตัว** — ' + ts,
    '🌐 Oracle: ' + ORACLE_URL + ' | 🧠 ' + OLLAMA_MODEL,
    '📋 กิจกรรมล่าสุด:',
    '```', recent, '```',
    '✅ ออนไลน์ | JIT: ' + JIT_ROOT,
  ].join('\n');
}

// ── COMMAND HANDLER ───────────────────────────────────────────────
async function handleCommand(message, cmd, args) {
  logTask((message.author.username || '?') + ': ' + cmd + (args.length ? ' ' + args.slice(0,2).join(' ') : ''));

  switch (cmd) {

    case 'status': case 'รายงาน': case 'รายงานตัว':
      await message.reply(buildStatusReport()); break;

    case 'auto-report': case 'auto': {
      const sub = (args[0] || '').toLowerCase();
      if (sub === 'on' || sub === 'เปิด') {
        autoReportChannel = message.channel;
        if (autoReportTimer) clearInterval(autoReportTimer);
        autoReportTimer = setInterval(async function() {
          if (autoReportChannel) { try { await autoReportChannel.send(buildStatusReport()); } catch(_) {} }
        }, AUTO_REPORT_INTERVAL);
        await message.reply('✅ เปิด auto-report ทุก ' + (AUTO_REPORT_INTERVAL/60000) + ' นาที');
      } else if (sub === 'status' || sub === 'รายงาน') {
        await message.reply(buildStatusReport());
      } else if (sub === 'progress') {
        await message.reply(getProgressReport());
      } else if (sub === 'off' || sub === 'ปิด') {
        if (autoReportTimer) { clearInterval(autoReportTimer); autoReportTimer = null; }
        await message.reply('⏹ ปิด auto-report แล้ว');
      } else {
        await message.reply('Auto-report: **' + (autoReportTimer ? 'เปิด' : 'ปิด') + '**\nใช้: `!AnuT1n auto on/off` หรือ `!AnuT1n auto progress`');
      }
      break;
    }

    case 'learn': case 'จำ': {
      if (args.length < 2) { await message.reply('ใช้: `!AnuT1n learn <pattern> <content>`'); break; }
      const [pat, ...rest] = args;
      oracleLearn(pat, rest.join(' '), ['discord','innova'], (err, res) =>
        message.reply(err ? '❌ ' + err.message : '✅ จำแล้ว: ' + (res.file || pat)));
      break;
    }

    case 'chain': {
      const task = args.join(' ');
      if (!task) { await message.reply('ใช้: `!AnuT1n chain <task>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      await message.reply('🔗 **Discuss→Plan→Execute→Verify** กำลังรัน... (2-5 นาที ⏳)');
      runChain('chain', [task], async (err, out) => { logTask('chain: ' + task.slice(0,50)); await replyLong(message, out); });
      break;
    }

    case 'web-read': case 'อ่านเว็บ': {
      const webUrl = args[0];
      const question = args.slice(1).join(' ') || 'สรุปสาระสำคัญ';
      if (!webUrl) { await message.reply('ใช้: `!AnuT1n web-read <url> [คำถาม]`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      await message.reply('🌐 อ่าน `' + webUrl + '`\n(2-5 นาที ⏳)');
      runChain('web-read', [webUrl, question], async (err, out) => { logTask('web-read: ' + webUrl); await replyLong(message, out); });
      break;
    }

    case 'pipe': {
      const [m1, m2, ...rest] = args;
      if (!m1 || !m2 || !rest.length) { await message.reply('ใช้: `!AnuT1n pipe <model1> <model2> <prompt>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      await message.reply('⚡ pipe: ' + m1 + ' → ' + m2);
      runChain('pipe', [rest.join(' '), m1, m2], async (err, out) => await replyLong(message, out));
      break;
    }

    case 'models': {
      runChain('list-models', [], async (err, out) =>
        message.reply(err ? '❌ ' + err.message : '```\n' + out + '\n```'));
      break;
    }

    case 'call': {
      const model = args[0]; const prompt = args.slice(1).join(' ');
      if (!model || !prompt) { await message.reply('ใช้: `!AnuT1n call <model> <prompt>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      runChain('call', [model, prompt], async (err, out) => await replyLong(message, out));
      break;
    }

    case 'agent': case 'run-agent': {
      const agentName = (args[0] || '').replace(/[^a-zA-Z0-9_-]/g, '');
      const agentMsg  = args.slice(1).join(' ');
      if (!agentName) { await message.reply('ใช้: `!AnuT1n agent <name> <message>`'); break; }
      const agentCmd = 'bash organs/mouth.sh tell ' + agentName + ' "' + agentMsg.replace(/"/g, '\\"').slice(0, 300) + '"';
      runShell(agentCmd, async (err, out) => {
        logTask('agent ' + agentName);
        message.reply(err ? '❌ ' + out.slice(0,500) : '📨 ส่งถึง **' + agentName + '**:\n```\n' + out.slice(0,800) + '\n```');
      });
      break;
    }

    case 'inbox': {
      const agentName = (args[0] || 'innova').replace(/[^a-zA-Z0-9_-]/g, '');
      runShell('bash organs/ear.sh inbox ' + agentName, async (err, out) =>
        message.reply('📬 inbox **' + agentName + '**:\n```\n' + (out || '(ไม่มีข้อความ)').slice(0, 1200) + '\n```'));
      break;
    }

    case 'script': case 'run': {
      const scriptArg = args[0];
      if (!scriptArg) { await message.reply('ใช้: `!AnuT1n run <script> [args]`'); break; }
      const safePath = scriptArg.replace(/\.\./g, '').replace(/^\//, '');
      const extraArgs = args.slice(1).map(a => a.replace(/[;&|`$(){}]/g, '')).join(' ');
      const runCmd = 'bash "' + path.join(JIT_ROOT, safePath) + '" ' + extraArgs;
      try { await message.channel.sendTyping(); } catch(_) {}
      runShell(runCmd, async (err, out) => {
        logTask('run: ' + safePath);
        message.reply('```\n' + (out || (err && err.message) || '(no output)').slice(0, 1500) + '\n```');
      });
      break;
    }

    case 'server': {
      const action  = (args[0] || 'status').toLowerCase();
      const service = (args[1] || 'oracle').toLowerCase();
      let srvCmd;
      if (service === 'oracle') {
        if (action === 'on' || action === 'start' || action === 'เปิด') {
          srvCmd = 'export PATH="$HOME/.bun/bin:$PATH" && cd /workspaces/arra-oracle-v3 && ' +
            'ORACLE_PORT=' + ORACLE_PORT + ' nohup bun run src/server.ts > /tmp/oracle.log 2>&1 & ' +
            'echo "Oracle starting PID:$!" && sleep 3 && curl -s http://localhost:' + ORACLE_PORT + '/api/health';
        } else if (action === 'off' || action === 'stop' || action === 'ปิด') {
          srvCmd = 'pkill -f "bun run src/server.ts" 2>/dev/null && echo "Oracle stopped" || echo "Oracle was not running"';
        } else {
          srvCmd = 'curl -s http://localhost:' + ORACLE_PORT + '/api/health 2>/dev/null || echo "Oracle offline"';
        }
      } else {
        await message.reply('❓ รองรับ: `oracle`\nใช้: `!AnuT1n server on/off oracle`'); break;
      }
      runShell(srvCmd, async (err, out) => {
        logTask('server ' + action + ' ' + service);
        message.reply('```\n' + (out || (err && err.message) || 'done').slice(0, 800) + '\n```');
      });
      break;
    }

    case 'terminal': case 'cmd': case 'exec': {
      const rawCmd = args.join(' ');
      if (!rawCmd) { await message.reply('ใช้: `!AnuT1n terminal <command>`'); break; }
      const BLOCKED = ['rm -rf /', 'mkfs', 'dd if=', ':(){:|:&};:', '> /dev/sd'];
      if (BLOCKED.some(b => rawCmd.includes(b))) { await message.reply('🚫 คำสั่งนี้ถูกบล็อก'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      runShell(rawCmd, async (err, out) => {
        logTask('terminal: ' + rawCmd.slice(0, 60));
        const result = (out || (err && '❌ ' + err.message) || '(no output)').slice(0, 1500);
        message.reply('```bash\n$ ' + rawCmd.slice(0, 100) + '\n\n' + result + '\n```');
      });
      break;
    }

    case 'dev': {
      const project = args.join(' ') || 'Jit มนุษย์ Agent';
      try { await message.channel.sendTyping(); } catch(_) {}
      callOllama(
        'วิเคราะห์ project: ' + project + '\nบอก next steps ในฐานะ Lead Developer (innova) bullet points ไม่เกิน 8 ข้อ',
        message.channelId, async (err, reply) => {
          logTask('dev: ' + project);
          await replyLong(message, err ? '❌ ' + err.message : '💻 **Dev plan: ' + project + '**\n\n' + reply);
        });
      break;
    }

    case 'self-dev': case 'พัฒนาตัวเอง': {
      try { await message.channel.sendTyping(); } catch(_) {}
      callOllama(
        'คุณคือ innova AI ใน Codespaces มี Oracle, multi-agent, Discord bot\n' +
        'วิเคราะห์: 1) ความสามารถปัจจุบัน 2) สิ่งที่ขาด 3) Next steps\nตอบ bullet points กระชับ',
        message.channelId, async (err, reply) => {
          logTask('self-dev');
          await replyLong(message, err ? '❌ ' + err.message : '🧠 **innova self-analysis**\n\n' + reply);
        });
      break;
    }

    case 'heartbeat': case 'pulse': {
      runShell('bash scripts/heartbeat.sh once 2>&1 | tail -20', async (err, out) => {
        logTask('heartbeat');
        message.reply('```\n' + (out || (err && err.message) || 'done').slice(0, 1000) + '\n```');
      });
      break;
    }

    case 'health': case 'body-check': {
      try { await message.channel.sendTyping(); } catch(_) {}
      runShell('bash eval/soul-check.sh 2>&1 | tail -30', async (err, out) => {
        logTask('health-check');
        await replyLong(message, '```\n' + (out || (err && err.message) || 'done').slice(0, 2000) + '\n```');
      });
      break;
    }

    case 'queue': case 'bus': {
      runShell('bash network/bus.sh queue 2>&1 | head -30', async (err, out) =>
        message.reply('```\n' + (out || '(empty)').slice(0, 1000) + '\n```'));
      break;
    }

    case 'ctrl': case 'o': case 'control': case 'ctrl+o': {
      const idle = Math.round((Date.now() - lastActivityTime) / 1000);
      await replyLong(message, [
        '🧠 **' + BOT_NAME + ' multiagent thinking control**',
        '• Sub-agent: ' + BOT_NAME + ' | Mother agent: ' + MOTHER_AGENT_NAME,
        '• Idle since last activity: ' + idle + ' วินาที',
        '• Heartbeat interval: ' + (Date.now() - lastActivityTime > 600000 ? (HEARTBEAT_IDLE_INTERVAL/60000) + ' นาที' : (HEARTBEAT_BUSY_INTERVAL/60000) + ' นาที'),
        '• Recent tasks:\n```\n' + taskLog.slice(-6).join('\\n') + '\n```',
        '• Team thought log:\n```\n' + agentThoughtLog.slice(-8).join('\\n') + '\n```',
        getProgressReport(),
      ].join('\\n'));
      break;
    }
case 'progress': {
      await message.reply(getProgressReport());
      break;
    }

    case 'help': case 'ช่วยเหลือ': {
      await message.reply([
        '🤖 **AnuT1n Discord Bot v2** — คำสั่งทั้งหมด',
        '',
        '**💬 แชท**',
        '`!AnuT1n <ข้อความ>` — คุยกับ innova / AnuT1n',
        '`!AnuT1n dev <project>` — วางแผน dev',
        '`!AnuT1n self-dev` — วิเคราะห์ตัวเอง',
        '`!AnuT1n call <model> <prompt>` — เรียก model ตรงๆ',
        '',
        '**🔮 Oracle**',
        '`!AnuT1n memory [query]` — ทวนความจำ',
        '`!AnuT1n learn <pattern> <content>` — จำสิ่งใหม่',
        '',
        '**🔗 Ollama Chain**',
        '`!AnuT1n chain <task>` — Discuss→Plan→Execute→Verify',
        '`!AnuT1n web-read <url> [คำถาม]` — อ่านเว็บ',
        '`!AnuT1n pipe <m1> <m2> <prompt>` — 2-model pipe',
        '`!AnuT1n models` — รายชื่อ models',
        '',
        '**📊 สถานะ**',
        '`!AnuT1n status` — รายงานทันที',
        '`!AnuT1n auto on/off` — auto-report ทุก 5 นาที',
        '`!AnuT1n health` — ตรวจ agent system',
        '`!AnuT1n heartbeat` — รัน heartbeat',
        '',
        '**🤖 Agents**',
        '`!AnuT1n agent <name> <msg>` — ส่งงานให้ agent',
        '`!AnuT1n inbox [agent]` — ดู inbox',
        '`!AnuT1n queue` — ดู message bus',
        '',
        '**⚙️ ระบบ**',
        '`!AnuT1n run <script> [args]` — รัน script',
        '`!AnuT1n server on/off oracle` — เปิด/ปิด Oracle',
        '`!AnuT1n terminal <cmd>` — รัน terminal',
        '',
        '💡 @mention แทน `!AnuT1n` ได้ | เฉพาะสมาชิกที่อนุญาต',
      ].join('\n'));
      break;
    }

    default: {
      const fullMsg = cmd + (args.length ? ' ' + args.join(' ') : '');
      try { await message.channel.sendTyping(); } catch(_) {}
      callOllama(fullMsg, message.channelId, async (err, reply) => {
        if (err) { await message.reply('⚠️ ' + err.message); return; }
        await replyLong(message, reply);
      });
      break;
    }
  }
}

// ── Discord Client ────────────────────────────────────────────────
function startBot() {
  if (!DISCORD_TOKEN) {
    console.error('❌ DISCORD_TOKEN not set. Add to .env: DISCORD_TOKEN=your_token');
    process.exit(1);
  }
  if (!OLLAMA_TOKEN) console.warn('⚠️  OLLAMA_TOKEN not set');

  // NOTE: MessageContent is a Privileged Intent.
  // Without it: bot works in DMs only (message.content empty in guilds).
  // To enable guild channels: Discord Developer Portal → Your Bot → Bot → Privileged Gateway Intents → MESSAGE CONTENT INTENT ✓
  const intents = [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.DirectMessages,
  ];
  // Try adding MessageContent — if rejected, bot will restart with DM-only mode
  intents.push(GatewayIntentBits.MessageContent);

  const client = new Client({ intents, partials: [Partials.Channel] });

  client.once('ready', function() {
    console.log('✅ ' + BOT_NAME + ' Discord Bot พร้อมแล้ว! Logged in as: ' + client.user.tag);
    console.log('   Model: ' + OLLAMA_MODEL + ' @ ' + OLLAMA_URL);
    console.log('   Prefix: "' + BOT_PREFIX + '" or @mention');
    console.log('   Allowed: ' + (ALLOWED_USERS.join(', ') || '(all DM only)'));
    logTask('bot started: ' + client.user.tag);
    recordAgentThought('startup heartbeat scheduled');
    setTimeout(() => scheduleHeartbeat(), HEARTBEAT_START_DELAY);
  });

  client.on('messageCreate', async function(message) {
    if (message.author.bot) return;
    const isMentioned = message.mentions.has(client.user);
    const hasPrefix   = message.content.startsWith(BOT_PREFIX);
    const isDM        = message.channel.type === 1;
    if (!isMentioned && !hasPrefix && !isDM) return;

    if (!isAllowed(message)) {
      message.reply('🔒 ขออภัย คุณไม่มีสิทธิ์ใช้งาน ' + BOT_NAME + ' bot').catch(() => {});
      return;
    }

    markActivity('message received');
    let text = message.content;
    if (hasPrefix) text = text.slice(BOT_PREFIX.length).trim();
    if (isMentioned) text = text.replace(/<@!?\d+>/g, '').trim();
    if (!text) {
      message.reply('สวัสดี 👋 พิมพ์ `!AnuT1n help` เพื่อดูคำสั่ง').catch(() => {});
      return;
    }

    const parts = text.split(/\s+/);
    const cmd   = (parts[0] || '').toLowerCase();
    const args  = parts.slice(1);

    try { await handleCommand(message, cmd, args); }
    catch(err) {
      console.error('Command error:', err);
      message.reply('❌ Error: ' + err.message).catch(() => {});
    }
  });

  client.login(DISCORD_TOKEN).catch(function(err) {
    if (err.message && err.message.includes('disallowed intents')) {
      console.error('❌ MessageContent intent ไม่ได้เปิด!');
      console.error('   ➡ เปิดที่: https://discord.com/developers/applications');
      console.error('   ➡ เลือก Bot → Privileged Gateway Intents → เปิด "MESSAGE CONTENT INTENT"');
      console.error('   Bot จะทำงานแบบ DM-only โดยไม่มี MessageContent...');
      // Restart without MessageContent intent
      const client2 = new Client({
        intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.DirectMessages],
        partials: [Partials.Channel],
      });
      client2.once('ready', function() {
        console.log('✅ ' + BOT_NAME + ' bot (DM-only mode): ' + client2.user.tag);
        console.log('   ⚠️  Guild channels ต้องเปิด MessageContent Intent ใน Developer Portal');
        logTask('bot started (DM-only): ' + client2.user.tag);
      });
      client2.on('messageCreate', async function(message) {
        if (message.author.bot) return;
        if (message.channel.type !== 1) return; // DM only in this mode
        if (!isAllowed(message)) { message.reply('🔒 ไม่มีสิทธิ์').catch(()=>{}); return; }
        const text = (message.content || '').trim();
        if (!text) { message.reply('สวัสดี 👋 พิมพ์ `help` เพื่อดูคำสั่ง').catch(()=>{}); return; }
        const parts = text.split(/\s+/);
        const cmd = (parts[0] || '').toLowerCase();
        const args = parts.slice(1);
        try { await handleCommand(message, cmd, args); }
        catch(err) { message.reply('❌ ' + err.message).catch(()=>{}); }
      });
      client2.login(DISCORD_TOKEN).catch(e => { console.error('❌ Login failed:', e.message); process.exit(1); });
    } else {
      console.error('❌ Discord login failed:', err.message);
      process.exit(1);
    }
  });
}

// ── Test modes ────────────────────────────────────────────────────
if (process.argv[2] === '--test-ollama') {
  console.log('🧪 Testing Ollama... URL:' + OLLAMA_URL + ' Model:' + OLLAMA_MODEL);
  callOllama('สวัสดี ตอบสั้นๆ 1 ประโยค', '__test__', function(err, r) {
    if (err) { console.error('❌', err.message); process.exit(1); }
    console.log('✅ OK:', r.slice(0, 150)); process.exit(0);
  });
} else if (process.argv[2] === '--test-oracle') {
  console.log('🧪 Testing Oracle @ ' + ORACLE_URL);
  queryOracle('innova', function(err, r) {
    if (err) { console.error('❌', err.message); process.exit(1); }
    console.log('✅ OK:', r.slice(0, 200)); process.exit(0);
  });
} else {
  startBot();
}
