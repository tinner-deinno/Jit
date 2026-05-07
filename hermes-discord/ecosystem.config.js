/**
 * PM2 Ecosystem Config — อนุ Discord Bot (24/7)
 *
 * Usage:
 *   npm install -g pm2
 *   pm2 start ecosystem.config.js
 *   pm2 save && pm2 startup   # auto-start on reboot
 *   pm2 logs hermes-discord   # live logs
 *   pm2 monit                 # realtime monitor
 */

module.exports = {
  apps: [
    {
      name: "hermes-discord",
      script: "bot.js",
      cwd: __dirname,

      // ── Restart policy ──────────────────────────────────────────
      autorestart: true,
      max_restarts: 20,
      restart_delay: 5000,       // wait 5s before restart
      min_uptime: "30s",         // crash loops < 30s = exponential backoff

      // ── Environment ─────────────────────────────────────────────
      env: {
        NODE_ENV: "production",
        // Tokens come from system env or .env loaded by dotenv
        // DISCORD_TOKEN and OLLAMA_TOKEN must be set in shell env
      },
      env_production: {
        NODE_ENV: "production",
        OLLAMA_BASE_URL: "https://ollama.mdes-innova.online",
        OLLAMA_MODEL: "gemma4:e4b",
        // Tune thought-loop for 24/7 production
        JIT_THOUGHT_LOOP_ENABLED: "true",
        JIT_THOUGHT_LOOP_INTERVAL_MS: "120000",         // 2 min (was 5 min)
        JIT_THOUGHT_LOOP_ACTIVE_WINDOW_MS: "900000",    // 15 min activity window
        JIT_THOUGHT_LOOP_MIN_MESSAGES: "2",             // lower threshold
        JIT_THOUGHT_LOOP_MIN_PARTICIPANTS: "1",         // single-user channels
      },

      // ── Log management ──────────────────────────────────────────
      log_file: "logs/hermes-combined.log",
      out_file: "logs/hermes-out.log",
      error_file: "logs/hermes-err.log",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      max_memory_restart: "400M",

      // ── Watch (disabled for prod — avoids restarts on log writes) ─
      watch: false,

      // ── Graceful shutdown ───────────────────────────────────────
      kill_timeout: 8000,
      listen_timeout: 5000,
    },
  ],
};
