<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: A13 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":130,"completion_tokens":5057,"total_tokens":5187} | 43s
 generated: 2026-06-12T19:28:46.801Z -->
/**
 * Assumed signature of `createRateLimiter` exported from "../middleware/rateLimiter":
 *
 *   (windowMs: number, max: number) =>
 *     (req: express.Request, res: express.Response, next: express.NextFunction) => void
 *
 * Behaviour:
 *  - Counts requests per IP (req.ip) within a fixed window of `windowMs` milliseconds.
 *  - Allows at most `max` requests per window; subsequent requests receive HTTP 429.
 *  - The counter resets completely when `windowMs` has elapsed since the first request.
 *  - Sets RateLimit headers on every response (both allowed and blocked):
 *    `X-RateLimit-Limit` (max), `X-RateLimit-Remaining`, `X-RateLimit-Reset` (Unix timestamp in seconds).
 */

import { describe, it, mock } from 'node:test';
import assert from 'node:assert/strict';
import { createRateLimiter } from '../middleware/rateLimiter';

interface MockResponse {
  statusCode?: number;
  body?: any;
  _headers: Record<string, string>;
  status(code: number): MockResponse;
  json(data: any): MockResponse;
  setHeader(key: string, value: string): void;
  getHeader(key: string): string | undefined;
  getHeaders(): Record<string, string>;
}

function createMocks(ip = '127.0.0.1') {
  const req = { ip };
  const res: MockResponse = {
    statusCode: undefined,
    body: undefined,
    _headers: {},
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(data: any) {
      this.body = data;
      return this;
    },
    setHeader(key: string, value: string) {
      this._headers[key.toLowerCase()] = value;
    },
    getHeader(key: string) {
      return this._headers[key.toLowerCase()];
    },
    getHeaders() {
      return { ...this._headers };
    },
  };
  const next = mock.fn();
  return { req, res, next };
}

describe('rate limiter middleware', () => {
  it('allows requests up to the maximum count', () => {
    const { req, res, next } = createMocks();
    const middleware = createRateLimiter(1000, 3);

    for (let i = 0; i < 3; i++) middleware(req, res, next);

    assert.strictEqual(next.mock.calls.length, 3);
    assert.strictEqual(res.statusCode, undefined);
  });

  it('returns 429 after exceeding the limit', () => {
    const { req, res, next } = createMocks();
    const middleware = createRateLimiter(100, 2);

    for (let i = 0; i < 2; i++) middleware(req, res, next);
    assert.strictEqual(next.mock.calls.length, 2);

    // Exceed
    middleware(req, res, next);
    assert.strictEqual(res.statusCode, 429);
    assert.ok(
      res.body?.error?.includes('Too many requests') ||
        res.body?.message?.includes('Too many requests'),
    );
    assert.strictEqual(next.mock.calls.length, 2); // next not called again
  });

  it('resets after the window duration', async () => {
    const windowMs = 80;
    const max = 2;
    const { req, res, next } = createMocks();
    const middleware = createRateLimiter(windowMs, max);

    // Consume max
    for (let i = 0; i < max; i++) middleware(req, res, next);
    assert.strictEqual(next.mock.calls.length, max);

    // Exceed → 429
    middleware(req, res, next);
    assert.strictEqual(res.statusCode, 429);

    // Wait for window to expire
    await new Promise((r) => setTimeout(r, windowMs + 20));

    // Fresh mocks for the next request
    const newRes: MockResponse = {
      statusCode: undefined,
      body: undefined,
      _headers: {},
      status(code: number) {
        this.statusCode = code;
        return this;
      },
      json(data: any) {
        this.body = data;
        return this;
      },
      setHeader(key: string, value: string) {
        this._headers[key.toLowerCase()] = value;
      },
      getHeader(key: string) {
        return this._headers[key.toLowerCase()];
      },
      getHeaders() {
        return { ...this._headers };
      },
    };
    const newNext = mock.fn();

    middleware(req, newRes, newNext);
    assert.strictEqual(newNext.mock.calls.length, 1, 'should allow request after window reset');
    assert.strictEqual(newRes.statusCode, undefined);
  });

  it('keys by req.ip', () => {
    const middleware = createRateLimiter(1000, 2);
    const ip1 = '192.168.0.1';
    const ip2 = '10.0.0.1';

    const { req: req1, res: res1, next: next1 } = createMocks(ip1);
    const { req: req2, res: res2, next: next2 } = createMocks(ip2);

    // Fill IP1 limit
    middleware(req1, res1, next1);
    middleware(req1, res1, next1);
    assert.strictEqual(next1.mock.calls.length, 2);

    // IP2 still has full quota
    middleware(req2, res2, next2);
    assert.strictEqual(next2.mock.calls.length, 1);
    middleware(req2, res2, next2);
    assert.strictEqual(next2.mock.calls.length, 2);

    // IP1 exceed
    middleware(req1, res1, next1);
    assert.strictEqual(res1.statusCode, 429);

    // IP2 exceed
    middleware(req2, res2, next2);
    assert.strictEqual(res2.statusCode, 429);
  });

  it('sets RateLimit headers on every response', () => {
    const max = 5;
    const middleware = createRateLimiter(60000, max);
    const { req, res, next } = createMocks();

    // First request
    middleware(req, res, next);
    const limit = res.getHeader('x-ratelimit-limit');
    const remaining = res.getHeader('x-ratelimit-remaining');
    const reset = res.getHeader('x-ratelimit-reset');

    assert.ok(limit, 'x-ratelimit-limit header missing');
    assert.ok(remaining, 'x-ratelimit-remaining header missing');
    assert.ok(reset, 'x-ratelimit-reset header missing');
    assert.strictEqual(Number(limit), max);
    assert.strictEqual(Number(remaining), max - 1);
    const nowSec = Math.floor(Date.now() / 1000);
    const resetVal = Number(reset);
    assert.ok(
      !isNaN(resetVal) && resetVal >= nowSec && resetVal <= nowSec + 60,
      'reset should be a future timestamp in seconds',
    );

    // Blocked request should also include headers
    for (let i = 0; i < max - 1; i++) middleware(req, res, next);
    middleware(req, res, next); // now blocked
    assert.strictEqual(res.statusCode, 429);
    const remainingBlocked = res.getHeader('x-ratelimit-remaining');
    assert.strictEqual(Number(remainingBlocked), 0, 'remaining should be 0 after exceeding');
    const limitBlocked = res.getHeader('x-ratelimit-limit');
    assert.strictEqual(Number(limitBlocked), max);
    assert.ok(res.getHeader('x-ratelimit-reset'), 'reset header should be present on 429');
  });
});
