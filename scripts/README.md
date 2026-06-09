# Scripts - Daemon and Startup Scripts

The `scripts/` directory contains daemon processes, startup/shutdown scripts, and system utilities for the มนุษย์ Agent (Jit) system. These scripts manage long-running processes, system initialization, health monitoring, and automated maintenance tasks.

## Overview

Scripts in this directory provide the operational infrastructure that keeps the Jit system running reliably. Unlike limb and organ scripts which are typically invoked on-demand by agents, these scripts often run as background daemons or are invoked during system startup/shutdown.

## Daemon Processes

### Heartbeat System (`heartbeat.sh`)
- **Purpose**: Living rhythm system that provides the vital heartbeat for the Jit system
- **Functions**: 
  - Collects signals/stats from all agents (IN beat - diastole)
  - Broadcasts energy/commands to all organs (OUT beat - systole)
  - Adaptive rate adjustment based on system activity (sprint/fast/normal/slow/rest)
  - Memory decay collection and anomaly detection (JIT-016, JIT-024)
  - DLQ health checking and Oracle health monitoring
- **Key Features**:
  - Dual-beat cycle: IN (collect) → OUT (broadcast)
  - Local state only - no git commits for runtime operations
  - Automatic stale message cleanup
  - Integration with Oracle health monitoring
- **Usage**:
  ```bash
  bash scripts/heartbeat.sh start     # Start background daemon
  bash scripts/heartbeat.sh stop      # Stop daemon  
  bash scripts/heartbeat.sh status    # Check daemon status
  bash scripts/heartbeat.sh once      # Single pulse (IN+OUT)
  bash scripts/heartbeat.sh rate <mode>  # Change rate (sprint/fast/normal/slow/rest)
  ```
- **Related**: `organs/heart.sh` (organ interface), `limbs/lib.sh` (shared functions)

### Oracle Daemon (`start-oracle.sh`)
- **Purpose**: Starts and manages the Arra Oracle V3 knowledge base service
- **Functions**:
  - Starts Oracle knowledge base on port 47778
  - Manages Oracle process lifecycle
  - Provides health checking and restart capabilities
- **Usage**:
  ```bash
  bash scripts/start-oracle.sh        # Start Oracle service
  # Manual control:
  cd /workspaces/arra-oracle-v3
  ORACLE_PORT=47778 bun run src/server.ts
  ```
- **Health Check**: `curl http://localhost:47778/api/health`

### Hermes Systems
- **Hermes Discord (`hermes-discord.sh`)**:
  - Purpose: Discord bot for system notifications and alerts
  - Usage: `bash scripts/hermes-discord.sh start|stop|status`
  
- **Hermes Ollama (`hermes-ollama.sh`)**:
  - Purpose: Ollama model server management
  - Usage: `bash scripts/hermes-ollama.sh start|stop|status`

### Loops and Automation
- **Loop Master (`jit-loops-master.sh`)**:
  - Purpose: Master loop coordinator for scheduled agent activities
  - Usage: `bash scripts/jit-loops-master.sh`
  
- **Housekeeping Loop (`housekeeping-loop.sh`)**:
  - Purpose: Periodic cleanup and maintenance tasks
  - Usage: `bash scripts/housekeeping-loop.sh`
  
- **Writer Loop (`writer-loop.sh`)**:
  - Purpose: Automated documentation and report generation
  - Usage: `bash scripts/writer-loop.sh`

### System Initialization
- **Bootstrap System (`bootstrap.sh`)**:
  - Purpose: Complete system initialization and setup
  - Functions:
    - Installs Bun package manager
    - Clones Arra Oracle V3 repository
    - Initializes Oracle database
    - Starts Oracle knowledge base
    - Runs initial health checks
  - Usage: `bash scripts/bootstrap.sh`
  
- **Initialize Life (`init-life.sh`)**:
  - Purpose: Initializes a new มนุษย์ Agent system instance
  - Usage: `bash scripts/init-life.sh`

### Remote Management
- **Innova Remote (`innova-remote.sh`)**:
  - Purpose: Remote management interface for innova agent
  - Usage: `bash scripts/innova-remote.sh [command]`
  
- **Karn Remote (`karn-remote.sh`)**:
  - Purpose: Remote input collection for karn (ear) agent
  - Usage: `bash scripts/karn-remote.sh`
  
- **Multi-Remote (`multi-remote.sh`)**:
  - Purpose: Multi-agent remote coordination
  - Usage: `bash scripts/multi-remote.sh`

### Monitoring and Reporting
- **Status Broadcaster (`status-broadcaster-loop.sh`)**:
  - Purpose: Periodic system status reporting
  - Usage: `bash scripts/status-broadcaster-loop.sh`
  
- **Hermes Report Status (`hermes-report-status.sh`)**:
  - Purpose: Generate and send status reports via Hermes
  - Usage: `bash scripts/hermes-report-status.sh`

### Identity and Synchronization
- **Sync Identity (`sync-identity.sh`)**:
  - Purpose: Synchronize agent identity across machines
  - Usage: `bash scripts/sync-identity.sh`
  
- **Sync Cross Machine (`sync-cross-machine.sh`)**:
  - Purpose: Synchronize state between multiple machines
  - Usage: `bash scripts/sync-cross-machine.sh [push|pull]`

### Pattern Detection
- **Pattern Detector Loop (`pattern-detector-loop.sh`)**:
  - Purpose: Detect patterns in system behavior and logs
  - Usage: `bash scripts/pattern-detector-loop.sh`

### Awakening System
- **Awaken (`awaken.sh`)**:
  - Purpose: System awakening and identity confirmation
  - Usage: `bash scripts/awaken.sh [--reawaken]`

### Cleanup and Maintenance
- **Cmdteam Daemon (`cmdteam-daemon.sh`)**:
  - Purpose: Background daemon for cmdteam operations
  - Usage: `bash scripts/cmdteam-daemon.sh start|stop|status`
  
- **Cmdteam Loops Master (`cmdteam-loops-master.sh`)**:
  - Purpose: Master loop for cmdteam scheduled tasks
  - Usage: `bash scripts/cmdteam-loops-master.sh`
  
- **Cmdteam Cleanup Loop (`cmdteam-cleanup-loop.sh`)**:
  - Purpose: Periodic cleanup of temporary files and logs
  - Usage: `bash scripts/cmdteam-cleanup-loop.sh`
  
- **Cmdteam Self-Improve Loop (`cmdteam-self-improve-loop.sh`)**:
  - Purpose: Autonomous self-improvement processes
  - Usage: `bash scripts/cmdteam-self-improve-loop.sh`
  
- **Cmdteam Status Daemon (`cmdteam-status-daemon.sh`)**:
  - Purpose: Background status monitoring daemon
  - Usage: `bash scripts/cmdteam-status-daemon.sh start|stop|status`

### Specialized Scripts
- **Codespace Presence (`codespace-presence.sh`)**:
  - Purpose: GitHub Codespace environment detection and setup
  - Usage: `bash scripts/codespace-presence.sh`
  
- **Create JIT (`create_jit.sh`)**:
  - Purpose: Template for creating new Jit system instances
  - Usage: `bash scripts/create_jit.sh`
  
- **GSD (`gsd.sh`)**:
  - Purpose: Getting Things Done task management system
  - Usage: `bash scripts/gsd.sh [command]`
  
- **Install Heartbeat Daemon (`install-heartbeat-daemon.sh`)**:
  - Purpose: Install heartbeat as system service
  - Usage: `bash scripts/install-heartbeat-daemon.sh`
  
- **Install Hermes Discord Daemon (`install-hermes-discord.sh`)**:
  - Purpose: Install Hermes Discord as system service
  - Usage: `bash scripts/install-hermes-discord.sh`
  
- **Life Checklist (`life-checklist.sh`)**:
  - Purpose: Personal development and system health checklist
  - Usage: `bash scripts/life-checklist.sh`
  
- **Selfhood Checklist (`selfhood-checklist.sh`)**:
  - Purpose: System identity and self-awareness validation
  - Usage: `bash scripts/selfhood-checklist.sh`
  
- **Setup Secrets (`setup-secrets.sh`)**:
  - Purpose: Configure system secrets and API keys
  - Usage: `bash scripts/setup-secrets.sh`
  
- **Rollback (`rollback.sh`)**:
  - Purpose: System rollback and recovery procedures
  - Usage: `bash scripts/rollback.sh`

## Script Categories

### Daemon Scripts (Long-Running Processes)
Scripts designed to run continuously in the background:
- `heartbeat.sh` - Vital heartbeat system
- `hermes-discord.sh` - Discord notification bot
- `hermes-ollama.sh` - Ollama model server
- `jit-loops-master.sh` - Loop coordinator
- `housekeeping-loop.sh` - Maintenance loop
- `writer-loop.sh` - Documentation loop
- `cmdteam-daemon.sh` - Cmdteam background daemon
- `cmdteam-loops-master.sh` - Cmdteam loop master
- `cmdteam-cleanup-loop.sh` - Cleanup loop
- `cmdteam-self-improve-loop.sh` - Self-improvement loop
- `cmdteam-status-daemon.sh` - Status monitoring daemon
- `status-broadcaster-loop.sh` - Status broadcaster
- `pattern-detector-loop.sh` - Pattern detection

### Startup/Initialization Scripts
Scripts for system setup and initialization:
- `bootstrap.sh` - Complete system bootstrap
- `init-life.sh` - Initialize new system instance
- `setup-secrets.sh` - Configure secrets and keys
- `create_jit.sh` - Create new Jit instance template
- `sync-identity.sh` - Identity synchronization
- `innova-remote.sh` - Innova remote management
- `karn-remote.sh` - Karn remote input
- `multi-remote.sh` - Multi-agent remote coordination
- `start-oracle.sh` - Oracle knowledge base startup

### Monitoring and Reporting Scripts
Scripts for system health and status:
- `heartbeat.sh status` - Heartbeat daemon status
- `hermes-report-status.sh` - Status report generation
- `status-broadcaster-loop.sh` - Periodic status broadcasting
- `sync-cross-machine.sh` - Cross-machine synchronization
- `life-checklist.sh` - Personal development checklist
- `selfhood-checklist.sh` - Identity validation
- `setup-secrets.sh` - Secret configuration verification

### Utility and Helper Scripts
Scripts providing specialized functionality:
- `codespace-presence.sh` - Environment detection
- `gsd.sh` - Task management
- `install-heartbeat-daemon.sh` - Service installation
- `install-hermes-discord.sh` - Service installation
- `pattern-detector-loop.sh` - Pattern detection
- `rollback.sh` - Recovery procedures
- `awaken.sh` - System awakening

## Common Patterns

### Daemon Lifecycle
Most daemon scripts follow this pattern:
```bash
# Start
bash script.sh start

# Stop  
bash script.sh stop

# Status
bash script.sh status

# Restart
bash script.sh stop && bash script.sh start
```

### Configuration
Scripts typically check for:
- Environment variables (often loaded from `.env`)
- Configuration files in `config/`
- State files in `/tmp/` or memory directories
- PID files for process management

### Logging
Daemon scripts usually log to:
- `/tmp/<script-name>.log` for runtime logs
- Systemd journal when installed as services
- Custom log files specified in script configuration

## Related Documentation

- [Core Body Map](../core/body-map.md) - Complete organ ownership and RACI matrix
- [Agent Registry](../network/registry.json) - Source of truth for agent capabilities
- [Limbs README](../limbs/README.md) - Core cognition command providers
- [Organs README](../organs/README.md) - I/O layer command providers
- [Network Protocol](../network/protocol.md) - Message format and subject conventions
- [DOC_GAP_ANALYSIS.json](../docs/DOC_GAP_ANALYSIS.json) - Documentation gap analysis

---
*Documentation generated as part of DOC_GAP_ANALYSIS.json recommendations*