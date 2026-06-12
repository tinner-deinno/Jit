<!-- cc-team deliverable
 group: SEC (Secrets overhaul tooling + docs (gitleaks, hooks, CI, sanitizer, playbook, README, hardened compose))
 member: S4 role=dev model=moonshotai/Kimi-K2.6
 finish_reason: length | tokens: {"prompt_tokens":244,"completion_tokens":7000,"total_tokens":7244,"prompt_tokens_details":{"cached_tokens":3,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":0,"image_tokens":0},"cache_creation_input_tokens":0} | 87s
 generated: 2026-06-12T19:16:37.471Z -->
The user wants a Node.js CommonJS utility script with specific requirements. Let me break down the requirements:

1. Output ONLY raw JavaScript (no markdown fences)
2. Start with node shebang line then a block comment
3. File: scripts/sanitize-log.js
4. Zero-dependency Node.js CommonJS utility
5. Use module.exports to export:
   - sanitize(text) - main function
   - maskValue(v) - helper function
6. Patterns to mask (keeping only first 4 chars then ...REDACTED):
   - sk- keys (20+ chars)
   - ghp_/gho_/github_pat_ tokens
   - user_ + 60 chars
   - RS256 JWT (eyJ...dot eyJ...dot rest)
   - AKIA + 16
   - Discord MT-style three-segment token
   - Bearer followed by a token
   - KEY=/TOKEN=/SECRET=/PASSWORD= assignment (mask only value, keep name)
   - 32+ char hex or base64 high-entropy runs
7. Idempotent: re-running on already-masked text must not double-mask
8. When run directly (require.main === module): read all stdin, write sanitize(stdin) to stdout
9. Use strict mode, comment well
10. Under 130 lines

Let me think about the regex patterns and idempotency.

Idempotency means if text already contains "...REDACTED", we shouldn't match it again or we need to ensure our regex doesn't match the masked output. The masked output format is "first4chars...REDACTED". So if we have something like "sk-ab...REDACTED", we need to make sure:
- The hex/base64 pattern doesn't match "...REDACTED" (it has dots, not hex/base64 chars)
- The sk- pattern requires 20+ chars after sk-, but "...REDACTED" is only 11 chars, so it won't match sk- requirement
- Bearer pattern: "Bearer ...REDACTED" - the token part would be "...REDACTED" which starts with dots, not alphanumeric. If Bearer requires a token, we should ensure the token doesn't start with "." or we exclude already masked.
- For KEY= etc: the value would be "...REDACTED" which starts with dots. If we require the value to be at least some chars and not start with dots, we're safe.

Actually, the safest approach for idempotency is to ensure none of our patterns match strings that contain "...REDACTED". But since the masked output is exactly 4 chars + "...REDACTED", and most patterns require specific prefixes or lengths, they likely won't match the masked output anyway.

Let me design the regexes:

1. sk- keys: `sk-[a-zA-Z0-9_-]{20,}` or similar. Masked would be `sk-a...REDACTED` - wait, the requirement says "keeping only the first 4 chars then the literal ...REDACTED". So for `sk-abcdefghijklmnopqrstuvwxyz`, it becomes `sk-a...REDACTED`? No, "first 4 chars" means the first 4 characters of the match. So `sk-ab` is 4 chars? Wait: `sk-` is 3 chars. If the match is `sk-xxxxxxxxxxxxxxxxxxxx`, first 4 chars are `sk-x`, then `...REDACTED`. That seems odd but that's what was asked.

Wait, let me re-read: "keeping only the first 4 chars then the literal ...REDACTED". So yes, for any match, we keep the first 4 characters of the matched string and append `...REDACTED`.

But for idempotency, if we have `sk-a...REDACTED`, and we run the sk- pattern again:
- `sk-a...REDACTED` - after `sk-` we have `a...REDACTED`. That's 3 (a..) + 8 = 11 chars? Let's count: `a...REDACTED` is 1 + 3 + 8 = 12 chars. So total length after sk- is 12, which is less than 20. So it won't match the sk- pattern (requires 20+). Good.

For hex/base64 32+ chars: `...REDACTED` contains dots and uppercase. Dots are not hex or base64 (base64 can include +, /, =, alphanumeric). So `...REDACTED` won't match a 32+ hex/base64 run because of the dots. Good.

For JWT: `eyJ...REDACTED` - wait, JWT pattern is specific: `eyJ` followed by base64, dot, `eyJ` followed by base64, dot, rest. If masked, it would be `eyJh...REDACTED` (first 4 chars of the whole match). The JWT regex looks for `eyJ` which is 3 chars. If the masked output starts with `eyJ`... wait, the first 4 chars of a JWT starting with `eyJ.` would be `eyJ.`. Then `...REDACTED`. So `eyJ....REDACTED`. The JWT regex might try to match `eyJ` again? Let's see: `eyJ....REDACTED` - does it contain `eyJ.` then `eyJ.` then rest? No, it has `eyJ.` then `..REDACTED`. So it won't match the JWT pattern. Good.

For Bearer: `Bearer ...REDACTED` - the token starts with `.`, which is unlikely to match a normal token pattern. We can define token as non-space chars excluding those starting with `.` if we want to be safe, or just rely on length/pattern.

For KEY= etc: `KEY=...REDACTED` - the value is `...REDACTED`. If we run the pattern again, it would match `KEY=...REDACTED`. But does it? The value part `...REDACTED` starts with dots. If we make the value matcher require at least one non-dot alphanumeric char or just not start with `.`, we avoid it. But actually, if someone had `KEY=...REDACTED`, the regex would capture `...REDACTED` as value. Then maskValue would produce `...R...REDACTED`? Wait, maskValue keeps first 4 chars of the value. So `...R` + `...REDACTED` = `...R...REDACTED`. That's double masking! We need to prevent this.

So for idempotency, we should ensure that when we match values for KEY= etc, we don't match values that already end with `...REDACTED` or contain it. Or more simply, we can check if the value already contains `...REDACTED` and skip it. But since we need to do this with regex replacement, it's tricky.

Alternative: We can make the regex not match things that are already masked. For example, for the assignment pattern, we can use a negative lookahead: the value should not contain `...REDACTED`. Or we can match only values that don't start with `.` or contain `REDACTED`.

Actually, the cleanest idempotency approach: In the replacement function, check if the match already ends with `...REDACTED` or contains it. If so, return the match unchanged.

Wait, but if we have `KEY=secret`, we mask to `KEY=secr...REDACTED`. If we run again, the regex matches `KEY=secr...REDACTED`. The replacement function gets the value `secr...REDACTED`. We can check: if the value (or the entire match) already contains `...REDACTED`, return the match unchanged.

Yes! That's a robust idempotency strategy. In every replacement function, we check if the input match already contains `...REDACTED`. If yes, return it as-is.

But wait, what about overlapping patterns? For example, a JWT might contain a segment that looks like a 32+ char hex run. If we apply hex run regex after JWT, we might mask part of the JWT's signature if it's already masked. But if the JWT is already masked to `eyJh...REDACTED`, the signature part is gone. If we process a raw JWT, we want to mask the whole JWT first, or ensure our regex order prevents partial masking.

Actually, the order of regex application matters. We should apply more specific patterns first, then general ones. But if a JWT is already masked, the general hex/base64 pattern might match the `REDACTED` part? No, because `REDACTED` is uppercase letters, but it's only 8 chars, not 32+. So no issue.

What about a long hex string that is part of a larger context? We want to mask 32+ char hex/base64 runs. If we have `password=abcdef...` (32 hex chars), the assignment pattern should catch it first? Or the hex run will catch it. Either way, it gets masked. But if it's already masked by assignment pattern to `pass...REDACTED`, then the hex run regex might try to match `REDACTED`? No, too short.

So the idempotency check in replacement functions is the key.

Let me draft the code structure:

```javascript
#!/usr/bin/env node
/*
 * sanitize-log.js
 * Masks secrets in text streams. Idempotent: safe to run multiple times.
 */

'use strict';

const REDACTED = '...REDACTED';

function maskValue(v) {
  if (typeof v !== 'string') return v;
  if (v.includes(REDACTED)) return v;
  return v.slice(0, 4) + REDACTED;
}

function sanitize(text) {
  if (typeof text !== 'string') return text;
  
  // Order: specific tokens first, then general high-entropy runs.
  
  // 1. Discord MT-style three-segment token: base64.base64.base64 (roughly)
  // Actually Discord tokens are typically: [base64].[base64].[base64] or specifically MT style?
  // Discord MT-style: three segments separated by dots. Let's assume alphanumeric/+/=/_/- segments.
  // Actually Discord tokens: e.g., MTEyMjMzNDQ1NTY2Nzc4ODk5.aAbBcC.dEfGhIjKlMnOpQrStUvWxYz
  // MT style starts with MT. Let's do: /[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{20,}/?
  // The prompt says "Discord MT-style three-segment token". MT tokens start with MT. So: /MT[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/
  // But to avoid matching already masked, we check in replacer.
  
  // 2. RS256 JWT: eyJ...dot eyJ...dot rest
  // JWT pattern: eyJ[base64chars]+\.eyJ[base64chars]+\.[base64chars]+
  // base64chars = [A-Za-z0-9_-]+ (URL-safe base64)
  
  // 3. sk- keys (20+ chars): /sk-[a-zA-Z0-9]{20,}/
  
  // 4. GitHub tokens: ghp_[a-zA-Z0-9]{36}, gho_[a-zA-Z0-9]{36}, github_pat_[a-zA-Z0-9_]+
  
  // 5. user_ + 60 chars: /user_[a-zA-Z0-9]{60}/
  
  // 6. AKIA + 16: /AKIA[A-Z0-9]{16}/
  
  // 7. Bearer token: /Bearer\s+[A-Za-z0-9_\-./]+/ (but need to be careful not to mask already masked)
  
  // 8. KEY=/TOKEN=/SECRET=/PASSWORD= assignment: /(KEY|TOKEN|SECRET|PASSWORD)=([^\s&;|"'<>{}[\]]+)/
  // Actually values could be quoted. Let's handle unquoted values first. Or handle values until whitespace or comma.
  // Prompt says "any KEY=/TOKEN=/SECRET=/PASSWORD= assignment (mask only the value, keep the name)".
  // Let's match the name, equals sign, and value. Value: non-whitespace chars? Or quoted?
  // Let's do: /(KEY|TOKEN|SECRET|PASSWORD)=([^\s,;|&"'<>{}[\]]+)/i ? But case sensitive? Usually uppercase.
  // The prompt says KEY=/TOKEN=/SECRET=/PASSWORD=, so exact case. But maybe we should be case-insensitive? Let's stick to exact as written to be safe, or maybe include common variants. The prompt says "any KEY=/TOKEN=/SECRET=/PASSWORD= assignment", so exact names.
  
  // 9. 32+ char hex or base64 high-entropy runs.
  // Hex: /[a-f0-9]{32,}/i
  // Base64: /[A-Za-z0-9+/]{32,}={0,2}/ but need to avoid matching normal words.
  // High-entropy: maybe require mixed case or no spaces. Let's do separate hex and base64.
  // But base64 can match normal text. We can require at least one digit and one uppercase and one lowercase? Or just match long alphanumeric strings that look random.
  // Let's do: /[a-f0-9]{32,}/gi for hex.
  // For base64: /[A-Za-z0-9+/]{32,}={0,2}/ but this might match URLs. Let's restrict to strings that look like tokens: maybe [A-Za-z0-9_-]{32,} for URL-safe base64, or [A-Za-z0-9+/]{32,}={0,2}.
  // Actually the prompt says "32+ char hex or base64 high-entropy runs". So we can do:
  // hex: \b[a-f0-9]{32,}\b
  // base64: \b[A-Za-z0-9+/]{32,}={0,2}\b
  // But \b might not work well with + and /. Let's use lookarounds or just match the chars.
  // To avoid double masking, we check for REDACTED.
  
  // Let's think about the replacement strategy. We can chain .replace() calls.
  
  // Important: For idempotency, each replacer should check if the full match already contains REDACTED.
  
  // Let's define a helper replacer:
  const redact = (m) => m.includes(REDACTED) ? m : m.slice(0, 4) + REDACTED;
  
  // But for assignments, we need to keep the name part.
  // const redactAssign = (m, name, val) => val.includes(REDACTED) ? m : name + '=' + maskValue(val);
  
  // Let's write the regexes carefully.
  
  // JWT: starts with eyJ, then base64url chars, dot, eyJ, base64url chars, dot, base64url chars.
  // Actually a JWT has three parts: header.payload.signature. For RS256, header typically has alg: RS256. The prompt specifically says "RS256 JWT (eyJ...dot eyJ...dot rest)". So it wants the pattern where header starts with eyJ (base64 of {"alg":"RS256"...}), payload starts with eyJ (maybe not always, but the prompt says eyJ...dot eyJ...dot rest). So the regex is: eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*
  // But we need to ensure it's long enough to be a real JWT. Let's just match the pattern.
  
  // Discord MT: three segments. MT\w+\.\w+\.\w+ but more specifically, let's use [A-Za-z0-9_-]+ for each segment. And MT at start.
  // Actually Discord MT tokens are exactly: MT followed by base64, dot, base64, dot, base64. Let's do: /MT[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g
  
  // sk-: /sk-[a-zA-Z0-9]{20,}/g (OpenAI keys are sk- followed by 48 chars usually). Let's include underscore and hyphen? OpenAI keys are alphanumeric. Let's do \w which includes underscore. But hyphen? No. Let's do [a-zA-Z0-9]{20,}.
  
  // GitHub: ghp_[a-zA-Z0-9]{36,}, gho_[a-zA-Z0-9]{36,}, github_pat_[a-zA-Z0-9_]+
  
  // user_ + 60: /user_[a-zA-Z0-9]{60}/g
  
  // AKIA: /AKIA[A-Z0-9]{16}/g (AWS access key ID)
  
  // Bearer: /Bearer\s+[^\s]+/g. But we need to ensure the token is at least some length? Let's say 8+. /Bearer\s+\S{8,}/g. But what if already masked? "Bearer ...REDACTED" - the token is "...REDACTED" which starts with dots. If we require the token to not start with dot, or just rely on the idempotency check. Let's use /Bearer\s+(\S+)/g and in replacer check.
  
  // KEY= etc: /(KEY|TOKEN|SECRET|PASSWORD)=([^\s&;|"'<>{}[\]]+)/g. Actually values might be quoted. Let's handle both quoted and unquoted.
  // Unquoted: value until whitespace or common delimiter.
  // Quoted: ="value" or ='value'.
  // Let's do: /(KEY|TOKEN|SECRET|PASSWORD)=(".*?"|'.*?'|[^\s,;]+)/g
  // But non-greedy might be slow. Let's keep it simple: unquoted non-whitespace is fine for logs.
  // Actually in logs, values might be URL-encoded or just strings. Let's do: /(KEY|TOKEN|SECRET|PASSWORD)=([^\s]+)/g
  // But if the log line is `KEY=abc SECRET=def`, then `[^\s]+` captures `abc` and `def` correctly.
  // However, if it's `KEY=abc,other=thing`, it captures `abc,other=thing`. That's bad.
  // Let's use: /(KEY|TOKEN|SECRET|PASSWORD)=([^\s&,;|]+)/g. Still not perfect but okay.
  // Or better: match until whitespace. So `([^\s]+)` and then in the replacement we don't consume following text. Actually regex will match the shortest? No, it matches the longest possible. So if there are multiple assignments, it might overconsume.
  // Let's use: /(KEY|TOKEN|SECRET|PASSWORD)=([^\s&,;|]+)/g. This stops at comma, ampersand, semicolon, pipe.
  
  // Wait, the prompt says "mask only the value, keep the name". So we need to replace the value part.
  
  // Hex: /[a-f0-9]{32,}/gi. But this could match inside already masked `...REDACTED`? No, `REDACTED` has letters not in a-f0-9 except E D A. But `REDACTED` is 8 chars. 32+ hex won't match it. However, it could match a long hex string inside a JWT before we mask the JWT. So order matters: JWT first, then hex.
  
  // Base64: /[A-Za-z0-9+/]{32,}={0,2}/g. But this might match normal text like a long sentence without spaces? Unlikely in logs. But to be safe, we can require it to be bounded by non-base64 or string boundaries. However, in code, we can just apply it and accept it might mask long random strings. But we should avoid masking the `REDACTED` part? `REDACTED` is only 8 chars. So no issue.
  
  // Actually, for base64, we should also include URL-safe base64: [A-Za-z0-9_-]{32,}. But this will match many normal words. So maybe we should stick to standard base64 with +/= or require high entropy (mixed case + digits). But the prompt specifically says "32+ char hex or base64 high-entropy runs". So maybe we can combine them: match 32+ chars that are hex-like or base64-like, but require that they contain at least one digit and one letter, and for base64, maybe at least one uppercase and one lowercase? That would reduce false positives.
  
  // Let's define high-entropy as: at least one uppercase, one lowercase, one digit for base64/alphanumeric runs. For hex, just 32+ hex chars.
  // But checking entropy in regex is hard. We can do it in the replacer function!
  // For the general high-entropy run, we can match [a-z0-9]{32,} (hex) and [a-zA-Z0-9+/=_-]{32,} (base64), then in the replacer, check if it looks high-entropy (contains both upper and lower, or is hex). But the prompt says "hex or base64 high-entropy runs". So we can just match them and mask. If it's already masked, we skip.
  
  // Let's keep it simple and match:
  // Hex: \b[a-f0-9]{32,}\b (case insensitive)
  // Base64: \b[A-Za-z0-9+/]{32,}={0,2}\b or \b[A-Za-z0-9_-]{32,}\b
  // But \b with +/ is tricky. Let's avoid \b and use lookarounds or just match the string.
  // Actually, we can use: /(?:[a-f0-9]{32,}|[A-Za-z0-9+/]{32,}={0,2})/gi
  // But this might match substrings inside larger tokens that we already masked? No, because if we mask a JWT, it becomes `eyJh...REDACTED`. The `REDACTED` part is only 8 chars. The `eyJh` is 4 chars. So no 32+ char match there.
  
  // However, if we have a long base64 string that hasn't been masked, we want to mask it. But if it's inside a URL like `https://example.com/path/to/thing`, the path segments are usually not 32+ chars. But query params might be. That's okay.
  
  // Let's think about line count. Under 130 lines. We need to be concise but well-commented.
  
  // Let's draft the code:
  
  ```javascript
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
  ```
  
  Let me count lines. This looks like around 80-90 lines. Good.
  
  But I need to double-check the requirements:
  - "sk- keys (20+ chars)" - I used `sk-[a-zA-Z0-9]{20,}`. Good.
  - "ghp_/gho_/github_pat_ tokens" - I used separate regexes. Good.
  - "user_ + 60 chars" - `user_[a-zA-Z0-9]{60}`. Good.
  - "RS256 JWT (eyJ...dot eyJ...dot rest)" - `eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+`. Good.
  - "AKIA + 16" - `AKIA[A-Z0-9]{16}`. Good.
  - "Discord MT-style three-segment token" - `MT[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`. Good.
  - "the word Bearer followed by a token" - `Bearer\s+\S+`. Good.
  - "any KEY=/TOKEN=/SECRET=/PASSWORD= assignment (mask only the value, keep the name)" - Done.
  - "32+ char hex or base64 high-entropy runs" - Done.
  - "plus 32+ char hex or base64 high-entropy runs" - I have both.
  - "idempotent" - The `r` helper and explicit checks handle this.
  - "Under 130 lines" - Yes.
  - "comment well" - I have some comments but could add a few more.
  - "starting with the node shebang line then a block comment" - Yes.
  - "Use strict mode" - Yes.
  - "read all of stdin and write sanitize(stdin) to stdout so it works as a pipe filter" - Yes.
  - "export a function sanitize(text)" and "Also export maskValue(v)" - Yes.
  
  Let me refine the entropy checks to be more robust and concise.
  
  For base64, I have two regexes. Maybe I can combine them. But having two is fine.
  
  Wait, the prompt says "32+ char hex or base64 high-entropy runs". The word "runs" suggests contiguous characters. My regexes do that.
  
  One issue: The `r` helper uses `m.slice(0, 4) + REDACTED`. But for the assignment pattern, I
