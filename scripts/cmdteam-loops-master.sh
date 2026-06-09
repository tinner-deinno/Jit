#!/usr/bin/env bash
# Master loop driver: status (15m), cleanup (1h), self-improve (2h)
# Each loop runs as separate background process for crash isolation
mkdir -p /tmp/cmdteam

# Status monitor (15 min = 900s)
( while true; do
    /workspaces/Jit/scripts/cmdteam-status-daemon.sh >> /tmp/cmdteam/status.log 2>&1
    sleep 900
  done ) >/dev/null 2>&1 &
echo "status-pid: $!"

# Cleanup loop (1 hour = 3600s)
( while true; do
    /workspaces/Jit/scripts/cmdteam-cleanup-loop.sh >> /tmp/cmdteam/cleanup.log 2>&1
    sleep 3600
  done ) >/dev/null 2>&1 &
echo "cleanup-pid: $!"

# Self-improve (2 hours = 7200s)
( while true; do
    /workspaces/Jit/scripts/cmdteam-self-improve-loop.sh >> /tmp/cmdteam/improve.log 2>&1
    sleep 7200
  done ) >/dev/null 2>&1 &
echo "improve-pid: $!"

echo "all loops started"
