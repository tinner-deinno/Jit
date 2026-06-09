/**
 * Secure Validation Function v8
 * High-performance input validation with multiple security layers
 * Task #8: Development implementation
 */

class SecureValidator {
  constructor(options = {}) {
    this.config = {
      maxLength: options.maxLength || 10000,
      maxDepth: options.maxDepth || 20,
      allowNull: options.allowNull !== false,
      sanitize: options.sanitize !== false,
      ...options
    };
    this.errors = [];
  }

  /**
   * Main validation entry point
   */
  validate(input) {
    this.errors = [];
    if (!input) return this.sanitize ? '' : input;
    
    // Length check
    if (input.length > this.config.maxLength) {
      this.errors.push(`Input exceeds max length of ${this.config.maxLength}`);
      return null;
    }

    // Security scan
    const securityCheck = this.scanSecurity(input);
    if (!securityCheck.safe) {
      this.errors.push(...securityCheck.violations);
      return null;
    }

    return this.sanitize ? this.sanitizeInput(input) : input;
  }

  /**
   * Fast security pattern detection
   */
  scanSecurity(input) {
    const violations = [];
    const patterns = {
      sqlInjection: /('|(\\x27))+(\s|%20)*(union|select|insert|update|delete|drop|create|alter)/gi,
      xss: /<script|on\w+=|javascript:|<iframe|eval\(|<\/?(style|link|base|meta|object|embed)/gi,
      commandInjection: /[;|&$`(){}[\]<>~^]|(\$\()/g,
      protoPollution: /(__proto__|constructor|prototype)/g
    };

    for (const [type, pattern] of Object.entries(patterns)) {
      if (pattern.test(input)) {
        violations.push(`Potential ${type} detected`);
        pattern.lastIndex = 0;
      }
    }

    return {
      safe: violations.length === 0,
      violations
    };
  }

  /**
   * Sanitize dangerous characters
   */
  sanitizeInput(input) {
    return input
      .replace(/[<>]/g, '')
      .replace(/[;|&$`]/g, '')
      .replace(/\\/g, '')
      .trim();
  }

  /**
   * Validate email format
   */
  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email) && email.length < 254;
  }

  /**
   * Validate URL
   */
  isValidUrl(url) {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Validate numeric input
   */
  validateNumber(value, min = -Infinity, max = Infinity) {
    const num = Number(value);
    if (isNaN(num)) {
      this.errors.push('Invalid number format');
      return false;
    }
    if (num < min || num > max) {
      this.errors.push(`Number out of range [${min}, ${max}]`);
      return false;
    }
    return true;
  }

  /**
   * Validate against allowed values
   */
  isInEnum(value, allowedValues) {
    return allowedValues.includes(value);
  }

  /**
   * Get validation errors
   */
  getErrors() {
    return this.errors;
  }

  /**
   * Check if validation passed
   */
  isValid() {
    return this.errors.length === 0;
  }
}

/**
 * Convenience function for quick validation
 */
function validate(input, options = {}) {
  const validator = new SecureValidator(options);
  const result = validator.validate(input);
  return {
    valid: validator.isValid(),
    data: result,
    errors: validator.getErrors()
  };
}

/**
 * Batch validator
 */
function validateBatch(inputs, options = {}) {
  const validator = new SecureValidator(options);
  return inputs.map(input => ({
    input,
    valid: !validator.validate(input) === null,
    errors: validator.getErrors()
  }));
}

module.exports = {
  SecureValidator,
  validate,
  validateBatch
};
