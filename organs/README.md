# Organs - I/O Layer Command Providers

The `organs/` directory contains I/O layer scripts that serve as command providers for agents in the มนุษย์ Agent (Jit) system. These scripts provide sensory input, motor output, and vital functions that agents use to interact with the internal and external world.

## Overview

Organs represent the interface layer of the system, analogous to biological organs that handle sensing, action, and vital functions. Agents invoke organ scripts to perceive their environment and act upon it.

## Command Providers

### Ear System (`ear.sh`)
- **Agent**: หู (karn) - Ear / Listener / Input Collector
- **Organ**: หู (Ear)
- **Purpose**: Receiving messages, listening to queues, collecting input
- **Capabilities**: listen, receive, inbox, from, clear, pulse, status
- **Usage**: `bash organs/ear.sh listen [timeout]`

### Eye System (`eye.sh`)
- **Agents**: 
  - เนตร (netra) - Eye / Observer / Monitor
  - เนตร (neta) - Eye / Code Reviewer
- **Organ**: ตา (Eye)
- **Purpose**: Observation, monitoring, environment scanning, change detection
- **Capabilities**: observe, monitor, watch, detect-changes, scan-environment, report-status, flag-anomaly, health-check
- **Usage**: `bash organs/eye.sh observe [target]`

### Mouth System (`mouth.sh`)
- **Agent**: ปาก (vaja) - Speech / Personal Assistant (PA)
- **Organ**: ปาก (Mouth)
- **Purpose**: Sending messages, output, logging, reporting
- **Capabilities**: say, tell, broadcast, reply, report, status
- **Usage**: `bash organs/mouth.sh tell <agent> "<subject>" "<message>"`

### Nose System (`nose.sh`)
- **Agent**: จมูก (chamu) - Nose / QA / Tester
- **Organ**: จมูก (Nose)
- **Purpose**: Detection, monitoring, health checking, quality gates
- **Capabilities**: detect, monitor, health, sniff, alert, report
- **Usage**: `bash organs/nose.sh detect [target]`

### Hand System (`hand.sh`)
- **Agent**: มือ (mue) - Hand / Executor / Action Agent
- **Organ**: มือ (Hand)
- **Purpose**: Execution, file operations, command running, action tracking
- **Capabilities**: execute, create, modify, delete, write-files, run-commands, action-tracking, result-reporting, change-management
- **Usage**: `bash organs/mouth.sh tell mue "bash organs/hand.sh create <filename> <content>"`

### Hand-Safe System (`hand-safe.sh`)
- **Purpose**: Secure file operations with injection protection
- **Capabilities**: safe-create, safe-modify, safe-delete
- **Usage**: `bash organs/hand-safe.sh safe-create <filename> <content>`

### Leg System (`leg.sh`)
- **Agent**: ขา (pada) - Foot / DevOps / Infrastructure
- **Organ**: ขา (Leg)
- **Purpose**: CI/CD, deployment, infrastructure management, incident response
- **Capabilities**: ci-cd, deploy, rollback, monitor, infra-as-code, incident-response, secret-manage
- **Usage**: `bash organs/leg.sh deploy <service> <version>`

### Heart System (`heart.sh`)
- **Agent**: หัวใจ (pran) - Heart / Vital Orchestrator / Heartbeat Monitor
- **Organ**: หัวใจ (Heart)
- **Purpose**: Vital sign monitoring, heartbeat, system-alive signal, task dispatch
- **Capabilities**: heartbeat, vital-sign-monitoring, pulse-check, system-alive-signal, rhythmic-operations, task-dispatch, emergency-alert, state-sync, rate, pump, rhythm, routes, oracle-health, monitor-oracle, read-health, memory-size, memory-prune, anomaly-status
- **Usage**: `bash organs/heart.sh beat cycle`

### Lung System (`lung.sh`)
- **Agent**: ปอด (lung) - Lung / Purifier / Energy Filter
- **Organ**: ปอด (Lung)
- **Purpose**: Purification, clean energy distribution, blood filtering, respiration, waste management
- **Capabilities**: purify, clean-energy, blood-filter, respiration, waste-management
- **Usage**: `bash organs/lung.sh purify [target]`

### Nerve System (`nerve.sh`)
- **Agent**: ระบบประสาท (sayanprasathan) - Nerve / Event / Signal Network
- **Organ**: ระบบประสาท (Nerve)
- **Purpose**: Signal detection, event broadcasting, alert propagation, signal routing
- **Capabilities**: signal-detection, event-broadcast, alert-propagation, signal-routing, event-logging, priority-escalation, cross-agent-notification, emergency-signals
- **Usage**: `bash organs/nerve.sh signal-detection [source]`

### Netra System (`netra.sh`)
- **Agent**: เนตร (netra) - Eye / Observer / Monitor (additional specialization)
- **Organ**: ตา (Eye) - shared with eye.sh
- **Purpose**: Extended observation, monitoring, watch functions
- **Capabilities**: observe, monitor, watch, detect-changes, scan-environment, report-status, flag-anomaly, health-check
- **Usage**: `bash organs/netra.sh observe [target]`

### Vitals System (`vitals.sh`)
- **Purpose**: Vital signs dashboard, system health overview
- **Capabilities**: rhythm (shows vital signs dashboard)
- **Usage**: `bash organs/vitals.sh`

## Usage Patterns

Agents invoke organ scripts to interact with their environment:

```bash
# Example: Karn (ear) agent listening for messages
bash organs/ear.sh listen 30

# Example: Netra (eye) agent observing system status
bash organs/eye.sh observe "system health"

# Example: Vaja (mouth) agent sending a report
bash organs/mouth.sh tell jit "status_report" "All systems operational"

# Example: Mue (hand) agent creating a file
bash organs/mouth.sh tell mue "bash organs/hand.sh create README.md \"# Project Documentation\""

# Example: Pran (heart) agent checking system vitality
bash organs/heart.sh rhythm
```

## Message Flow

Organs facilitate the standard message flow in the Jit system:

### Standard Feature Flow
```
human → vaja (mouth) → jit (index) → soma (think) → lak (design) → innova (oracle) 
→ chamu (nose) → neta (eye) → pada (leg) → vaja (mouth) → human
```

### Standard Bug Flow
```
chamu (nose) → jit (index) → innova (oracle) → neta (eye) → pada (leg) → vaja (mouth)
```

### System Health/Monitoring Flow
```
pran (heart) ← all agents ← jit (index) → sayanprasathan (nerve) (broadcast alerts)
netra (eye) + karn (ear) → jit (index) → mue (hand) (execute)
```

## Related Documentation

- [Core Body Map](../core/body-map.md) - Complete organ ownership and RACI matrix
- [Agent Registry](../network/registry.json) - Source of truth for agent capabilities
- [Limbs README](../limbs/README.md) - Core cognition command providers
- [Scripts README](../scripts/README.md) - Daemon and startup scripts
- [Network Protocol](../network/protocol.md) - Message format and subject conventions

---
*Documentation generated as part of DOC_GAP_ANALYSIS.json recommendations*