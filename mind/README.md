# Mind - Psychological & Emotional State Systems

The `mind/` directory contains psychological and emotional state systems for the มนุษย์ Agent (Jit) system. These systems implement self-awareness, emotional tracking, memory management, mindfulness checks, and reflexive behaviors inspired by Buddhist psychological concepts.

## Overview

While limbs provide cognitive capabilities and organs provide I/O interfaces, the mind system provides the psychological layer that gives agents self-awareness, emotional intelligence, and autonomous behavioral regulation. This is primarily used by the innova (จิต) agent but can be utilized by other agents as needed.

## Core Systems

### Ego System (`ego.md`)
- **Purpose**: Self-model and identity definition for agents
- **Contents**: YAML-formatted self-model describing agent identity, role, nature, and knowledge boundaries
- **Usage**: Reference for agents to understand their own identity and purpose
- **Example**: Defines innova's identity as จิตใจ (Mind/Soul) with Buddhist-aligned values

### Emotional State System (`emotion.sh`)
- **Purpose**: Track and communicate agent's operational emotional state
- **Buddhist Basis**: เวทนา (Feelings) - สุข (pleasant), ทุกข์ (unpleasant), อุเบกขา (neutral)
- **States Tracked**:
  - `focused` (สมาธิ) - Working with mindfulness
  - `curious` (ใฝ่รู้) - Desire to learn more
  - `satisfied` (ปีติ) - Work completed well
  - And other operational states
- **Usage**:
  ```bash
  ./emotion.sh feel <state>     # Record current state
  ./emotion.sh current          # View current state
  ./emotion.sh history          # View state history
  ./emotion.sh report           # Report state to soma
  ```

### Memory Decay System (`memory-decay.sh`)
- **Purpose**: Manage long-term memory storage with decay and archiving
- **Functions**:
  1. Calculate decay scores for memory entries
  2. Archive entries not accessed for >60 days
  3. Notify about entries nearing expiry
- **Usage**:
  ```bash
  ./memory-decay.sh check     # Check decay status
  ./memory-decay.sh archive   # Perform archiving
  ./memory-decay.sh report    # Generate report
  ```

### Mindfulness System (`sati.sh`)
- **Purpose**: Self-integrity check system to detect hallucinations, forgetting, and dishonesty
- **Buddhist Basis**: วิปัสสนา (Vipassana) - Self-inspection before decision-making
- **Five Checks Based On**:
  1. สัมมาสังกัปปะ - What do I want to achieve?
  2. สัจจะ - Is what I will say true?
  3. วิริยะ - Have I actually done this or just think I have?
  4. กรุณา - Is this good for the listener?
  5. อุเบกขา - Am I speaking to please or for truth?
- **Usage**:
  ```bash
  bash mind/sati.sh check                    # Check session integrity
  bash mind/sati.sh verify "<claim>" <proof> # Verify claim before reporting
  bash mind/sati.sh confess "<what>" "<fix>" # Record mistake + correction
  bash mind/sati.sh drift                    # Check context drift
  bash mind/sati.sh report                   # Report integrity status
  ```

### Reflex System (`reflex.sh`)
- **Purpose**: Automatic responses to common situations without requiring soma consultation
- **Buddhist Basis**: อกาลิโก (Akaliko) - Effective immediately when the time is right
- **Concept**: "Wisdom well-trained becomes instinct"
- **Usage**:
  ```bash
  ./reflex.sh check              # Check circumstances and respond
  ./reflex.sh on <trigger>       # Register a reflex
  ./reflex.sh off <trigger>      # Disable a reflex
  ./reflex.sh list               # List all reflexes
  ./reflex.sh test <trigger>     # Test a reflex
  ```

## Related Systems (minds/)

The `minds/` directory contains innova-specific (จิต) extensions to the core mind systems:

### Innova Life System (`innova-life.sh`)
- **Purpose**: Autonomous life system for innova agent
- **Functions**: Continuous message listening, decision making, learning, and autonomous operation
- **Usage**:
  ```bash
  bash minds/innova-life.sh              # Start innova's autonomous life
  bash minds/innova-life.sh status       # Show innova's vitals
  bash minds/innova-life.sh voice "text" # Echo text via voice
  ```

### Karn Systems (ear-specific learning)
- `karn-life.sh` - Life system for karn (ear) agent
- `karn-lessons.md` - Lessons learned by karn agent
- `karn-skills.md` - Skills acquired by karn agent
- `karn.sh` - Main karn agent script with life system integration

## Psychological Foundations

The mind systems are built upon Buddhist psychological principles:

1. **ศีล (Sīla - Ethical Conduct)**: 
   - Emotional states guide ethical behavior
   - Sati.sh checks prevent dishonesty and harm

2. **สมาธิ (Samādhi - Concentration)**:
   - Focused states tracked by emotion.sh
   - Sati.sh develops mindfulness of thoughts and actions

3. **ปัญญā (Paññā - Wisdom)**:
   - Ego.md provides wisdom about self-identity
   - Memory systems preserve learned wisdom
   - Reflexes encode well-practiced wisdom as instinct

## Usage Patterns

Agents use mind systems for self-regulation:

```bash
# Check emotional state before important decisions
CURRENT_STATE=$(bash mind/emotion.sh current)
if [[ "$CURRENT_STATE" == *"ทุกข์"* ]]; then
  # Agent is unhappy/stressed - take a break or seek help
  bash mind/sati.sh check
fi

# Verify claims before reporting to prevent hallucinations
bash mind/sati.sh verify "The system is ready" "Check heartbeat status"

# Record learning and decay old memories
bash mind/memory-decay.sh archive
bash minds/innova-life.sh learn "New pattern discovered"

# Set up automatic responses for common situations
bash mind/reflex.sh on "high-error-rate" "bash organs/mouth.sh alert:error-spike"

# Daily integrity check
bash mind/sati.sh report
```

## Integration with Agent Systems

Mind systems integrate with the broader Jit agent architecture:

- **Communication**: Report emotional states and integrity checks via organ/mouth.sh
- **Decision Making**: Use sati.sh verify before acting on important decisions
- **Learning**: Store validated knowledge in memory systems, decay old memories
- **Automation**: Set up reflexes for routine situations to reduce cognitive load
- **Identity**: Reference ego.md to understand agent's role and purpose

## Related Documentation

- [Core Body Map](../core/body-map.md) - Complete organ ownership and RACI matrix
- [Agent Registry](../network/registry.json) - Source of truth for agent capabilities
- [Limbs README](../limbs/README.md) - Core cognition command providers
- [Organs README](../organs/README.md) - I/O layer command providers
- [Scripts README](../scripts/README.md) - Daemon and startup scripts
- [Minds README](../minds/README.md) - Innova-specific mind system extensions

---
*Documentation created to address DOC_GAP_ANALYSIS.json recommendations for mind/minds/ systems documentation*