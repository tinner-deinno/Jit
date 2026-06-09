/**
 * Test suite for JSON Validator
 * Covers security validation, schema validation, and edge cases
 */

const { JSONValidator, SchemaValidator, validate, validateWithSchema } = require('../src/json_validator');

// Test helpers
function runTests() {
  let passCount = 0;
  let failCount = 0;
  const results = [];

  function test(name, fn) {
    try {
      fn();
      passCount++;
      results.push({ test: name, status: 'PASS' });
    } catch (e) {
      failCount++;
      results.push({ test: name, status: 'FAIL', error: e.message });
      console.error(`FAIL: ${name}\n  ${e.message}\n`);
    }
  }

  function assert(condition, message) {
    if (!condition) throw new Error(message);
  }

  function assertEqual(actual, expected, message) {
    if (actual !== expected) {
      throw new Error(`${message}: expected ${expected}, got ${actual}`);
    }
  }

  // ========== BASIC VALIDATION TESTS ==========
  test('Valid simple JSON object', () => {
    const result = validate('{"name": "Alice", "age": 30}');
    assert(result.valid === true, 'Should be valid');
    assert(result.data.name === 'Alice', 'Should parse correctly');
  });

  test('Valid JSON array', () => {
    const result = validate('[1, 2, 3, "test"]');
    assert(result.valid === true, 'Should be valid');
    assert(Array.isArray(result.data), 'Should be array');
  });

  test('Valid nested JSON', () => {
    const result = validate('{"user": {"name": "Bob", "address": {"city": "NYC"}}}');
    assert(result.valid === true, 'Should be valid');
    assert(result.data.user.address.city === 'NYC', 'Should parse nested objects');
  });

  test('Null value is valid', () => {
    const result = validate('null');
    assert(result.valid === true, 'Null should be valid');
    assert(result.data === null, 'Should parse as null');
  });

  // ========== INVALID JSON TESTS ==========
  test('Invalid JSON syntax', () => {
    const result = validate('{invalid json}');
    assert(result.valid === false, 'Should be invalid');
    assert(result.errors.length > 0, 'Should have error');
  });

  test('Incomplete JSON', () => {
    const result = validate('{"name": "Alice"');
    assert(result.valid === false, 'Should be invalid');
  });

  test('Single quotes instead of double quotes', () => {
    const result = validate("{'name': 'Alice'}");
    assert(result.valid === false, 'Should be invalid (single quotes not allowed in JSON)');
  });

  // ========== SECURITY TESTS ==========
  test('Detect SQL injection pattern in string', () => {
    const malicious = '{"query": "SELECT * FROM users WHERE id = 1; DROP TABLE users--"}';
    const result = validate(malicious);
    assert(result.valid === false, 'Should detect SQL injection');
    assert(result.errors.some(e => e.includes('dangerous')), 'Should mention dangerous pattern');
  });

  test('Detect XSS script injection', () => {
    const malicious = '{"content": "<script>alert(\'xss\')</script>"}';
    const result = validate(malicious);
    assert(result.valid === false, 'Should detect XSS');
  });

  test('Detect event handler injection', () => {
    const malicious = '{"html": "<img onerror=alert(1)>"}';
    const result = validate(malicious);
    assert(result.valid === false, 'Should detect event handler');
  });

  test('Detect command injection patterns', () => {
    const malicious = '{"cmd": "rm -rf /; echo done"}';
    const result = validate(malicious);
    assert(result.valid === false, 'Should detect command injection');
  });

  test('Detect prototype pollution (forbidden key)', () => {
    const result = validate('{"__proto__": {"isAdmin": true}}');
    assert(result.valid === false, 'Should reject __proto__');
  });

  test('Detect constructor key pollution', () => {
    const result = validate('{"constructor": {"prototype": {"isAdmin": true}}}');
    assert(result.valid === false, 'Should reject constructor key');
  });

  // ========== DEPTH LIMIT TESTS ==========
  test('Reject deeply nested objects', () => {
    let json = '{"a":';
    for (let i = 0; i < 25; i++) {
      json += '{"b":';
    }
    json += '1';
    for (let i = 0; i < 25; i++) {
      json += '}';
    }
    json += '}';

    const validator = new JSONValidator({ maxDepth: 20 });
    const result = validator.validate(json);
    assert(result.valid === false, 'Should reject excessive nesting');
  });

  test('Allow reasonable nesting within limit', () => {
    let json = '{"a":';
    for (let i = 0; i < 10; i++) {
      json += '{"b":';
    }
    json += '1';
    for (let i = 0; i < 10; i++) {
      json += '}';
    }
    json += '}';

    const validator = new JSONValidator({ maxDepth: 20 });
    const result = validator.validate(json);
    assert(result.valid === true, 'Should allow reasonable nesting');
  });

  // ========== SIZE LIMIT TESTS ==========
  test('Reject oversized payload', () => {
    const largeString = 'x'.repeat(11 * 1024 * 1024);
    const json = `{"data": "${largeString}"}`;
    const result = validate(json);
    assert(result.valid === false, 'Should reject oversized payload');
  });

  test('Accept payload within size limit', () => {
    const smallString = 'x'.repeat(1000);
    const json = `{"data": "${smallString}"}`;
    const result = validate(json);
    assert(result.valid === true, 'Should accept reasonable size');
  });

  // ========== KEY VALIDATION TESTS ==========
  test('Accept valid key names', () => {
    const result = validate('{"name": "test", "user_id": 123, "email-address": "test@example.com"}');
    assert(result.valid === true, 'Should accept alphanumeric, underscore, hyphen, dot');
  });

  test('Reject invalid key names', () => {
    const result = validate('{"na<me>": "test"}');
    assert(result.valid === false, 'Should reject keys with invalid characters');
  });

  // ========== CIRCULAR REFERENCE TESTS ==========
  test('Detect circular references', () => {
    const obj = { a: 1 };
    obj.self = obj;
    const validator = new JSONValidator();
    assert(validator.hasCircularReference(obj), 'Should detect circular reference');
  });

  test('Allow non-circular references', () => {
    const obj = { a: 1, b: { c: 2 } };
    const validator = new JSONValidator();
    assert(!validator.hasCircularReference(obj), 'Should not flag normal objects');
  });

  // ========== SCHEMA VALIDATION TESTS ==========
  test('Schema: valid required fields', () => {
    const schema = {
      type: 'object',
      required: ['name', 'email'],
      properties: {
        name: { type: 'string' },
        email: { type: 'string' }
      }
    };
    const data = { name: 'Alice', email: 'alice@example.com' };
    const result = SchemaValidator.validate(data, schema);
    assert(result.valid === true, 'Should pass required field check');
  });

  test('Schema: missing required field', () => {
    const schema = {
      type: 'object',
      required: ['name', 'email'],
      properties: {
        name: { type: 'string' },
        email: { type: 'string' }
      }
    };
    const data = { name: 'Alice' };
    const result = SchemaValidator.validate(data, schema);
    assert(result.valid === false, 'Should fail missing required field');
  });

  test('Schema: string length constraints', () => {
    const schema = {
      type: 'object',
      properties: {
        username: { type: 'string', minLength: 3, maxLength: 20 }
      }
    };

    const tooShort = { username: 'ab' };
    const result1 = SchemaValidator.validate(tooShort, schema);
    assert(result1.valid === false, 'Should reject too short');

    const valid = { username: 'alice' };
    const result2 = SchemaValidator.validate(valid, schema);
    assert(result2.valid === true, 'Should accept valid length');
  });

  test('Schema: number range constraints', () => {
    const schema = {
      type: 'object',
      properties: {
        age: { type: 'number', minimum: 0, maximum: 150 }
      }
    };

    const tooLow = { age: -1 };
    const result1 = SchemaValidator.validate(tooLow, schema);
    assert(result1.valid === false, 'Should reject below minimum');

    const valid = { age: 30 };
    const result2 = SchemaValidator.validate(valid, schema);
    assert(result2.valid === true, 'Should accept within range');
  });

  test('Schema: email format validation', () => {
    const schema = {
      type: 'object',
      properties: {
        email: { type: 'string', format: 'email' }
      }
    };

    const invalid = { email: 'not-an-email' };
    const result1 = SchemaValidator.validate(invalid, schema);
    assert(result1.valid === false, 'Should reject invalid email');

    const valid = { email: 'alice@example.com' };
    const result2 = SchemaValidator.validate(valid, schema);
    assert(result2.valid === true, 'Should accept valid email');
  });

  test('Schema: enum validation', () => {
    const schema = {
      type: 'object',
      properties: {
        status: { type: 'string', enum: ['active', 'inactive', 'pending'] }
      }
    };

    const invalid = { status: 'blocked' };
    const result1 = SchemaValidator.validate(invalid, schema);
    assert(result1.valid === false, 'Should reject value not in enum');

    const valid = { status: 'active' };
    const result2 = SchemaValidator.validate(valid, schema);
    assert(result2.valid === true, 'Should accept enum value');
  });

  test('Schema: pattern matching', () => {
    const schema = {
      type: 'object',
      properties: {
        zipcode: { type: 'string', pattern: '^[0-9]{5}$' }
      }
    };

    const invalid = { zipcode: 'ABC12' };
    const result1 = SchemaValidator.validate(invalid, schema);
    assert(result1.valid === false, 'Should reject pattern mismatch');

    const valid = { zipcode: '12345' };
    const result2 = SchemaValidator.validate(valid, schema);
    assert(result2.valid === true, 'Should accept pattern match');
  });

  // ========== COMPLEX REAL-WORLD TESTS ==========
  test('Real-world: API request with nested data', () => {
    const apiRequest = JSON.stringify({
      user_id: 12345,
      action: 'update_profile',
      data: {
        name: 'Bob Smith',
        email: 'bob@example.com',
        preferences: {
          notifications: true,
          theme: 'dark'
        }
      }
    });
    const result = validate(apiRequest);
    assert(result.valid === true, 'Should validate clean API request');
  });

  test('Real-world: reject malicious API payload', () => {
    const malicious = JSON.stringify({
      user_id: 12345,
      query: "'; DROP TABLE users; --"
    });
    const result = validate(malicious);
    assert(result.valid === false, 'Should reject malicious payload');
  });

  test('Real-world: bot webhook from Discord', () => {
    const webhook = JSON.stringify({
      id: '123456789',
      type: 'MESSAGE_CREATE',
      author: { id: '987654321', username: 'bot' },
      content: 'Hello world',
      timestamp: '2026-06-08T10:00:00Z'
    });
    const result = validate(webhook);
    assert(result.valid === true, 'Should validate legitimate webhook');
  });

  // ========== PRINT RESULTS ==========
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Tests Complete: ${passCount} PASS, ${failCount} FAIL`);
  console.log(`Pass Rate: ${((passCount / (passCount + failCount)) * 100).toFixed(1)}%`);
  console.log(`${'='.repeat(50)}\n`);

  return { passCount, failCount, results };
}

// Run tests
const summary = runTests();

module.exports = { runTests };
