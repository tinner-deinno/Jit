#!/usr/bin/env bash
# ghp.sh — GitHub PAT helper
# Stores and retrieves the user's GitHub PAT from Windows Credential Manager
# (or fallback to .ghp-cache) so agents can use gh CLI without env-var shuffling.
#
# Usage:
#   ghp set <token>     — store token in Windows Credential Manager
#   ghp get             — print token to stdout (or set GITHUB_TOKEN in env)
#   ghp clear           — remove token
#   ghp status          — show current PAT state (presence only, no secret)
#   ghp test            — call gh api user to verify token works

set -e

CACHE_FILE="$HOME/.ghp-cache"
VAULT_NAME="mdes-innova-ghp"

cmd="${1:-status}"
shift || true

set_token() {
  local token="$1"
  if [ -z "$token" ]; then
    echo "Usage: ghp set <token>"
    exit 1
  fi
  # Try Windows Credential Manager (works under git-bash on Windows)
  if command -v cmdkey >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "cmdkey /generic:$VAULT_NAME /user:ghp /pass:'$token'" >/dev/null 2>&1 || true
    echo "✅ Stored in Windows Credential Manager (vault: $VAULT_NAME)"
  fi
  # Fallback cache (chmod 600)
  echo "$token" > "$CACHE_FILE"
  chmod 600 "$CACHE_FILE" 2>/dev/null || true
  echo "✅ Cached at $CACHE_FILE (chmod 600)"
}

get_token() {
  if [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN"
    return
  fi
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    return
  fi
  if command -v powershell.exe >/dev/null 2>&1; then
    local token
    token=$(powershell.exe -NoProfile -Command "(Get-StoredCredential -Target '$VAULT_NAME' -ErrorAction SilentlyContinue).GetNetworkCredential().Password" 2>/dev/null || true)
    if [ -n "$token" ]; then
      echo "$token"
      return
    fi
  fi
  echo ""
}

clear_token() {
  rm -f "$CACHE_FILE"
  if command -v cmdkey >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "cmdkey /delete:$VAULT_NAME" >/dev/null 2>&1 || true
  fi
  unset GITHUB_TOKEN
  echo "✅ ghp cleared"
}

status_token() {
  if [ -n "$(get_token)" ]; then
    echo "✅ ghp: token present"
  else
    echo "❌ ghp: no token (run: ghp set <token>)"
    exit 1
  fi
}

test_token() {
  local token
  token=$(get_token)
  if [ -z "$token" ]; then
    echo "❌ No token to test"
    exit 1
  fi
  echo "Testing token against GitHub API..."
  if command -v gh >/dev/null 2>&1; then
    GH_TOKEN="$token" gh api user --jq '.login' 2>&1
  else
    curl -sf -H "Authorization: token $token" https://api.github.com/user | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>{try{console.log(JSON.parse(d).login||'?')}catch(e){console.log('parse error')}});"
  fi
}

case "$cmd" in
  set)    set_token "$1" ;;
  get)    get_token ;;
  clear)  clear_token ;;
  status) status_token ;;
  test)   test_token ;;
  *)      echo "Usage: ghp {set|get|clear|status|test}"; exit 1 ;;
esac
