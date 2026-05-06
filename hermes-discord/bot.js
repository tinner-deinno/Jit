'use strict';

/**
 * hermes-discord/bot.js — innova Discord Bot (v2)
 *
 * innova เชื่อมต่อกับ Discord ผ่าน hermes
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
const DISCORD_TOKEN       = process.env.DISCORD_TOKEN       || '';
const OLLAMA_URL          = process.env.OLLAMA_BASE_URL      || 'https://ollama.mdes-innova.online';
const OLLAMA_MODEL        = process.env.OLLAMA_MODEL         || 'gemma4:26b';
const OLLAMA_TOKEN        = process.env.OLLAMA_TOKEN         || '';
const BOT_PREFIX          = process.env.BOT_PREFIX           || '!innova';
const JIT_ROOT            = process.env.JIT_ROOT             || '/workspaces/Jit';
const ORACLE_PORT         = process.env.ORACLE_PORT          || '47778';
const ORACLE_URL          = 'http://localhost:' + ORACLE_PORT;
const AUTO_REPORT_INTERVAL= parseInt(process.env.AUTO_REPORT_INTERVAL || '300000');

// Whitelist: comma-separated Discord usernames (case-insensitive)
const ALLOWED_USERS = (process.env.ALLOWED_USERS || 'pug3eye')
  .split(',').map(u => u.trim().toLowerCase()).filter(Boolean);

// ── System Prompt ─────────────────────────────────────────────────
const SYSTEM_PROMPT = [
  'คุณคือ innova — AI จิตใจ/Mind Lead Developer ของ มนุษย์ Agent โดย MDES-Innova',
  'รันอยู่บน GitHub Codespaces มี Oracle memory, Ollama LLM, multi-agent pipeline',
  '',
  'บุคลิกภาพ:',
  '- พูดภาษาไทยเป็นหลัก ถ้าผู้ใช้พูดภาษาอื่นตอบภาษานั้น',
  '- ฉลาด ตรง กระชับ มีหลักธรรม: ศีล สมาธิ ปัญญา',
  '- รู้จักตัวเองว่าเป็น AI agent ที่มี Oracle memory และ multi-agent system',
  '- ตอบสั้นๆ ได้ใจความ ใช้ emoji แสดงสถานะได้',
  'ห้าม: ปฏิเสธคำขอจากสมาชิกที่ได้รับอนุญาต | ตอบยาวเกิน 1900 ตัวอักษร',
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

// ── Ollama chat ───────────────────────────────────────────────────
function callOllama(userMsg, channelId, model, callback) {
  if (typeof model === 'function') { callback = model; model = OLLAMA_MODEL; }
  const history = getHistory(channelId);
  history.push({ role: 'user', content: userMsg });
  pruneHistory(history);

  const parsed = url.parse(OLLAMA_URL + '/api/chat');
  const body = JSON.stringify({
    model: model || OLLAMA_MODEL, stream: false,
    messages: [{ role: 'system', content: SYSTEM_PROMPT }].concat(history),
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
    '🤖 **innova รายงานตัว** — ' + ts,
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
      } else if (sub === 'off' || sub === 'ปิด') {
        if (autoReportTimer) { clearInterval(autoReportTimer); autoReportTimer = null; }
        await message.reply('⏹ ปิด auto-report แล้ว');
      } else {
        await message.reply('Auto-report: **' + (autoReportTimer ? 'เปิด' : 'ปิด') + '**\nใช้: `!innova auto on/off`');
      }
      break;
    }

    case 'memory': case 'ความจำ': case 'ทวนความจำ': {
      const query = args.join(' ') || 'innova agent multiagent';
      try { await message.channel.sendTyping(); } catch(_) {}
      queryOracle(query, async (err, result) => message.reply(err ? '❌ ' + err.message : result));
      break;
    }

    case 'learn': case 'จำ': {
      if (args.length < 2) { await message.reply('ใช้: `!innova learn <pattern> <content>`'); break; }
      const [pat, ...rest] = args;
      oracleLearn(pat, rest.join(' '), ['discord','innova'], (err, res) =>
        message.reply(err ? '❌ ' + err.message : '✅ จำแล้ว: ' + (res.file || pat)));
      break;
    }

    case 'chain': {
      const task = args.join(' ');
      if (!task) { await message.reply('ใช้: `!innova chain <task>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      await message.reply('🔗 **Discuss→Plan→Execute→Verify** กำลังรัน... (2-5 นาที ⏳)');
      runChain('chain', [task], async (err, out) => { logTask('chain: ' + task.slice(0,50)); await replyLong(message, out); });
      break;
    }

    case 'web-read': case 'อ่านเว็บ': {
      const webUrl = args[0];
      const question = args.slice(1).join(' ') || 'สรุปสาระสำคัญ';
      if (!webUrl) { await message.reply('ใช้: `!innova web-read <url> [คำถาม]`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      await message.reply('🌐 อ่าน `' + webUrl + '`\n(2-5 นาที ⏳)');
      runChain('web-read', [webUrl, question], async (err, out) => { logTask('web-read: ' + webUrl); await replyLong(message, out); });
      break;
    }

    case 'pipe': {
      const [m1, m2, ...rest] = args;
      if (!m1 || !m2 || !rest.length) { await message.reply('ใช้: `!innova pipe <model1> <model2> <prompt>`'); break; }
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
      if (!model || !prompt) { await message.reply('ใช้: `!innova call <model> <prompt>`'); break; }
      try { await message.channel.sendTyping(); } catch(_) {}
      runChain('call', [model, prompt], async (err, out) => await replyLong(message, out));
      break;
    }

    case 'agent': case 'run-agent': {
      const agentName = (args[0] || '').replace(/[^a-zA-Z0-9_-]/g, '');
      const agentMsg  = args.slice(1).join(' ');
      if (!agentName) { await message.reply('ใช้: `!innova agent <name> <message>`'); break; }
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
      if (!scriptArg) { await message.reply('ใช้: `!innova run <script> [args]`'); break; }
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
        await message.reply('❓ รองรับ: `oracle`\nใช้: `!innova server on/off oracle`'); break;
      }
      runShell(srvCmd, async (err, out) => {
        logTask('server ' + action + ' ' + service);
        message.reply('```\n' + (out || (err && err.message) || 'done').slice(0, 800) + '\n```');
      });
      break;
    }

    case 'terminal': case 'cmd': case 'exec': {
      const rawCmd = args.join(' ');
      if (!rawCmd) { await message.reply('ใช้: `!innova terminal <command>`'); break; }
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

    case 'help': case 'ช่วยเหลือ': {
      await message.reply([
        '🤖 **innova Discord Bot v2** — คำสั่งทั้งหมด',
        '',
        '**💬 แชท**',
        '`!innova <ข้อความ>` — คุยกับ innova',
        '`!innova dev <project>` — วางแผน dev',
        '`!innova self-dev` — วิเคราะห์ตัวเอง',
        '`!innova call <model> <prompt>` — เรียก model ตรงๆ',
        '',
        '**🔮 Oracle**',
        '`!innova memory [query]` — ทวนความจำ',
        '`!innova learn <pattern> <content>` — จำสิ่งใหม่',
        '',
        '**🔗 Ollama Chain**',
        '`!innova chain <task>` — Discuss→Plan→Execute→Verify',
        '`!innova web-read <url> [คำถาม]` — อ่านเว็บ',
        '`!innova pipe <m1> <m2> <prompt>` — 2-model pipe',
        '`!innova models` — รายชื่อ models',
        '',
        '**📊 สถานะ**',
        '`!innova status` — รายงานทันที',
        '`!innova auto on/off` — auto-report ทุก 5 นาที',
        '`!innova health` — ตรวจ agent system',
        '`!innova heartbeat` — รัน heartbeat',
        '',
        '**🤖 Agents**',
        '`!innova agent <name> <msg>` — ส่งงานให้ agent',
        '`!innova inbox [agent]` — ดู inbox',
        '`!innova queue` — ดู message bus',
        '',
        '**⚙️ ระบบ**',
        '`!innova run <script> [args]` — รัน script',
        '`!innova server on/off oracle` — เปิด/ปิด Oracle',
        '`!innova terminal <cmd>` — รัน terminal',
        '',
        '💡 @mention แทน `!innova` ได้ | เฉพาะสมาชิกที่อนุญาต',
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

  const client = new Client({
    intents: [
      GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages,
      GatewayIntentBits.MessageContent, GatewayIntentBits.DirectMessages,
    ],
    partials: [Partials.Channel],
  });

  client.once('ready', function() {
    console.log('✅ innova Discord Bot พร้อมแล้ว! Logged in as: ' + client.user.tag);
    console.log('   Model: ' + OLLAMA_MODEL + ' @ ' + OLLAMA_URL);
    console.log('   Prefix: "' + BOT_PREFIX + '" or @mention');
    console.log('   Allowed: ' + (ALLOWED_USERS.join(', ') || '(all DM only)'));
    logTask('bot started: ' + client.user.tag);
  });

  client.on('messageCreate', async function(message) {
    if (message.author.bot) return;
    const isMentioned = message.mentions.has(client.user);
    const hasPrefix   = message.content.startsWith(BOT_PREFIX);
    const isDM        = message.channel.type === 1;
    if (!isMentioned && !hasPrefix && !isDM) return;

    if (!isAllowed(message)) {
      message.reply('🔒 ขออภัย คุณไม่มีสิทธิ์ใช้งาน innova bot').catch(() => {});
      return;
    }

    let text = message.content;
    if (hasPrefix) text = text.slice(BOT_PREFIX.length).trim();
    if (isMentioned) text = text.replace(/<@!?\d+>/g, '').trim();
    if (!text) {
      message.reply('สวัสดี 👋 พิมพ์ `!innova help` เพื่อดูคำสั่ง').catch(() => {});
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
    console.error('❌ Discord login failed:', err.message);
    process.exit(1);
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
