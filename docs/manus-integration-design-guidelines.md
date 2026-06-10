# Manus Integration — Design & Coding Guidelines for innomcp

> "Less structure, more intelligence" — Manus philosophy  
> Applied to innomcp's 14-agent organ system

---

## Quick Reference

| Concept | innomcp | Manus | Integration |
|---------|---------|-------|-------------|
| **Agent/Executor** | Organ (mouth, ear, etc) | Skill | Map 1:1 |
| **Task** | TICKET (001–006) | Task object | Direct mapping |
| **Workflow** | Standard flow (chamu→innova→neta→pada) | Project | Map workflows → projects |
| **Communication** | File-based bus (`/tmp/manusat-bus/`) | REST webhooks | Enhance with webhooks |
| **State** | Shared JSON + Oracle | Result data + webhook payload | Combine for observability |
| **Tracing** | Git commit hash | request_id | Standardize IDs |

---

## Design Principle 1: Skill-Based Organ Registration

**Rule**: Each innomcp organ is a reusable Skill in Manus.

```javascript
// Bad (monolithic task)
async function executeTask(task) {
  const input = parseInput(task);
  const result = process(input);
  return result;
}

// Good (skill-based, composable)
const mouth = {
  name: 'mouth-broadcast',
  inputs: { agent: 'string', message: 'string' },
  outputs: { message_id: 'string', delivered_at: 'timestamp' },
  execute: async (task) => {
    const { agent, message } = task.inputs;
    const message_id = generateId();
    await writeToInbox(agent, { message, message_id });
    return { message_id, delivered_at: Date.now() };
  }
};

const oracle = {
  name: 'oracle-search',
  inputs: { query: 'string', limit: 'number' },
  outputs: { results: 'array<result>', search_time_ms: 'number' },
  execute: async (task) => {
    const start = Date.now();
    const results = await oracleDB.search(task.inputs.query, task.inputs.limit);
    return { results, search_time_ms: Date.now() - start };
  }
};
```

**When to apply**: Any organ that will be called from multiple workflows. All 14 organs qualify.

---

## Design Principle 2: Consistent Response Wrapper

**Rule**: All task results follow Manus response format.

```javascript
// Bad (varies by organ)
async mouth.execute() {
  return { success: true, msg_id: '123' };  // inconsistent
}

async oracle.execute() {
  return [ { id: 1, text: '...' } ];  // inconsistent
}

// Good (standardized)
async mouth.execute(task) {
  return {
    ok: true,
    request_id: task.request_id,
    data: {
      message_id: '123',
      delivered_at: 1718072400000
    }
  };
}

async oracle.execute(task) {
  return {
    ok: true,
    request_id: task.request_id,
    data: {
      results: [ { id: 1, text: '...' } ],
      search_time_ms: 42
    }
  };
}
```

**When to apply**: Every organ response. No exceptions.

---

## Design Principle 3: Request ID Propagation

**Rule**: Every operation carries a unique `request_id` from start to finish.

```javascript
// Bad (no tracing)
async function workflow() {
  const result1 = await mouth.broadcast('msg');
  const result2 = await oracle.search('query');
  const result3 = await innova.decide(result1, result2);
  return result3;
}

// Good (traced end-to-end)
async function workflow(request_id) {
  const result1 = await mouth.broadcast({ 
    request_id, 
    message: 'msg' 
  });
  
  const result2 = await oracle.search({ 
    request_id, 
    query: 'query' 
  });
  
  const result3 = await innova.decide({ 
    request_id,
    prior_results: [result1, result2]
  });
  
  logger.info(`Workflow ${request_id} complete`, { result: result3 });
  return result3;
}

// Usage
const request_id = generateUUID();
const result = await workflow(request_id);
// Later: can trace entire workflow via request_id in logs
```

**When to apply**: Every external-facing operation (API endpoint, webhook handler, TICKET execution).

---

## Design Principle 4: Project-Scoped Context

**Rule**: Related tasks share a Project with common instructions and constraints.

```javascript
// Bad (tasks have no shared context)
const tasks = [
  { id: 'TICKET-002-test-1', prompt: 'Route Thai prompt "สวัสดี"' },
  { id: 'TICKET-002-test-2', prompt: 'Route Thai prompt "ขอบคุณ"' },
  { id: 'TICKET-002-test-3', prompt: 'Route Thai prompt "สำคัญ"' }
];

// Good (project provides shared context)
const project = {
  id: 'TICKET-002-thai-routing',
  name: 'Thai Knowledge Routing Audit',
  instructions: `
    Route Thai language prompts deterministically.
    Rules:
    1. Parse Thai text with gemma4:26b
    2. Extract intent (knowledge, question, command)
    3. Assign to lane (innova, chamu, rupa, etc)
    4. Verify determinism: same prompt → same lane
  `,
  context: {
    language: 'Thai',
    model: 'gemma4:26b',
    lanes: ['innova', 'chamu', 'rupa', 'pada', 'netra'],
    determinism_tolerance: 0,  // 0% variance
    test_count: 40
  },
  skills: ['thai-parser', 'intent-extractor', 'lane-router', 'determinism-verifier']
};

const tasks = [
  {
    id: 'TICKET-002-test-1',
    project_id: project.id,
    input: { prompt: 'สวัสดี' },
    // Inherits: instructions, context, skills from project
  },
  {
    id: 'TICKET-002-test-2',
    project_id: project.id,
    input: { prompt: 'ขอบคุณ' }
    // Inherits: instructions, context, skills from project
  }
];
```

**When to apply**: For multi-step workflows (like TICKET-002 with 40 test cycles). Reduces duplication.

---

## Design Principle 5: Webhook-Based Async Notification

**Rule**: Critical task completions trigger webhooks for real-time notification.

```javascript
// Bad (polling for task status)
async function monitorTask(task_id) {
  while (true) {
    const status = await manus.tasks.get(task_id);
    if (status.completed) {
      return status.result;
    }
    await sleep(5000);  // Poll every 5 seconds
  }
}

// Good (webhook-based notification)
// 1. Register webhook when submitting task
const task = {
  id: 'TICKET-002-verification',
  title: 'Verify Thai routing determinism',
  result_webhook: 'https://innomcp.local/webhooks/task-complete'
};
await manus.tasks.create(task);

// 2. Listen for webhook
app.post('/webhooks/task-complete', async (req) => {
  const { request_id, task_id, status, result } = req.body;
  
  if (status === 'completed' && result.determinism_score === 100) {
    await mouth.broadcast({
      request_id,
      agent: 'innova',
      message: `✅ TICKET-002 passed! Determinism: ${result.determinism_score}%`
    });
  }
  
  res.json({ ok: true, request_id });
});
```

**When to apply**: High-priority task completions (TICKET pass/fail, security tests, deployment gates).

---

## Design Principle 6: Error Handling with Request ID

**Rule**: Errors preserve `request_id` for debugging.

```javascript
// Bad (loses context)
async function route(prompt) {
  const parsed = parseThaiText(prompt);
  if (!parsed) throw new Error('Parse failed');
  return router.assign(parsed);
}

// Good (preserves request_id)
async function route(request_id, prompt) {
  try {
    const parsed = parseThaiText(prompt);
    if (!parsed) {
      return {
        ok: false,
        request_id,
        error: { 
          code: 'PARSE_ERROR',
          message: 'Thai text parsing failed',
          input: prompt
        }
      };
    }
    const lane = await router.assign(parsed);
    return {
      ok: true,
      request_id,
      data: { lane, parsed }
    };
  } catch (e) {
    logger.error(`Route error [${request_id}]`, { error: e, prompt });
    return {
      ok: false,
      request_id,
      error: { code: 'INTERNAL', message: e.message }
    };
  }
}
```

**When to apply**: Any function that can fail. No exceptions.

---

## Design Principle 7: File Attachments for Rich Workflows

**Rule**: Attach design specs, test data, and documentation to tasks.

```javascript
// Good (task with rich attachments)
const task = {
  id: 'TICKET-006-poc',
  title: 'Build Manus PoC for Thai routing',
  project_id: 'innomcp-manus-integration',
  attachments: [
    {
      type: 'markdown',
      name: 'Architecture',
      url: 'file:///docs/manus-integration-design-guidelines.md'
    },
    {
      type: 'csv',
      name: 'Thai Test Prompts',
      url: 'file:///eval/thai-test-prompts.csv'
    },
    {
      type: 'json',
      name: 'Skill Definitions',
      url: 'file:///skills.json'
    }
  ],
  result_webhook: 'https://innomcp.local/webhooks/poc-complete'
};
```

**When to apply**: Complex tasks (design, architecture, testing) where context documents are needed.

---

## Coding Patterns: By Organ

### Mouth (vaja) — Broadcast Skill

```javascript
const mouth = {
  name: 'mouth-broadcast',
  inputs: {
    request_id: 'string',
    agent: 'string',
    message: 'string',
    prefix: { type: 'string', default: 'report:' }  // task:, think:, alert:
  },
  outputs: {
    message_id: 'string',
    delivered_at: 'number (timestamp)',
    inbox_size: 'number'
  },
  execute: async (task) => {
    const { request_id, agent, message, prefix = 'report:' } = task.inputs;
    const message_id = `${Date.now()}-${Math.random().toString(36).substr(2,9)}`;
    
    const envelope = {
      from: 'system',
      subject: `${prefix}${Date.now()}`,
      body: message,
      timestamp: Date.now()
    };
    
    const inboxPath = `/tmp/manusat-bus/${agent}/`;
    await fs.promises.mkdir(inboxPath, { recursive: true });
    await fs.promises.writeFile(
      `${inboxPath}${message_id}.json`,
      JSON.stringify(envelope, null, 2)
    );
    
    return {
      ok: true,
      request_id,
      data: {
        message_id,
        delivered_at: Date.now(),
        inbox_size: (await fs.promises.readdir(inboxPath)).length
      }
    };
  }
};
```

### Oracle (innova) — Knowledge Skill

```javascript
const oracle = {
  name: 'oracle-search',
  inputs: {
    request_id: 'string',
    query: 'string',
    limit: { type: 'number', default: 5 }
  },
  outputs: {
    results: 'array<{id, text, score, concepts}>',
    search_time_ms: 'number',
    query_normalized: 'string'
  },
  execute: async (task) => {
    const { request_id, query, limit } = task.inputs;
    const start = Date.now();
    
    try {
      const results = await oracleDB.ftsSearch(query, limit);
      
      return {
        ok: true,
        request_id,
        data: {
          results: results.map(r => ({
            id: r.id,
            text: r.content,
            score: r.relevance_score,
            concepts: r.concepts
          })),
          search_time_ms: Date.now() - start,
          query_normalized: query.toLowerCase()
        }
      };
    } catch (e) {
      return {
        ok: false,
        request_id,
        error: { code: 'ORACLE_ERROR', message: e.message }
      };
    }
  }
};
```

### Chamu (QA) — Test Verifier Skill

```javascript
const testVerifier = {
  name: 'test-verifier',
  inputs: {
    request_id: 'string',
    test_suite: 'string',  // e.g., 'thai-memory-symmetry'
    tests: 'array<{name, input, expected_output}>'
  },
  outputs: {
    passed: 'number',
    failed: 'number',
    total: 'number',
    pass_rate: 'number (0-100)',
    failures: 'array<{test_name, expected, actual, error}>'
  },
  execute: async (task) => {
    const { request_id, test_suite, tests } = task.inputs;
    
    const results = {
      passed: 0,
      failed: 0,
      total: tests.length,
      failures: []
    };
    
    for (const test of tests) {
      try {
        const actual = await executeTest(test.name, test.input);
        if (deepEqual(actual, test.expected_output)) {
          results.passed++;
        } else {
          results.failed++;
          results.failures.push({
            test_name: test.name,
            expected: test.expected_output,
            actual,
            error: 'Output mismatch'
          });
        }
      } catch (e) {
        results.failed++;
        results.failures.push({
          test_name: test.name,
          expected: test.expected_output,
          actual: null,
          error: e.message
        });
      }
    }
    
    return {
      ok: results.failed === 0,
      request_id,
      data: {
        ...results,
        pass_rate: Math.round((results.passed / results.total) * 100)
      }
    };
  }
};
```

---

## Quick Checklist: Manus-Compliant Code

- [ ] Every function has `request_id` parameter
- [ ] All responses follow `{ ok, request_id, data/error }` wrapper
- [ ] Skills have defined `inputs` and `outputs` specs
- [ ] Errors preserve `request_id` for tracing
- [ ] Critical task completions have webhook handlers
- [ ] Related tasks grouped under shared Project
- [ ] File attachments included for complex tasks
- [ ] Git commits reference `request_id` or `TICKET` number
- [ ] Logs include `request_id` for filtering

---

## When to Apply These Guidelines

| Scenario | Apply? | Effort |
|----------|--------|--------|
| New organ implementation | ✅ YES | Low (1-2 hours) |
| Refactoring existing organ | ✅ YES | Medium (review + adapt) |
| TICKET implementation | ✅ YES | Built-in to TICKET flow |
| Internal utility function | ⚠️ OPTIONAL | (not exposed to Manus) |
| Bug fix | ❌ NO | (preserve existing contract) |

---

## References

- **Manus Analysis**: [`ψ/memory/learnings/2026-06-11_manus-ai-analysis-for-innomcp.md`](../ψ/memory/learnings/2026-06-11_manus-ai-analysis-for-innomcp.md)
- **innomcp Architecture**: [`/docs/multiagent-spec.md`](./multiagent-spec.md)
- **Team Charter**: [`/teams/team-charter.yaml`](../teams/team-charter.yaml)
- **Organ System**: [`/core/body-map.md`](../core/body-map.md)

---

**Guidelines created**: 2026-06-11  
**Applicability**: All innomcp development (14 organs, TICKETs, workflows)  
**Compliance**: MANDATORY for new organ/skill implementations
