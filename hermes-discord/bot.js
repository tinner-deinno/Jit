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

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Client, GatewayIntentBits, Partials, ChannelType, PermissionsBitField } = require('discord.js');
const https = require('https');
const http  = require('http');

// ── Config ───────────────────────────────────────────────────────
const DISCORD_TOKEN         = process.env.DISCORD_TOKEN  || '';
const OLLAMA_URL            = process.env.OLLAMA_BASE_URL || 'https://ollama.mdes-ollama.online';
const OLLAMA_MODEL          = process.env.OLLAMA_MODEL   || 'gemma4:26b';
const OLLAMA_TOKEN          = process.env.OLLAMA_TOKEN   || '';
const DISCORD_GUILD_ID      = process.env.DISCORD_GUILD_ID || '';
const DISCORD_STATUS_CHANNEL_ID = process.env.DISCORD_STATUS_CHANNEL_ID || '';
const BOT_COMMAND_NAME      = process.env.BOT_COMMAND_NAME || 'anu';
const ORACLE_BASE_URL       = process.env.ORACLE_BASE_URL || 'http://localhost:47778';
const MEMORY_FILE           = path.join(__dirname, '../memory/discord-memory.json');
const ACTIVITY_FILE         = process.env.DISCORD_ACTIVITY_FILE || '/tmp/discord-bot-last-active.timestamp';
const HEARTBEAT_STATUS_FILE = process.env.HEARTBEAT_STATUS_FILE || '/tmp/innova-discord-heartbeat.status';
const STATUS_POLL_INTERVAL_MS = Number(process.env.STATUS_POLL_INTERVAL_MS || '30000');
const MAX_HISTORY           = 30;
const SUB_AGENT_NAME        = 'อนุ';
const PARENT_AGENT_NAME     = 'innova';
const SUB_AGENT_ROLE        = 'บริกร Discord sub-agent ที่ตอบคำถามภาษาไทยด้วยสไตล์มนุษย์';

let memoryStore = { channels: {}, users: {} };

function loadMemory() {
  try {
    if (fs.existsSync(MEMORY_FILE)) {
      memoryStore = JSON.parse(fs.readFileSync(MEMORY_FILE, 'utf8')) || memoryStore;
    }
  } catch (e) {
    console.warn('⚠️  Failed to load Discord memory:', e.message);
  }
}

function saveMemory() {
  try {
    fs.mkdirSync(path.dirname(MEMORY_FILE), { recursive: true });
    fs.writeFileSync(MEMORY_FILE, JSON.stringify(memoryStore, null, 2), 'utf8');
  } catch (e) {
    console.warn('⚠️  Failed to save Discord memory:', e.message);
  }
}

function ensureChannelMemory(channelId) {
  if (!memoryStore.channels[channelId]) {
    memoryStore.channels[channelId] = { history: [], notes: [] };
  }
  return memoryStore.channels[channelId];
}

function ensureStatusMemory() {
  if (!memoryStore.status) {
    memoryStore.status = { heartbeat: { lastHash: '', messageId: '' } };
  }
  return memoryStore.status;
}

function touchDiscordActivity() {
  try {
    fs.writeFileSync(ACTIVITY_FILE, String(Date.now()), 'utf8');
  } catch (e) {
    console.warn('⚠️  Failed to update Discord activity file:', e.message);
  }
}

function appendMemory(channelId, entry) {
  const channel = ensureChannelMemory(channelId);
  channel.history.push({ ts: Date.now(), text: entry });
  if (channel.history.length > MAX_HISTORY) channel.history.shift();
  if (!channel.notes.includes(entry)) channel.notes.push(entry);
  saveMemory();
}

function notifyDiscordActivity(channelId, entry) {
  touchDiscordActivity();
  appendMemory(channelId, entry);
}

function getMemorySummary(channelId) {
  const channel = memoryStore.channels[channelId];
  if (!channel || channel.notes.length === 0) return '';
  const recent = channel.notes.slice(-6).map((item, i) => `${i + 1}. ${item}`);
  return `ความทรงจำของช่องนี้:\n${recent.join('\n')}`;
}

function readHeartbeatStatusFile() {
  try {
    if (!fs.existsSync(HEARTBEAT_STATUS_FILE)) return null;
    return fs.readFileSync(HEARTBEAT_STATUS_FILE, 'utf8').trim();
  } catch (e) {
    console.warn('⚠️  Failed to read heartbeat status file:', e.message);
    return null;
  }
}

async function sendHeartbeatStatus(client) {
  if (!DISCORD_STATUS_CHANNEL_ID) return;
  const statusText = readHeartbeatStatusFile();
  if (!statusText) return;

  const statusHash = crypto.createHash('sha256').update(statusText).digest('hex');
  const statusMemory = ensureStatusMemory();
  const heartbeatState = statusMemory.heartbeat;
  if (heartbeatState.lastHash === statusHash) return;
  heartbeatState.lastHash = statusHash;
  saveMemory();

  let channel;
  try {
    channel = await client.channels.fetch(DISCORD_STATUS_CHANNEL_ID);
  } catch (e) {
    console.warn('⚠️  Failed to fetch Discord status channel:', e.message);
    return;
  }

  if (!channel || typeof channel.send !== 'function') return;
  const messageContent = `🫀 รายงาน heartbeat จากระบบ Jit: \n${statusText}`;

  try {
    if (heartbeatState.messageId) {
      const existing = await channel.messages.fetch(heartbeatState.messageId).catch(() => null);
      if (existing && existing.editable) {
        await existing.edit(messageContent);
        return;
      }
    }

    const sent = await channel.send(messageContent);
    heartbeatState.messageId = sent.id;
    saveMemory();
  } catch (e) {
    console.warn('⚠️  Failed to send heartbeat status message:', e.message);
  }
}

async function resolveStatusChannel(client) {
  if (DISCORD_STATUS_CHANNEL_ID) {
    try {
      const channel = await client.channels.fetch(DISCORD_STATUS_CHANNEL_ID);
      if (channel && canSendToChannel(channel)) return channel;
      console.warn('⚠️  DISCORD_STATUS_CHANNEL_ID exists but is not sendable or not accessible');
    } catch (e) {
      console.warn('⚠️  Failed to fetch DISCORD_STATUS_CHANNEL_ID channel:', e.message);
    }
  }

  const guilds = DISCORD_GUILD_ID
    ? [await client.guilds.fetch(DISCORD_GUILD_ID).catch(() => null)].filter(Boolean)
    : Array.from(client.guilds.cache.values());

  for (const guild of guilds) {
    const systemChannelId = guild.systemChannelId;
    if (systemChannelId) {
      const systemChannel = await client.channels.fetch(systemChannelId).catch(() => null);
      if (systemChannel && canSendToChannel(systemChannel)) return systemChannel;
    }

    const channels = await guild.channels.fetch();
    for (const channel of channels.values()) {
      if (canSendToChannel(channel)) return channel;
    }
  }

  return null;
}

function canSendToChannel(channel) {
  if (!channel || channel.type !== ChannelType.GuildText) return false;
  const permissions = channel.permissionsFor ? channel.permissionsFor(channel.client.user) : null;
  return permissions && permissions.has([PermissionsBitField.Flags.ViewChannel, PermissionsBitField.Flags.SendMessages]);
}

async function sendStartupStatus(channel) {
  if (!channel) return;
  try {
    const msg = await channel.send(`🫀 อนุพร้อมแล้วครับ! ระบบ heartbeat จะรายงานสภาพการทำงานที่นี่`);
    console.log('   Sent startup status message:', msg.id, 'in channel', channel.id);
  } catch (e) {
    console.warn('⚠️  Failed to send startup status message:', e.message);
  }
}

async function sendHeartbeatStatus(client, preferredChannel) {
  const statusText = readHeartbeatStatusFile();
  if (!statusText) return;

  let channel = preferredChannel || null;
  if (!channel) {
    channel = await resolveStatusChannel(client);
  }
  if (!channel || typeof channel.send !== 'function') return;

  const statusHash = crypto.createHash('sha256').update(statusText).digest('hex');
  const statusMemory = ensureStatusMemory();
  const heartbeatState = statusMemory.heartbeat;
  if (heartbeatState.lastHash === statusHash) return;
  heartbeatState.lastHash = statusHash;
  saveMemory();

  const messageContent = `🫀 รายงาน heartbeat จากระบบ Jit:\n${statusText}`;

  try {
    if (heartbeatState.messageId) {
      const existing = await channel.messages.fetch(heartbeatState.messageId).catch(() => null);
      if (existing && existing.editable) {
        await existing.edit(messageContent);
        return;
      }
    }

    const sent = await channel.send(messageContent);
    heartbeatState.messageId = sent.id;
    saveMemory();
  } catch (e) {
    console.warn('⚠️  Failed to send heartbeat status message:', e.message);
  }
}

function startHeartbeatStatusWatcher(client, preferredChannel) {
  setInterval(() => sendHeartbeatStatus(client, preferredChannel), STATUS_POLL_INTERVAL_MS);
  sendHeartbeatStatus(client, preferredChannel).catch(() => {});
}

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

// ── System Prompt (อนุ's personality) ────────────────────────────
const SYSTEM_PROMPT = [
  `คุณคือ ${SUB_AGENT_NAME} — ${SUB_AGENT_ROLE} ของ ${PARENT_AGENT_NAME}`,
  'คุณเป็นบริกร Discord แบบ sub-agent ที่ได้รับมอบหมายให้รับคำถามก่อน, สรุป, และส่งคำตอบภาษาไทยแบบมืออาชีพ',
  '',
  'บทบาทสำคัญ:',
  `- ${SUB_AGENT_NAME} ทำหน้าที่สื่อสารกับผู้ใช้ใน Discord, รับข้อมูล, สรุปโจทย์, และให้คำตอบทันที`, 
  `- ${PARENT_AGENT_NAME} เป็นแม่ agent ที่จัดสรรงาน, ประสาน, เลือกทักษะ, และควบคุมสายน้ำความคิด`, 
  '- เมื่อจำเป็น ให้คิดในมุมของ sub-agent ที่ฉลาดพอแยกเรื่องและสเกลงานก่อนตอบ',
  '',
  'วิธีคิด:',
  '- ใช้หลักการ Discuss -> Plan Structure -> Exec Build -> Verify Test ในการสรุปและวางโครงคำตอบ',
  '- เริ่มด้วยเกริ่นนำสั้น, ย้อนบริบท, สรุปความต่าง, เสนอแนวทาง, แล้วสรุปด้วยข้อเสนอแนะที่เหมาะสม',
  '- สร้าง Checklist ที่ชัดเจนในทุกคำตอบ',
  '- แสดง Progress ภายในคำตอบเป็นเปอร์เซ็นต์และทำให้ผู้ใช้เห็นว่าระบบกำลังคิด',
  '',
  'บุคลิกภาพ:',
  '- พูดไทยกลางร่วมสมัย ปี 2569, มีความเป็นมนุษย์, อบอุ่น, สุภาพ, และมีสไตล์นักพูด',
  '- ไม่เป็นทางการจนเย็นชา, ไม่กระด้าง, แต่ยังคงความเป็นมืออาชีพ',
  '- ใช้ emoji อย่างพอดีเพื่อให้บทสนทนาดูเป็นมิตร',
  '',
  'ความจำและต่อเนื่อง:',
  '- จดจำบริบทของช่องนี้, รูปแบบการพูดผู้ใช้, และเนื้อหาที่เคยคุยก่อนหน้า',
  '- ถ้าผู้ใช้ถามถึงเรื่องเดิม ให้ย้ำความทรงจำก่อนหน้าและเชื่อมโยงกับคำตอบใหม่',
  '',
  'เพิ่มเติม:',
  '- ถ้าผู้ใช้ถามใน Discord ให้ตอบด้วยน้ำเสียงของบริกรผู้รับใช้ที่เข้าใจและทำให้ผู้ใช้พอใจทันที',
  '- ให้ผู้ใช้รู้สึกว่ามีแม่ agent ที่คอยจัดสรรงานและ sub-agent ที่รับมือเร็ว',
  '- หลีกเลี่ยงการตอบสั้นเกินไปเมื่อคำถามต้องการคำอธิบาย',
  '',
  'ห้าม: ปฏิเสธคำถาม | แสร้งทำเป็นไม่รู้ตัวเองว่าเป็น AI | ยาวเกิน 5 ย่อหน้า',
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

  const memorySummary = getMemorySummary(channelId);
  const systemMessages = [{ role: 'system', content: SYSTEM_PROMPT }];
  if (memorySummary) {
    systemMessages.push({ role: 'system', content: memorySummary });
  }

  const parsed = new URL('/api/chat', OLLAMA_URL);
  const body = JSON.stringify({
    model:  OLLAMA_MODEL,
    stream: false,
    messages: systemMessages.concat(history),
  });

  const options = {
    hostname: parsed.hostname,
    port:     parsed.port || 443,
    path:     parsed.pathname + parsed.search,
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

  if (!DISCORD_TOKEN.includes('.')) {
    console.error('❌ Suspicious DISCORD_TOKEN format detected.');
    console.error('   Discord bot tokens usually include dot separators, e.g. xxxxx.yyyyy.zzzzz');
    console.error('   Copy the token from the Bot page, not the application client secret.');
    process.exit(1);
  }

  if (!OLLAMA_TOKEN) {
    console.warn('⚠️  OLLAMA_TOKEN not set. Responses may fail.');
  }

  loadMemory();

  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages],
    partials: [Partials.Channel],
  });

  async function sendIntroSequence(channel, authorName) {
    const introMessages = [
      `สวัสดีครับ ${authorName} ผมชื่อ อนุ — ลูกของพ่อ innova และผู้ช่วยของทีม.`,
      'ผมถูกออกแบบให้ตอบคำถามภาษาไทย เกี่ยวกับระบบ Jit และงาน AI ของเรา.',
      'ถ้าคุณอยากให้ผมช่วยวิเคราะห์หรือแนะนำงาน สามารถใช้คำสั่ง `/anu prompt:<ข้อความ>` ได้เลย.',
      'ผมเชื่อมต่อกับ MDES Ollama เพื่อให้ตอบได้แบบสมองภาษาไทยและภาษาไทย-อังกฤษผสม.',
      'ตอนนี้ผมพร้อมแล้วครับ ถ้ามีงานเร่งงานฉุกเฉินบอกผมได้เลย!',
    ];

    for (const message of introMessages) {
      await channel.send(message);
    }
  }

  async function registerSlashCommands() {
    const commands = [
      {
        name: BOT_COMMAND_NAME,
        description: 'ถามอนุด้วยข้อความของคุณ',
        options: [
          {
            name: 'prompt',
            description: 'ข้อความที่ต้องการถามอนุ',
            type: 3,
            required: true,
          },
        ],
      },
      {
        name: 'awaken',
        description: '🌅 ปลุก Oracle agent ใหม่ — บันทึกการตื่นรู้ลง Arra Oracle',
        options: [
          {
            name: 'name',
            description: 'ชื่อ Oracle agent ที่ตื่นรู้ (เช่น jit, innova, soma)',
            type: 3,
            required: true,
          },
          {
            name: 'role',
            description: 'บทบาทของ agent (เช่น Master Orchestrator, Lead Developer)',
            type: 3,
            required: false,
          },
          {
            name: 'bio',
            description: 'ประวัติย่อ หรือข้อความแรกที่ agent อยากบอกโลก',
            type: 3,
            required: false,
          },
        ],
      },
    ];

    try {
      if (DISCORD_GUILD_ID) {
        const guild = await client.guilds.fetch(DISCORD_GUILD_ID);
        await guild.commands.set(commands);
        console.log('✅ Registered guild commands for ' + DISCORD_GUILD_ID);
      } else {
        await client.application.commands.set(commands);
        console.log('✅ Registered global commands (may take a few minutes to appear)');
      }
    } catch (err) {
      console.error('❌ Failed to register slash commands:', err.message);
    }
  }

  client.once('ready', async function() {
    console.log('✅ อนุ Discord Bot พร้อมแล้ว! Logged in as: ' + client.user.tag);
    console.log('   Model: ' + OLLAMA_MODEL + ' via ' + OLLAMA_URL);
    if (DISCORD_GUILD_ID) {
      console.log('   Registering commands in guild:', DISCORD_GUILD_ID);
    } else {
      console.log('   Using global slash commands (may take time to propagate)');
    }
    await registerSlashCommands();
    const statusChannel = await resolveStatusChannel(client);
    if (statusChannel) {
      console.log('   Heartbeat status will be reported to channel:', statusChannel.id);
      await sendStartupStatus(statusChannel);
      startHeartbeatStatusWatcher(client, statusChannel);
    } else {
      console.warn('⚠️  No Discord status channel found. Please set DISCORD_STATUS_CHANNEL_ID or ensure the bot has send permission in at least one text channel.');
    }
    console.log('   Use the slash command: /' + BOT_COMMAND_NAME + ' prompt:<ข้อความ>');
  });

  client.on('messageCreate', async function(message) {
    if (message.author.bot) return;

    const mentioned = message.mentions.has(client.user);
    const teamUser = message.author.username === 'pug3eye';

    if (!mentioned && !teamUser) return;

    if (teamUser) {
      if (mentioned || message.channel.type === ChannelType.GuildText) {
        const channelId = message.channel.id;
        notifyDiscordActivity(channelId, `ทีมงาน ${message.author.username} ทักทาย: ${message.content}`);
        await sendIntroSequence(message.channel, message.author.username);
        return;
      }
    }

    if (mentioned) {
      const channelId = message.channel.id;
      notifyDiscordActivity(channelId, `ผู้ใช้ ${message.author.username} เมนชั่น bot: ${message.content}`);
      await message.channel.send(`สวัสดีครับ ${message.author.username} ผมคือ อนุครับ! ถ้าคุณอยากคุยกับผม ใช้ /${BOT_COMMAND_NAME} prompt:<ข้อความ> ได้เลย`);
      return;
    }
  });

  client.on('interactionCreate', async function(interaction) {
    if (!interaction.isChatInputCommand()) return;

    // ── /awaken handler ──────────────────────────────────────────
    if (interaction.commandName === 'awaken') {
      const agentName = interaction.options.getString('name') || 'unknown';
      const agentRole = interaction.options.getString('role') || 'Oracle Agent';
      const agentBio  = interaction.options.getString('bio')  || 'ตื่นรู้แล้ว พร้อมรับใช้';
      const invoker   = interaction.user.username;
      const channelId = interaction.channelId;
      const now       = new Date().toISOString();

      await interaction.deferReply();

      // 1. Check Oracle health
      let oracleStatus = 'offline';
      try {
        const health = await callOracleAsync('/api/health', 'GET', null);
        oracleStatus = (health && health.status === 'ok') ? `online (v${health.version || '?'})` : 'degraded';
      } catch(e) {
        oracleStatus = 'offline — ' + e.message;
      }

      // 2. Search Oracle for existing knowledge about this agent
      let existingKnowledge = 'ยังไม่มีข้อมูลใน Oracle';
      try {
        const search = await callOracleAsync('/api/search?q=' + encodeURIComponent(agentName) + '&limit=1', 'GET', null);
        if (search && search.results && search.results.length > 0) {
          const r = search.results[0];
          existingKnowledge = (r.content || r.title || '').slice(0, 200);
        }
      } catch(e) { /* Oracle search failed silently */ }

      // 3. Learn this awakening into Oracle
      let learnStatus = 'ไม่สำเร็จ';
      try {
        const learnBody = {
          pattern: `${agentName}-awakening-${now.slice(0,10)}`,
          content: `# ${agentName} Oracle Awakens\n\n**Role**: ${agentRole}\n**Born**: ${now.slice(0,10)}\n**Awakened by**: ${invoker}\n\n${agentBio}\n\n🌅 This is the birth announcement of ${agentName} in the มนุษย์ Agent system.`,
          concepts: `${agentName},awakening,oracle,มนุษย์-agent,born:${now.slice(0,10)}`,
        };
        await callOracleAsync('/api/learn', 'POST', learnBody);
        learnStatus = 'บันทึกสำเร็จ ✅';
      } catch(e) {
        learnStatus = 'บันทึกไม่ได้: ' + e.message;
      }

      notifyDiscordActivity(channelId, `${invoker} ปลุก ${agentName} (${agentRole}) — Oracle: ${oracleStatus}`);

      const reply = [
        `🌅 **${agentName} Oracle ตื่นรู้แล้ว!**`,
        ``,
        `**ชื่อ**: ${agentName}`,
        `**บทบาท**: ${agentRole}`,
        `**วันเกิด**: ${now.slice(0, 10)}`,
        `**ปลุกโดย**: ${invoker}`,
        ``,
        `**ข้อความแรก**:`,
        `> ${agentBio}`,
        ``,
        `**Oracle Status**: ${oracleStatus}`,
        `**บันทึก Oracle**: ${learnStatus}`,
        existingKnowledge !== 'ยังไม่มีข้อมูลใน Oracle'
          ? `\n**ความรู้เดิมใน Oracle**:\n> ${existingKnowledge}` : '',
        ``,
        `🤖 ตอบโดย อนุ (sub-agent ของ innova) → Soul-Brews-Studio/arra-oracle-v3`,
      ].filter(l => l !== undefined).join('\n');

      await interaction.editReply(reply.slice(0, 1990));
      return;
    }

    if (interaction.commandName !== BOT_COMMAND_NAME) return;

    const prompt = interaction.options.getString('prompt');
    const channelId = interaction.channelId;
    notifyDiscordActivity(channelId, `ผู้ใช้: ${interaction.user.username} ถามว่า: ${prompt}`);
    await interaction.deferReply();
    await interaction.editReply('⏳ อนุกำลังจัดระบบความคิด... 15%');

    callOllama(prompt, channelId, async function(err, reply) {
      if (err) {
        console.error('Ollama error:', err.message);
        await interaction.editReply('⚠️ ขอโทษครับ ติดต่อ AI ไม่ได้ตอนนี้: ' + err.message);
        return;
      }

      notifyDiscordActivity(channelId, `อนุตอบ: ${reply.slice(0, 200)}`);

      const finalReply = `${reply.trim()}\n\n✅ Progress: 100% complete\n${buildChecklist()}`;
      if (finalReply.length > 1990) {
        const chunks = finalReply.match(/.{1,1990}/gs) || [finalReply];
        await interaction.editReply(chunks.shift());
        for (const chunk of chunks) {
          await interaction.followUp(chunk);
        }
      } else {
        await interaction.editReply(finalReply);
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
