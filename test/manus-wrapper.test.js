// SA FIXES APPLIED (TICKET-007b review):
// Fix 1: wrapOk arg order — B3 used wrapOk(data, requestId) but B1 API is wrapOk(request_id, data)
// Fix 2: wrapErr arg order — B3 used wrapErr(msg, id) but B1 API is wrapErr(request_id, code, message)
// Fix 3: wrapErr result shape — B3 expected {error: string} but B1 returns {error: {code, message}}; test updated to check .error.message
// Fix 4: withRequestId signature — B3 called withRequestId(requestId, fn) but B1 API is withRequestId(fn) (auto-generates id); tests rewritten to match actual HOF contract
// Fix 5: withRequestId sync tests — added await since B1 always returns a Promise

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
  // FIX 1: corrected arg order to wrapOk(request_id, data) per B1 API
  describe('wrapOk', () => {
    it('should return an object with exactly ok, request_id, and data', () => {
      const data = { some: 'data' };
      const requestId = generateRequestId();
      const result = wrapOk(requestId, data); // FIX 1: was wrapOk(data, requestId)
      assert.deepStrictEqual(result, {
        ok: true,
        request_id: requestId,
        data,
      });
      const keys = Object.keys(result);
      assert.deepStrictEqual(keys.sort(), ['data', 'ok', 'request_id']);
    });
  });

  // 3. wrapErr shape exact
  // FIX 2+3: corrected arg order and result shape — B1 returns {ok, request_id, error:{code,message}}
  describe('wrapErr', () => {
    it('should return an object with ok:false, request_id, and error:{code,message}', () => {
      const requestId = generateRequestId();
      // FIX 2: was wrapErr(errorMsg, requestId) — B1 signature is wrapErr(request_id, code, message)
      const result = wrapErr(requestId, 'TEST_CODE', 'Something went wrong');
      assert.strictEqual(result.ok, false);
      assert.strictEqual(result.request_id, requestId);
      // FIX 3: B1 returns nested {error:{code,message}}, not flat string
      assert.strictEqual(result.error.code, 'TEST_CODE');
      assert.strictEqual(result.error.message, 'Something went wrong');
    });
  });

  // 4. withRequestId passes through return value wrapped in ok envelope
  // FIX 4+5: B1 withRequestId(fn) is a HOF that auto-generates request_id and returns async fn
  describe('withRequestId – sync function', () => {
    it('should wrap the return value in an ok envelope', async () => {
      // FIX 4: B1 API is withRequestId(fn), not withRequestId(id, fn)
      const wrapped = withRequestId((req_id, x) => x * 2);
      // FIX 5: must await — B1 always returns Promise
      const result = await wrapped(21);
      assert.strictEqual(result.ok, true);
      assert.strictEqual(result.data, 42);
      assert.match(result.request_id, /^req_/);
    });
  });

  // 5. withRequestId converts thrown Error into {ok:false,...} with same request_id
  describe('withRequestId – sync function throwing', () => {
    it('should convert a thrown Error into an err envelope', async () => {
      const wrapped = withRequestId(() => { throw new Error('failure'); });
      // FIX 5: must await
      const result = await wrapped();
      assert.strictEqual(result.ok, false);
      // FIX 3: error is nested object
      assert.strictEqual(result.error.message, 'failure');
      assert.match(result.request_id, /^req_/);
    });
  });

  // 6. async function support
  describe('withRequestId – async function', () => {
    it('should work with an async function that resolves', async () => {
      // FIX 4: B1 injects request_id as first arg to fn
      const wrapped = withRequestId(async (req_id, a, b) => a + b);
      const result = await wrapped(3, 4);
      assert.strictEqual(result.ok, true);
      assert.strictEqual(result.data, 7);
      assert.match(result.request_id, /^req_/);
    });

    it('should work with an async function that rejects', async () => {
      const wrapped = withRequestId(async () => { throw new Error('async fail'); });
      const result = await wrapped();
      assert.strictEqual(result.ok, false);
      assert.strictEqual(result.error.message, 'async fail');
      assert.match(result.request_id, /^req_/);
    });
  });
});
