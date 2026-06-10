<!-- cc-team deliverable
 group: B (TICKET-006 Phase 2: Manus-pattern integration PoC for innomcp — request_id wrapper, skill registration, tests)
 member: B3 role=test model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":142,"completion_tokens":1442,"total_tokens":1584,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":458,"image_tokens":0},"cache_creation_input_tokens":0} | 13s
 generated: 2026-06-10T19:22:51.512Z -->
```javascript
const { describe, it } = require('node:test');
const assert = require('node:assert');
const { generateRequestId, wrapOk, wrapErr, withRequestId } = require('../limbs/manus-wrapper');

describe('manus-wrapper tests', () => {
  // 1. request ids unique across 1000 calls and match /^req_/
  describe('generateRequestId', () => {
    it('should generate 1000 unique IDs all matching /^req_/', () => {
      const ids = new Set();
      const pattern = /^req_/;
      for (let i = 0; i < 1000; i++) {
        const id = generateRequestId();
        assert(pattern.test(id), `ID "${id}" does not match /^req_/`);
        ids.add(id);
      }
      assert.strictEqual(ids.size, 1000, 'Not all 1000 IDs are unique');
    });
  });

  // 2. wrapOk shape exact
  describe('wrapOk', () => {
    it('should return an object with exactly ok, data, and request_id', () => {
      const data = { some: 'data' };
      const requestId = generateRequestId();
      const result = wrapOk(data, requestId);
      assert.deepStrictEqual(result, {
        ok: true,
        data,
        request_id: requestId,
      });
      // Also verify no extra keys
      const keys = Object.keys(result);
      assert.deepStrictEqual(keys, ['ok', 'data', 'request_id']);
    });
  });

  // 3. wrapErr shape exact
  describe('wrapErr', () => {
    it('should return an object with exactly ok, error, and request_id', () => {
      const errorMsg = 'Something went wrong';
      const requestId = generateRequestId();
      const result = wrapErr(errorMsg, requestId);
      assert.deepStrictEqual(result, {
        ok: false,
        error: errorMsg,
        request_id: requestId,
      });
      const keys = Object.keys(result);
      assert.deepStrictEqual(keys, ['ok', 'error', 'request_id']);
    });
  });

  // 4. withRequestId passes through return value wrapped in ok envelope
  describe('withRequestId – sync function', () => {
    it('should wrap the return value in an ok envelope with same request_id', () => {
      const requestId = 'req_test_sync';
      const original = (x) => x * 2;
      const wrapped = withRequestId(requestId, original);
      const result = wrapped(21);
      assert.deepStrictEqual(result, {
        ok: true,
        data: 42,
        request_id: requestId,
      });
    });
  });

  // 5. withRequestId converts thrown Error into {ok:false,...} with same request_id
  describe('withRequestId – sync function throwing', () => {
    it('should convert a thrown Error into an err envelope with same request_id', () => {
      const requestId = 'req_test_err';
      const original = () => { throw new Error('failure'); };
      const wrapped = withRequestId(requestId, original);
      const result = wrapped();
      assert.strictEqual(result.ok, false);
      assert.strictEqual(result.error, 'failure');
      assert.strictEqual(result.request_id, requestId);
      // Check exact shape
      assert.deepStrictEqual(Object.keys(result), ['ok', 'error', 'request_id']);
    });
  });

  // 6. async function support
  describe('withRequestId – async function', () => {
    it('should work with an async function that resolves', async () => {
      const requestId = 'req_async_ok';
      const original = async (a, b) => a + b;
      const wrapped = withRequestId(requestId, original);
      const result = await wrapped(3, 4);
      assert.deepStrictEqual(result, {
        ok: true,
        data: 7,
        request_id: requestId,
      });
    });

    it('should work with an async function that rejects', async () => {
      const requestId = 'req_async_err';
      const original = async () => { throw new Error('async fail'); };
      const wrapped = withRequestId(requestId, original);
      const result = await wrapped();
      assert.strictEqual(result.ok, false);
      assert.strictEqual(result.error, 'async fail');
      assert.strictEqual(result.request_id, requestId);
    });
  });
});
```
