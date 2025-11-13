import { test as base, Page, Cookie, BrowserContext } from '@playwright/test';
import * as fs from 'fs/promises';
import path from 'path';

const cookieFilePath = path.resolve(__dirname, '../cookies/all-cookies.json');

export async function loadAuthenticatedCookies(): Promise<Cookie[]> {
  let cookies: unknown;
  try {
    const content = await fs.readFile(cookieFilePath, 'utf-8');
    cookies = JSON.parse(content);
  } catch {
    throw new Error(
      `FATAL: Could not load cookies from ${cookieFilePath}. ` +
        `Ensure the file exists and is a valid JSON array.`
    );
  }

  return (cookies as Cookie[]).map((cookie: Record<string, unknown>) => {
    if (!cookie || typeof cookie !== 'object') {
      return cookie as Cookie;
    }

    const normalized: Record<string, unknown> = { ...cookie };
    const allowedSameSite = ['Strict', 'Lax', 'None'];
    const value = (normalized.sameSite as string | undefined)?.toLowerCase();

    if (value) {
      if (value === 'strict') {
        normalized.sameSite = 'Strict';
      } else if (value === 'lax') {
        normalized.sameSite = 'Lax';
      } else if (value === 'none') {
        normalized.sameSite = 'None';
      } else if (!allowedSameSite.includes(normalized.sameSite as string)) {
        delete normalized.sameSite;
      }
    }

    if (typeof normalized.partitionKey === 'object') {
      delete normalized.partitionKey;
    }

    return normalized as Cookie;
  });
}

export async function applyAuthenticatedCookies(context: BrowserContext): Promise<void> {
  const cookies = await loadAuthenticatedCookies();
  if (cookies.length === 0) {
    return;
  }

  await context.addCookies(cookies);
}

export const test = base.extend<{
  authenticatedPage: Page;
}>({
  authenticatedPage: async ({ browser }, use) => {
    const context = await browser.newContext();
    await applyAuthenticatedCookies(context);

    const page = await context.newPage();
    await use(page);

    await context.close();
  },
});

export { expect } from '@playwright/test';


