<!-- cc-team deliverable
 group: U (innomcp UI debug wave — central backend URL helper, fix broken fetches, hide test creds, VQA regression spec)
 member: U4 role=test model=moonshotai/Kimi-K2.6
 finish_reason: length | tokens: {"prompt_tokens":317,"completion_tokens":4000,"total_tokens":4317,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":0,"image_tokens":0},"cache_creation_input_tokens":0} | 69s
 generated: 2026-06-12T08:55:28.056Z -->
The user wants a complete Playwright spec file with specific requirements. Let me break down the requirements:

1. File: `tests/vqa-regression.spec.ts`
2. Framework: @playwright/test
3. App: Next.js at http://localhost:3000
4. Routes: /living-chat (chat UI), /login (login)
5. Tests inside `test.describe('VQA regression', ...)`:
   - (1) 'no requests to dead backend port 3011': Collect all request URLs during load of /living-chat (domcontentloaded + 5s settle), assert none contain 'localhost:3011'
   - (2) 'no 404 API responses': Collect responses during same load, assert no response with status 404 whose URL contains '/api/'
   - (3) 'page has a title': assert (await page.title()).length > 0
   - (4) 'no zero-size content panels': evaluate elements matching 'main div' that have non-empty textContent, assert none with offsetWidth === 0 and offsetHeight === 0
   - (5) 'login page hides test credentials in production': goto /login, read body text; skipped unless process.env.VQA_PROD === '1'; when run asserts body text does NOT contain 'Test Credentials'
6. Timeout: test.setTimeout(30000) per test or describe-level
7. Viewport: 1440x900 via test.use
8. Strict TypeScript
9. Output ONLY raw TypeScript file content, no markdown fences, no commentary

Let me construct the file carefully.

Structure:
```typescript
import { test, expect } from '@playwright/test';

test.describe('VQA regression', () => {
  test.use({
    viewport: { width: 1440, height: 900 },
    baseURL: 'http://localhost:3000',
  });

  test.setTimeout(30000);

  // Test 1 & 2 share the same load context? The prompt says "during the same load" for test 2 referring to test 1's load. But each test should be independent. However, the prompt says "collect responses during the same load". This could mean each test does its own load, or they share a page. But Playwright tests are isolated by default. I think each test should independently do the navigation and collection. Or maybe I should combine them? The prompt says "The spec must contain exactly these tests". So I need exactly 5 test() calls. But test 2 says "during the same load". This is ambiguous. 

Wait, "collect responses during the same load" — this likely means the same load as test 1. But in Playwright, each test gets a new page. To truly share the same load, I'd need to do the navigation in a beforeEach or similar. But the prompt says "exactly these tests". It doesn't say I can't have beforeEach. However, "collect all request URLs during load of /living-chat" for test 1 and "collect responses during the same load" for test 2.

Actually, looking closely: "during the same load" might just mean during the load of /living-chat (i.e., the same type of load scenario), not literally the same navigation event. But to be safe and accurate, I could do the navigation and collection within each test. However, if I want to be precise about "same load", I might need to use a shared page or do the setup in a way that both tests observe the same navigation. But Playwright's test isolation makes this tricky.

Alternative: Use `test.beforeEach` to navigate, but then how do I collect requests for both tests? I could attach listeners in beforeEach and store in a variable, but tests run sequentially and share the describe scope. However, Playwright runs tests in parallel by default in different worker processes, but within a file they run sequentially in the same worker. Actually, by default tests in the same file run sequentially in the same worker. So I could do:

```typescript
let requestUrls: string[] = [];
let responses: Response[] = [];

test.beforeEach(async ({ page }) => {
  // But this would run for all tests including login test.
});
```

But the login test doesn't need this. And test 3 and 4 also need to load /living-chat? Let's check:

Test 3: 'page has a title' — likely on /living-chat? Or just in general? The prompt doesn't specify the URL for test 3 and 4, but given the context, probably /living-chat. Actually, test 3 just says "page has a title" — it could be any page, but likely /living-chat since that's the main subject. Test 4 says "no zero-size content panels" — definitely needs to be on /living-chat.

Wait, test 1 and 2 explicitly mention load of /living-chat. Test 3 and 4 don't specify URL but in context they should probably also go to /living-chat. Test 5 goes to /login.

So maybe:
- Test 1: goto /living-chat, collect requests, assert no localhost:3011
- Test 2: goto /living-chat, collect responses, assert no 404 API
- Test 3: goto /living-chat, assert title length > 0
- Test 4: goto /living-chat, evaluate main divs, assert no zero size
- Test 5: goto /login, conditional skip, assert body text

But the prompt says for test 2: "collect responses during the same load". This is slightly problematic if each test is independent. I think the safest interpretation is that test 2 also performs the same load sequence (goto /living-chat, wait for domcontentloaded + 5s) and collects responses during that load. The phrase "same load" means "the same loading procedure as test 1". I'll implement each test with its own page.goto to /living-chat for tests 1-4.

Actually, to be more precise and avoid flakiness, I should use `Promise.all` with page.waitForEvent('request')? No, that's not scalable. Better to use `page.on('request', ...)` and `page.on('response', ...)`.

For test 1:
```typescript
test('no requests to dead backend port 3011', async ({ page }) => {
  const requestUrls: string[] = [];
  page.on('request', request => {
    requestUrls.push(request.url());
  });
  await page.goto('/living-chat');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(5000);
  
  const badRequests = requestUrls.filter(url => url.includes('localhost:3011'));
  expect(badRequests).toEqual([]);
});
```

For test 2:
```typescript
test('no 404 API responses', async ({ page }) => {
  const responses: { url: string; status: number }[] = [];
  page.on('response', response => {
    responses.push({ url: response.url(), status: response.status() });
  });
  await page.goto('/living-chat');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(5000);
  
  const badResponses = responses.filter(r => r.status === 404 && r.url.includes('/api/'));
  expect(badResponses).toEqual([]);
});
```

For test 3:
```typescript
test('page has a title', async ({ page }) => {
  await page.goto('/living-chat');
  const title = await page.title();
  expect(title.length).toBeGreaterThan(0);
});
```

For test 4:
```typescript
test('no zero-size content panels', async ({ page }) => {
  await page.goto('/living-chat');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(5000);
  
  const zeroSizeElements = await page.evaluate(() => {
    const elements = document.querySelectorAll('main div');
    const bad: string[] = [];
    elements.forEach(el => {
      if (el.textContent && el.textContent.trim().length > 0) {
        if (el.offsetWidth === 0 && el.offsetHeight === 0) {
          bad.push(el.outerHTML.slice(0, 200));
        }
      }
    });
    return bad;
  });
  
  expect(zeroSizeElements).toEqual([]);
});
```

Wait, the prompt says: "evaluate elements matching 'main div' that have non-empty textContent, assert none with offsetWidth === 0 and offsetHeight === 0". So I need to find elements matching selector 'main div', check if textContent is non-empty, then check offsetWidth/Height. The assertion is that none have both zero. So the evaluate should return the count or list of such elements, and we assert it's empty.

For test 5:
```typescript
test('login page hides test credentials in production', async ({ page }) => {
  test.skip(process.env.VQA_PROD !== '1', 'Skipping non-production environment');
  await page.goto('/login');
  const bodyText = await page.locator('body').innerText();
  expect(bodyText).not.toContain('Test Credentials');
});
```

Wait, the prompt says: "this test must be skipped (test.skip) unless process.env.VQA_PROD === '1'". In Playwright, `test.skip(condition, description)` is used at the test level. But inside the test function, we can also use `test.skip()`. However, the prompt specifically says "test.skip". Usually it's done as:
```typescript
test('login page hides test credentials in production', async ({ page }) => {
  test.skip(process.env.VQA_PROD !== '1', 'Skipped outside production');
  // ...
});
```
This is valid in Playwright. The `test` parameter in the callback has a `skip` method. Actually, in Playwright, the first argument to the test function is an object with `page`, etc., and the test object itself has `skip`? No, in Playwright you do:
```typescript
test('name', async ({ page }, testInfo) => {
  test.skip(condition, 'reason');
});
```
Wait, actually `test.skip` inside the test body is not standard. The standard way is:
- `test.skip(condition, description)` at the top level? No, that's `test.skip(title, body)`.
- Inside a test: `test.skip()` is not a thing. But you can do `testInfo.skip()`? Let me check.

Actually, in Playwright, you can do:
```typescript
test('foo', async ({ page }, testInfo) => {
  testInfo.skip();
});
```
But the prompt explicitly says "test.skip". There is also a `test.skip()` call that can be made inside the test callback? Let me verify.

Looking at Playwright docs: You can call `test.skip()` inside a test function? Actually, no. The `test` object exported by @playwright/test has methods like `test.skip(title, body)`, `test.only`, etc. But inside a test, you can use `testInfo.skip()`. However, there is a pattern where you can do:

```typescript
test('foo', async ({ page }) => {
  // ...
});
```

And to skip conditionally at runtime, you use:
```typescript
test('foo', async ({ page }, testInfo) => {
  testInfo.skip(condition, 'reason');
});
```

But the prompt says "test.skip". Maybe they mean the `test.skip()` method on the test info object? Or maybe they mean using `test.skip` as a decorator before the test? Like:

```typescript
test.skip(({ env }) => env.VQA_PROD !== '1', 'login page hides test credentials in production');
```

Wait, Playwright supports:
```typescript
test.skip(condition, description);
```
where condition is a function that receives fixtures, and it applies to all subsequent tests in the same scope. But the prompt says "this test must be skipped (test.skip) unless process.env.VQA_PROD === '1'". 

Actually, there is a form:
```typescript
test('login page hides test credentials in production', async ({ page }) => {
  test.skip(process.env.VQA_PROD !== '1', 'Skipped outside production');
  // ...
});
```

Wait, I think I'm confusing this with other frameworks. In Playwright, can you call `test.skip` inside the test body? Let me think. The `test` function object has a `skip` method. When you write `test('name', fn)`, `test` is a function with properties. Inside the test function, `test` is not in scope unless imported. But if you import `test`, you can call `test.skip()`? No, `test.skip(title, body)` defines a skipped test. 

Actually, looking at Playwright's type definitions, inside the test function you get `(fixtures, testInfo)`. `testInfo` has `skip(condition?: boolean, description?: string): void`. So it should be `testInfo.skip()`.

But the prompt explicitly says "test.skip". Maybe they want:
```typescript
test.skip(process.env.VQA_PROD !== '1', 'login page hides test credentials in production');
```
But that would skip all subsequent tests in the describe block, which is not what we want.

Another option: use a conditional `test` call:
```typescript
(process.env.VQA_PROD === '1' ? test : test.skip)('login page hides test credentials in production', async ({ page }) => { ... });
```

But the prompt says "this test must be skipped (test.skip) unless...". The `test.skip` method is used to declare a test that is always skipped. But there's also the runtime skip.

Actually, I recall now: In Playwright, you can do:
```typescript
test('foo', async ({ page }) => {
  // ...
});
```

And to skip based on a condition at runtime, you can use:
```typescript
test('foo', async ({ page }, testInfo) => {
  testInfo.skip(process.env.VQA_PROD !== '1', 'reason');
});
```

But the prompt specifically mentions `test.skip`. Maybe they accept `testInfo.skip`? No, they explicitly wrote "test.skip".

Wait, there is another pattern in Playwright:
```typescript
test('login page hides test credentials in production', async ({ page }) => {
  test.skip(process.env.VQA_PROD !== '1', 'Skipped outside production');
  // ...
});
```

Is this valid? Let me check the Playwright types mentally. The `@playwright/test` exports a `test` object. The `test` object is callable. It also has properties like `skip`, `only`, `fail`, etc. These are used as:
- `test.skip(title, body)` - define a skipped test
- `test.only(title, body)` - define an only test

But inside a test function, if you have access to the imported `test`, calling `test.skip()` would try to define a new test, not skip the current one. So that can't be right.

However, there is a `test.skip(conditionFn, reason)` that can be called in a describe block to skip all tests in that block conditionally. But again, that's not per-test.

Actually, I think the user might be referring to the `test.skip()` method available on the `test` object inside the test callback? No, that doesn't exist.

Wait, looking at the Playwright documentation: "You can skip a test conditionally using testInfo.skip()". But the prompt says "test.skip". Maybe they mean the `test.skip` fixture annotation? Or maybe they just want the string "test.skip" to appear in the code, meaning `testInfo.skip` is not what they want.

Let me reconsider. There is a way to do:
```typescript
const isProd = process.env.VQA_PROD === '1';

test('login page hides test credentials in production', async ({ page }) => {
  if (!isProd) {
    test.skip();
  }
  // ...
});
```

But `test.skip()` inside a test function - would that work? In some frameworks like Vitest, `test.skip` inside a test doesn't make sense. But in Playwright, I don't think `test` inside the test body refers to the test runner.

Actually, I just remembered: In Playwright, the first argument to the test function is an object containing fixtures. The second argument is `testInfo`. There is no `test` fixture. So `test.skip` inside the test body would refer to the imported `test` if you didn't shadow it. But calling `test.skip()` there would be a type error because it expects a title and body.

Unless... Playwright has a `test.skip()` method that when called inside a test body, skips the current test? Let me check my knowledge base. I think there might be a `test.skip(condition, description)` that works as a "step" inside the test? No.

Actually, looking at the Playwright Test API, there is `test.step`, but not `test.skip` inside a test.

Given the strict requirement, I think the best approach is to use `testInfo.skip()` but the user explicitly said `test.skip`. Another interpretation: they want `test.skip` used as a function call before the test definition, but scoped to the test. Like:

```typescript
test.describe('VQA regression', () => {
  if (process.env.VQA_PROD !== '1') {
    test.skip('login page hides test credentials in production', async () => {});
  } else {
    test('login page hides test credentials in production', async ({ page }) => { ... });
  }
});
```

But that's ugly and not standard.

Another approach: use `test.fixme` or conditional test declaration:
```typescript
const testOrSkip = process.env.VQA_PROD === '1' ? test : test.skip;

testOrSkip('login page hides test credentials in production', async ({ page }) => {
  // ...
});
```

This uses `test.skip` exactly as the user requested. This is a common pattern and valid TypeScript. The `test.skip` method creates a test that is skipped (not run). So if `VQA_PROD !== '1'`, we use `test.skip` which will mark the test as skipped. If it is '1', we use `test`.

This satisfies "this test must be skipped (test.skip) unless process.env.VQA_PROD === '1'". So:

```typescript
const runLoginTest = process.env.VQA_PROD === '1';
(runLoginTest ? test : test.skip)('login page hides test credentials in production', async ({ page }) => {
  await page.goto('/login');
  const bodyText = await page.locator('body').innerText();
  expect(bodyText).not.toContain('Test Credentials');
});
```

This is clean and uses `test.skip` explicitly. I think this is the best interpretation.

Now, for the timeout: `test.setTimeout(30000)` can
