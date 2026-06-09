/**
 * Test suite for secure_validator.js
 * Tests all validation functions and security patterns
 */

const {
  validateInput,
  validateString,
  validateEmail,
  validateUrl,
  sanitizeString,
  detectDangerousPatterns,
  hashValue,
  generateToken,
} = require('../src/secure_validator');

let passCount = 0;
let failCount = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
    passCount++;
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(`  ${error.message}`);
    failCount++;
  }
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(message || `Expected ${expected}, got ${actual}`);
  }
}

// String validation tests
test('Valid string passes validation', () => {
  const result = validateString('hello world', {});
  assert(result.valid, 'String should be valid');
  assertEqual(result.value, 'hello world');
});

test('String exceeding max length fails', () => {
  const result = validateString('a'.repeat(10001), {});
  assert(!result.valid, 'String should exceed limit');
});

test('String with min length constraint', () => {
  const result = validateString('hi', { minLength: 5 });
  assert(!result.valid, 'String should fail min length');
});

test('String enum validation', () => {
  const result = validateString('admin', { enum: ['admin', 'user', 'guest'] });
  assert(result.valid, 'String should be in enum');
});

// Email validation tests
test('Valid email passes validation', () => {
  const result = validateEmail('user@example.com', {});
  assert(result.valid, 'Email should be valid');
  assertEqual(result.value, 'user@example.com');
});

test('Invalid email format fails', () => {
  const result = validateEmail('not-an-email', {});
  assert(!result.valid, 'Invalid email should fail');
});

test('Email is normalized to lowercase', () => {
  const result = validateEmail('User@Example.COM', {});
  assert(result.valid, 'Email should be valid');
  assertEqual(result.value, 'user@example.com');
});

// URL validation tests
test('Valid HTTPS URL passes validation', () => {
  const result = validateUrl('https://example.com/path', {});
  assert(result.valid, 'HTTPS URL should be valid');
});

test('Valid HTTP URL passes validation', () => {
  const result = validateUrl('http://example.com', {});
  assert(result.valid, 'HTTP URL should be valid');
});

test('Invalid URL format fails', () => {
  const result = validateUrl('not a url', {});
  assert(!result.valid, 'Invalid URL should fail');
});

// Sanitization tests
test('SQL injection patterns are detected', () => {
  const patterns = detectDangerousPatterns("'; DROP TABLE users; --");
  assert(patterns.includes('SQL_INJECTION'), 'SQL injection should be detected');
});

test('XSS patterns are detected', () => {
  const patterns = detectDangerousPatterns('<script>alert("xss")</script>');
  assert(patterns.includes('XSS_SCRIPT'), 'XSS script should be detected');
});

test('Event handler injection is detected', () => {
  const patterns = detectDangerousPatterns('<div onclick="alert(1)">');
  assert(patterns.includes('XSS_EVENT'), 'XSS event should be detected');
});

test('Sanitize removes HTML tags', () => {
  const result = sanitizeString('<b>bold</b>');
  assert(result !== '<b>bold</b>', 'HTML tags should be encoded');
  assert(result.includes('&lt;'), 'Should contain HTML entity');
});

test('Sanitize encodes quotes', () => {
  const result = sanitizeString('Hello "world"');
  assert(result.includes('&quot;'), 'Quotes should be encoded');
});

// Type validation tests
test('Number validation accepts valid numbers', () => {
  const result = validateInput(42, { type: 'number' });
  assert(result.valid, 'Valid number should pass');
  assertEqual(result.value, 42);
});

test('Number validation rejects non-numbers', () => {
  const result = validateInput('not a number', { type: 'number' });
  assert(!result.valid, 'Non-number should fail');
});

test('Number range validation with min/max', () => {
  const result = validateInput(50, { type: 'number', min: 0, max: 100 });
  assert(result.valid, 'Number in range should pass');
});

test('Number validation rejects out-of-range values', () => {
  const result = validateInput(150, { type: 'number', min: 0, max: 100 });
  assert(!result.valid, 'Out-of-range number should fail');
});

// Boolean validation tests
test('Boolean validation accepts true/false', () => {
  const result = validateInput(true, { type: 'boolean' });
  assert(result.valid, 'Boolean should be valid');
});

test('Boolean coercion from string', () => {
  const result = validateInput('true', { type: 'boolean' });
  assert(result.valid, 'String "true" should coerce');
  assertEqual(result.value, true);
});

// Array validation tests
test('Array validation accepts arrays', () => {
  const result = validateInput([1, 2, 3], { type: 'array' });
  assert(result.valid, 'Array should be valid');
});

test('Array validation rejects non-arrays', () => {
  const result = validateInput('not an array', { type: 'array' });
  assert(!result.valid, 'Non-array should fail');
});

test('Array size limit enforcement', () => {
  const bigArray = new Array(1001).fill(0);
  const result = validateInput(bigArray, { type: 'array' });
  assert(!result.valid, 'Array exceeding size limit should fail');
});

// Object validation tests
test('Object validation accepts objects', () => {
  const result = validateInput({ key: 'value' }, { type: 'object' });
  assert(result.valid, 'Object should be valid');
});

test('Object validation with schema', () => {
  const schema = {
    type: 'object',
    schema: {
      name: { type: 'string', required: true },
      age: { type: 'number', min: 0, max: 150 }
    }
  };
  const result = validateInput({ name: 'John', age: 30 }, schema);
  assert(result.valid, 'Valid object should pass schema');
});

test('Object validation fails on bad schema', () => {
  const schema = {
    type: 'object',
    schema: {
      age: { type: 'number', min: 0, max: 150 }
    }
  };
  const result = validateInput({ age: 200 }, schema);
  assert(!result.valid, 'Invalid age should fail');
});

// Required field tests
test('Required field validation', () => {
  const result = validateInput(null, { required: true });
  assert(!result.valid, 'Null should fail required check');
});

test('Required field with valid value', () => {
  const result = validateInput('value', { required: true, type: 'string' });
  assert(result.valid, 'Non-null should pass required check');
});

// Cryptographic function tests
test('hashValue generates consistent hash', () => {
  const hash1 = hashValue('password');
  const hash2 = hashValue('password');
  assertEqual(hash1, hash2, 'Same input should produce same hash');
});

test('hashValue produces different hashes for different inputs', () => {
  const hash1 = hashValue('password1');
  const hash2 = hashValue('password2');
  assert(hash1 !== hash2, 'Different inputs should produce different hashes');
});

test('generateToken produces random tokens', () => {
  const token1 = generateToken();
  const token2 = generateToken();
  assert(token1 !== token2, 'Tokens should be different');
  assert(token1.length === 64, 'Default token should be 64 chars');
});

test('generateToken with custom length', () => {
  const token = generateToken(16);
  assert(token.length === 32, 'Custom length token should match (16 bytes = 32 hex chars)');
});

// Summary
console.log('\n' + '='.repeat(50));
console.log(`Tests passed: ${passCount}`);
console.log(`Tests failed: ${failCount}`);
console.log('='.repeat(50));

// Exit with appropriate code
process.exit(failCount > 0 ? 1 : 0);
