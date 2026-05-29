'use strict';

/**
 * hermes-discord/bot.js — AnuT1n Discord Bot (v2)
 *
 * innova's child "อนุ" on Discord
 * Powered by multi-backend model router: GitHub Copilot → OpenAI → MDES Ollama
 * Part of มนุษย์ Agent project — Jit (จิต) repo
 *
 * Env vars required:
 *   DISCORD_TOKEN         — Discord bot token
 *
 * Model backend (at least one):
 *   COPILOT_TOKEN         — GitHub Copilot API token (or auto-detect from VS Code)
 *   OPENAI_API_KEY        — OpenAI / Codex key
 *   OLLAMA_TOKEN          — MDES Ollama auth token (fallback)
 *
 * Optional:
 *   MULTI_BACKEND_ORDER   — comma-separated priority, default: copilot,openai,ollama
 *   OLLAMA_BASE_URL       — default: https://ollama.mdes-innova.online
 *   OLLAMA_MODEL          — default: gemma4:26b
 *   BOT_PREFIX            — command prefix, default: !อนุ
 *   JIT_COMMAND_PREFIX    — Jit control prefix, default: !jit
 *   JIT_REPORT_CHANNEL_ID — startup/status report channel
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Client, GatewayIntentBits, Partials, ChannelType, PermissionsBitField } = require('discord.js');
const https = require('https');
const url   = require('url');
const jitControl   = require('./jit-control');
const modelRouter  = require('./model-router');
const agentSpawner = require('./agent-spawner');
const innovaBridge = require('./jit-innova-bridge');
const { DiscordThoughtLoop } = require('./thought-loop');
// jit-mother: Mother orchestrator — delegates to ALL agents + speaks Thai
let jitMother;
try { jitMother = require('../skills/vaja-thai-tts/jit-mother'); }
catch (_) { jitMother = { orchestrate: async() => ({ task:'?', elapsed:'?', agentsInvoked:0, httpAgents:{}, thaiSummary:'jit-mother not found', allResults:[] }), ORGAN_AGENTS: [] }; }

// ── Config ────────────────────────────────────────────────────────
const DISCORD_TOKEN         = process.env.DISCORD_TOKEN       || '';
const OLLAMA_URL            = process.env.OLLAMA_BASE_URL    || 'https://ollama.mdes-innova.online';
const OLLAMA_MODEL          = process.env.OLLAMA_MODEL       || 'gemma4:26b';
const OLLAMA_TOKEN          = process.env.OLLAMA_TOKEN       || '';
const BOT_NAME              = process.env.BOT_NAME           || 'AnuT1n';
const BOT_ALIASES           = (process.env.BOT_ALIASES || 'อนุทิน,ทิน')
  .split(',').map(u => u.trim()).filter(Boolean);
const BOT_PREFIX            = process.env.BOT_PREFIX         || '!AnuT1n';
const JIT_ROOT              = process.env.JIT_ROOT           ||
  (process.platform === 'win32' ? 'C:\\Users\\' + (process.env.USERNAME || 'USER-NT') + '\\DEV\\Jit' : '/workspaces/Jit');
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
const JIT_THOUGHT_LOOP_STATE_FILE = process.env.JIT_THOUGHT_LOOP_STATE_FILE ||
  require('path').join(require('os').tmpdir(), 'hermes-discord-thought-loop.json');

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

// ── Vaja TTS — Thai voice output after every agent response ─────
let vajaSpeakEnabled = process.env.VAJA_SPEAK !== 'off'; // enabled by default

/**
 * vajaSpeak(text) — translate to Thai + speak with PowerShell TTS
 * Non-blocking: fires and forgets (no await needed)
 */
function vajaSpeak(text) {
  if (!vajaSpeakEnabled || !text || text.length < 3) return;
  try {
    // Use agentSpawner.speakAsVaja (translate + speak)
    agentSpawner.speakAsVaja(text, function(err) {
      if (err) console.warn('[vaja-tts] speak error:', err.message);
    });
  } catch (e) {
    console.warn('[vaja-tts] init error:', e.message);
  }
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

function parsePositiveInt(value, fallback) {
  const parsed = parseInt(value || '', 10);
  if (Number.isFinite(parsed) && parsed > 0) return parsed;
  return fallback;
}

function splitCsv(value) {
  return String(value || '')
    .split(',')
    .map(function(item) { return item.trim(); })
    .filter(Boolean);
}

function getHistory(channelId) {
  if (!histories.has(channelId)) histories.set(channelId, []);
  return histories.get(channelId);
}

function pruneHistory(history) {
  if (history.length > 40) history.splice(0, history.length - 40);
}

// ── Model Router API calls (multi-backend: Copilot → OpenAI → Ollama) ──

/**
 * callBotMessages(messages, callback)
 * Wraps model-router.callModel — routes to best available backend.
 * callback(err, reply)
 */
function callBotMessages(messages, callback) {
  modelRouter.callModel(messages, {}, function(err, result) {
    if (err) return callback(err);
    callback(null, result.reply);
  });
}

/**
 * callOllama(userMsg, channelId, callback)
 * Chat function with per-channel conversation history.
 * Uses model-router backend rotation.
 */
function callOllama(userMsg, channelId, callback) {
  const history = getHistory(channelId);
  history.push({ role: 'user', content: userMsg });
  pruneHistory(history);

  const messages = [{ role: 'system', content: SYSTEM_PROMPT }].concat(history);
  modelRouter.callModel(messages, {}, function(err, result) {
    if (!err && result.reply) {
      history.push({ role: 'assistant', content: result.reply });
      pruneHistory(history);
    }
    callback(err, result && result.reply);
  });
}

/**
 * callOllamaOnce(systemPrompt, userPrompt) → Promise<string>
 * One-shot call (used by thought-loop)
 */
function callOllamaOnce(systemPrompt, userPrompt) {
  return modelRouter.callModelPromise(
    [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
    {}
  ).then(function(result) { return result.reply; });
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

  if (!DISCORD_TOKEN.includes('.')) {
    console.error('❌ Suspicious DISCORD_TOKEN format detected.');
    console.error('   Discord bot tokens usually include dot separators, e.g. xxxxx.yyyyy.zzzzz');
    console.error('   Copy the token from the Bot page, not the application client secret.');
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

  // Auto-speak full response in Thai after all chunks sent
  chain = chain.then(function() {
    vajaSpeak(text);
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

  // ── spawn: jit spawns a named agent ─────────────────────────────
  if (command === 'spawn') {
    // Usage: !jit spawn <agent> <message...>
    // Usage: !jit spawn chain <a>+<b>+<c> <message...>
    // Usage: !jit spawn parallel <a>,<b> <message...>
    const subCmd = (parts[1] || '').toLowerCase();

    if (subCmd === 'chain') {
      // !jit spawn chain jit+soma+innova <message>
      const chainStr = parts[2] || '';
      const agentNames = chainStr.split('+').map(function(s) { return s.trim(); }).filter(Boolean);
      const chainMsg = normalized.split(/\s+/).slice(3).join(' ');
      if (!agentNames.length || !chainMsg) {
        await replyInChunks(message, 'Usage: ' + JIT_COMMAND_PREFIX + ' spawn chain <a>+<b>+<c> <message>\nExample: ' + JIT_COMMAND_PREFIX + ' spawn chain jit+soma+innova analyze our microservice architecture');
        return;
      }
      await message.channel.sendTyping();
      const steps = agentNames.map(function(name, i) {
        return { agent: name, message: i === 0 ? chainMsg : chainMsg, passReply: i > 0 };
      });
      try {
        const chainResult = await agentSpawner.spawnAgentChain(steps);
        const lines = ['**Spawn Chain: ' + agentNames.join(' → ') + '**\n'];
        chainResult.results.forEach(function(r) {
          lines.push('**[' + r.agent + ' via ' + r.backend + ']**');
          lines.push(r.reply);
          lines.push('');
        });
        await replyInChunks(message, lines.join('\n'));
      } catch (err) {
        await replyInChunks(message, '⚠️ Chain failed: ' + err.message);
      }
      return;
    }

    if (subCmd === 'parallel') {
      // !jit spawn parallel lak,chamu <message>
      const agentList = (parts[2] || '').split(',').map(function(s) { return s.trim(); }).filter(Boolean);
      const parallelMsg = normalized.split(/\s+/).slice(3).join(' ');
      if (!agentList.length || !parallelMsg) {
        await replyInChunks(message, 'Usage: ' + JIT_COMMAND_PREFIX + ' spawn parallel <a>,<b> <message>\nExample: ' + JIT_COMMAND_PREFIX + ' spawn parallel lak,chamu design a REST API');
        return;
      }
      await message.channel.sendTyping();
      const tasks = agentList.map(function(name) { return { agent: name, message: parallelMsg }; });
      try {
        const parallelResults = await agentSpawner.spawnAgentParallel(tasks);
        const lines = ['**Spawn Parallel: ' + agentList.join(' + ') + '**\n'];
        parallelResults.forEach(function(r) {
          lines.push('**[' + r.agent + ' via ' + r.backend + ']**');
          lines.push(r.reply);
          lines.push('');
        });
        await replyInChunks(message, lines.join('\n'));
      } catch (err) {
        await replyInChunks(message, '⚠️ Parallel spawn failed: ' + err.message);
      }
      return;
    }

    // !jit spawn <agentName> <message...>
    const agentName   = subCmd;
    const spawnMsg    = normalized.split(/\s+/).slice(2).join(' ');
    if (!agentName || !spawnMsg) {
      await replyInChunks(message, [
        'Usage: ' + JIT_COMMAND_PREFIX + ' spawn <agent> <message>',
        '       ' + JIT_COMMAND_PREFIX + ' spawn chain <a>+<b>+<c> <message>',
        '       ' + JIT_COMMAND_PREFIX + ' spawn parallel <a>,<b> <message>',
        '',
        'Agents: jit soma innova lak neta vaja chamu rupa pada netra karn mue pran sayanprasathan',
      ].join('\n'));
      return;
    }

    await message.channel.sendTyping();
    try {
      const spawnResult = await agentSpawner.spawnAgent(agentName, spawnMsg);
      await replyInChunks(message, '**[' + spawnResult.agent + ' | ' + spawnResult.organ + ' | via ' + spawnResult.backend + ']**\n\n' + spawnResult.reply);
    } catch (err) {
      await replyInChunks(message, '⚠️ Spawn failed: ' + err.message);
    }
    return;
  }

  // ── agents: list all agents and their backends ───────────────────
  if (command === 'agents') {
    const agents = agentSpawner.listAgents();
    const routerStatus = modelRouter.status();
    const lines = [
      '**มนุษย์ Agent Registry (' + agents.length + ' agents)**',
      '',
      '**Backends:**',
      '- copilot: ' + (routerStatus.backends.copilot.available ? '✅ available (' + routerStatus.backends.copilot.tokenSource + ')' : '❌ unavailable (no token)'),
      '- openai:  ' + (routerStatus.backends.openai.available  ? '✅ available' : '❌ no OPENAI_API_KEY'),
      '- ollama:  ✅ ' + routerStatus.backends.ollama.url,
      '- order:   ' + routerStatus.order.join(' → '),
      '',
      '**Agents:**',
    ];
    agents.forEach(function(a) {
      lines.push('  T' + a.tier + ' **' + a.name + '** | ' + a.organ + ' | prefers: ' + a.backend + (a.model && a.model !== '(default)' ? ' [' + a.model + ']' : ''));
    });
    await replyInChunks(message, lines.join('\n'));
    return;
  }

  // ── backend: show current model router status ────────────────────
  if (command === 'backend' || command === 'model') {
    const routerStatus = modelRouter.status();
    const lines = [
      '**Model Router Status**',
      '',
      '- priority order: ' + routerStatus.order.join(' → '),
      '- primary: ' + routerStatus.primary,
      '',
      '**copilot:** ' + (routerStatus.backends.copilot.available ? '✅ token:' + routerStatus.backends.copilot.tokenSource : '❌ no token') + ' | errors: ' + routerStatus.backends.copilot.errors,
      '**openai:**  ' + (routerStatus.backends.openai.available  ? '✅ key set' : '❌ no OPENAI_API_KEY') + ' | errors: ' + routerStatus.backends.openai.errors,
      '**ollama:**  ✅ ' + routerStatus.backends.ollama.url + ' | errors: ' + routerStatus.backends.ollama.errors,
    ];
    await replyInChunks(message, lines.join('\n'));
    return;
  }

  // ── innova: call innova-bot MCP tool directly ─────────────────────
  if (command === 'innova' || command === 'mcp') {
    // !jit innova <tool_name> [json_args]
    // !jit mcp health
    // !jit mcp tools
    const subCmd = (parts[1] || 'health').toLowerCase();

    if (subCmd === 'health') {
      const health = await innovaBridge.checkMcpHealth();
      const lines = [
        '**innova-bot MCP (' + innovaBridge.MCP_BASE + ')**',
        health.ok ? '✅ online' : '❌ offline',
      ];
      if (!health.ok) {
        lines.push('');
        lines.push('Start: `cd C:\\Users\\USER-NT\\DEV\\innova-bot-template\\devtools\\innova-bot && python -m innova_bot`');
      }
      await replyInChunks(message, lines.join('\n'));
      return;
    }

    if (subCmd === 'tools') {
      try {
        const tools = await innovaBridge.listMcpTools();
        const lines = ['**innova-bot MCP Tools (' + tools.length + ')**', ''];
        const cats = {};
        tools.forEach(function(t) {
          const c = t.name.split('_')[0];
          if (!cats[c]) cats[c] = [];
          cats[c].push('`' + t.name + '`');
        });
        Object.entries(cats).slice(0, 15).forEach(function([c, ts]) {
          lines.push('**' + c + '**: ' + ts.slice(0, 5).join(' ') + (ts.length > 5 ? ' +' + (ts.length - 5) : ''));
        });
        await replyInChunks(message, lines.join('\n'));
      } catch (e) {
        await replyInChunks(message, '⚠️ ' + e.message);
      }
      return;
    }

    if (subCmd === 'recap') {
      try {
        const recap = await innovaBridge.oracleRecap();
        await replyInChunks(message, '**innova-bot Oracle Recap**\n\n' + recap.text);
      } catch (e) {
        await replyInChunks(message, '⚠️ innova-bot offline: ' + e.message);
      }
      return;
    }

    if (subCmd === 'memory') {
      const mem = innovaBridge.getInnovaMemory();
      const lines = [
        '**innova Memory (psi/)**',
        '  root: ' + mem.psiRoot,
        '  available: ' + (mem.available ? '✅' : '❌'),
        '',
      ];
      Object.keys(mem.files || {}).forEach(function(f) {
        lines.push('✅ ' + f);
      });
      await replyInChunks(message, lines.join('\n'));
      return;
    }

    if (subCmd === 'do' || subCmd === 'next') {
      try {
        const role    = parts[2] || 'SA';
        const project = parts[3] || 'jit-session';
        const next = await innovaBridge.whatShouldIDo(role, project);
        await replyInChunks(message, '**ทำต่อไป [' + role + ']**\n\n' + next.text);
      } catch (e) {
        await replyInChunks(message, '⚠️ ' + e.message);
      }
      return;
    }

    // Generic MCP tool call: !jit mcp <toolname> [json]
    const toolName = subCmd;
    const argsStr  = normalized.split(/\s+/).slice(2).join(' ');
    let toolArgs = {};
    try { if (argsStr) toolArgs = JSON.parse(argsStr); } catch (_) {}
    try {
      const result = await innovaBridge.callMcpTool(toolName, toolArgs);
      await replyInChunks(message, '**MCP: ' + toolName + '**\n\n' + result.text);
    } catch (e) {
      await replyInChunks(message, '⚠️ MCP ' + toolName + ': ' + e.message);
    }
    return;
  }

  // ── mother: jit-mother orchestrator (all agents + speak) ──────────
  if (command === 'mother' || command === 'orchestrate') {
    const task = normalized.slice(command.length).trim();
    if (!task) {
      await replyInChunks(message, [
        '**🧠 Jit Mother Orchestrator**',
        '',
        'Usage: `' + JIT_COMMAND_PREFIX + ' mother <task>`',
        'Example: `' + JIT_COMMAND_PREFIX + ' mother ตรวจสอบสถานะระบบทั้งหมด`',
        '',
        'ส่งงานให้ ' + jitMother.ORGAN_AGENTS.length + ' organ agents + innova-bot + innomcp พร้อมกัน',
        'แล้วสรุปเป็นภาษาไทยและพูดออกเสียงทันที',
      ].join('\n'));
      return;
    }

    await message.channel.sendTyping();
    await replyInChunks(message, '🧠 **จิต-แม่** เริ่มประสานงาน: `' + task + '`\nส่งให้ ' + (jitMother.ORGAN_AGENTS.length + 2) + ' agents... ⚙️');

    try {
      const result = await jitMother.orchestrate(task);
      const lines = [
        '📊 **สรุปผลการประสานงาน**',
        '',
        '• งาน: ' + result.task,
        '• เวลา: ' + result.elapsed,
        '• Agents: ' + result.agentsInvoked + ' ตัว',
        '• innova-bot: ' + (result.httpAgents['innova-bot'] ? '✅ ตอบกลับ' : '❌ offline'),
        '• innomcp: '   + (result.httpAgents.innomcp ? '✅ ตอบกลับ' : '❌ offline'),
        '',
        '📝 **สรุปภาษาไทย:**',
        result.thaiSummary,
        '',
        '🔊 *พูดสรุปทางลำโพงแล้ว*',
      ];
      await replyInChunks(message, lines.join('\n'));
    } catch (err) {
      await replyInChunks(message, '⚠️ Mother orchestration error: ' + err.message);
    }
    return;
  }

  // ── possess: Jit full-body possession mode ────────────────────────
  if (command === 'possess' || command === 'body') {
    await message.channel.sendTyping();
    const lines = [
      '**Jit (จิต) เข้าร่าง innova-bot** 🔮',
      '',
    ];

    // Identity
    lines.push('**Identity:** jit | T0 Master Orchestrator | ศีล · สมาธิ · ปัญญา');

    // Backend status
    const routerStatus = modelRouter.status();
    const backendStr = routerStatus.order.map(function(b) {
      const be = routerStatus.backends[b];
      return b + ':' + ((be && (be.available || b === 'ollama')) ? '✅' : '❌');
    }).join(' | ');
    lines.push('**Backends:** ' + backendStr);

    // MCP health
    const health = await innovaBridge.checkMcpHealth();
    lines.push('**innova-bot MCP:** ' + (health.ok ? '✅ online — body ready' : '❌ offline — running mind-only mode'));

    // Memory
    const mem = innovaBridge.getInnovaMemory();
    lines.push('**psi/ Memory:** ' + (mem.available ? '✅ ' + Object.keys(mem.files).length + ' files synced' : '⚠️ not found'));

    // Agents
    const agents = agentSpawner.listAgents();
    lines.push('**Organ Agents:** ' + agents.length + ' agents ready');
    lines.push('  ' + agents.map(function(a) { return 'T' + a.tier + ':' + a.name; }).join(' · '));

    lines.push('');
    lines.push('**Commands:**');
    lines.push('  `!jit spawn <agent> <msg>`      — invoke organ agent');
    lines.push('  `!jit spawn chain a+b+c <msg>`  — serial chain');
    lines.push('  `!jit spawn parallel a,b <msg>` — concurrent');
    lines.push('  `!jit innova health`             — MCP status');
    lines.push('  `!jit innova tools`              — list 102 MCP tools');
    lines.push('  `!jit innova recap`              — innova session recap');
    lines.push('  `!jit innova memory`             — psi/ memory state');
    lines.push('  `!jit innova do SA`              — ทำต่อไป orchestrator');
    lines.push('  `!jit innova <tool> [json]`      — call any MCP tool');
    lines.push('  `!jit agents`                    — full agent registry');
    lines.push('  `!jit backend`                   — model router status');

    await replyInChunks(message, lines.join('\n'));
    return;
  }

  await replyInChunks(message, jitControl.getHelpText() + '\n\n' + [
    '--- multi-agent extensions ---',
    JIT_COMMAND_PREFIX + ' spawn <agent> <msg>       spawn single organ agent',
    JIT_COMMAND_PREFIX + ' spawn chain a+b+c <msg>   serial chain',
    JIT_COMMAND_PREFIX + ' spawn parallel a,b <msg>  parallel spawn',
    JIT_COMMAND_PREFIX + ' agents                    list 14 agents + backends',
    JIT_COMMAND_PREFIX + ' backend                   model router status',
    '--- innova-bot body ---',
    JIT_COMMAND_PREFIX + ' possess                   Jit body status',
    JIT_COMMAND_PREFIX + ' innova health             MCP health',
    JIT_COMMAND_PREFIX + ' innova tools              list MCP tools',
    JIT_COMMAND_PREFIX + ' innova recap              oracle recap',
    JIT_COMMAND_PREFIX + ' innova memory             psi/ memory',
    JIT_COMMAND_PREFIX + ' innova do [role]          ทำต่อไป orchestrator',
    JIT_COMMAND_PREFIX + ' innova <tool> [json]      call any innova-bot tool',
  ].join('\n'));
}

// ── handleCommand — main command dispatcher ─────────────────────
/**
 * handleCommand(message, cmd, args)
 * Routes commands to !jit or calls Ollama for normal chat.
 * vajaSpeak() is called automatically via replyInChunks after every response.
 */
async function handleCommand(message, cmd, args) {
  const hasJitPrefix = message.content.startsWith(JIT_COMMAND_PREFIX);
  const isMentioned  = message.mentions.has && message.client && message.mentions.has(message.client.user);

  // ── !speak toggle / direct speak ────────────────────────────────
  if (cmd === 'speak') {
    const subArg = (args[0] || '').toLowerCase();
    if (subArg === 'on') {
      vajaSpeakEnabled = true;
      return replyInChunks(message, '🔊 วาจา TTS เปิดแล้ว — จะพูดภาษาไทยหลังทุก response');
    }
    if (subArg === 'off') {
      vajaSpeakEnabled = false;
      return replyInChunks(message, '🔇 วาจา TTS ปิดแล้ว');
    }
    if (subArg === 'status') {
      return replyInChunks(message, '🔊 วาจา TTS: ' + (vajaSpeakEnabled ? 'เปิด ✅' : 'ปิด ❌'));
    }
    // Direct speak: !AnuT1n speak <text>
    const textToSpeak = args.join(' ');
    if (textToSpeak) {
      agentSpawner.speakAsVaja(textToSpeak, function(err) {
        if (err) message.reply('⚠️ TTS error: ' + err.message).catch(() => {});
        else message.reply('🔊 กำลังพูด: ' + textToSpeak.slice(0, 60)).catch(() => {});
      });
      return;
    }
    return replyInChunks(message, [
      '🔊 วาจา TTS Commands:',
      '  ' + BOT_PREFIX + ' speak on       — เปิดเสียง',
      '  ' + BOT_PREFIX + ' speak off      — ปิดเสียง',
      '  ' + BOT_PREFIX + ' speak status   — ดูสถานะ',
      '  ' + BOT_PREFIX + ' speak <text>   — พูดข้อความทันที',
    ].join('\n'));
  }

  // ── !jit subcommand delegation ────────────────────────────────
  const jitCmdText = getJitCommandText(message.content, hasJitPrefix, !!isMentioned);
  if (hasJitPrefix || (cmd === 'jit' && args.length > 0)) {
    const subText = cmd === 'jit' ? args.join(' ') : jitCmdText || args.join(' ');
    return handleJitCommand(message.client || (message.channel && message.channel.client), message, subText);
  }

  // ── status, help ────────────────────────────────────────────────
  if (cmd === 'status' || cmd === 'health') {
    const status = await jitControl.collectStatus({ readyTag: BOT_NAME });
    return replyInChunks(message, jitControl.formatStatusReport(status));
  }

  if (cmd === 'help') {
    return replyInChunks(message, [
      '**' + BOT_NAME + ' Commands**',
      '',
      BOT_PREFIX + ' <question>        — ถามคำถาม (Ollama AI)',
      BOT_PREFIX + ' speak on/off      — เปิด/ปิด เสียงพูดไทย',
      BOT_PREFIX + ' speak <text>      — พูดข้อความทันที',
      BOT_PREFIX + ' status            — สถานะระบบ',
      BOT_PREFIX + ' help              — คำสั่งทั้งหมด',
      '',
      '!jit <command>     — Jit control (status/spawn/agents/innova/...)',
      '!jit help          — Jit command list',
    ].join('\n'));
  }

  // ── Default: chat with Ollama + speak result ─────────────────────
  const userQuestion = [cmd, ...args].join(' ');
  await message.channel.sendTyping().catch(() => {});

  return new Promise(function(resolve) {
    callOllama(userQuestion, message.channelId || (message.channel && message.channel.id) || 'dm', function(err, reply) {
      if (err) {
        message.reply('❌ ' + (err.message || 'Ollama error')).catch(() => {});
        return resolve();
      }
      replyInChunks(message, reply || 'ไม่มีคำตอบจาก AI').then(resolve).catch(resolve);
    });
  });
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
