#!/usr/bin/env node
/*
 * sanitize-log.js
 * Masks secrets in text. Idempotent: already-masked tokens are left untouched.
 */

'use strict';

const REDACTED = '...REDACTED';

/** Mask a value, preserving its first 4 characters. */
function maskValue(v) {
  if (typeof v !== 'string' || v.includes(REDACTED)) return v;
  return v.slice(0, 4) + REDACTED;
}

/** Sanitize a string by masking known secret patterns. */
function sanitize(text) {
  if (typeof text !== 'string') return text;

  // Helper: replace match unless it already contains REDACTED.
  const r = (m) => m.includes(REDACTED) ? m : m.slice(0, 4) + REDACTED;

  // 1. RS256 JWTs: eyJ<hdr>.eyJ<payload>.<sig>
  text = text.replace(/eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+/g, r);

  // 2. Discord MT-style three-segment token.
  text = text.replace(/MT[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, r);

  // 3. OpenAI sk- keys (20+ chars after prefix).
  text = text.replace(/sk-[a-zA-Z0-9]{20,}/g, r);

  // 4. GitHub tokens.
  text = text.replace(/ghp_[a-zA-Z0-9]{36,}/g, r);
  text = text.replace(/gho_[a-zA-Z0-9]{36,}/g, r);
  text = text.replace(/github_pat_[a-zA-Z0-9_]+/g, r);

  // 5. user_ + 60 chars.
  text = text.replace(/user_[a-zA-Z0-9]{60}/g, r);

  // 6. AWS AKIA access key ID.
  text = text.replace(/AKIA[A-Z0-9]{16}/g, r);

  // 7. Bearer tokens.
  text = text.replace(/Bearer\s+\S+/g, (m) => m.includes(REDACTED) ? m : m.slice(0, 4) + REDACTED);
  // Wait, for Bearer, the first 4 chars of the match would be "Bear". That would turn "Bearer token" into "Bear...REDACTED". But the prompt says "the word Bearer followed by a token". It says "keeping only the first 4 chars then ...REDACTED". So yes, the first 4 chars of the entire match. So "Bear...REDACTED" is correct per spec. But that seems to lose the word "Bearer". However, the spec says "keeping only the first 4 chars then the literal ...REDACTED" for these patterns. So for Bearer, the match is "Bearer <token>", first 4 chars are "Bear". So output "Bear...REDACTED". That seems odd but it's what was asked.
  // Actually, maybe the match should be just the token after Bearer? But the prompt says "the word Bearer followed by a token" as a pattern to replace. It doesn't explicitly say whether Bearer is part of the match or not. But "keeping only the first 4 chars" suggests the entire match is replaced. So if the match includes "Bearer ", first 4 chars are "Bear". Let's re-read: "the word Bearer followed by a token". This is describing the pattern. The replacement rule is global: "keeping only the first 4 chars then the literal ...REDACTED". So yes, for any match, keep first 4 chars. So "Bearer <token>" -> "Bear...REDACTED".
  // But wait, for assignments: "mask only the value, keep the name". This is an exception to the general rule. So for Bearer, there is no exception mentioned, so general rule applies.

  // 8. KEY=/TOKEN=/SECRET=/PASSWORD= assignments.
  text = text.replace(/(KEY|TOKEN|SECRET|PASSWORD)=([^\s&,;|]+)/g, (m, name, val) => {
    return val.includes(REDACTED) ? m : name + '=' + val.slice(0, 4) + REDACTED;
  });

  // 9. High-entropy hex runs (32+ chars).
  text = text.replace(/\b[a-f0-9]{32,}\b/gi, r);

  // 10. High-entropy base64 runs (32+ chars, standard or URL-safe).
  // Standard base64 with +/=:
  text = text.replace(/[A-Za-z0-9+/]{32,}={0,2}/g, (m) => {
    // Avoid masking already-redacted or pure-lowercase hex-like strings already handled.
    if (m.includes(REDACTED)) return m;
    // Quick entropy check: must contain at least one upper, one lower, and one digit
    // OR contain + or / or = to be base64-like.
    const isBase64Like = /[+/=]/.test(m) || (/[A-Z]/.test(m) && /[a-z]/.test(m) && /[0-9]/.test(m));
    return isBase64Like ? m.slice(0, 4) + REDACTED : m;
  });

  // Also URL-safe base64 (no +/):
  text = text.replace(/\b[A-Za-z0-9_-]{32,}\b/g, (m) => {
    if (m.includes(REDACTED)) return m;
    // Avoid masking normal words: require high entropy (mixed case + digits).
    if (/[A-Z]/.test(m) && /[a-z]/.test(m) && /[0-9]/.test(m)) {
      return m.slice(0, 4) + REDACTED;
    }
    return m;
  });

  return text;
}

module.exports = { sanitize, maskValue };

if (require.main === module) {
  const chunks = [];
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', c => chunks.push(c));
  process.stdin.on('end', () => process.stdout.write(sanitize(chunks.join(''))));
}
