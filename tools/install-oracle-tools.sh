#!/usr/bin/env bash
# install-oracle-tools.sh — install the ghp + oracle CLI helpers into the user's PATH
# Run once. Idempotent.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"

# Link ghp + oracle
ln -sf "$SCRIPT_DIR/ghp.sh" "$INSTALL_DIR/ghp"
ln -sf "$SCRIPT_DIR/oracle" "$INSTALL_DIR/oracle"

chmod +x "$INSTALL_DIR/ghp" "$INSTALL_DIR/oracle"

# Verify PATH
case ":$PATH:" in
  *":$INSTALL_DIR:"*) echo "✅ $INSTALL_DIR already in PATH" ;;
  *)
    echo "⚠️  Add this to your shell profile:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

# Smoke test
echo
echo "=== Smoke test ==="
"$INSTALL_DIR/oracle" --help | head -3
echo "---"
"$INSTALL_DIR/ghp" status || true
