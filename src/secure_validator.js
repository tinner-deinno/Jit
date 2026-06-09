/**
 * Secure Validation Function Suite
 * Provides safe input validation with sanitization and type checking
 *
 * Design Principles:
 * - Whitelist approach (reject by default)
 * - No code execution from user input
 * - Type-safe validation
 * - Detailed error reporting
 * - Input length limits to prevent DoS
 */

const crypto = require('crypto');

// Configuration constants
const VALIDATION_LIMITS = {
  MAX_STRING_LENGTH: 10000,
  MAX_EMAIL_LENGTH: 254,
  MAX_URL_LENGTH: 2048,
  MAX_OBJECT_DEPTH: 10,
  MAX_ARRAY_SIZE: 1000,
};

const UNSAFE_PATTERNS = {
  SQL_INJECTION: /('|(--|;))|(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER)\b)/gi,
  XSS_SCRIPT: /<script[^>]*>[\s\S]*?<\/script>/gi,
  XSS_EVENT: /on\w+\s*=\s*["'][^"']*["']/gi,
  COMMAND_INJECTION: /[;&|`$(){}[\]]/g,
  PATH_TRAVERSAL: /\.\.[\\\/]/g,
};

const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

const URL_REGEX = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i;

/**
 * Main validation function - validates input against specified rules
 * @param {*} input - Data to validate
 * @param {Object} rules - Validation rules
 * @param {string} rules.type - Expected type: string, number, boolean, email, url, array, object
 * @param {boolean} rules.required - Whether input must be present
 * @param {number} rules.minLength - Minimum string length
 * @param {number} rules.maxLength - Maximum string length
 * @param {number} rules.min - Minimum number value
 * @param {number} rules.max - Maximum number value
 * @param {Array} rules.enum - Allowed values
 * @param {boolean} rules.sanitize - Whether to sanitize dangerous patterns
 * @returns {Object} { valid: boolean, value: *, error: string|null }
 */
function validateInput(input, rules = {}) {
  try {
    // Check if required
    if (rules.required && (input === null || input === undefined || input === '')) {
      return { valid: false, error: 'Input is required' };
    }

    // Allow null/undefined if not required
    if (!rules.required && (input === null || input === undefined)) {
      return { valid: true, value: input };
    }

    const type = rules.type || typeof input;

    // Type validation
    if (type === 'string') {
      return validateString(input, rules);
    } else if (type === 'number') {
      return validateNumber(input, rules);
    } else if (type === 'boolean') {
      return validateBoolean(input, rules);
    } else if (type === 'email') {
      return validateEmail(input, rules);
    } else if (type === 'url') {
      return validateUrl(input, rules);
    } else if (type === 'array') {
      return validateArray(input, rules);
    } else if (type === 'object') {
      return validateObject(input, rules);
    }

    return { valid: true, value: input };
  } catch (error) {
    return { valid: false, error: `Validation error: ${error.message}` };
  }
}

/**
 * Validate string input
 */
function validateString(input, rules) {
  if (typeof input !== 'string') {
    return { valid: false, error: 'Expected string' };
  }

  // Check length limits
  const maxLength = rules.maxLength || VALIDATION_LIMITS.MAX_STRING_LENGTH;
  if (input.length > maxLength) {
    return { valid: false, error: `String exceeds maximum length of ${maxLength}` };
  }

  if (rules.minLength && input.length < rules.minLength) {
    return { valid: false, error: `String below minimum length of ${rules.minLength}` };
  }

  // Check enum values
  if (rules.enum && !rules.enum.includes(input)) {
    return { valid: false, error: `Value not in allowed list: ${rules.enum.join(', ')}` };
  }

  // Sanitize if requested
  let value = input;
  if (rules.sanitize) {
    value = sanitizeString(input);
    if (value !== input) {
      // Pattern was detected and sanitized
      if (!rules.allowDangerous) {
        return { valid: false, error: 'Input contains unsafe patterns' };
      }
    }
  }

  return { valid: true, value };
}

/**
 * Validate number input
 */
function validateNumber(input, rules) {
  const num = Number(input);

  if (isNaN(num) || typeof num !== 'number') {
    return { valid: false, error: 'Expected valid number' };
  }

  if (!isFinite(num)) {
    return { valid: false, error: 'Number must be finite' };
  }

  if (rules.min !== undefined && num < rules.min) {
    return { valid: false, error: `Number below minimum of ${rules.min}` };
  }

  if (rules.max !== undefined && num > rules.max) {
    return { valid: false, error: `Number exceeds maximum of ${rules.max}` };
  }

  if (rules.enum && !rules.enum.includes(num)) {
    return { valid: false, error: `Value not in allowed list` };
  }

  return { valid: true, value: num };
}

/**
 * Validate boolean input
 */
function validateBoolean(input, rules) {
  if (typeof input !== 'boolean') {
    // Try to coerce
    if (input === 'true' || input === 1) {
      return { valid: true, value: true };
    }
    if (input === 'false' || input === 0) {
      return { valid: true, value: false };
    }
    return { valid: false, error: 'Expected boolean' };
  }

  return { valid: true, value: input };
}

/**
 * Validate email address
 */
function validateEmail(input, rules) {
  if (typeof input !== 'string') {
    return { valid: false, error: 'Email must be string' };
  }

  if (input.length > VALIDATION_LIMITS.MAX_EMAIL_LENGTH) {
    return { valid: false, error: 'Email exceeds maximum length' };
  }

  if (!EMAIL_REGEX.test(input)) {
    return { valid: false, error: 'Invalid email format' };
  }

  return { valid: true, value: input.toLowerCase() };
}

/**
 * Validate URL
 */
function validateUrl(input, rules) {
  if (typeof input !== 'string') {
    return { valid: false, error: 'URL must be string' };
  }

  if (input.length > VALIDATION_LIMITS.MAX_URL_LENGTH) {
    return { valid: false, error: 'URL exceeds maximum length' };
  }

  if (!URL_REGEX.test(input)) {
    return { valid: false, error: 'Invalid URL format' };
  }

  try {
    new URL(input);
    return { valid: true, value: input };
  } catch {
    return { valid: false, error: 'URL parsing failed' };
  }
}

/**
 * Validate array input
 */
function validateArray(input, rules, depth = 0) {
  if (!Array.isArray(input)) {
    return { valid: false, error: 'Expected array' };
  }

  if (input.length > VALIDATION_LIMITS.MAX_ARRAY_SIZE) {
    return { valid: false, error: `Array exceeds maximum size of ${VALIDATION_LIMITS.MAX_ARRAY_SIZE}` };
  }

  if (depth > VALIDATION_LIMITS.MAX_OBJECT_DEPTH) {
    return { valid: false, error: 'Object nesting exceeds maximum depth' };
  }

  // Validate array items if schema provided
  if (rules.items) {
    const validatedItems = [];
    for (const item of input) {
      const result = validateInput(item, rules.items);
      if (!result.valid) {
        return { valid: false, error: `Array item validation failed: ${result.error}` };
      }
      validatedItems.push(result.value);
    }
    return { valid: true, value: validatedItems };
  }

  return { valid: true, value: input };
}

/**
 * Validate object input
 */
function validateObject(input, rules, depth = 0) {
  if (typeof input !== 'object' || input === null || Array.isArray(input)) {
    return { valid: false, error: 'Expected object' };
  }

  if (depth > VALIDATION_LIMITS.MAX_OBJECT_DEPTH) {
    return { valid: false, error: 'Object nesting exceeds maximum depth' };
  }

  // Validate object schema if provided
  if (rules.schema) {
    const validatedObj = {};

    for (const [key, schema] of Object.entries(rules.schema)) {
      const value = input[key];
      const result = validateInput(value, schema);

      if (!result.valid) {
        return {
          valid: false,
          error: `Object field '${key}' validation failed: ${result.error}`
        };
      }

      validatedObj[key] = result.value;
    }

    return { valid: true, value: validatedObj };
  }

  return { valid: true, value: input };
}

/**
 * Sanitize string by removing dangerous patterns
 */
function sanitizeString(str) {
  let sanitized = str;

  // Remove SQL injection patterns
  sanitized = sanitized.replace(UNSAFE_PATTERNS.SQL_INJECTION, '');

  // Remove XSS script tags
  sanitized = sanitized.replace(UNSAFE_PATTERNS.XSS_SCRIPT, '');

  // Remove XSS event handlers
  sanitized = sanitized.replace(UNSAFE_PATTERNS.XSS_EVENT, '');

  // HTML encode special characters
  sanitized = sanitized
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');

  return sanitized;
}

/**
 * Detect dangerous patterns in input
 */
function detectDangerousPatterns(input) {
  if (typeof input !== 'string') return [];

  const detectedPatterns = [];

  for (const [patternName, regex] of Object.entries(UNSAFE_PATTERNS)) {
    if (regex.test(input)) {
      detectedPatterns.push(patternName);
    }
  }

  return detectedPatterns;
}

/**
 * Hash sensitive data (one-way)
 */
function hashValue(value, algorithm = 'sha256') {
  const hash = crypto.createHash(algorithm);
  hash.update(String(value));
  return hash.digest('hex');
}

/**
 * Generate a secure random token
 */
function generateToken(length = 32) {
  return crypto.randomBytes(length).toString('hex');
}

module.exports = {
  validateInput,
  validateString,
  validateNumber,
  validateBoolean,
  validateEmail,
  validateUrl,
  validateArray,
  validateObject,
  sanitizeString,
  detectDangerousPatterns,
  hashValue,
  generateToken,
  VALIDATION_LIMITS,
  UNSAFE_PATTERNS,
};
