# Limbs - Core Cognition Command Providers

The `limbs/` directory contains core cognition scripts that serve as command providers for agents in the มนุษย์ Agent (Jit) system. These scripts provide fundamental cognitive functions that agents can invoke to perform thinking, acting, speaking, and other core mental operations.

## Overview

Limbs represent the cognitive layer of the system, analogous to the nervous system's role in processing information and coordinating responses. Agents invoke limb scripts to access shared cognitive capabilities without duplicating implementation.

## Command Providers

### Think System (`think.sh`)
- **Agent**: สมอง (soma) - Brain / Strategic Lead
- **Organ**: สมอง (Brain)
- **Purpose**: Strategic thinking, analysis, decision-making, synthesis
- **Capabilities**: reason, analyze, decide, synthesize, command, architect
- **Usage**: `bash limbs/think.sh "<prompt>" [--agent NAME]`

### Oracle System (`oracle.sh`)
- **Agent**: ปัญญา (innova) - Mind/Soul / Orchestrator
- **Organ**: ปัญญา (Knowledge)
- **Purpose**: Knowledge access, learning, memory, coordination
- **Capabilities**: think, plan, learn, coordinate, remember, implement
- **Usage**: `bash limbs/oracle.sh "<prompt>" [--agent NAME]`

### Index System (`index.sh`)
- **Agent**: จิต (jit) - Soul / Master Orchestrator
- **Organ**: จิต (Soul)
- **Purpose**: System coordination, task delegation, state management
- **Capabilities**: orchestrate, coordinate, synthesize, decide, monitor-all-agents, delegate-tasks, manage-state, health-check-system, strategic-planning
- **Usage**: `bash limbs/index.sh "<prompt>" [--agent NAME]`

### Act System (`act.sh`)
- **Purpose**: Executing actions, creating/modifying files, running commands
- **Capabilities**: execute, create, modify, delete, write-files, run-commands, action-tracking, result-reporting, change-management
- **Usage**: `bash limbs/act.sh "<action>" [parameters]`

### Speak System (`speak.sh`)
- **Purpose**: Speech output, logging, communication formatting
- **Capabilities**: say, tell, broadcast, reply, report
- **Usage**: `bash limbs/speak.sh "<message>" [--to AGENT]`

### Embed System (`embed.sh`)
- **Purpose**: Text embedding generation for semantic search and similarity
- **Capabilities**: generate embeddings, load embedding index, similarity search
- **Usage**: `bash limbs/embed.sh "<text>" [--action ACTION]`

### LLM System (`llm.sh`)
- **Purpose**: Unified multi-provider LLM gateway (Claude, Ollama, OpenAI, Codex)
- **Capabilities**: call, route, providers, agents, chain, status
- **Usage**: `bash limbs/llm.sh call "<prompt>" [--agent NAME] [--provider P] [--model M]`

### Ledger System (`ledger.sh`)
- **Purpose**: Decision logging, audit trails, action recording
- **Capabilities**: log-decision, record-action, audit-trail, compliance-check
- **Usage**: `bash limbs/ledger.sh "<entry>" [--type TYPE]`

### Validate System (`validate.sh`)
- **Purpose**: Input validation, data verification, constraint checking
- **Capabilities**: validate-input, check-constraints, verify-data, sanitize
- **Usage**: `bash limbs/validate.sh "<data>" [--rule RULE]`

### Validate-Task System (`validate-task.sh`)
- **Purpose**: Task-specific validation, workflow verification
- **Capabilities**: validate-task, check-workflow, verify-completion
- **Usage**: `bash limbs/validate-task.sh "<task>" [--workflow WF]`

### Agent Filter System (`agent_filter.sh`)
- **Purpose**: Message filtering, routing preferences, priority assessment
- **Capabilities**: filter-route, assess-priority, route-message
- **Usage**: `bash limbs/agent_filter.sh "<message>" [--filter RULE]`

### Index System (`index.sh`)
- **Purpose**: System indexing, metadata management, cross-referencing
- **Capabilities**: create-index, update-index, search-index, metadata-query
- **Usage**: `bash limbs/index.sh "<operation>" [--index NAME]`

### Lib System (`lib.sh`)
- **Purpose**: Shared library functions, common utilities, helper functions
- **Not intended for direct invocation** - used by other scripts
- **Functions**: logging, error handling, JSON parsing, HTTP utilities, crypto functions

### Provider Abstraction Layer (`limbs/providers/`)
- **Purpose**: Unified interface for multiple LLM providers (Claude, Ollama, OpenAI, Codex)
- **Design Pattern**: Strategy pattern with fallback chains
- **Provider Scripts**:
  - `claude.sh` - Anthropic Claude via claude CLI / CommandCode proxy
  - `ollama.sh` - Local Ollama models via HTTP API
  - `openai.sh` - OpenAI GPT models via HTTP API
  - `codex.sh` - OpenAI Codex models via HTTP API
- **Shared Contract** (implemented by all providers):
  - `available` → Exit 0 if provider can serve a call now
  - `call <model_id> <system> <user>` → Print completion to stdout; non-zero exit on failure
- **Configuration**: Injected by llm.sh via environment variables:
  - `PROVIDER_API_KEY` - API key for the provider
  - `PROVIDER_CLI` - CLI binary name (for CLI-based providers)
  - `PROVIDER_BASE_URL` - Base URL override (for HTTP providers)
  - `PROVIDER_TIMEOUT` - Timeout in seconds
- **Usage Pattern**: Agents never call providers directly - they use `limbs/llm.sh` which handles:
  1. Provider selection based on flags, agent configuration, or defaults
  2. Fallback chain traversal when primary provider fails
  3. Environment variable injection for each provider call
  4. Result collection and error handling

## Usage Patterns

Agents typically invoke limb scripts through their organ-specific interfaces:

```bash
# Example: Soma (brain) agent thinking
bash organs/ear.sh tell soma "bash limbs/think.sh \"What is the optimal architecture?\""

# Example: Innova (mind) agent learning  
bash organs/ear.sh tell innova "bash limbs/oracle.sh \"Learn about microservices patterns\""

# Example: Jit (soul) agent orchestrating
bash organs/ear.sh tell jit "bash limbs/index.sh \"Coordinate the next development sprint\""
```

## Related Documentation

- [Core Body Map](../core/body-map.md) - Complete organ ownership and RACI matrix
- [Agent Registry](../network/registry.json) - Source of truth for agent capabilities
- [Organs README](../organs/README.md) - I/O layer command providers
- [Scripts README](../scripts/README.md) - Daemon and startup scripts

---
*Documentation generated as part of DOC_GAP_ANALYSIS.json recommendations*