<!-- cc-team deliverable
 group: MANUS (manus-parity scaffolds: tools, agent loop, SSE, workspace stream, artifacts, contract tests, docs)
 member: C4 role=dev model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":109,"completion_tokens":1174,"total_tokens":1283,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":958,"image_tokens":0},"cache_creation_input_tokens":0} | 13s
 generated: 2026-06-13T05:45:22.170Z -->
import { test } from 'node:test';
import assert from 'node:assert/strict';

const API_BASE = process.env.API_BASE || "http://localhost:3015";

test('GET /api/tasks returns 200 with tasks array or 401 for guest', async (t) => {
  let response: Response;
  try {
    response = await fetch(`${API_BASE}/api/tasks`);
  } catch (err: any) {
    t.skip(`Server at ${API_BASE} is unreachable: ${err.message}`);
    return;
  }

  if (response.status === 200) {
    const body = await response.json();
    assert.ok(body.tasks, 'Response should have a "tasks" property');
    assert.ok(Array.isArray(body.tasks), '"tasks" should be an array');
  } else if (response.status === 401) {
    // allowed for guest – test passes
  } else {
    assert.fail(`Unexpected status ${response.status}`);
  }
});
