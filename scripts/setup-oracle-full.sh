#!/usr/bin/env bash
# scripts/setup-oracle-full.sh — Arra Oracle Full Setup
#
# สั่งรันได้ครั้งเดียว ครบทุก component:
#   1. arra-oracle  — HTTP server (port 47778)
#   2. arra-cli     — Plugin runner CLI
#   3. oracle-studio — React dashboard UI
#   4. oracle-vault — Vault CLI wrapper
#   5. Claude MCP   — ~/.claude.json auto-config
#
# Usage:
#   bash scripts/setup-oracle-full.sh           # setup + start all
#   bash scripts/setup-oracle-full.sh --status  # check running services
#   bash scripts/setup-oracle-full.sh --stop    # stop all background services
#
# Environment:
#   ORACLE_PORT       default: 47778
#   ORACLE_STUDIO_PORT default: 47779

set -euo pipefail

export PATH="$HOME/.bun/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORACLE_SRC="/workspaces/arra-oracle-v3"

ORACLE_PORT="${ORACLE_PORT:-47778}"
ORACLE_STUDIO_PORT="${ORACLE_STUDIO_PORT:-47779}"

LOG_ORACLE="/tmp/oracle-server.log"
LOG_STUDIO="/tmp/oracle-studio.log"
PID_ORACLE="/tmp/oracle-server.pid"
PID_STUDIO="/tmp/oracle-studio.pid"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

banner() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║  🔮 Arra Oracle — Full Setup                         ║${RESET}"
  echo -e "${BOLD}${CYAN}║  มนุษย์ Agent · Jit repo · $(date '+%Y-%m-%d %H:%M')          ║${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

ok()   { echo -e "  ${GREEN}✅${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠️ ${RESET} $1"; }
err()  { echo -e "  ${RED}❌${RESET} $1"; }
step() { echo -e "\n${BOLD}  ── $1 ──${RESET}"; }

# ── --status mode ─────────────────────────────────────────────────
if [ "${1:-}" = "--status" ]; then
  banner
  step "Service Status"
  # Oracle HTTP
  if [ -f "$PID_ORACLE" ] && kill -0 "$(cat "$PID_ORACLE")" 2>/dev/null; then
    ok "arra-oracle HTTP running (PID $(cat "$PID_ORACLE")) → http://localhost:$ORACLE_PORT"
    curl -s "http://localhost:$ORACLE_PORT/api/health" | python3 -c \
      'import sys,json; d=json.load(sys.stdin); print("     status:", d.get("status"), "| version:", d.get("version"))' 2>/dev/null || true
  else
    warn "arra-oracle HTTP not running"
  fi
  # Studio
  if [ -f "$PID_STUDIO" ] && kill -0 "$(cat "$PID_STUDIO")" 2>/dev/null; then
    ok "oracle-studio running (PID $(cat "$PID_STUDIO")) → http://localhost:$ORACLE_STUDIO_PORT"
  else
    warn "oracle-studio not running"
  fi
  echo ""
  exit 0
fi

# ── --stop mode ────────────────────────────────────────────────────
if [ "${1:-}" = "--stop" ]; then
  banner
  step "Stopping services"
  for pid_file in "$PID_ORACLE" "$PID_STUDIO"; do
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
      kill "$(cat "$pid_file")"
      ok "stopped PID $(cat "$pid_file")"
      rm -f "$pid_file"
    fi
  done
  ok "All services stopped"
  exit 0
fi

banner

# ════════════════════════════════════════════════════════════════
# Step 1 — Bun
# ════════════════════════════════════════════════════════════════
step "1. Bun runtime"
if command -v bun &>/dev/null; then
  ok "bun $(bun --version) found at $(which bun)"
else
  err "bun not found — installing..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  ok "bun installed: $(bun --version)"
fi

# ════════════════════════════════════════════════════════════════
# Step 2 — Clone / update arra-oracle-v3 source
# ════════════════════════════════════════════════════════════════
step "2. arra-oracle-v3 source"
if [ -d "$ORACLE_SRC/.git" ]; then
  ok "already cloned at $ORACLE_SRC"
  (cd "$ORACLE_SRC" && git pull --quiet origin main 2>&1 | tail -1) || true
else
  echo "  Cloning Soul-Brews-Studio/arra-oracle-v3..."
  if [ -w "/workspaces" ]; then
    git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3 "$ORACLE_SRC"
  else
    sudo git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3 "$ORACLE_SRC"
    sudo chown -R "$(id -u):$(id -g)" "$ORACLE_SRC"
  fi
  ok "cloned to $ORACLE_SRC"
fi
(cd "$ORACLE_SRC" && bun install --silent)
ok "dependencies installed"

# ════════════════════════════════════════════════════════════════
# Step 3 — Start Oracle HTTP server
# ════════════════════════════════════════════════════════════════
step "3. arra-oracle HTTP server  (port $ORACLE_PORT)"
echo -e "  ${CYAN}bunx --bun arra-oracle@github:Soul-Brews-Studio/arra-oracle-v3${RESET}"

# Stop stale instance
if [ -f "$PID_ORACLE" ] && kill -0 "$(cat "$PID_ORACLE")" 2>/dev/null; then
  warn "stopping old instance (PID $(cat "$PID_ORACLE"))"
  kill "$(cat "$PID_ORACLE")" && sleep 1
fi

ORACLE_PORT="$ORACLE_PORT" bun run "$ORACLE_SRC/src/server.ts" >> "$LOG_ORACLE" 2>&1 &
echo $! > "$PID_ORACLE"
sleep 2

if curl -sf "http://localhost:$ORACLE_PORT/api/health" >/dev/null; then
  ok "HTTP server running → http://localhost:$ORACLE_PORT  (log: $LOG_ORACLE)"
else
  err "server did not start — check $LOG_ORACLE"
fi

# ════════════════════════════════════════════════════════════════
# Step 4 — arra-cli
# ════════════════════════════════════════════════════════════════
step "4. arra-cli plugin runner"
echo -e "  ${CYAN}bunx --bun arra-cli@github:Soul-Brews-Studio/arra-oracle-v3 --help${RESET}"
PLUGIN_COUNT=$(bun "$ORACLE_SRC/cli/src/cli.ts" 2>&1 | grep -o 'loaded [0-9]* plugins' | head -1 || echo "loaded")
ok "arra-cli ready — $PLUGIN_COUNT"
echo -e "  ${YELLOW}  Tip: bun $ORACLE_SRC/cli/src/cli.ts search \"<query>\"${RESET}"

# ════════════════════════════════════════════════════════════════
# Step 5 — oracle-studio UI
# ════════════════════════════════════════════════════════════════
step "5. oracle-studio UI  (port $ORACLE_STUDIO_PORT)"
echo -e "  ${CYAN}bunx --bun oracle-studio@github:Soul-Brews-Studio/oracle-studio${RESET}"

# Stop stale instance
if [ -f "$PID_STUDIO" ] && kill -0 "$(cat "$PID_STUDIO")" 2>/dev/null; then
  warn "stopping old studio (PID $(cat "$PID_STUDIO"))"
  kill "$(cat "$PID_STUDIO")" && sleep 1
fi

ORACLE_API_URL="http://localhost:$ORACLE_PORT" \
  bunx --bun oracle-studio@github:Soul-Brews-Studio/oracle-studio \
  --port "$ORACLE_STUDIO_PORT" >> "$LOG_STUDIO" 2>&1 &
echo $! > "$PID_STUDIO"
sleep 3

if kill -0 "$(cat "$PID_STUDIO")" 2>/dev/null; then
  ok "oracle-studio running → http://localhost:$ORACLE_STUDIO_PORT  (log: $LOG_STUDIO)"
else
  warn "oracle-studio may not have started — check $LOG_STUDIO"
fi

# ════════════════════════════════════════════════════════════════
# Step 6 — oracle-vault CLI wrapper
# ════════════════════════════════════════════════════════════════
step "6. oracle-vault CLI"
echo -e "  ${CYAN}oracle-vault → bun $ORACLE_SRC/src/vault/cli.ts${RESET}"

# Create oracle-vault shim in ~/.local/bin
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/oracle-vault" << VAULT_EOF
#!/usr/bin/env bash
# oracle-vault — shim for arra-oracle-v3 vault CLI
export PATH="\$HOME/.bun/bin:\$PATH"
exec bun /workspaces/arra-oracle-v3/src/vault/cli.ts "\$@"
VAULT_EOF
chmod +x "$HOME/.local/bin/oracle-vault"
export PATH="$HOME/.local/bin:$PATH"

VAULT_VER=$(bun "$ORACLE_SRC/src/vault/cli.ts" --help 2>&1 | grep -o 'v[0-9.]*[-a-z]*' | head -1 || echo "ok")
ok "oracle-vault shim created → ~/.local/bin/oracle-vault ($VAULT_VER)"
echo -e "  ${YELLOW}  Tip: oracle-vault init <owner/repo> | status | sync | pull | migrate${RESET}"

# ════════════════════════════════════════════════════════════════
# Step 7 — Claude MCP config
# ════════════════════════════════════════════════════════════════
step "7. Claude MCP — ~/.claude.json"
echo -e "  ${CYAN}claude mcp add arra-oracle-v2 -- bun /workspaces/arra-oracle-v3/src/index.ts${RESET}"

cat > "$HOME/.claude.json" << MCP_EOF
{
  "mcpServers": {
    "arra-oracle-v2": {
      "command": "$HOME/.bun/bin/bun",
      "args": ["$ORACLE_SRC/src/index.ts"],
      "env": {
        "PATH": "$HOME/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "ORACLE_PORT": "$ORACLE_PORT"
      }
    }
  }
}
MCP_EOF
ok "~/.claude.json written — 24 MCP tools available via arra-oracle-v2"
echo -e "  ${YELLOW}  Tools: arra_search arra_learn arra_reflect arra_stats arra_verify${RESET}"
echo -e "  ${YELLOW}         arra_thread arra_trace arra_schedule_add arra_handoff + more${RESET}"

# ════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║  🎉 Arra Oracle — All components ready!              ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}HTTP Server${RESET}   http://localhost:$ORACLE_PORT/api/health"
echo -e "  ${BOLD}Studio UI${RESET}     http://localhost:$ORACLE_STUDIO_PORT"
echo -e "  ${BOLD}arra-cli${RESET}      bun $ORACLE_SRC/cli/src/cli.ts <command>"
echo -e "  ${BOLD}oracle-vault${RESET}  oracle-vault <init|status|sync|pull|migrate>"
echo -e "  ${BOLD}MCP server${RESET}    configured in ~/.claude.json"
echo ""
echo -e "  ${YELLOW}# Check health:${RESET}   curl http://localhost:$ORACLE_PORT/api/health"
echo -e "  ${YELLOW}# Search:${RESET}         bun $ORACLE_SRC/cli/src/cli.ts search \"innova\""
echo -e "  ${YELLOW}# Stop all:${RESET}       bash $0 --stop"
echo ""
