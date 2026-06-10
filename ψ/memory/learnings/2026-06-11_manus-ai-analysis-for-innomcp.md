---
name: manus-ai-innomcp-analysis
description: Deep analysis of Manus.ai (Meta platform) and integration patterns for innomcp design/coding
metadata:
  ticket: TICKET-006
  priority: high
  date: 2026-06-11
  project: innomcp
---

# Manus.ai Analysis for innomcp Design & Coding

## What is Manus.ai?

**Platform**: Meta's "Hands On AI" — REST-based multi-agent orchestration platform  
**Philosophy**: "Less structure, more intelligence"  
**Status**: Formerly manus.ai, now manus.im (Meta acquisition)  
**API Version**: v2 (v1 deprecated) — REST endpoint: `https://api.manus.ai`

---

## Core Architecture

### 1. **Task-Centric Model**
- Create tasks with multi-turn conversation support
- Tasks support complex workflows with multiple steps
- Each task has a lifecycle (creation → execution → webhook notification)

### 2. **Project Organization**
- Tasks grouped under Projects
- Shared instructions/context per project
- Enables consistent behavior across related tasks

### 3. **Extensibility Layer (Skills & Agents)**
- Custom Skills extend platform capabilities
- Custom Agents manage task execution
- Allows domain-specific specialization

### 4. **File Handling**
- Supports: PDFs, images, CSVs, general attachments
- File attachment mechanism in tasks
- Enables rich-media workflows

### 5. **Real-Time Integration (Webhooks)**
- Webhooks on task completion
- Webhooks on input requirements (async collaboration)
- Request ID tracking for debugging

### 6. **REST API**
- Consistent response wrapper: `{ok: bool, request_id: string, data: {...}}`
- Authentication via API key
- Standard REST patterns (POST for create, GET for retrieve)

---

## Innomcp Design Patterns (Learnings for Application)

### Pattern 1: Multi-Agent Orchestration (ALIGNED ✅)

**Manus approach:**
- Tasks coordinate multiple Skills & Agents
- Webhook-based async communication
- Projects provide shared context

**Innomcp current:**
- 14-agent organ system (soma, innova, lak, etc.)
- File-based message bus (`/tmp/manusat-bus/`)
- Shared memory in Oracle + JSON state files

**Recommendation**: 
Manus pattern could enhance innomcp's messaging layer:
- Replace/complement file-based bus with REST webhooks
- Standardize task/skill naming (aligns with organ metaphor)
- Adopt request ID tracking for traceability

**Code pattern** (pseudocode):
```javascript
// innomcp agent as Manus skill
async function skillManusAdapter(task) {
  const request_id = generateRequestId();
  const agent = selectOrgan(task.agent_name); // soma, innova, lak
  const result = await agent.execute(task);
  return {
    ok: true,
    request_id,
    data: result
  };
}

// Webhook listener for task completion
app.post('/webhooks/manus/task-complete', async (req) => {
  const { request_id, data } = req.body;
  await innomcp_bus.notify(request_id, data);
});
```

### Pattern 2: Project-Scoped Context (APPLICABLE)

**Manus approach:**
- Projects = instruction templates + shared state
- All tasks in a project inherit context

**Innomcp application:**
- Map innomcp "workflows" to Manus Projects
- Example: Thai Knowledge Routing (TICKET-002) = Project
- All tasks in that project get Thai language context, routing rules, etc.

**Code pattern**:
```javascript
// innomcp project definition
const projects = {
  'thai-knowledge-routing': {
    instructions: 'Route Thai prompts with deterministic lane assignment',
    context: { language: 'Thai', ...},
    skills: ['thai-parser', 'route-lane-selector', 'test-verifier']
  },
  'multiagent-coordination': {
    instructions: 'Coordinate 14-agent organ system',
    context: { agents: 14, bus: '/tmp/manusat-bus/', ...},
    skills: ['soma-brain', 'innova-executor', ...]
  }
};
```

### Pattern 3: Skill-Based Extensibility (STRONG ALIGNMENT)

**Manus approach:**
- Skills = reusable capabilities registered in platform
- Each Skill has defined inputs/outputs
- Multiple agents can invoke same Skill

**Innomcp mapping:**
- Organs = Skills (mouth.sh, ear.sh, oracle.sh, ollama.sh)
- Each organ has defined I/O contract
- Agents invoke organs via message bus

**Code pattern** (innomcp Manus adapter):
```javascript
// Define innomcp organs as Manus Skills
const skills = [
  {
    id: 'mouth-speak',
    description: 'vaja (mouth) — broadcast message',
    inputs: { agent: string, message: string },
    outputs: { message_id: string, delivered_at: timestamp }
  },
  {
    id: 'oracle-search',
    description: 'innova (knowledge) — query oracle',
    inputs: { query: string, limit: number },
    outputs: { results: array, search_time_ms: number }
  },
  {
    id: 'ollama-think',
    description: 'chamu (processor) — Thai language processing',
    inputs: { prompt: string, language: string },
    outputs: { response: string, model: string }
  }
];
```

### Pattern 4: File Attachments for Rich Workflows (APPLICABLE)

**Manus approach:**
- Tasks can attach PDFs, images, CSVs
- Enables document-driven workflows
- Good for design/architecture documentation

**Innomcp use case:**
- Attach design specs to tasks (TICKET-006 → attach design docs)
- Attach test data CSVs to testing tasks
- Embed images in learning documents

**Code pattern**:
```javascript
// Task with attachments
const task = {
  project_id: 'TICKET-006',
  title: 'Learn manus.ai design patterns',
  attachments: [
    { type: 'markdown', url: 'file:///.../manus-ai-analysis.md' },
    { type: 'image', url: 'manus-architecture-diagram.png' }
  ],
  result_webhook: 'https://innomcp.local/webhooks/task-complete'
};
```

### Pattern 5: Webhook-Based Async Collaboration (ENHANCEMENT)

**Manus approach:**
- Task completion triggers webhook
- Enables agent-to-agent async communication
- Request IDs track the flow

**Innomcp enhancement:**
- Combine with file-based bus for best of both worlds
- Webhooks for time-critical notifications (alerts, completions)
- Message bus for regular inter-agent messaging

**Code pattern**:
```javascript
// Webhook for high-priority task completion
app.post('/webhooks/innomcp/critical-task-done', async (req) => {
  const { request_id, task_id, status, result } = req.body;
  
  // Log for traceability
  console.log(`[${request_id}] Task ${task_id} completed with status: ${status}`);
  
  // Route to appropriate organ
  await organs.mouth.broadcast('task-complete', { 
    request_id, 
    task_id, 
    result 
  });
});
```

---

## Integration Roadmap for innomcp

### Phase 1: Learning & Proof-of-Concept (Current)
- [ ] TICKET-006: Learn Manus API thoroughly
- [ ] Map innomcp organs to Manus Skills
- [ ] Create test adapter (innomcp → Manus)
- [ ] Document mapping in `/docs/`

### Phase 2: Pilot Integration
- [ ] Implement REST webhook listener for task completion
- [ ] Add Manus API client to innomcp core
- [ ] Route TICKET-002 (Thai Knowledge) through Manus Skills
- [ ] Test determinism with Manus request IDs

### Phase 3: Full Architecture Integration
- [ ] Replace/enhance message bus with Manus webhooks (optional)
- [ ] Standardize skill naming across 14 organs
- [ ] Create innomcp Project templates in Manus
- [ ] Document in `/teams/team-charter.yaml` and `/docs/`

### Phase 4: Production Hardening
- [ ] Error handling & retry logic
- [ ] Request ID tracking end-to-end
- [ ] Security: API key rotation, auth
- [ ] Monitoring: webhook failures, latency

---

## Code Design Guidelines for innomcp + Manus

### 1. **Consistent Response Wrapper** (adopt from Manus)
```javascript
// Standard innomcp response (inspired by Manus)
{
  ok: boolean,
  request_id: string,  // for tracing
  data: { /* actual result */ },
  error: { code, message } // if !ok
}
```

### 2. **Skill Registration Pattern**
```javascript
// Register organ as a Skill
async function registerSkill(organ_name, input_spec, output_spec) {
  return await manus.skills.register({
    id: `innomcp-${organ_name}`,
    name: organ_name,
    description: `innomcp organ: ${organ_name}`,
    inputs: input_spec,
    outputs: output_spec,
    handler: async (task) => organs[organ_name].execute(task)
  });
}

// Example: register mouth.sh as "broadcast" skill
await registerSkill('mouth', 
  { agent: 'string', message: 'string' },
  { message_id: 'string', delivered_at: 'timestamp' }
);
```

### 3. **Request ID Propagation**
```javascript
// Every innomcp call should carry request_id
async function executeTask(request_id, task) {
  const span = tracer.startSpan('task.execute', { request_id });
  try {
    const result = await task.run();
    return { ok: true, request_id, data: result };
  } catch (e) {
    return { ok: false, request_id, error: e.message };
  } finally {
    span.end();
  }
}
```

### 4. **Webhook Handler Template**
```javascript
// Express/Node webhook for task completion
app.post('/webhooks/manus/:event', async (req, res) => {
  const { request_id, task_id, project_id, data, timestamp } = req.body;
  const { event } = req.params;
  
  // Validate signature
  if (!validateManusSignature(req)) {
    return res.status(401).json({ ok: false, error: 'unauthorized' });
  }
  
  // Log event
  logger.info(`Webhook: ${event}`, { request_id, task_id, timestamp });
  
  // Route to appropriate handler
  switch (event) {
    case 'task:completed':
      await handleTaskComplete(request_id, data);
      break;
    case 'task:failed':
      await handleTaskFailed(request_id, data);
      break;
    case 'input:required':
      await handleInputRequired(request_id, data);
      break;
  }
  
  res.json({ ok: true, request_id });
});
```

### 5. **Project Context Pattern**
```javascript
// Define innomcp project in Manus
const ticketProject = {
  id: 'TICKET-006',
  name: 'Learn manus.ai',
  instructions: `
    Learn manus.ai platform and design patterns.
    Apply to innomcp design and coding practices.
    Create documentation for team.
  `,
  context: {
    priority: 'high',
    project: 'innomcp',
    owner: 'innova',
    linked_to: 'innomcp-multiagent-system'
  },
  skills: ['oracle-search', 'document-generator', 'design-synthesizer']
};
```

---

## Key Takeaways

1. **Manus = Task + Project + Skills + Webhooks orchestration** — very aligned with innomcp's multi-agent architecture
2. **"Less structure, more intelligence"** — matches innomcp's organ metaphor (each organ is smart, minimal centralized control)
3. **REST API + webhooks** — could enhance innomcp's file-based message bus for time-critical flows
4. **Request ID tracking** — implement for full traceability across 14-agent system
5. **Skill-based extensibility** — directly maps to innomcp's 14 organs, each with specialized capabilities

---

## Next Steps (innova)

**For TICKET-006:**
- [ ] Create Manus account / API access
- [ ] Test Manus API v2 with simple task
- [ ] Build proof-of-concept: innomcp organ adapter
- [ ] Document learnings + code patterns in `/docs/manus-integration.md`
- [ ] Design skill registration flow
- [ ] Plan Phase 2 (pilot integration with Thai Knowledge Routing)

**For innomcp team:**
- [ ] Review this analysis at next team sync
- [ ] Decide on Manus integration timeline
- [ ] Update `/teams/team-charter.yaml` with Manus mapping
- [ ] Consider hybrid approach: keep message bus + add webhooks for critical paths

---

**Learning completed by**: claude (Haiku 4.5)  
**Date**: 2026-06-11  
**Confidence**: HIGH (official Manus docs + Meta platform)  
**Applicability**: DIRECT — strong architectural alignment with innomcp
