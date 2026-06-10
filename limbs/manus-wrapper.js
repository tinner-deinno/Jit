/**
 * Generates a unique request identifier.
 * @returns {string} A request ID in the format 'req_<timestamp>_<random>'.
 */
function generateRequestId() {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  return `req_${timestamp}_${random}`;
}

/**
 * Creates a successful response wrapper.
 * @param {string} request_id - The request identifier.
 * @param {*} data - The response payload.
 * @returns {{ok: true, request_id: string, data: *}} A wrapped success response.
 */
function wrapOk(request_id, data) {
  return { ok: true, request_id, data };
}

/**
 * Creates an error response wrapper.
 * @param {string} request_id - The request identifier.
 * @param {string} code - A machine-readable error code.
 * @param {string} message - A human-readable error message.
 * @returns {{ok: false, request_id: string, error: {code: string, message: string}}} A wrapped error response.
 */
function wrapErr(request_id, code, message) {
  return { ok: false, request_id, error: { code, message } };
}

/**
 * Wraps an asynchronous (or synchronous) function with request ID injection,
 * logging, and automatic transformation of results/errors into the Manus response envelope.
 * 
 * The wrapped function receives the generated request ID as its first argument,
 * followed by any additional arguments passed to the wrapper.
 * 
 * @param {Function} fn - The function to wrap. Should have signature (requestId, ...args) and may return a value or a Promise.
 * @returns {Function} An async function that accepts the remaining arguments, injects a request ID, logs start/end/error,
 *                     and wraps the outcome using wrapOk / wrapErr.
 */
function withRequestId(fn) {
  return async function (...args) {
    const request_id = generateRequestId();
    console.log(`[${request_id}] start`);
    try {
      const result = await fn(request_id, ...args);
      console.log(`[${request_id}] end`);
      return wrapOk(request_id, result);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error(`[${request_id}] error`, errorMessage);
      const code = (err && err.code) || 'UNKNOWN';
      return wrapErr(request_id, code, errorMessage);
    }
  };
}

module.exports = { generateRequestId, wrapOk, wrapErr, withRequestId };
