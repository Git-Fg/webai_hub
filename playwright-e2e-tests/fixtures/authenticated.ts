import { test as base, Page } from '@playwright/test';
import * as fs from 'fs/promises';
import path from 'path';

export const test = base.extend<{
  authenticatedPage: Page;
}>({
  authenticatedPage: async ({ browser }, use) => {
    const cookieFilePath = path.join(
      process.cwd(),
      'playwright-e2e-tests/cookies/all-cookies.json'
    );

    let cookies;
    try {
      const content = await fs.readFile(cookieFilePath, 'utf-8');
      cookies = JSON.parse(content);
    } catch (error) {
      const details = error instanceof Error ? error.message : String(error);
      throw new Error(
        `FATAL: Could not load cookies from ${cookieFilePath}. ` +
          `Ensure the file exists and is a valid JSON array. Original error: ${details}`
      );
    }

    const context = await browser.newContext();
    await context.addCookies(cookies);

    const page = await context.newPage();
    await use(page);

    await context.close();
  },
});

export { expect } from '@playwright/test';

