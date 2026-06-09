/**
 * Test Suite: Secure Validator v8
 * Task #8 test implementation
 */

const { SecureValidator, validate, validateBatch } = require('../src/secure_validator_v8');

describe('SecureValidator v8', () => {
  const validator = new SecureValidator();

  test('validates safe input', () => {
    const result = validate('hello world');
    expect(result.valid).toBe(true);
    expect(result.data).toBe('hello world');
  });

  test('detects SQL injection', () => {
    const result = validate("' UNION SELECT * FROM users");
    expect(result.valid).toBe(false);
    expect(result.errors.length).toBeGreaterThan(0);
  });

  test('detects XSS attempts', () => {
    const result = validate('<script>alert("xss")</script>');
    expect(result.valid).toBe(false);
  });

  test('detects command injection', () => {
    const result = validate('; rm -rf /');
    expect(result.valid).toBe(false);
  });

  test('validates email', () => {
    expect(validator.isValidEmail('test@example.com')).toBe(true);
    expect(validator.isValidEmail('invalid.email')).toBe(false);
  });

  test('validates URL', () => {
    expect(validator.isValidUrl('https://example.com')).toBe(true);
    expect(validator.isValidUrl('not a url')).toBe(false);
  });

  test('validates numbers with range', () => {
    validator.errors = [];
    expect(validator.validateNumber(42, 0, 100)).toBe(true);
    validator.errors = [];
    expect(validator.validateNumber(150, 0, 100)).toBe(false);
  });

  test('checks enum values', () => {
    expect(validator.isInEnum('active', ['active', 'inactive'])).toBe(true);
    expect(validator.isInEnum('pending', ['active', 'inactive'])).toBe(false);
  });

  test('respects max length', () => {
    const longStr = 'x'.repeat(11000);
    const result = validate(longStr, { maxLength: 10000 });
    expect(result.valid).toBe(false);
  });

  test('sanitizes output when enabled', () => {
    const result = validate('hello<script>alert</script>', { sanitize: true });
    expect(result.data).not.toContain('<');
  });

  test('batch validation', () => {
    const results = validateBatch(['safe', "' OR '1'='1", 'another safe']);
    expect(results[0].valid).toBe(true);
    expect(results[1].valid).toBe(false);
    expect(results[2].valid).toBe(true);
  });
});
