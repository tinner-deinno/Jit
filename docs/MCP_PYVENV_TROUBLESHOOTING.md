# MCP / pyvenv.cfg Troubleshooting

## Error: `failed to locate pyvenv.cfg ... calling "initialize": EOF`

This error occurs when an MCP client (Claude Desktop, Copilot, Antigravity) tries to
launch an MCP server via a Python virtual environment that is broken or missing.

## Root Cause

The MCP configuration (`claude_desktop_config.json` or equivalent) points to a Python
executable inside `.venv/bin/python`, but:

- `.venv/pyvenv.cfg` is missing (venv was never created, or deleted)
- `.venv/` points to the wrong Python version
- The venv was created on a different machine with an incompatible path

## Fix

### 1. Locate the broken venv

```bash
# Find pyvenv.cfg candidates
find /workspaces /home -name 'pyvenv.cfg' 2>/dev/null

# Check for broken state
ls -la /workspaces/Jit/.venv 2>/dev/null || echo "No .venv in Jit repo"
ls -la /workspaces/innova-bot/.venv 2>/dev/null || echo "No innova-bot .venv"
```

### 2. Rename broken venv

```bash
BROKEN_VENV="/workspaces/innova-bot/.venv"
if [ -d "$BROKEN_VENV" ] && [ ! -f "$BROKEN_VENV/pyvenv.cfg" ]; then
  mv "$BROKEN_VENV" "${BROKEN_VENV}.broken-$(date +%Y%m%d%H%M%S)"
  echo "Renamed broken venv"
fi
```

### 3. Recreate venv

```bash
cd /workspaces/innova-bot  # or wherever your MCP server lives
python3 -m venv .venv
source .venv/bin/activate
pip install -e .   # or: pip install -r requirements.txt
```

### 4. Update MCP config

Find your MCP config (commonly one of these paths):
- `~/.config/claude/claude_desktop_config.json`
- `~/.claude/mcp_servers.json`
- `/workspaces/Jit/config/mcp_servers.json`
- VS Code settings: `copilot.mcp.servers`

Ensure the `command` field points to the recreated venv:

```json
{
  "mcpServers": {
    "innova-bot": {
      "command": "/workspaces/innova-bot/.venv/bin/python",
      "args": ["-m", "innova_bot.main"],
      "env": {
        "MCP_TRANSPORT": "sse",
        "MCP_HOST": "127.0.0.1",
        "MCP_PORT": "7010"
      }
    }
  }
}
```

### 5. Alternative: use system Python

If you don't need isolation, point MCP directly at system Python:

```json
{
  "command": "/home/codespace/.python/current/bin/python3",
  "args": ["-m", "innova_bot.main"]
}
```

### 6. Verify

```bash
# Check venv is valid
python3 -c "import sys; print(sys.prefix)"

# Check MCP server starts
/workspaces/innova-bot/.venv/bin/python -m innova_bot.main &
sleep 2
curl -sf http://127.0.0.1:7010/gui && echo "MCP GUI: OK"
```

## PC3 Node Status (2026-05-05)

- No `.venv` in Jit repo (not needed — shell-based system)
- `innova-bot` repo: **not cloned** — MCP server not active
- System Python: `/home/codespace/.python/current/bin/python3` (3.12.1)
- MCP port 7010: **not bound** (innova-bot not running)

To activate MCP/Antigravity on PC3:
```bash
bash scripts/innova-bot-setup.sh <your-innova-bot-git-url>
```
