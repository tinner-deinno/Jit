#!/usr/bin/env node

/**
 * Secure Validation CLI v12
 * Task #12: Codex CLI provider for secure validation
 * Provides JSON-based REST-like interface for validation
 */

const { SecureValidator, validate, validateBatch } = require('./secure_validator_v8');

/**
 * Main CLI handler
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    printHelp();
    process.exit(0);
  }

  const command = args[0];
  const options = parseOptions(args);

  try {
    let result;

    switch (command) {
      case 'validate':
        result = handleValidate(args.slice(1), options);
        break;
      case 'batch':
        result = handleBatch(args.slice(1), options);
        break;
      case 'email':
        result = handleEmail(args.slice(1), options);
        break;
      case 'url':
        result = handleUrl(args.slice(1), options);
        break;
      case 'number':
        result = handleNumber(args.slice(1), options);
        break;
      case 'enum':
        result = handleEnum(args.slice(1), options);
        break;
      case 'help':
      case '-h':
      case '--help':
        printHelp();
        process.exit(0);
        break;
      default:
        result = {
          status: 'error',
          completion_percent: 0,
          error: `Unknown command: ${command}`
        };
    }

    console.log(JSON.stringify(result, null, 2));
    process.exit(result.status === 'error' ? 1 : 0);
  } catch (error) {
    console.log(JSON.stringify({
      status: 'error',
      completion_percent: 0,
      error: error.message
    }, null, 2));
    process.exit(1);
  }
}

/**
 * Validate single input
 */
function handleValidate(args, options) {
  const input = args[0];
  if (!input) {
    return {
      status: 'error',
      completion_percent: 0,
      error: 'Input required for validate command'
    };
  }

  const validatorOptions = {
    maxLength: parseInt(options.maxLength) || 10000,
    maxDepth: parseInt(options.maxDepth) || 20,
    allowNull: options.allowNull !== 'false',
    sanitize: options.sanitize !== 'false'
  };

  const result = validate(input, validatorOptions);

  return {
    status: result.valid ? 'success' : 'validation_failed',
    completion_percent: result.valid ? 100 : 0,
    data: {
      input: input.substring(0, 50) + (input.length > 50 ? '...' : ''),
      valid: result.valid,
      errors: result.errors,
      sanitized: result.data
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * Validate batch inputs (JSON array)
 */
function handleBatch(args, options) {
  const inputJson = args[0];
  if (!inputJson) {
    return {
      status: 'error',
      completion_percent: 0,
      error: 'JSON array required for batch command'
    };
  }

  let inputs;
  try {
    inputs = JSON.parse(inputJson);
    if (!Array.isArray(inputs)) {
      throw new Error('Input must be a JSON array');
    }
  } catch (e) {
    return {
      status: 'error',
      completion_percent: 0,
      error: `Invalid JSON: ${e.message}`
    };
  }

  const validatorOptions = {
    maxLength: parseInt(options.maxLength) || 10000,
    maxDepth: parseInt(options.maxDepth) || 20,
    sanitize: options.sanitize !== 'false'
  };

  // Validate each input individually
  const results = inputs.map(input => {
    const result = validate(input, validatorOptions);
    return {
      input: input.length > 50 ? input.substring(0, 50) + '...' : input,
      valid: result.valid,
      errors: result.errors
    };
  });

  const successCount = results.filter(r => r.valid).length;
  const completionPercent = results.length === 0 ? 0 : Math.round((successCount / results.length) * 100);

  return {
    status: successCount === results.length ? 'success' : 'partial_failure',
    completion_percent: completionPercent,
    data: {
      total: results.length,
      valid: successCount,
      invalid: results.length - successCount,
      results: results
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * Email validation
 */
function handleEmail(args, options) {
  const email = args[0];
  if (!email) {
    return {
      status: 'error',
      completion_percent: 0,
      error: 'Email address required'
    };
  }

  const validator = new SecureValidator();
  const isValid = validator.isValidEmail(email);

  return {
    status: isValid ? 'success' : 'validation_failed',
    completion_percent: isValid ? 100 : 0,
    data: {
      email,
      valid: isValid
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * URL validation
 */
function handleUrl(args, options) {
  const url = args[0];
  if (!url) {
    return {
      status: 'error',
      completion_percent: 0,
      error: 'URL required'
    };
  }

  const validator = new SecureValidator();
  const isValid = validator.isValidUrl(url);

  return {
    status: isValid ? 'success' : 'validation_failed',
    completion_percent: isValid ? 100 : 0,
    data: {
      url,
      valid: isValid
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * Number validation
 */
function handleNumber(args, options) {
  const value = args[0];
  const min = parseFloat(options.min) || -Infinity;
  const max = parseFloat(options.max) || Infinity;

  if (!value) {
    return {
      status: 'error',
      completion_percent: 0,
      error: 'Number value required'
    };
  }

  const validator = new SecureValidator();
  const isValid = validator.validateNumber(value, min, max);

  return {
    status: isValid ? 'success' : 'validation_failed',
    completion_percent: isValid ? 100 : 0,
    data: {
      value: Number(value),
      valid: isValid,
      range: [min, max],
      errors: validator.getErrors()
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * Enum validation
 */
function handleEnum(args, options) {
  const value = args[0];
  const allowedJson = args[1];

  if (!value || !allowedJson) {
    return {
      status: 'error',
      completion_percent: 0,
      error: 'Value and allowed list (JSON) required'
    };
  }

  let allowed;
  try {
    allowed = JSON.parse(allowedJson);
    if (!Array.isArray(allowed)) {
      throw new Error('Allowed values must be a JSON array');
    }
  } catch (e) {
    return {
      status: 'error',
      completion_percent: 0,
      error: `Invalid JSON for allowed list: ${e.message}`
    };
  }

  const validator = new SecureValidator();
  const isValid = validator.isInEnum(value, allowed);

  return {
    status: isValid ? 'success' : 'validation_failed',
    completion_percent: isValid ? 100 : 0,
    data: {
      value,
      valid: isValid,
      allowed
    },
    timestamp: new Date().toISOString()
  };
}

/**
 * Parse CLI options
 */
function parseOptions(args) {
  const options = {};
  for (let i = 1; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const [key, value] = args[i].substring(2).split('=');
      options[key] = value || 'true';
    }
  }
  return options;
}

/**
 * Print help text
 */
function printHelp() {
  console.log(`
Secure Validation CLI v12 (Task #12)

USAGE:
  validate <input> [options]     Validate single input
  batch <json-array> [options]   Validate batch of inputs
  email <email>                  Validate email address
  url <url>                      Validate URL
  number <value> [options]       Validate number
  enum <value> <json-array>      Validate against enum/allowlist

OPTIONS:
  --maxLength=N                  Maximum input length (default: 10000)
  --maxDepth=N                   Maximum nesting depth (default: 20)
  --sanitize=true|false          Sanitize output (default: true)
  --allowNull=true|false         Allow null values (default: true)
  --min=N                        Minimum value (for numbers)
  --max=N                        Maximum value (for numbers)

EXAMPLES:
  node secure_validator_cli.js validate "SELECT * FROM users"
  node secure_validator_cli.js email "test@example.com"
  node secure_validator_cli.js url "https://example.com"
  node secure_validator_cli.js number 42 --min=0 --max=100
  node secure_validator_cli.js enum "admin" '["user","admin","guest"]'
  node secure_validator_cli.js batch '["input1","input2"]'

JSON OUTPUT:
  All commands return JSON with: status, completion_percent, data, timestamp
  Status values: success, validation_failed, error, partial_failure
  `);
}

// Run CLI
main().catch(error => {
  console.log(JSON.stringify({
    status: 'error',
    completion_percent: 0,
    error: error.message
  }, null, 2));
  process.exit(1);
});
