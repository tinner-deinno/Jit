<!-- cc-team deliverable
 group: SEC (Secrets overhaul tooling + docs (gitleaks, hooks, CI, sanitizer, playbook, README, hardened compose))
 member: S1 role=dev model=deepseek/deepseek-v4-pro
 finish_reason: stop | tokens: {"prompt_tokens":295,"completion_tokens":3280,"total_tokens":3575,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":2612,"image_tokens":0},"cache_creation_input_tokens":0} | 32s
 generated: 2026-06-12T19:15:10.857Z -->
# Project Secrets Detection Configuration

[extend]
useDefault = true

# Custom rule: COMMANDCODE key with literal prefix 'user_' followed by 60-90 alphanumeric chars
[[rules]]
id = "commandcode-key"
description = "Matches COMMANDCODE secrets with prefix user_ and 60-90 [A-Za-z0-9] chars"
regex = 'user_[A-Za-z0-9]{60,90}'
keywords = ["commandcode", "user_"]

# Custom rule: 32-char lowercase hex token assigned to OLLAMA_TOKEN or THAILLM_TOKEN
[[rules]]
id = "ollama-thaillm-token"
description = "Detects 32-char hex token in OLLAMA_TOKEN or THAILLM_TOKEN assignments"
regex = '(OLLAMA_TOKEN|THAILLM_TOKEN)\s*=\s*[''"]?([a-f0-9]{32})[''"]?'
keywords = ["OLLAMA_TOKEN", "THAILLM_TOKEN"]

# Custom rule: Discord bot token (three dot-separated segments, first segment 24+ chars)
[[rules]]
id = "discord-bot-token"
description = "Discord bot token pattern: base64 segments separated by dots, first part >=24 chars"
regex = '[A-Za-z0-9_-]{24,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{27,}'
keywords = ["discord", "bot", "token", "DISCORD_TOKEN"]

# Custom rule: RS256 JWT assigned to CODEX_API_KEY (header and payload start with eyJ)
[[rules]]
id = "codex-api-key-jwt"
description = "Detects a full RS256 JWT assigned to CODEX_API_KEY"
regex = 'CODEX_API_KEY\s*=\s*eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
keywords = ["CODEX_API_KEY", "jwt", "rs256"]

# Custom rule: Generic OpenAI API key starting with sk-
[[rules]]
id = "openai-api-key"
description = "Generic OpenAI API key (sk- followed by 20+ alphanumeric characters)"
regex = 'sk-[a-zA-Z0-9]{20,}'
keywords = ["openai", "api", "key", "sk-"]

[allowlist]
  # Paths to ignore: .env.example files, docs/ directory, markdown placeholder docs, pnpm-lock.yaml, node_modules
  paths = [
    '''.*\.env\.example$''',
    '''^docs/''',
    '''.*\.md$''',
    '''pnpm-lock\.yaml$''',
    '''node_modules/''',
  ]
  # Allow secrets containing common placeholders like YOUR_, REDACTED, example, change-me, ${ shell-var
  regexes = [
    '''(YOUR_|REDACTED|example|change-me|\$\{)''',
  ]
