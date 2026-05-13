#!/usr/bin/env node
/**
 * hermes-discord-broadcaster.js
 * Broadcast innova heartbeat results to Discord
 * 
 * Usage:
 *   node hermes-discord-broadcaster.js --beat 1 --message "System healthy" --status success
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// Configuration
const DISCORD_TOKEN = process.env.DISCORD_TOKEN || '';
const DISCORD_CHANNEL_ID = process.env.DISCORD_STATUS_CHANNEL_ID || '';
const DISCORD_WEBHOOK = process.env.DISCORD_WEBHOOK || '';

// Parse arguments
const args = process.argv.slice(2);
let beatNum = 0;
let message = '';
let status = 'success';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--beat') beatNum = parseInt(args[++i], 10);
  if (args[i] === '--message') message = args[++i];
  if (args[i] === '--status') status = args[++i];
}

/**
 * Send embed to Discord via webhook
 */
async function sendViaWebhook(embed) {
  return new Promise((resolve, reject) => {
    if (!DISCORD_WEBHOOK) {
      console.error('❌ DISCORD_WEBHOOK not configured');
      resolve();
      return;
    }

    const payload = JSON.stringify({ embeds: [embed] });
    
    const url = new URL(DISCORD_WEBHOOK);
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        console.log(`✅ Discord webhook sent (${res.statusCode})`);
        resolve();
      });
    });

    req.on('error', (err) => {
      console.error(`❌ Webhook error: ${err.message}`);
      reject(err);
    });

    req.write(payload);
    req.end();
  });
}

/**
 * Build embed
 */
function buildEmbed() {
  const colors = {
    success: 3066993,    // green
    failure: 15158332,   // red
    warning: 16776960,   // yellow
    info: 3447003,       // blue
  };

  return {
    title: `💓 Heartbeat #${beatNum}`,
    description: message.substring(0, 2000),
    color: colors[status] || colors.info,
    timestamp: new Date().toISOString(),
    footer: {
      text: `innova-bot • Jit Heartbeat System`,
      icon_url: 'https://github.com/identicons/innova.png',
    },
    fields: [
      {
        name: 'Status',
        value: status.toUpperCase(),
        inline: true,
      },
      {
        name: 'System',
        value: 'Jit (จิต) - Master Orchestrator',
        inline: true,
      },
    ],
  };
}

/**
 * Main
 */
async function main() {
  console.log(`\n🫀 Hermes Broadcaster - Heartbeat #${beatNum}`);
  console.log(`   Status: ${status}`);
  console.log(`   Message: ${message.substring(0, 100)}...`);

  try {
    const embed = buildEmbed();
    await sendViaWebhook(embed);
    console.log('✅ Broadcast complete\n');
  } catch (err) {
    console.error(`❌ Broadcast failed: ${err.message}\n`);
    process.exit(1);
  }
}

main();
