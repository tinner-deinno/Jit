<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: A09 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: refined_via_debug-mantra_loop | iterations: 2/10
 generated: 2026-06-13T00:00:00.000Z -->
import { test, expect } from '@playwright/test';

test.describe('Living Chat Offline Resilience', () => {
  test.use({ viewport: { width: 1440, height: 900 } });
  test.setTimeout(60000);

  async function navigateAndSkip(page) {
    await page.goto('/living-chat');
    // Using a more robust selector for the skip button if it's a common onboarding pattern
    const skipBtn = page.getByText('ข้าม');
    if (await skipBtn.isVisible()) {
      await skipBtn.click();
    }
  }

  test('should survive offline/online and keep chat input interactive', async ({ page }) => {
    await navigateAndSkip(page);
    const chatInput = page.getByRole('textbox').first();
    await expect(chatInput).toBeVisible({ timeout: 10000 });

    await page.context().setOffline(true);
    await expect(chatInput).toBeEnabled();
    
    await page.context().setOffline(false);
    await expect(chatInput).toBeEnabled();
    
    await chatInput.fill('Hello after reconnect');
    await expect(chatInput).toHaveValue('Hello after reconnect');
  });

  test('should handle multiple offline/online cycles without crashing', async ({ page }) => {
    await navigateAndSkip(page);
    const chatInput = page.getByRole('textbox').first();
    await expect(chatInput).toBeVisible({ timeout: 10000 });

    for (let i = 0; i < 5; i++) {
      await page.context().setOffline(true);
      await expect(chatInput).toBeEnabled();
      await page.context().setOffline(false);
      // Verify connectivity by checking if the input is still ready
      await expect(chatInput).toBeEnabled();
    }

    await chatInput.fill('cycle test');
    await expect(chatInput).toHaveValue('cycle test');
  });

  test('should allow typing while offline and remain functional after reconnect', async ({ page }) => {
    await navigateAndSkip(page);
    const chatInput = page.getByRole('textbox').first();
    await expect(chatInput).toBeVisible({ timeout: 10000 });

    await page.context().setOffline(true);
    await chatInput.fill('offline message');
    await expect(chatInput).toHaveValue('offline message');

    await page.context().setOffline(false);
    await chatInput.clear();
    await chatInput.fill('reconnected');
    await expect(chatInput).toHaveValue('reconnected');
  });

  test('should not display unhandled errors after offline/online', async ({ page }) => {
    const errors: Error[] = [];
    page.on('pageerror', (error) => errors.push(error));
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        // We ignore expected network errors when offline, 
        // but we'll track them if we want strictness.
        if (!msg.text().includes('net::ERR_INTERNET_DISCONNECTED')) {
          errors.push(new Error(msg.text()));
        }
      }
    });

    await navigateAndSkip(page);
    const chatInput = page.getByRole('textbox').first();
    await expect(chatInput).toBeVisible({ timeout: 10000 });

    await page.context().setOffline(true);
    await chatInput.fill('test error');
    await page.context().setOffline(false);

    expect(errors).toHaveLength(0);
  });
});
