<!-- cc-team deliverable
 group: U (innomcp UI debug wave — central backend URL helper, fix broken fetches, hide test creds, VQA regression spec)
 member: U4 role=test model=deepseek/deepseek-v4-pro
 finish_reason: stop | tokens: {"prompt_tokens":384,"completion_tokens":1075,"total_tokens":1459,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":388,"image_tokens":0},"cache_creation_input_tokens":0} | 17s
 generated: 2026-06-12T08:59:26.266Z -->
import { test, expect } from "@playwright/test";

test.describe("VQA regression", () => {
  test.use({ viewport: { width: 1440, height: 900 } });

  test("no requests to dead backend port 3011", async ({ page }) => {
    test.setTimeout(30000);
    const requestUrls: string[] = [];
    page.on("request", (request) => {
      requestUrls.push(request.url());
    });
    await page.goto("http://localhost:3000/living-chat", {
      waitUntil: "domcontentloaded",
    });
    await page.waitForTimeout(5000);
    const badRequests: string[] = requestUrls.filter((url: string) =>
      url.includes("localhost:3011")
    );
    expect(badRequests.length).toBe(0);
  });

  test("no 404 API responses", async ({ page }) => {
    test.setTimeout(30000);
    const responseStatuses: { url: string; status: number }[] = [];
    page.on("response", (response) => {
      responseStatuses.push({ url: response.url(), status: response.status() });
    });
    await page.goto("http://localhost:3000/living-chat", {
      waitUntil: "domcontentloaded",
    });
    await page.waitForTimeout(5000);
    const api404s: { url: string; status: number }[] = responseStatuses.filter(
      (r: { url: string; status: number }) =>
        r.status === 404 && r.url.includes("/api/")
    );
    expect(api404s.length).toBe(0);
  });

  test("page has a title", async ({ page }) => {
    test.setTimeout(30000);
    await page.goto("http://localhost:3000/living-chat");
    const title: string = await page.title();
    expect(title.length).toBeGreaterThan(0);
  });

  test("no zero-size content panels", async ({ page }) => {
    test.setTimeout(30000);
    await page.goto("http://localhost:3000/living-chat");
    await page.waitForTimeout(5000);
    const zeroSizeCount: number = await page.evaluate(() => {
      const divs: NodeListOf<HTMLDivElement> =
        document.querySelectorAll("main div");
      let count: number = 0;
      divs.forEach((div: HTMLDivElement) => {
        const text: string = (div.textContent || "").trim();
        if (
          text.length > 0 &&
          div.offsetWidth === 0 &&
          div.offsetHeight === 0
        ) {
          count++;
        }
      });
      return count;
    });
    expect(zeroSizeCount).toBe(0);
  });

  test("login page hides test credentials in production", async ({ page }) => {
    test.setTimeout(30000);
    test.skip(process.env.VQA_PROD !== "1");
    await page.goto("http://localhost:3000/login");
    const bodyText: string = await page.evaluate(() => document.body.innerText);
    expect(bodyText).not.toContain("Test Credentials");
  });
});
