import { test, expect } from '../fixtures/authenticated';
import { SUPPORTED_SITES } from '~/chatbots';

const providerUrls: Record<string, string> = {
  ai_studio: 'https://aistudio.google.com/prompts/new_chat',
  kimi: 'https://kimi.com/',
  z_ai: 'https://chat.z.ai/',
};

for (const providerId of Object.keys(SUPPORTED_SITES)) {
  test.describe(`E2E Selector Validation for: ${providerId}`, () => {
    let selectors: Record<string, unknown>;

    try {
      // WHY: Playwright executes tests in a CommonJS context and we need a runtime-resolved path for selector modules.
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const module = require(`~/chatbots/${providerId.replace('_', '-')}`) as {
        SELECTORS?: Record<string, unknown>;
      };
      selectors = module.SELECTORS ?? {};
      if (!module.SELECTORS) {
        throw new Error(`'SELECTORS' constant not exported from ${providerId}.ts`);
      }
    } catch (error) {
      throw new Error(`Failed to load selectors for provider "${providerId}": ${error}`);
    }

    for (const selectorName in selectors) {
      const selectorValue = selectors[selectorName];
      if (typeof selectorValue === 'function') continue;

      test(`should find an actionable element for: ${selectorName}`, async ({ authenticatedPage }) => {
        const page = authenticatedPage;
        const url = providerUrls[providerId];
        if (!url) throw new Error(`No URL defined for provider "${providerId}"`);

        await page.goto(url);
        await page.waitForLoadState('domcontentloaded');

        const selectorArray = Array.isArray(selectorValue) ? selectorValue : [selectorValue];
        let foundElement = null;

        for (const selector of selectorArray) {
          const locator = page.locator(selector).first();
          if ((await locator.count()) > 0) {
            foundElement = locator;
            break;
          }
        }

        expect(foundElement, `No element found for selector key: ${selectorName}`).not.toBeNull();

        if (!foundElement) {
          throw new Error(`Element for "${selectorName}" is null`);
        }

        await expect(foundElement, `Element for "${selectorName}" is not visible`).toBeVisible();
        await expect(foundElement, `Element for "${selectorName}" is not enabled`).toBeEnabled();
      });
    }
  });
}

