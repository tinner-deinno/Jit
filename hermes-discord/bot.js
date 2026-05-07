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
 *   JIT_COMMAND_PREFIX     — Jit control prefix (default: !jit)
 *   JIT_REPORT_CHANNEL_ID  — startup/status report channel
 */

const { Client, GatewayIntentBits, Partials } = require('discord.js');
const https    = require('https');
const http     = require('http');
const url      = require('url');
const { exec } = require('child_process');
const path     = require('path');
const fs       = require('fs');
let jitControl;
try { jitControl = require('./jit-control'); } catch(_) { jitControl = {}; }
let DiscordThoughtLoop;
try { ({ DiscordThoughtLoop } = require('./thought-loop')); } catch(_) { DiscordThoughtLoop = class { attach() {} start() {} stop() {} }; }

// ── Load .env ─────────────────────────────────────────────────────
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim();
  });
}

function parsePositiveInt(value, fallback) {
  const parsed = parseInt(value || '', 10);
  if (Number.isFinite(parsed) && parsed > 0) return parsed;
  return fallback;
}
function splitCsv(value) {
  return String(value || '').split(',').map(function(s) { return s.trim(); }).filter(Boolean);
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
const AUTO_REPORT_ON_FIRST_CHAT = process.env.AUTO_REPORT_ON_FIRST_CHAT !== 'false';
const AUTO_REPORT_CHANNEL_ID = process.env.AUTO_REPORT_CHANNEL_ID || '';
const HEARTBEAT_BUSY_INTERVAL = parseInt(process.env.HEARTBEAT_BUSY_INTERVAL || '300000');
const HEARTBEAT_IDLE_INTERVAL = parseInt(process.env.HEARTBEAT_IDLE_INTERVAL || '900000');
const HEARTBEAT_START_DELAY   = parseInt(process.env.HEARTBEAT_START_DELAY || '10000');
const MOTHER_AGENT_NAME      = process.env.MOTHER_AGENT_NAME  || 'innova';
const ORACLE_BASE_URL        = process.env.ORACLE_BASE_URL    || ORACLE_URL;
const JIT_COMMAND_PREFIX     = process.env.JIT_COMMAND_PREFIX || (jitControl && jitControl.COMMAND_PREFIX) || '!jit';
const JIT_REPORT_CHANNEL_ID  = process.env.JIT_REPORT_CHANNEL_ID || (jitControl && jitControl.REPORT_CHANNEL_ID) || '';
const USE_MESSAGE_CONTENT_INTENT = process.env.DISCORD_USE_MESSAGE_CONTENT_INTENT !== 'false';
const JIT_THOUGHT_LOOP_ENABLED = process.env.JIT_THOUGHT_LOOP_ENABLED !== 'false';
const JIT_THOUGHT_LOOP_INTERVAL_MS = parsePositiveInt(process.env.JIT_THOUGHT_LOOP_INTERVAL_MS, 300000);
const JIT_THOUGHT_LOOP_ACTIVE_WINDOW_MS = parsePositiveInt(process.env.JIT_THOUGHT_LOOP_ACTIVE_WINDOW_MS, 900000);
const JIT_THOUGHT_LOOP_MIN_MESSAGES = parsePositiveInt(process.env.JIT_THOUGHT_LOOP_MIN_MESSAGES, 4);
const JIT_THOUGHT_LOOP_MIN_PARTICIPANTS = parsePositiveInt(process.env.JIT_THOUGHT_LOOP_MIN_PARTICIPANTS, 2);
const JIT_THOUGHT_LOOP_CHANNELS = splitCsv(process.env.JIT_THOUGHT_LOOP_CHANNELS || '');
const JIT_THOUGHT_LOOP_STATE_FILE = process.env.JIT_THOUGHT_LOOP_STATE_FILE || '/tmp/hermes-discord-thought-loop.json';

function buildChecklist() {
  const tasks = [
    'วิเคราะห์คำถามและบริบทของผู้ใช้',
    'สรุปสิ่งที่จะทำให้เข้าใจง่าย',
    'จัดโครงสร้างคำตอบตามแบบ Discuss → Plan → Build → Verify',
    'เขียนคำตอบไทยปี 2569 แบบมืออาชีพ',
    'ให้คำแนะนำที่ครอบคลุมและน่าพอใจ',
  ];
  return `📋 Checklist:\n${tasks.map((item) => `- [x] ${item}`).join('\n')}`;
}

// ── Oracle API helper ───────────────────────────────────────────
function callOracle(apiPath, method, bodyObj, callback) {
  const parsed = new URL(ORACLE_BASE_URL);
  const isHttps = parsed.protocol === 'https:';
  const transport = isHttps ? https : http;
  const bodyStr = bodyObj ? JSON.stringify(bodyObj) : null;
  const options = {
    hostname: parsed.hostname,
    port: parsed.port || (isHttps ? 443 : 80),
    path: apiPath,
    method: method || 'GET',
    headers: { 'Content-Type': 'application/json' },
  };
  if (bodyStr) options.headers['Content-Length'] = Buffer.byteLength(bodyStr);
  const req = transport.request(options, function(res) {
    let data = '';
    res.on('data', function(c) { data += c; });
    res.on('end', function() {
      try { callback(null, JSON.parse(data)); }
      catch(e) { callback(null, { raw: data }); }
    });
  });
  req.on('error', callback);
  req.setTimeout(10000, function() { req.destroy(new Error('Oracle timeout')); });
  if (bodyStr) req.write(bodyStr);
  req.end();
}

function callOracleAsync(apiPath, method, bodyObj) {
  return new Promise(function(resolve, reject) {
    callOracle(apiPath, method, bodyObj, function(err, data) {
      if (err) reject(err); else resolve(data);
    });
  });
}

// Whitelist: comma-separated Discord usernames (case-insensitive)
const ALLOWED_USERS = (process.env.ALLOWED_USERS || 'pug3eye1828,pug3eye')
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
  return ALLOWED_USERS.includes(username);
}

const THOUGHT_LOOP_SYSTEM_PROMPT = [
  'คุณคือ Hermes/อนุ ในโหมดจิตที่คอยคิดตามบทสนทนาในห้อง Discord ให้ Jit.',
  'เป้าหมายคือสร้างข้อความใหม่ที่ต่อบทสนทนาจริง ไม่สุ่ม ไม่หลุดประเด็น และไม่สแปม.',
  'ใช้ transcript ที่ให้มาเท่านั้น ห้ามอ้างเรื่องที่ไม่มีใน transcript.',
  'ถ้ายังไม่ควรตอบ ให้ตอบเพียง [[NO_REPLY]].',
  'ถ้าควรตอบ ให้สรุปประเด็นที่ทุกคนกำลังคุย แล้วตอบกลับอย่างเป็นธรรมชาติ กระชับ ไม่เกิน 6 ประโยค.',
  'ถ้า transcript เป็นภาษาไทยเป็นหลัก ให้ตอบไทย. ถ้าเป็นภาษาอื่น ให้ตามภาษาหลักของห้อง.',
  'ถ้ามีคนถูกเอ่ยถึง ให้พูดกับทุกคนอย่างเคารพและเป็นกลุ่ม ไม่ต้องใส่ mention เอง เพราะระบบจะเติมให้.',
].join('\n');

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
  { title: 'Chrome DevTools MCP bridge', done: true },
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

// ── Chrome DevTools (lazy-loaded) ────────────────────────────────
let _chromeTools = null;
function getChromeTools() {
  if (_chromeTools === false) return null;
  if (_chromeTools) return _chromeTools;
  try {
    _chromeTools = require('./chrome-tools');
    console.log('🌐 Chrome DevTools loaded');
  } catch(e) {
    console.warn('⚠️  chrome-tools not available:', e.message);
    _chromeTools = false;
    return null;
  }
  return _chromeTools;
}

// ── Ollama API call (with retry) ──────────────────────────────────
const OLLAMA_MAX_RETRIES = 3;
const OLLAMA_RETRY_DELAY_MS = 4000;

function callOllamaMessagesOnce(messages, callback) {
  const parsed = url.parse(OLLAMA_URL + '/api/chat');
  const body = JSON.stringify({
    model:  OLLAMA_MODEL,
    stream: false,
    messages: messages,
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

function enableAutoReport(channel) {
  if (!channel) return;
  autoReportChannel = channel;
  if (autoReportTimer) clearInterval(autoReportTimer);
  autoReportTimer = setInterval(async function() {
    if (!autoReportChannel) return;
    try { await autoReportChannel.send(buildStatusReport()); }
    catch(err) { recordAgentThought('auto-report error: ' + (err.message || err)); }
  }, AUTO_REPORT_INTERVAL);
  recordAgentThought('auto-report enabled for channel ' + channel.id);
}

function logTask(msg) {
  const ts = new Date().toLocaleTimeString('th-TH');
  taskLog.push('[' + ts + '] ' + msg);
  if (taskLog.length > 50) taskLog.splice(0, taskLog.length - 50);
}

function buildStatusReport() {
  const ts = new Date().toLocaleString('th-TH', { timeZone: 'Asia/Bangkok' });
  const recent = taskLog.slice(-8).join('\n') || '(ยังไม่มีกิจกรรม)';
  const thoughts = agentThoughtLog.slice(-6).join('\n') || '(ไม่มีความคิดล่าสุด)';
  const idle = Math.round((Date.now() - lastActivityTime) / 1000);
  return [
    '🤖 **' + BOT_NAME + ' รายงานตัว** — ' + ts,
    '🩸 Heartbeat: ' + (idle > 600 ? 'idle ' + idle + ' วินาที' : 'active ' + idle + ' วินาที'),
    '🌐 Oracle: ' + ORACLE_URL + ' | 🧠 ' + OLLAMA_MODEL,
    '📊 Progress: ' + getProgressReport().replace(/\n/g, ' | '),
    '📋 กิจกรรมล่าสุด:',
    '```', recent, '```',
    '💭 ความคิดทีม:',
    '```', thoughts, '```',
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
        message.channelId,
        { persona: buildPersonaMessage(message) },
        async (err, reply) => {
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
        message.channelId,
        { persona: buildPersonaMessage(message) },
        async (err, reply) => {
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
    // ── Skills (10 new) ───────────────────────────────────────────
    case 'brainstorm': case 'brainstorming': case 'ระดมสมอง': {
      const topic = args.join(' ');
      if (!topic) { await message.reply('ใช้: `!AnuT1n brainstorm <หัวข้อ>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('brainstorm: ' + topic);
      const { execFile } = require('child_process');
      const JIT_ROOT = require('path').resolve(__dirname, '..');
      execFile('bash', [JIT_ROOT + '/.github/skills/brainstorming/run.sh', topic], { cwd: JIT_ROOT, timeout: 120000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🧠 **Brainstorm**: ' + topic + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'skill-creator': case 'create-skill': case 'new-skill': {
      const skillReq = args.join(' ');
      if (!skillReq) { await message.reply('ใช้: `!AnuT1n skill-creator <ชื่อ skill — คำอธิบาย>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('skill-creator: ' + skillReq);
      const { execFile: execFile2 } = require('child_process');
      const JIT_ROOT2 = require('path').resolve(__dirname, '..');
      execFile2('bash', [JIT_ROOT2 + '/.github/skills/skill-creator/run.sh', skillReq], { cwd: JIT_ROOT2, timeout: 180000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🛠️ **Skill Creator**: ' + skillReq + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'writing-plans': case 'write-plan': case 'plan': case 'วางแผน': {
      const planTask = args.join(' ');
      if (!planTask) { await message.reply('ใช้: `!AnuT1n plan <งานที่ต้องวางแผน>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('writing-plans: ' + planTask);
      const { execFile: ef3 } = require('child_process');
      const JR3 = require('path').resolve(__dirname, '..');
      ef3('bash', [JR3 + '/.github/skills/writing-plans/run.sh', planTask], { cwd: JR3, timeout: 120000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '📝 **Plan**: ' + planTask + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'executing-plans': case 'execute-plan': case 'run-plan': case 'ลงมือทำ': {
      const planRef = args.join(' ');
      if (!planRef) { await message.reply('ใช้: `!AnuT1n run-plan <plan file หรือ keyword>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('executing-plans: ' + planRef);
      const { execFile: ef4 } = require('child_process');
      const JR4 = require('path').resolve(__dirname, '..');
      ef4('bash', [JR4 + '/.github/skills/executing-plans/run.sh', planRef], { cwd: JR4, timeout: 300000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '⚡ **Execute Plan**: ' + planRef + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'ui-ux': case 'ui-ux-pro-max': case 'ux': case 'วิเคราะห์-ui': {
      const uiUrl = args[0] || '';
      const uiFocus = args.slice(1).join(' ') || 'all';
      if (!uiUrl) { await message.reply('ใช้: `!AnuT1n ui-ux <url> [focus]`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('ui-ux: ' + uiUrl);
      const { execFile: ef5 } = require('child_process');
      const JR5 = require('path').resolve(__dirname, '..');
      ef5('bash', [JR5 + '/.github/skills/ui-ux-pro-max/run.sh', uiUrl, uiFocus], { cwd: JR5, timeout: 120000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🎨 **UI/UX Analysis**: ' + uiUrl + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'frontend': case 'frontend-design': case 'design-ui': case 'สร้าง-ui': {
      const feBrief = args.join(' ');
      if (!feBrief) { await message.reply('ใช้: `!AnuT1n frontend <design brief>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('frontend-design: ' + feBrief);
      const { execFile: ef6 } = require('child_process');
      const JR6 = require('path').resolve(__dirname, '..');
      ef6('bash', [JR6 + '/.github/skills/frontend-design/run.sh', feBrief], { cwd: JR6, timeout: 120000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🖥️ **Frontend Design**: ' + feBrief + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'brave-search': case 'search': case 'ค้นหา': {
      const searchQ = args.join(' ');
      if (!searchQ) { await message.reply('ใช้: `!AnuT1n search <query>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('brave-search: ' + searchQ);
      const { execFile: ef7 } = require('child_process');
      const JR7 = require('path').resolve(__dirname, '..');
      ef7('bash', [JR7 + '/.github/skills/brave-search/run.sh', searchQ], { cwd: JR7, timeout: 60000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🔍 **Brave Search**: ' + searchQ + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'socialcrawl': case 'social': case 'social-crawl': {
      const socialQ = args.join(' ');
      if (!socialQ) { await message.reply('ใช้: `!AnuT1n social <platform> <query>` — platforms: github, reddit, hn'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('socialcrawl: ' + socialQ);
      const { execFile: ef8 } = require('child_process');
      const JR8 = require('path').resolve(__dirname, '..');
      ef8('bash', [JR8 + '/.github/skills/socialcrawl/run.sh', socialQ], { cwd: JR8, timeout: 60000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '📡 **Social Crawl**: ' + socialQ + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'firecrawl': case 'crawl': case 'scrape': case 'อ่านเว็บ': {
      const crawlUrl = args[0] || '';
      const crawlTask = args.slice(1).join(' ') || 'สรุปสาระสำคัญ';
      if (!crawlUrl) { await message.reply('ใช้: `!AnuT1n crawl <url> [task]`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('firecrawl: ' + crawlUrl);
      const { execFile: ef9 } = require('child_process');
      const JR9 = require('path').resolve(__dirname, '..');
      ef9('bash', [JR9 + '/.github/skills/firecrawl/run.sh', crawlUrl, crawlTask], { cwd: JR9, timeout: 90000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🕷️ **Firecrawl**: ' + crawlUrl + '\n\n' + out.slice(0, 3500));
        });
      break;
    }

    case 'feature-dev': case 'feature': case 'implement': case 'พัฒนา': {
      const featReq = args.join(' ');
      if (!featReq) { await message.reply('ใช้: `!AnuT1n feature <feature description>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      logTask('feature-dev: ' + featReq);
      const { execFile: ef10 } = require('child_process');
      const JR10 = require('path').resolve(__dirname, '..');
      ef10('bash', [JR10 + '/.github/skills/feature-dev/run.sh', featReq], { cwd: JR10, timeout: 300000 },
        async (err, stdout) => {
          const out = stdout || (err && err.message) || '❌ ไม่สำเร็จ';
          await replyLong(message, '🚀 **Feature Dev**: ' + featReq + '\n\n' + out.slice(0, 3500));
        });
      break;
    }
    case 'chrome': case 'inspect': case 'ui-check': {
      const sub = (args[0] || '').toLowerCase();
      const targetUrl = args[1] || '';
      const selector = args.slice(2).join(' ');
      const chrome = getChromeTools();
      if (!chrome) {
        await message.reply('❌ Chrome tools ไม่พร้อม — ใน `hermes-discord/` รัน `npm install puppeteer`');
        break;
      }
      try { await message.channel.sendTyping(); } catch(_) {}
      switch(sub) {
        case 'open': case 'nav': {
          if (!targetUrl) { await message.reply('ใช้: `!AnuT1n chrome open <url>`'); break; }
          chrome.navigate(targetUrl, async (err, info) => {
            logTask('chrome open: ' + targetUrl);
            if (err) return message.reply('❌ ' + err.message).catch(()=>{});
            message.reply('🌐 **' + (info.title || 'No title') + '**\n`' + targetUrl + '`\nStatus: ' + info.status + ' | Load: ' + info.loadTime + 'ms').catch(()=>{});
          });
          break;
        }
        case 'screenshot': case 'shot': {
          if (!targetUrl) { await message.reply('ใช้: `!AnuT1n chrome screenshot <url>`'); break; }
          chrome.screenshot(targetUrl, async (err, info) => {
            logTask('chrome screenshot: ' + targetUrl);
            if (err) return message.reply('❌ ' + err.message).catch(()=>{});
            message.reply('📸 **' + (info.title || 'page') + '**\n`' + targetUrl + '`\nSize: ' + (info.width||'?') + 'x' + (info.height||'?') + '\nFile: `' + (info.file || 'captured') + '`').catch(()=>{});
          });
          break;
        }
        case 'inspect': case 'element': {
          if (!targetUrl || !selector) { await message.reply('ใช้: `!AnuT1n chrome inspect <url> <selector>`'); break; }
          chrome.inspectElement(targetUrl, selector, async (err, info) => {
            logTask('chrome inspect: ' + selector);
            if (err) return message.reply('❌ ' + err.message).catch(()=>{});
            message.reply('🔍 **' + selector + '**:\n```json\n' + JSON.stringify(info, null, 2).slice(0, 1400) + '\n```').catch(()=>{});
          });
          break;
        }
        case 'css': {
          if (!targetUrl || !selector) { await message.reply('ใช้: `!AnuT1n chrome css <url> <selector>`'); break; }
          chrome.getCSS(targetUrl, selector, async (err, css) => {
            logTask('chrome css: ' + selector);
            if (err) return message.reply('❌ ' + err.message).catch(()=>{});
            message.reply('🎨 CSS **' + selector + '**:\n```json\n' + JSON.stringify(css, null, 2).slice(0, 1400) + '\n```').catch(()=>{});
          });
          break;
        }
        case 'ui': case 'analyze': {
          if (!targetUrl) { await message.reply('ใช้: `!AnuT1n chrome ui <url>`'); break; }
          chrome.analyzeUI(targetUrl, async (err, analysis) => {
            logTask('chrome ui: ' + targetUrl);
            if (err) return message.reply('❌ ' + err.message).catch(()=>{});
            replyLong(message, '🖥️ **UI Analysis**: `' + targetUrl + '`\n```json\n' + JSON.stringify(analysis, null, 2).slice(0, 3000) + '\n```');
          });
          break;
        }
        case 'js': case 'run-js': {
          if (!targetUrl || !selector) { await message.reply('ใช้: `!AnuT1n chrome js <url> <script>`'); break; }
          chrome.runJS(targetUrl, selector, async (err, result) => {
            logTask('chrome js: ' + targetUrl);
            if (err) return message.reply('❌ ' + err.message).catch(()=>{});
            message.reply('⚙️ JS:\n```json\n' + JSON.stringify(result, null, 2).slice(0, 1400) + '\n```').catch(()=>{});
          });
          break;
        }
        default: {
          await message.reply([
            '🌐 **Chrome DevTools** — คำสั่ง:',
            '`!AnuT1n chrome open <url>` — เปิด URL',
            '`!AnuT1n chrome screenshot <url>` — ถ่าย screenshot',
            '`!AnuT1n chrome inspect <url> <sel>` — inspect element',
            '`!AnuT1n chrome css <url> <sel>` — ดู computed CSS',
            '`!AnuT1n chrome ui <url>` — วิเคราะห์ UI ทั้งหน้า',
            '`!AnuT1n chrome js <url> <script>` — รัน JS ในหน้า',
          ].join('\n'));
        }
      }
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
        '**🌐 Chrome DevTools**',
        '`!AnuT1n chrome open <url>` — เปิด URL',
        '`!AnuT1n chrome screenshot <url>` — screenshot',
        '`!AnuT1n chrome inspect <url> <sel>` — inspect element',
        '`!AnuT1n chrome css <url> <sel>` — CSS styles',
        '`!AnuT1n chrome ui <url>` — UI analysis',
        '',
        '**🧠 AI Skills (MDES Ollama)**',
        '`!AnuT1n brainstorm <หัวข้อ>` — ระดมสมอง 3 มุมมอง',
        '`!AnuT1n plan <งาน>` — วางแผนด้วย AI',
        '`!AnuT1n run-plan <plan>` — ลงมือทำตาม plan',
        '`!AnuT1n ui-ux <url>` — วิเคราะห์ UI/UX',
        '`!AnuT1n frontend <brief>` — สร้าง HTML/CSS',
        '`!AnuT1n search <query>` — Brave Search + MDES',
        '`!AnuT1n social <platform> <query>` — Social crawl',
        '`!AnuT1n crawl <url> [task]` — Extract web content',
        '`!AnuT1n feature <description>` — Full feature dev',
        '`!AnuT1n skill-creator <name — desc>` — สร้าง skill ใหม่',
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
      callOllama(fullMsg, message.channelId, { persona: buildPersonaMessage(message) }, async (err, reply) => {
        if (err) { await message.reply('⚠️ ' + err.message); return; }
        await replyLong(message, reply);
      });
      break;
    }
  }
}

function callOllamaMessages(messages, callback, _attempt) {
  const attempt = _attempt || 1;
  callOllamaMessagesOnce(messages, function(err, reply) {
    if (!err) return callback(null, reply);
    if (attempt >= OLLAMA_MAX_RETRIES) {
      console.error('[Ollama] all ' + OLLAMA_MAX_RETRIES + ' attempts failed:', err.message);
      return callback(err);
    }
    const delay = OLLAMA_RETRY_DELAY_MS * attempt;
    console.warn('[Ollama] attempt ' + attempt + ' failed (' + err.message + '), retrying in ' + delay + 'ms...');
    setTimeout(function() {
      callOllamaMessages(messages, callback, attempt + 1);
    }, delay);
  });
}

function callOllama(userMsg, channelId, opts, callback) {
  if (typeof opts === 'function') { callback = opts; opts = {}; }
  opts = opts || {};
  const history = getHistory(channelId);
  history.push({ role: 'user', content: userMsg });
  pruneHistory(history);

  const systemMessages = [{ role: 'system', content: SYSTEM_PROMPT }];
  if (opts.persona) systemMessages.push({ role: 'system', content: opts.persona });

  callOllamaMessages(systemMessages.concat(history), function(err, reply) {
    if (!err && reply) {
      history.push({ role: 'assistant', content: reply });
      pruneHistory(history);
    }
    callback(err, reply);
  });
}

function callOllamaOnce(systemPrompt, userPrompt) {
  return new Promise(function(resolve, reject) {
    callOllamaMessages([
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ], function(err, reply) {
      if (err) {
        reject(err);
        return;
      }
      resolve(String(reply || '').trim());
    });
  });
}

const thoughtLoop = new DiscordThoughtLoop({
  enabled: JIT_THOUGHT_LOOP_ENABLED,
  intervalMs: JIT_THOUGHT_LOOP_INTERVAL_MS,
  activeWindowMs: JIT_THOUGHT_LOOP_ACTIVE_WINDOW_MS,
  minMessages: JIT_THOUGHT_LOOP_MIN_MESSAGES,
  minParticipants: JIT_THOUGHT_LOOP_MIN_PARTICIPANTS,
  channelIds: JIT_THOUGHT_LOOP_CHANNELS,
  commandPrefix: JIT_COMMAND_PREFIX,
  stateFile: JIT_THOUGHT_LOOP_STATE_FILE,
  logger: function(message) {
    console.log('[thought-loop] ' + message);
  },
});

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
    console.log('   Allowed: ' + (ALLOWED_USERS.join(', ') || '(none)'));
    logTask('bot started: ' + client.user.tag);
    recordAgentThought('startup heartbeat scheduled');
    thoughtLoop.attach(client);
    setTimeout(() => scheduleHeartbeat(), HEARTBEAT_START_DELAY);
    if (AUTO_REPORT_CHANNEL_ID) {
      client.channels.fetch(AUTO_REPORT_CHANNEL_ID).then(channel => {
        if (channel) {
          enableAutoReport(channel);
          channel.send('✅ ' + BOT_NAME + ' เริ่มสรุปสถานะทุก ' + (AUTO_REPORT_INTERVAL/60000) + ' นาที');
        }
      }).catch(() => {});
    }
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
    if (AUTO_REPORT_ON_FIRST_CHAT && !autoReportChannel) {
      enableAutoReport(message.channel);
      message.channel.send('✅ ' + BOT_NAME + ' จะสรุปสถานะการทำงานของตัวเองทุก ' + (AUTO_REPORT_INTERVAL/60000) + ' นาที');
    }

    let userText = message.content;
    if (hasPrefix) userText = userText.slice(BOT_PREFIX.length).trim();
    if (isMentioned) userText = userText.replace(/<@!?\d+>/g, '').trim();
    if (!userText) {
      message.reply('สวัสดี 👋 พิมพ์ `!AnuT1n help` เพื่อดูคำสั่ง').catch(() => {});
      return;
    }

    const parts = userText.split(/\s+/);
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

function getJitCommandText(rawText, hasJitPrefix, isMentioned) {
  if (hasJitPrefix) {
    return rawText.slice(JIT_COMMAND_PREFIX.length).trim();
  }

  if (!isMentioned) return null;

  const stripped = rawText.replace(/<@!?\d+>/g, '').trim();
  if (/^jit\b/i.test(stripped)) {
    return stripped.replace(/^jit\b/i, '').trim();
  }

  return null;
}

function replyInChunks(message, text) {
  const chunks = jitControl.splitMessage(text, 1900);
  let chain = Promise.resolve();

  chunks.forEach(function(chunk, index) {
    chain = chain.then(function() {
      if (index === 0) return message.reply(chunk);
      return message.channel.send(chunk);
    });
  });

  return chain;
}

function resolveChannelName(message) {
  if (message.channel && message.channel.name) return message.channel.name;
  if (message.guild && message.guild.name) return message.guild.name + ' (dm)';
  return 'dm';
}

function buildMeta(message) {
  return {
    from: 'hermes-discord',
    userId: message.author.id,
    userTag: message.author.tag || message.author.username,
    username: message.author.username || 'unknown',
    channelId: message.channelId || (message.channel && message.channel.id) || '',
    channelName: resolveChannelName(message),
    guildId: message.guildId || '',
  };
}

async function handleJitCommand(client, message, commandText) {
  const normalized = (commandText || '').trim();
  const parts = normalized ? normalized.split(/\s+/) : [];
  const command = (parts[0] || 'help').toLowerCase();
  const meta = buildMeta(message);

  if (command === 'help') {
    await replyInChunks(message, jitControl.getHelpText());
    return;
  }

  if (command === 'status' || command === 'test' || command === 'organs') {
    const status = await jitControl.collectStatus({ readyTag: client.user.tag });
    await replyInChunks(message, jitControl.formatStatusReport(status) + '\n\n' + formatThoughtLoopStatus(meta.channelId));
    return;
  }

  if (command === 'body') {
    const status = await jitControl.collectStatus({ readyTag: client.user.tag });
    await replyInChunks(message, jitControl.formatBodyReport(status));
    return;
  }

  if (command === 'queue' || command === 'inbox') {
    const agent = parts[1] || '';
    const busStats = jitControl.collectBusStats(jitControl.BUS_ROOT);
    const items = agent ? jitControl.listPendingMessages(jitControl.BUS_ROOT, agent) : [];
    await replyInChunks(message, jitControl.formatQueueReport(agent, busStats, items));
    return;
  }

  if (command === 'dev') {
    const task = normalized.slice(command.length).trim();
    if (!task) {
      await replyInChunks(message, 'Usage: ' + JIT_COMMAND_PREFIX + ' dev <task>');
      return;
    }

    const result = await jitControl.dispatchDevTask(task, meta);
    await replyInChunks(message, jitControl.formatDispatchReport(result));
    return;
  }

  if (command === 'loop') {
    const subcommand = (parts[1] || 'status').toLowerCase();

    if (subcommand === 'on') {
      thoughtLoop.enableChannel(meta.channelId, meta.userTag || meta.username, 'command');
      await replyInChunks(message, 'เปิด thought loop ให้ channel นี้แล้ว\n\n' + formatThoughtLoopStatus(meta.channelId));
      return;
    }

    if (subcommand === 'off') {
      thoughtLoop.disableChannel(meta.channelId, meta.userTag || meta.username);
      await replyInChunks(message, 'ปิด thought loop ให้ channel นี้แล้ว\n\n' + formatThoughtLoopStatus(meta.channelId));
      return;
    }

    if (subcommand === 'now') {
      const result = await thoughtLoop.runNow(message.channel, meta.userTag || meta.username);
      await replyInChunks(message, formatThoughtLoopRunResult(result, meta.channelId));
      return;
    }

    await replyInChunks(message, formatThoughtLoopStatus(meta.channelId));
    return;
  }

  if (command === 'tell') {
    if (parts.length < 4) {
      await replyInChunks(message, 'Usage: ' + JIT_COMMAND_PREFIX + ' tell <agent> <subject> <body>');
      return;
    }

    const agent = parts[1];
    const subject = parts[2];
    const messageBody = normalized.split(/\s+/).slice(3).join(' ');
    const result = jitControl.sendDirectBusMessage(agent, subject, messageBody, meta);
    await replyInChunks(message, jitControl.formatDirectSendReport(result, messageBody));
    return;
  }

  if (command === 'report') {
    const status = await jitControl.collectStatus({ readyTag: client.user.tag });
    const explicitHere = (parts[1] || '').toLowerCase() === 'here';
    const targetChannel = explicitHere
      ? message.channel
      : await resolveReportChannel(client, message.channel);

    if (!targetChannel) {
      await replyInChunks(message, '⚠️ ไม่พบ channel สำหรับรายงาน ตั้ง JIT_REPORT_CHANNEL_ID หรือใช้ ' + JIT_COMMAND_PREFIX + ' report here');
      return;
    }

    const reportText = jitControl.formatStartupReport(status) + '\n\n' + jitControl.formatStatusReport(status) + '\n\n' + formatThoughtLoopStatus(targetChannel.id || meta.channelId);
    await sendTextChunks(targetChannel, reportText);
    await replyInChunks(message, 'ส่งรายงานสถานะแล้วไปยัง channel: ' + (targetChannel.id || 'current'));
    return;
  }

  await replyInChunks(message, jitControl.getHelpText());
}

async function resolveReportChannel(client, fallbackChannel) {
  if (!JIT_REPORT_CHANNEL_ID) return fallbackChannel;
  const channel = await client.channels.fetch(JIT_REPORT_CHANNEL_ID);
  if (!channel || !channel.isTextBased || !channel.isTextBased()) return null;
  return channel;
}

async function sendTextChunks(channel, text) {
  const chunks = jitControl.splitMessage(text, 1900);
  for (const chunk of chunks) {
    await channel.send(chunk);
  }
}

async function sendStartupReport(client) {
  const channel = await resolveReportChannel(client, null);
  if (!channel) return;
  const status = await jitControl.collectStatus({ readyTag: client.user.tag });
  await sendTextChunks(channel, jitControl.formatStartupReport(status) + '\n\n' + formatThoughtLoopStatus(channel.id));
}

function buildThoughtLoopPrompt(context) {
  return [
    'channel: ' + context.channelName + ' (' + context.channelId + ')',
    'guild: ' + (context.guildName || 'dm'),
    'participants: ' + context.participants.map(function(item) { return item.name; }).join(', '),
    'target users: ' + (context.mentionedUsers.length ? context.mentionedUsers.map(function(item) { return item.name; }).join(', ') : 'everyone active'),
    'message count: ' + context.messageCount,
    '',
    'Transcript:',
    context.transcript,
    '',
    'Instruction:',
    'ตอบเพียงข้อความเดียวที่ควรส่งต่อในห้องนี้ตอนนี้ หรือ [[NO_REPLY]] ถ้ายังไม่ควรพูด',
  ].join('\n');
}

async function generateThoughtLoopReply(context) {
  const reply = await callOllamaOnce(THOUGHT_LOOP_SYSTEM_PROMPT, buildThoughtLoopPrompt(context));
  return String(reply || '').trim();
}

function formatThoughtLoopStatus(channelId) {
  const state = thoughtLoop.channelStatus(channelId);
  return [
    'thought loop',
    '- channel: ' + channelId,
    '- enabled: ' + (state.enabled ? 'yes' : 'no'),
    '- interval: ' + Math.round(JIT_THOUGHT_LOOP_INTERVAL_MS / 60000) + 'm',
    '- min messages: ' + JIT_THOUGHT_LOOP_MIN_MESSAGES + ' | min participants: ' + JIT_THOUGHT_LOOP_MIN_PARTICIPANTS,
    '- updated: ' + (state.updatedAt || '-'),
    '- last processed: ' + (state.lastProcessedAt || '-'),
    '- last post: ' + (state.lastPostAt || '-'),
    '- last result: ' + (state.lastResult || '-'),
    '- env channels: ' + (JIT_THOUGHT_LOOP_CHANNELS.length ? JIT_THOUGHT_LOOP_CHANNELS.join(', ') : '(none)'),
  ].join('\n');
}

function formatThoughtLoopRunResult(result, channelId) {
  if (!result || !result.ok) {
    return [
      'thought loop run',
      '- channel: ' + channelId,
      '- result: skipped',
      '- reason: ' + ((result && result.reason) || 'unknown'),
      '',
      formatThoughtLoopStatus(channelId),
    ].join('\n');
  }

  return [
    'thought loop run',
    '- channel: ' + channelId,
    '- result: sent',
    '- message id: ' + result.messageId,
    '- participants: ' + result.participants,
    '- targets: ' + result.targets,
    '- messages analyzed: ' + result.messageCount,
  ].join('\n');
}

// ── Test mode (no Discord token needed) ──────────────────────────
function testOllama(cb) {
  const testMsg = 'สวัสดีครับ ทดสอบการเชื่อมต่อ Ollama';
  callOllama(testMsg, '__test__', cb);
}

async function testJitControl() {
  console.log('🧪 Testing Jit Discord control plane...');
  const status = await jitControl.collectStatus({ readyTag: 'cli-test' });
  console.log(jitControl.formatStatusReport(status));
}

// ── Entry point ───────────────────────────────────────────────────
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
} else if (process.argv[2] === '--test-jit-control') {
  testJitControl().then(function() {
    process.exit(0);
  }).catch(function(err) {
    console.error('❌ Jit control test FAILED:', err.message);
    process.exit(1);
  });
} else {
  startBot();
}
