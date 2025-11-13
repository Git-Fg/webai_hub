import { test, expect } from '../fixtures/authenticated';
import { SUPPORTED_SITES } from '~/chatbots';

const providerUrls: Record<string, string> = {
  ai_studio: 'https://aistudio.google.com/prompts/new_chat',
  kimi: 'https://kimi.com/',
  z_ai: 'https://chat.z.ai/',
};

for (const providerId of Object.keys(SUPPORTED_SITES)) {
  test.describe(`E2E Selector Validation for: ${providerId}`, () => {
    let selectors: Record<string, unknown> = {};

    test.beforeAll(async () => {
      try {
        const module = await import(`~/chatbots/${providerId.replace('_', '-')}`);
        const exported = (module as { SELECTORS?: Record<string, unknown> }).SELECTORS;
        if (!exported) {
          throw new Error(`'SELECTORS' constant not exported from ${providerId}.ts`);
        }
        selectors = exported;
      } catch (error) {
        throw new Error(
          `Failed to load selectors for provider "${providerId}": ${error instanceof Error ? error.message : String(error)}`
        );
      }
    });

    for (const selectorName of Object.keys(selectors)) {
      const selectorValue = selectors[selectorName];

      if (typeof selectorValue === 'function') {
        continue;
      }

      test(`should find an actionable element for: ${selectorName}`, async ({ authenticatedPage }) => {
        const page = authenticatedPage;
        const url = providerUrls[providerId];
        if (!url) {
          throw new Error(`No URL defined for provider "${providerId}"`);
        }

        await test.step(`Navigate to ${providerId} homepage`, async () => {
          await page.goto(url);
          await page.waitForLoadState('domcontentloaded');
        });

        await test.step(`Validate selector: ${selectorName}`, async () => {
          const candidateSelectors = Array.isArray(selectorValue) ? selectorValue : [selectorValue];
          let actionableLocator = null;

          for (const candidate of candidateSelectors) {
            if (typeof candidate !== 'string') {
              continue;
            }
            const locator = page.locator(candidate).first();
            if (await locator.count()) {
              actionableLocator = locator;
              break;
            }
          }

          if (!actionableLocator) {
            throw new Error(`No element found for selector key: ${selectorName}`);
          }

          await expect(actionableLocator, `Element for "${selectorName}" is not visible`).toBeVisible();
          await expect(actionableLocator, `Element for "${selectorName}" is not enabled`).toBeEnabled();
        });
      });
    }
  });
}

