<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: A14 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":106,"completion_tokens":1365,"total_tokens":1471} | 14s
 generated: 2026-06-12T19:28:17.579Z -->
/**
 * Assumed signature of aggregateHealth:
 *   aggregateHealth(services: { name: string, status: 'healthy' | 'degraded' | 'unhealthy' }[]):
 *     {
 *       status: 'healthy' | 'degraded' | 'unhealthy' | 'unknown',
 *       services: { name: string, status: 'healthy' | 'degraded' | 'unhealthy' }[]
 *     }
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { aggregateHealth } from '../services/healthAggregator';

describe('aggregateHealth', () => {
  it('all healthy services => overall healthy, preserves service names and statuses', () => {
    const input = [
      { name: 'db', status: 'healthy' },
      { name: 'cache', status: 'healthy' },
      { name: 'api', status: 'healthy' },
    ];
    const result = aggregateHealth(input);
    assert.strictEqual(result.status, 'healthy');
    assert.deepStrictEqual(result.services, input);
  });

  it('one unhealthy service => overall status is degraded or unhealthy, preserves services', () => {
    const input = [
      { name: 'db', status: 'healthy' },
      { name: 'cache', status: 'unhealthy' },
    ];
    const result = aggregateHealth(input);
    assert.ok(
      result.status === 'degraded' || result.status === 'unhealthy',
      `Expected status to be 'degraded' or 'unhealthy', got '${result.status}'`
    );
    assert.deepStrictEqual(result.services, input);
  });

  it('empty services => overall status is unknown or unhealthy, services array is empty', () => {
    const input: { name: string; status: 'healthy' | 'degraded' | 'unhealthy' }[] = [];
    const result = aggregateHealth(input);
    assert.ok(
      result.status === 'unknown' || result.status === 'unhealthy',
      `Expected status to be 'unknown' or 'unhealthy', got '${result.status}'`
    );
    assert.deepStrictEqual(result.services, []);
  });

  it('mixed statuses including degraded -> overall status is non-healthy, preserves services exactly', () => {
    const input = [
      { name: 's1', status: 'healthy' },
      { name: 's2', status: 'degraded' },
      { name: 's3', status: 'healthy' },
    ];
    const result = aggregateHealth(input);
    // Expect not healthy (could be degraded or unhealthy)
    assert.notStrictEqual(result.status, 'healthy');
    assert.deepStrictEqual(result.services, input);
  });
});
