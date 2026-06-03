#!/usr/bin/env bash
# eval/bus-latency-check.sh — Quality Gate for Sayanprasathan (Nerve System)
#
# This script measures the end-to-end latency of the communication bus
# to ensure that the "connective tissue" is not straining.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

BUS_ROOT="/tmp/manusat-bus"
TARGET_PATH=("vaja" "jit" "soma" "lak" "innova" "vaja")
THRESHOLD_MS=500

echo -e "${BOLD}=== Sayanprasathan Quality Gate: Bus Latency Check ===${RESET}"

# 1. Measure End-to-End Propagation Lag (The Neural Pulse)
echo -n "Testing Neural Pulse (vaja -> jit -> soma -> lak -> innova -> vaja)... "
START_TIME=$(date +%s%3N)

# Simplified simulation of the chain for latency measurement
# In a real scenario, this would trigger the agents to actually respond.
# For the quality gate, we measure the time to write and read a sequence of messages.

T_START=$(date +%s%3N)
# Simulation: send 5 messages in sequence and read them back
for AGENT in "${TARGET_PATH[@]}"; do
  bash "$SCRIPT_DIR/../network/bus.sh" send "$AGENT" "latency-test" "ping" > /dev/null
done

# Wait for them to be processed (simulated)
# We check for the existence of the last message in the cycle
LAST_AGENT="${TARGET_PATH[-1]}"
while [ ! -f "$BUS_ROOT/$LAST_AGENT"/*.msg ] 2>/dev/null; do
  sleep 0.01
done

T_END=$(date +%s%3N)
LATENCY=$((T_END - T_START))

if [ "$LATENCY" -le "$THRESHOLD_MS" ]; then
  echo -e "${GREEN}PASS${RESET} (${LATENCY}ms)"
else
  echo -e "${RED}FAIL${RESET} (${LATENCY}ms > ${THRESHOLD_MS}ms)"
  EXIT_CODE=1
fi

# 2. Measure Signal-to-Noise Ratio (SNR)
echo -n "Measuring Signal-to-Noise Ratio... "
TOTAL_MSGS=$(find "$BUS_ROOT" -name "*.msg" 2>/dev/null | wc -l)
CRITICAL_MSGS=$(find "$BUS_ROOT" -name "*.msg" 2>/dev/null | xargs grep -lE "subject:(task|alert|request)" | wc -l)
NOISE_MSGS=$(find "$BUS_ROOT" -name "*.msg" 2>/dev/null | xargs grep -lE "subject:(heartbeat|pulse)" | wc -l)

if [ "$TOTAL_MSGS" -eq 0 ]; then
  echo -e "${YELLOW}SKIP${RESET} (No messages in bus)"
elif [ "$NOISE_MSGS" -gt 0 ]; then
  SNR=$(echo "scale=2; $CRITICAL_MSGS / $NOISE_MSGS" | bc 2>/dev/null || echo "0")
  if (( $(echo "$SNR > 0.1" | bc -l) )); then
    echo -e "${GREEN}PASS${RESET} (SNR: $SNR)"
  else
    echo -e "${YELLOW}WARN${RESET} (SNR: $SNR - Noise is dominating)"
  fi
else
  echo -e "${GREEN}PASS${RESET} (No noise detected)"
fi

# 3. Inbox Backlog (Congestion Check)
echo -n "Checking for Inbox Congestion... "
PENDING=$(find "$BUS_ROOT" -name "*.msg" 2>/dev/null | wc -l)
if [ "$PENDING" -lt 100 ]; then
  echo -e "${GREEN}PASS${RESET} ($PENDING pending)"
else
  echo -e "${RED}FAIL${RESET} ($PENDING pending - System congested!)"
  EXIT_CODE=1
fi

if [ -z "$EXIT_CODE" ]; then
  echo -e "\n${GREEN}✔ Sayanprasathan Health: STABLE${RESET}"
  exit 0
else
  echo -e "\n${RED}✘ Sayanprasathan Health: DEGRADED${RESET}"
  exit $EXIT_CODE
fi
