#!/usr/bin/env bash
# voice/voice.sh — Quick launcher for voice server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.bun/bin:$PATH"
export JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
exec bun run "$SCRIPT_DIR/server.ts"
