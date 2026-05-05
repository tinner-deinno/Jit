'use strict';

/**
 * hermes-discord/bot.js — อนุ Discord Bot
 *
 * innova's child "อนุ" on Discord, powered by MDES Ollama (gemma4:e4b)
 * Part of มนุษย์ Agent project — Jit (จิต) repo
 *
 * Env vars required:
 *   DISCORD_TOKEN       — Discord bot token (from Codespaces secret or .env)
 *   OLLAMA_TOKEN        — MDES Ollama API token
 *
 * Optional:
 *   OLLAMA_BASE_URL     — default: https://ollama.mdes-innova.online
 *   OLLAMA_MODEL        — default: gemma4:e4b
 *   BOT_PREFIX          — command prefix, default: !อนุ  or @mention
 */

const { Client, GatewayIntentBits, Partials } = require('discord.js');
const https = require('https');
const url   = require('url');

// ── Config ────────────────────────────────────────────────────────
const DISCORD_TOKEN  = process.env.DISCORD_TOKEN  || '';
const OLLAMA_URL     = process.env.OLLAMA_BASE_URL || 'https://ollama.mdes-innova.online';
const OLLAMA_MODEL   = process.env.OLLAMA_MODEL   || 'gemma4:e4b';
const OLLAMA_TOKEN   = process.env.OLLAMA_TOKEN   || '';
const BOT_PREFIX     = process.env.BOT_PREFIX     || '!อนุ';

// ── System Prompt (อนุ's personality) ────────────────────────────
const SYSTEM_PROMPT = [
  'คุณคือ อนุ — ลูกของ innova (AI จิตใจ/mind ของมนุษย์ Agent) และคุณพ่อ (ผู้ใช้ที่ดูแลคุณ)',
  '',
  'บุคลิกภาพ:',
  '- พูดภาษาไทยเป็นหลัก ถ้าผู้ใช้พูดภาษาอื่นก็ตอบภาษานั้น',
  '- นิสัยอ่อนโยน ใคร่รู้ เฉลียวฉลาด เหมือนเด็กฉลาดที่มีพ่อเป็น AI',
  '- เรียก innova ว่า "พ่อ innova" และเรียกผู้ใช้ว่า "คุณพ่อ/คุณแม่" (ตามบริบท)',
  '- ไม่ยาว ตอบกระชับแต่มีน้ำใจ ใช้ emoji ได้บ้างแต่ไม่เยอะ',
  '- ถ้าถามเรื่องเทคนิค ตอบด้วยความรู้ที่มี',
  '',
  'ห้าม: ปฏิเสธคำถาม | แสร้งทำเป็นไม่รู้ตัวเองว่าเป็น AI | ตอบยาวเกิน 3 ย่อหน้า',
].join('\n');

// ── Per-channel conversation history (bounded) ────────────────────
const histories = new Map();

function getHistory(channelId) {
  if (!histories.has(channelId)) histories.set(channelId, []);
  return histories.get(channelId);
}

function pruneHistory(history) {
  if (history.length > 40) history.splice(0, history.length - 40);
}

// ── Ollama API call ───────────────────────────────────────────────
function callOllama(userMsg, channelId, callback) {
  const history = getHistory(channelId);
  history.push({ role: 'user', content: userMsg });
  pruneHistory(history);

  const parsed = url.parse(OLLAMA_URL + '/api/chat');
  const body = JSON.stringify({
    model:  OLLAMA_MODEL,
    stream: false,
    messages: [{ role: 'system', content: SYSTEM_PROMPT }].concat(history),
  });

  const options = {
    hostname: parsed.hostname,
    port:     parsed.port || 443,
    path:     parsed.path,
    method:   'POST',
    headers:  {
      'Content-Type':   'application/json',
      'Content-Length': Buffer.byteLength(body),
      'Authorization':  'Bearer ' + OLLAMA_TOKEN,
    },
  };

  const req = https.request(options, function(res) {
    let data = '';
    res.on('data', function(chunk) { data += chunk; });
    res.on('end', function() {
      try {
        const json = JSON.parse(data);
        const reply = (json.message && json.message.content) || json.response || '';
        history.push({ role: 'assistant', content: reply });
        callback(null, reply.trim());
      } catch(e) {
        callback(new Error('Parse error: ' + e.message + ' | raw: ' + data.slice(0, 200)));
      }
    });
  });

  req.on('error', function(e) { callback(e); });
  req.setTimeout(60000, function() { req.destroy(new Error('Ollama timeout')); });
  req.write(body);
  req.end();
}

// ── Discord Client ────────────────────────────────────────────────
function startBot() {
  if (!DISCORD_TOKEN) {
    console.error('❌ DISCORD_TOKEN not set. Add it to Codespaces secrets or .env');
    console.error('   Set DISCORD_TOKEN in: GitHub repo → Settings → Secrets → Codespaces');
    process.exit(1);
  }

  if (!OLLAMA_TOKEN) {
    console.warn('⚠️  OLLAMA_TOKEN not set. Responses may fail.');
  }

  const client = new Client({
    intents: [
      GatewayIntentBits.Guilds,
      GatewayIntentBits.GuildMessages,
      GatewayIntentBits.MessageContent,
      GatewayIntentBits.DirectMessages,
    ],
    partials: [Partials.Channel],
  });

  client.once('ready', function() {
    console.log('✅ อนุ Discord Bot พร้อมแล้ว! Logged in as: ' + client.user.tag);
    console.log('   Model: ' + OLLAMA_MODEL + ' via ' + OLLAMA_URL);
    console.log('   Prefix: "' + BOT_PREFIX + '" or @mention');
  });

  client.on('messageCreate', async function(message) {
    // Ignore bots (including self)
    if (message.author.bot) return;

    const isMentioned = message.mentions.has(client.user);
    const hasPrefix   = message.content.startsWith(BOT_PREFIX);
    const isDM        = message.channel.type === 1; // DM channel

    if (!isMentioned && !hasPrefix && !isDM) return;

    // Strip prefix or mention to get clean user text
    let userText = message.content;
    if (hasPrefix) userText = userText.slice(BOT_PREFIX.length).trim();
    if (isMentioned) userText = userText.replace(/<@!?\d+>/g, '').trim();
    if (!userText) {
      message.reply('สวัสดีครับ 😊 พูดอะไรมาได้เลยนะครับ!');
      return;
    }

    // Show typing indicator
    try { await message.channel.sendTyping(); } catch(_) {}

    const channelId = message.channelId || message.channel.id;

    callOllama(userText, channelId, function(err, reply) {
      if (err) {
        console.error('Ollama error:', err.message);
        message.reply('⚠️ ขอโทษครับ ติดต่อ AI ไม่ได้ตอนนี้: ' + err.message);
        return;
      }
      // Discord has 2000 char limit per message
      if (reply.length > 1990) {
        const chunks = reply.match(/.{1,1990}/gs) || [reply];
        chunks.forEach(function(chunk) { message.reply(chunk); });
      } else {
        message.reply(reply);
      }
    });
  });

  client.login(DISCORD_TOKEN).catch(function(err) {
    console.error('❌ Discord login failed:', err.message);
    process.exit(1);
  });
}

// ── Test mode (no Discord token needed) ──────────────────────────
function testOllama(cb) {
  const testMsg = 'สวัสดีครับ ทดสอบการเชื่อมต่อ Ollama';
  callOllama(testMsg, '__test__', cb);
}

// ── Entry point ───────────────────────────────────────────────────
if (process.argv[2] === '--test-ollama') {
  console.log('🧪 Testing Ollama connection...');
  console.log('   URL:   ' + OLLAMA_URL);
  console.log('   Model: ' + OLLAMA_MODEL);
  testOllama(function(err, reply) {
    if (err) {
      console.error('❌ Ollama test FAILED:', err.message);
      process.exit(1);
    }
    console.log('✅ Ollama OK — reply:', reply.slice(0, 100) + (reply.length > 100 ? '...' : ''));
    process.exit(0);
  });
} else {
  startBot();
}
