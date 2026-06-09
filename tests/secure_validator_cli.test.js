/**
 * Task #12: Secure Validation CLI Tests
 * Tests JSON output, CLI argument parsing, all validation commands
 */

const { execSync } = require('child_process');
const path = require('path');

const CLI_PATH = path.join(__dirname, '../src/secure_validator_cli.js');

function runCli(args) {
  try {
    const output = execSync(`node ${CLI_PATH} ${args}`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe']
    });
    return JSON.parse(output);
  } catch (error) {
    if (error.stdout) {
      try {
        return JSON.parse(error.stdout);
      } catch {
        return {
          status: 'error',
          completion_percent: 0,
          error: error.message
        };
      }
    }
    throw error;
  }
}

describe('Secure Validator CLI v12', () => {

  test('validate command with safe input', () => {
    const result = runCli('validate "hello world"');
    expect(result.status).toBe('success');
    expect(result.completion_percent).toBe(100);
    expect(result.data.valid).toBe(true);
    expect(result.timestamp).toBeDefined();
  });

  test('validate command detects SQL injection', () => {
    const result = runCli("validate \"' OR '1'='1\"");
    expect(result.status).toBe('validation_failed');
    expect(result.completion_percent).toBe(0);
    expect(result.data.valid).toBe(false);
    expect(result.data.errors.length).toBeGreaterThan(0);
  });

  test('validate command detects XSS', () => {
    const result = runCli('validate "<script>alert(\'xss\')</script>"');
    expect(result.status).toBe('validation_failed');
    expect(result.data.valid).toBe(false);
  });

  test('email validation success', () => {
    const result = runCli('email "test@example.com"');
    expect(result.status).toBe('success');
    expect(result.completion_percent).toBe(100);
    expect(result.data.valid).toBe(true);
  });

  test('email validation failure', () => {
    const result = runCli('email "invalid-email"');
    expect(result.status).toBe('validation_failed');
    expect(result.completion_percent).toBe(0);
    expect(result.data.valid).toBe(false);
  });

  test('url validation success', () => {
    const result = runCli('url "https://example.com"');
    expect(result.status).toBe('success');
    expect(result.completion_percent).toBe(100);
    expect(result.data.valid).toBe(true);
  });

  test('url validation failure', () => {
    const result = runCli('url "not-a-url"');
    expect(result.status).toBe('validation_failed');
    expect(result.data.valid).toBe(false);
  });

  test('number validation in range', () => {
    const result = runCli('number 42 --min=0 --max=100');
    expect(result.status).toBe('success');
    expect(result.completion_percent).toBe(100);
    expect(result.data.valid).toBe(true);
    expect(result.data.value).toBe(42);
  });

  test('number validation out of range', () => {
    const result = runCli('number 200 --min=0 --max=100');
    expect(result.status).toBe('validation_failed');
    expect(result.data.valid).toBe(false);
  });

  test('enum validation success', () => {
    const result = runCli('enum "admin" \'["user","admin","guest"]\'');
    expect(result.status).toBe('success');
    expect(result.completion_percent).toBe(100);
    expect(result.data.valid).toBe(true);
  });

  test('enum validation failure', () => {
    const result = runCli('enum "superuser" \'["user","admin","guest"]\'');
    expect(result.status).toBe('validation_failed');
    expect(result.data.valid).toBe(false);
  });

  test('batch validation mixed results', () => {
    const result = runCli('batch \'["hello","<script>","world"]\'');
    expect(result.status).toBe('partial_failure');
    expect(result.completion_percent).toBeGreaterThan(0);
    expect(result.completion_percent).toBeLessThan(100);
    expect(result.data.total).toBe(3);
    expect(result.data.valid).toBe(2);
    expect(result.data.invalid).toBe(1);
  });

  test('batch validation all valid', () => {
    const result = runCli('batch \'["safe1","safe2","safe3"]\'');
    expect(result.status).toBe('success');
    expect(result.completion_percent).toBe(100);
    expect(result.data.total).toBe(3);
    expect(result.data.valid).toBe(3);
  });

  test('JSON output always has required fields', () => {
    const result = runCli('validate "test"');
    expect(result).toHaveProperty('status');
    expect(result).toHaveProperty('completion_percent');
    expect(result).toHaveProperty('timestamp');
    expect(typeof result.status).toBe('string');
    expect(typeof result.completion_percent).toBe('number');
    expect(result.completion_percent).toBeGreaterThanOrEqual(0);
    expect(result.completion_percent).toBeLessThanOrEqual(100);
  });

  test('error handling for invalid command', () => {
    const result = runCli('invalid-command test');
    expect(result.status).toBe('error');
    expect(result.completion_percent).toBe(0);
    expect(result.error).toBeDefined();
  });

  test('error handling for missing arguments', () => {
    const result = runCli('validate');
    expect(result.status).toBe('error');
    expect(result.completion_percent).toBe(0);
    expect(result.error).toBeDefined();
  });

  test('sanitization option works', () => {
    const result = runCli('validate "hello<world" --sanitize=true');
    expect(result.data.sanitized).not.toContain('<');
  });

  test('maxLength option enforced', () => {
    const longInput = 'a'.repeat(100);
    const result = runCli(`validate "${longInput}" --maxLength=50`);
    expect(result.status).toBe('validation_failed');
  });

});
