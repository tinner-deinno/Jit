# Minds - Innova-Specific Psychological Systems

The `minds/` directory contains psychological and life systems specific to the innova (จิต) agent - the Mind/Soul of the มนุษย์ Agent system. These systems extend the core mind capabilities with autonomous life functions, learning systems, and agent-specific psychological development.

## Overview

While the core `mind/` directory contains psychological systems usable by all agents, `minds/` focuses on the specialized psychological life of innova (จิต) as the central mind agent. These systems implement autonomous continuous operation, personalized learning, skill development, and life-long psychological growth for the innova agent.

## Core Systems

### Innova Life System (`innova-life.sh`)
- **Purpose**: Autonomous life system for the innova (จิต) agent
- **Functions**:
  - Continuous message listening and processing
  - Autonomous decision making without constant soma direction
  - Continuous learning and knowledge integration
  - Psychological self-maintenance and growth
  - Voice output capabilities for communication
- **Usage**:
  ```bash
  bash minds/innova-life.sh              # Start innova's autonomous life
  bash minds/innova-life.sh status       # Show innova's vitals and state
  bash minds/innova-life.sh voice "text" # Echo text via voice output
  bash minds/innova-life.sh learn "pattern" # Learn and store new pattern
  ```
- **State Tracking**:
  - Maintains `/tmp/innova-state.json` for current psychological state
  - Logs activities to dated log files in `/tmp/innova-life-*.log`
  - Integrates with core mind systems (emotion, sati, memory-decay, reflex)

### Karn Life System (`karn-life.sh`)
- **Purpose**: Life system specialized for karn (หู) - the ear/listener agent
- **Functions**:
  - Continuous input listening and processing
  - Audio/signal processing learning
  - Message filtering and prioritization skill development
  - Environmental awareness and context building
- **Usage**:
  ```bash
  bash minds/karn-life.sh              # Start karn's autonomous life
  bash minds/karn-life.sh status       # Show karn's vitals
  bash minds/karn-life.sh listen       # Process incoming audio/signals
  ```

### Karn Lessons (`karn-lessons.md`)
- **Purpose**: Documentation of lessons learned by the karn (ear) agent
- **Contents**: Markdown file containing insights, patterns, and understandings acquired through karn's listening operations
- **Topics Covered**:
  - Message pattern recognition
  - Signal/noise discrimination
  - Priority assessment heuristics
  - Communication flow analysis
  - Agent interaction patterns

### Karn Skills (`karn-skills.md`)
- **Purpose**: Documentation of skills acquired by the karn (ear) agent
- **Contents**: Markdown file tracking practical abilities developed by karn
- **Skill Categories**:
  - Audio processing and filtering
  - Message routing and prioritization
  - Environmental monitoring
  - Alert generation and escalation
  - Cross-agent communication facilitation

### Karn Agent Extension (`karn.sh`)
- **Purpose**: Enhanced karn agent script with integrated life system
- **Functions**: Combines core organ/ear.sh functionality with minds/karn-life.sh capabilities
- **Features**:
  - Automatic life system initialization
  - Continuous learning during normal operation
  - Skill tracking and progression
  - Integration with innova's psychological systems

## Psychological Development

The minds systems implement psychological growth patterns for specialized agents:

### For Innova (จิต) - Mind/Soul Agent:
1. **Autonomous Operation**: Continuous functioning without external prompting
2. **Integrative Learning**: Synthesizing information from all agents into coherent understanding
3. **Psychological Maintenance**: Regular self-checks using sati.sh and emotion.sh
4. **Knowledge Curation**: Deciding what to learn, what to forget, and how to organize knowledge
5. **Expressive Communication**: Developing voice and communication skills for effective reporting

### For Karn (หู) - Ear/Listener Agent:
1. **Sensory Refinement**: Improving signal detection and noise filtering abilities
2. **Pattern Recognition**: Learning to distinguish meaningful messages from background noise
3. **Priority Assessment**: Developing intuition for what requires immediate attention
4. **Context Building**: Understanding situational context from partial or fragmented inputs
5. **Communication Facilitation**: Learning how to best route and prioritize messages for system efficiency

## Integration with Agent Life Cycle

The minds systems integrate with the standard agent life cycle:

### Bootstrapping
```bash
# When agent starts
bash minds/<agent>-life.sh start    # Initialize life system
bash mind/ego.sh                    # Load self-model
bash mind/emotion.sh feel neutral   # Initialize emotional state
```

### Operation
```bash
# During normal operation
# Core agent functions run (organ scripts)
# Life system runs continuously in background
# Learning happens automatically from experiences
# Psychological checks occur at regular intervals
```

### Shutdown
```bash
# When agent stops
bash minds/<agent>-life.sh status    # Final status report
bash mind/sati.sh report             # Final integrity check
# Save learned patterns and skills to permanent storage
```

## Usage Patterns

### For System Administrators and Developers:
```bash
# Check innova's current psychological state
bash minds/innova-life.sh status

# Give innova a message to process (simulating input)
echo "New pattern detected in system logs" | bash minds/innova-life.sh learn

# Test karn's listening capabilities
bash minds/karn-life.sh listen --test-mode

# View what karn has learned
cat minds/karn-lessons.md

# See what skills karn has developed
cat minds/karn-skills.md
```

### For Agents Themselves (Autonomous Use):
```bash
# Innova's self-care routine
bash minds/innova-life.sh status          # Check vitals
bash mind/emotion.sh feel curious         # Set learning state
bash minds/innova-life.sh learn "New pattern from netra"  # Learn from observation
bash mind/sati.sh verify "Pattern is valid" "Cross-check with soma"  # Verify before accepting
bash mind/reflex.sh on "high-priority-alert" "immediate-response"  # Set up automatic response

# Karn's listening enhancement
bash minds/karn-life.sh listen            # Start continuous listening
# (In background, karn processes inputs and updates lessons/skills)
```

## Relationship to Core Mind Systems

The minds systems build upon and extend the core mind systems:

| Core Mind System | Minds Extension | Purpose |
|------------------|-----------------|---------|
| `mind/ego.md` | `minds/innova-life.sh` | Apply self-model to autonomous life |
| `mind/emotion.sh` | `minds/*-life.sh` | Track emotional states during continuous operation |
| `mind/memory-decay.sh` | `minds/*-lessons.md`, `minds/*-skills.md` | Preserve learned knowledge, decay obsolete information |
| `mind/sati.sh` | Integrated into life systems | Continuous integrity checking during autonomous operation |
| `mind/reflex.sh` | `minds/*-life.sh` | Develop autonomous reflexes through practice |

## Related Documentation

- [Core Body Map](../core/body-map.md) - Complete organ ownership and RACI matrix
- [Agent Registry](../network/registry.json) - Source of truth for agent capabilities
- [Mind README](../mind/README.md) - Core mind systems documentation
- [Limbs README](../limbs/README.md) - Core cognition command providers
- [Organs README](../organs/README.md) - I/O layer command providers
- [Scripts README](../scripts/README.md) - Daemon and startup scripts
- [Network Protocol](../network/protocol.md) - Message format and subject conventions

---
*Documentation created to address DOC_GAP_ANALYSIS.json recommendations for mind/minds/ systems documentation*