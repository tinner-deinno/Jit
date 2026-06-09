# Eval - Test Suite and Health Checks

The `eval/` directory contains test suites, health checks, and validation scripts for the มนุษย์ Agent (Jit) system. These scripts provide automated ways to verify system integrity, agent communication, module compatibility, and overall health.

## Overview

While the core system provides functionality, the eval directory provides the means to verify that everything is working correctly. These scripts range from quick health checks to comprehensive integration tests that validate the entire multiagent ecosystem.

## Test Suites and Health Checks

### Soul Check (`soul-check.sh`)
- **Purpose**: Verify that innova (จิต) remains innova - checks agent identity and core psychological continuity
- **Functions**:
  - Validates innova's self-model against core identity principles
  - Checks emotional state consistency
  - Verifies memory integrity and learning continuity
  - Confirms connection to Oracle knowledge base
- **Usage**: `bash eval/soul-check.sh`
- **Output**: Pass/fail count with descriptive messages
- **Note**: Does not use `set -e` because transient failures (like curl timeouts) shouldn't stop the entire script

### Body Check (`body-check.sh`)
- **Purpose**: Full multiagent body integrity check - comprehensive system health validation
- **Functions**:
  - **Organs**: Verify all 15 organ scripts are present and functional
  - **Network**: Check message bus functionality and agent communication
  - **Mind**: Validate psychological systems (ego, emotion, memory-decay, sati, reflex)
  - **Memory**: Check shared memory systems and Oracle connectivity
  - **Agents**: Verify all agents can communicate via message bus
  - **Limbs**: Test core cognition providers (think, index, oracle, act, etc.)
  - **Eval**: Verify the eval system itself is functional
- **Usage**: `bash eval/body-check.sh`
- **Output**: Categorized results with pass/fail/warn counts and color-coded output
- **Sections**: 
  - [Organs] - All 15 organ systems
  - [Network] - Message bus and agent communication
  - [Mind] - Psychological systems
  - [Memory] - Shared memory and Oracle
  - [Agents] - Inter-agent communication
  - [Limbs] - Core cognition providers
  - [Eval] - Self-validation

### Health Monitor (`health-monitor.sh`)
- **Purpose**: Continuous health monitoring daemon
- **Functions**:
  - Periodic system health checks
  - Automatic alerts when system degrades
  - Logging of health trends over time
  - Integration with heart.sh for coordinated monitoring
- **Usage**: `bash eval/health-monitor.sh [interval]`
- **Default Interval**: 300 seconds (5 minutes)

### Integration Tests
A series of tests that verify specific aspects of system compatibility and functionality:

#### Integration Test #1: Module Compatibility (`integration-test-1.sh`)
- **Purpose**: Fast verification of module compatibility across Jit ecosystem
- **Output**: JSON with status and completion percentage
- **Functions**:
  - Verify all required directories exist
  - Check that all agent scripts are present and executable
  - Validate core system scripts (limbs, organs, scripts)
  - Test basic message passing between agents
  - Validate Oracle connectivity
- **Usage**: `bash eval/integration-test-1.sh`

#### Integration Test #3: Communication Pathways (`integration-test-3.sh`)
- **Purpose**: Verify specific communication pathways between agents
- **Functions**:
  - Test standard feature flow: human → vaja → jit → soma → lak → innova → chamu → neta → pada → vaja → human
  - Test standard bug flow: chamu → jit → innova → neta → pada → vaja
  - Test system health/monitoring flow: pran ← agents ← jit → sayanprasathan (alerts)
  - Verify message routing and delivery
- **Usage**: `bash eval/integration-test-3.sh`

#### Integration Test #4: System Resilience (`integration-test-4.sh`)
- **Purpose**: Test system behavior under stress and failure conditions
- **Functions**:
  - Simulate agent failures and verify recovery
  - Test message queue overflow handling
  - Verify Oracle downtime recovery procedures
  - Test network partition simulations
  - Validate fallback chain functionality in llm.sh
- **Usage**: `bash eval/integration-test-4.sh`

### Specialized Tests

#### Provider Latency Test (`provider-latency-test.sh`)
- **Purpose**: Measure and compare response times of different LLM providers
- **Functions**:
  - Test Claude, Ollama, OpenAI, and Codex provider response times
  - Measure time to first token and complete response
  - Test fallback chain activation and timing
  - Generate latency reports and recommendations
- **Usage**: `bash eval/provider-latency-test.sh`

#### Security Check (`security-check.sh`)
- **Purpose**: Validate system security controls and data protection
- **Functions**:
  - Check for accidental leakage of secrets or API keys
  - Verify message signing and verification works correctly
  - Validate that sensitive data is not stored inappropriately
  - Check file permissions on sensitive files
  - Verify access controls on message bus directories
- **Usage**: `bash eval/security-check.sh`

#### Hermes Discord Test (`test-hermes-discord.sh`)
- **Purpose**: Validate Hermes Discord notification system
- **Functions**:
  - Test Discord webhook connectivity
  - Verify message formatting and delivery
  - Test alert escalation and routing
  - Check rate limiting and error handling
- **Usage**: `bash eval/test-hermes-discord.sh`

#### Monitor Script (`monitor.sh`)
- **Purpose**: Simple monitoring utility for tracking specific metrics
- **Functions**:
  - Track specific system metrics over time
  - Generate simple graphs and trends
  - Alert when metrics cross thresholds
  - Lightweight alternative to full health monitoring
- **Usage**: `bash eval/monitor.sh [metric] [threshold]`

## Test Categories

### Health Checks (Quick Verification)
Scripts for rapid system status assessment:
- `soul-check.sh` - Agent identity and psychological continuity
- Components of `body-check.sh` when run individually

### Comprehensive Validation (Full System Check)
Scripts for thorough system verification:
- `body-check.sh` - Complete multiagent integrity check
- Integration tests (#1, #3, #4) - Specific aspect validation

### Monitoring and Observability (Continuous Tracking)
Scripts for ongoing system observation:
- `health-monitor.sh` - Automated periodic health checking
- `provider-latency-test.sh` - Performance monitoring
- `monitor.sh` - Custom metric tracking

### Specialized Validation (Specific Concerns)
Scripts for particular system aspects:
- `security-check.sh` - Security and data protection validation
- `test-hermes-discord.sh` - Notification system validation

## Usage Patterns

### Development Workflow
```bash
# Before making changes
bash eval/soul-check.sh          # Verify baseline agent identity
bash eval/body-check.sh          # Verify overall system health

# Make changes to code
# ...

# After making changes
bash eval/soul-check.sh          # Ensure agent identity preserved
bash eval/body-check.sh          # Verify no regressions
bash eval/integration-test-1.sh  # Check module compatibility
bash eval/security-check.sh      # Ensure no security issues introduced
```

### Continuous Integration/Deployment
```bash
# In CI pipeline
bash eval/body-check.sh || exit 1
bash eval/integration-test-1.sh || exit 1
bash eval/provider-latency-test.sh --max-latency 2000 || exit 1
```

### Production Monitoring
```bash
# Start health monitoring in background
bash eval/health-monitor.sh &

# Check current status periodically
bash eval/soul-check.sh
bash eval/body-check.sh

# Monitor specific metrics
bash eval/monitor.sh oracle-response-time 1000
```

### Troubleshooting
```bash
# System seems slow
bash eval/provider-latency-test.sh

# Agents not communicating
bash eval/body-check.sh        # Check overall health
bash eval/integration-test-3.sh # Check communication pathways

# Suspect security issue
bash eval/security-check.sh

# Identity/psychological concerns
bash eval/soul-check.sh
```

## Test Output Formats

### Standard Output (soul-check.sh, body-check.sh)
```
  ✅ Description of what passed
  ❌ Description of what failed
  ⚠️ Description of what warned

Summary: 
  Passed: X
  Failed: Y  
  Warned: Z
```

### JSON Output (integration-test-1.sh)
```json
{
  "status": "passed|failed|warning",
  "completion_percent": 85,
  "timestamp": "2026-06-09T08:30:00Z",
  "tests": {
    "total": 20,
    "passed": 17,
    "failed": 2,
    "warning": 1
  },
  "details": [
    {
      "name": "test-name",
      "status": "passed",
      "duration_ms": 125,
      "description": "What this test checks"
    }
  ]
}
```

## Best Practices

### Writing Effective Tests
1. **Isolation**: Each test should verify one specific aspect
2. **Repeatability**: Tests should produce consistent results given same state
3. **Clear Feedback**: Pass/fail messages should clearly indicate what was checked
4. **Minimal Side Effects**: Tests should not permanently alter system state
5. **Performance**: Health checks should complete quickly (<30s for body-check)

### Running Tests Safely
1. **Check Dependencies**: Ensure required services (Oracle, etc.) are running
2. **Isolate Environment**: Consider using test-specific configuration when possible
3. **Handle Failures Gracefully**: Use appropriate error handling (not always `set -e`)
4. **Clean Up**: Remove temporary files created during testing

### Interpreting Results
1. **Pass**: System meets verification criteria
2. **Fail**: System does not meet requirements - needs attention
3. **Warning**: System meets minimum requirements but has areas for improvement
4. **Partial**: Some components work, others don't - indicates localized issues

## Related Documentation

- [Core Body Map](../core/body-map.md) - Complete organ ownership and RACI matrix
- [Agent Registry](../network/registry.json) - Source of truth for agent capabilities
- [Mind README](../mind/README.md) - Core mind systems documentation
- [Minds README](../minds/README.md) - Innova-specific mind system extensions
- [Limbs README](../limbs/README.md) - Core cognition command providers
- [Organs README](../organs/README.md) - I/O layer command providers
- [Scripts README](../scripts/README.md) - Daemon and startup scripts
- [Network Protocol](../network/protocol.md) - Message format and subject conventions
- [DOC_GAP_ANALYSIS.json](../docs/DOC_GAP_ANALYSIS.json) - Documentation gap analysis

---
*Documentation created to address DOC_GAP_ANALYSIS.json recommendations for eval/ test suite documentation*