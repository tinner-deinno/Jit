'use strict';

const crypto = require('crypto');
const fs = require('fs');

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

function dedupe(items) {
  const seen = new Set();
  return items.filter(function(item) {
    if (!item || seen.has(item)) return false;
    seen.add(item);
    return true;
  });
}

function isoNow() {
  return new Date().toISOString();
}

function displayName(message) {
  if (message.member && message.member.displayName) return message.member.displayName;
  if (message.author && message.author.globalName) return message.author.globalName;
  if (message.author && message.author.username) return message.author.username;
  return 'unknown';
}

class DiscordThoughtLoop {
  constructor(options) {
    this.enabled = options && Object.prototype.hasOwnProperty.call(options, 'enabled') ? options.enabled : true;
    this.intervalMs = parsePositiveInt(options && options.intervalMs, 300000);
    this.activeWindowMs = parsePositiveInt(options && options.activeWindowMs, 900000);
    this.minMessages = parsePositiveInt(options && options.minMessages, 4);
    this.minParticipants = parsePositiveInt(options && options.minParticipants, 2);
    this.maxMessages = parsePositiveInt(options && options.maxMessages, 25);
    this.maxMentions = parsePositiveInt(options && options.maxMentions, 6);
    this.commandPrefix = options && options.commandPrefix ? options.commandPrefix : '!jit';
    this.channelIds = splitCsv(options && options.channelIds);
    this.stateFile = options && options.stateFile ? options.stateFile :
      require('path').join(require('os').tmpdir(), 'hermes-discord-thought-loop.json');
    this.logger = options && options.logger ? options.logger : function() {};
    this.client = null;
    this.handlers = null;
    this.timer = null;
    this.state = this.loadState();
  }

  loadState() {
    try {
      return JSON.parse(fs.readFileSync(this.stateFile, 'utf8'));
    } catch (_) {
      return { channels: {} };
    }
  }

  saveState() {
    fs.writeFileSync(this.stateFile, JSON.stringify(this.state, null, 2), 'utf8');
  }

  ensureChannelState(channelId) {
    if (!this.state.channels[channelId]) {
      this.state.channels[channelId] = { enabled: false, source: 'runtime', updatedAt: isoNow() };
    }
    return this.state.channels[channelId];
  }

  attach(client, handlers) {
    this.client = client;
    this.handlers = handlers || {};
    this.channelIds.forEach((channelId) => {
      const state = this.ensureChannelState(channelId);
      if (!state.enabled) {
        state.enabled = true;
        state.source = state.source || 'env';
        state.updatedAt = isoNow();
      }
    });
    this.saveState();
    this.start();
  }

  start() {
    if (!this.enabled || this.timer) return;
    this.timer = setInterval(() => {
      this.tick().catch((error) => this.logger('tick error: ' + error.message));
    }, Math.min(this.intervalMs, 60000));
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  enableChannel(channelId, actor, source) {
    const state = this.ensureChannelState(channelId);
    this.enabled = true;
    state.enabled = true;
    state.source = source || 'command';
    state.actor = actor || '';
    state.updatedAt = isoNow();
    this.saveState();
    this.start();
    return state;
  }

  disableChannel(channelId, actor) {
    const state = this.ensureChannelState(channelId);
    state.enabled = false;
    state.actor = actor || '';
    state.updatedAt = isoNow();
    this.saveState();
    return state;
  }

  channelStatus(channelId) {
    const state = this.ensureChannelState(channelId);
    return {
      enabled: Boolean(state.enabled),
      source: state.source || 'runtime',
      updatedAt: state.updatedAt || '',
      lastProcessedAt: state.lastProcessedAt || '',
      lastPostAt: state.lastPostAt || '',
      lastResult: state.lastResult || '',
    };
  }

  async tick() {
    if (!this.client || !this.handlers || typeof this.handlers.generateReply !== 'function') return;
    const channelIds = dedupe(this.channelIds.concat(Object.keys(this.state.channels).filter((channelId) => this.state.channels[channelId].enabled)));
    for (const channelId of channelIds) {
      try {
        await this.evaluateChannel(channelId, { reason: 'interval' });
      } catch (error) {
        this.logger('channel ' + channelId + ' error: ' + error.message);
      }
    }
  }

  async runNow(channel, actor) {
    return this.evaluateChannel(typeof channel === 'string' ? channel : channel.id, { force: true, reason: 'manual', actor: actor || '' });
  }

  async evaluateChannel(channelId, options) {
    const state = this.ensureChannelState(channelId);
    if (!options.force && !state.enabled) return { ok: false, reason: 'disabled', channelId: channelId };
    if (!this.client) return { ok: false, reason: 'client not attached', channelId: channelId };

    if (!options.force && state.lastPostAt) {
      const lastPostAt = Date.parse(state.lastPostAt);
      if (Number.isFinite(lastPostAt) && Date.now() - lastPostAt < this.intervalMs) {
        return { ok: false, reason: 'cooldown', channelId: channelId };
      }
    }

    const channel = await this.client.channels.fetch(channelId);
    if (!channel || !channel.isTextBased || !channel.isTextBased()) return { ok: false, reason: 'channel unavailable', channelId: channelId };
    if (!channel.messages || typeof channel.messages.fetch !== 'function') return { ok: false, reason: 'message fetch unavailable', channelId: channelId };

    const fetched = await channel.messages.fetch({ limit: this.maxMessages });
    const cutoff = Date.now() - this.activeWindowMs;
    let messages = Array.from(fetched.values())
      .filter((message) => message && message.author && !message.author.bot && String(message.content || '').trim())
      .filter((message) => !String(message.content || '').trim().startsWith(this.commandPrefix + ' '))
      .sort((left, right) => left.createdTimestamp - right.createdTimestamp)
      .filter((message) => options.force || message.createdTimestamp >= cutoff);

    if (!messages.length) return { ok: false, reason: 'no messages', channelId: channelId };

    if (!options.force && state.lastProcessedAt) {
      const lastProcessedAt = Date.parse(state.lastProcessedAt);
      if (Number.isFinite(lastProcessedAt)) {
        messages = messages.filter((message) => message.createdTimestamp > lastProcessedAt - 1000);
      }
    }

    if (!messages.length) return { ok: false, reason: 'no new messages', channelId: channelId };

    const participantIds = dedupe(messages.map((message) => message.author.id));
    if (!options.force && messages.length < this.minMessages) {
      return { ok: false, reason: 'not enough messages', channelId: channelId, count: messages.length };
    }
    if (!options.force && participantIds.length < this.minParticipants) {
      return { ok: false, reason: 'not enough participants', channelId: channelId, participants: participantIds.length };
    }

    const fingerprint = crypto.createHash('sha1')
      .update(messages.map((message) => message.id + ':' + String(message.content || '').trim()).join('|'))
      .digest('hex');
    if (!options.force && state.lastFingerprint === fingerprint) return { ok: false, reason: 'same fingerprint', channelId: channelId };

    const context = this.buildContext(channel, messages, options);
    const reply = String(await this.handlers.generateReply(context) || '').trim();

    state.lastProcessedAt = isoNow();
    state.lastFingerprint = fingerprint;

    if (!reply || reply === '[[NO_REPLY]]') {
      state.lastResult = 'no-reply';
      state.updatedAt = isoNow();
      this.saveState();
      return { ok: false, reason: 'no-reply', channelId: channelId, messageCount: messages.length };
    }

    const mentionPrefix = context.targetIds.length ? context.targetIds.map((userId) => '<@' + userId + '>').join(' ') + '\n' : '';
    const sentMessage = await channel.send(mentionPrefix + reply);

    state.lastPostAt = isoNow();
    state.lastResult = 'sent';
    state.lastSentMessageId = sentMessage.id;
    state.updatedAt = isoNow();
    this.saveState();

    return { ok: true, channelId: channelId, messageId: sentMessage.id, targets: context.targetIds.length, participants: context.participants.length, messageCount: messages.length };
  }

  buildContext(channel, messages, options) {
    const participants = new Map();
    const mentionedUsers = new Map();

    messages.forEach((message) => {
      participants.set(message.author.id, { id: message.author.id, name: displayName(message) });
      if (message.mentions && message.mentions.users) {
        message.mentions.users.forEach((user) => {
          if (user && !user.bot) {
            mentionedUsers.set(user.id, { id: user.id, name: user.globalName || user.username || user.id });
          }
        });
      }
    });

    const targetIds = dedupe(Array.from(mentionedUsers.keys())).slice(0, this.maxMentions);
    const transcript = messages.map((message) => {
      const mentionIds = message.mentions && message.mentions.users
        ? Array.from(message.mentions.users.values()).filter((user) => !user.bot).map((user) => '@' + (user.globalName || user.username || user.id))
        : [];
      return '[' + new Date(message.createdTimestamp).toISOString() + '] ' + displayName(message) + ': ' + String(message.content || '').trim() + (mentionIds.length ? ' | mentions ' + mentionIds.join(', ') : '');
    }).join('\n');

    return {
      force: Boolean(options.force),
      channelId: channel.id,
      channelName: channel.name || channel.id,
      guildName: channel.guild && channel.guild.name ? channel.guild.name : '',
      messageCount: messages.length,
      participants: Array.from(participants.values()),
      mentionedUsers: Array.from(mentionedUsers.values()),
      targetIds: targetIds,
      transcript: transcript,
      commandPrefix: this.commandPrefix,
    };
  }
}

module.exports = {
  DiscordThoughtLoop: DiscordThoughtLoop,
};