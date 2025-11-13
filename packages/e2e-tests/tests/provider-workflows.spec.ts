import path from 'path';

import { expect, test, applyAuthenticatedCookies } from '../fixtures/authenticated';
import { SUPPORTED_SITES } from '~/chatbots';

type BridgeWindow = Window & {
  __AI_HYBRID_HUB_INITIALIZED__?: boolean;
  startAutomation: (
    providerId: string,
    prompt: string,
    settingsJson: string,
    timeoutModifier: number
  ) => Promise<void>;
  extractFinalResponse: () => Promise<string>;
};

const providerUrls = {
  ai_studio: 'https://aistudio.google.com/prompts/new_chat',
  kimi: 'https://kimi.com/',
  z_ai: 'https://chat.z.ai/',
} as const satisfies Record<string, string>;

const bridgeScriptPath = path.resolve(__dirname, '../../../assets/js/bridge.js');

const providerIds = Object.keys(SUPPORTED_SITES) as string[];

for (const providerId of providerIds) {
  if (providerId === 'kimi') {
    continue;
  }

  test.describe(`E2E Workflow Validation for: ${providerId}`, () => {
    test.setTimeout(90 * 1000);

    test('should complete a full send-and-receive workflow', async ({ authenticatedPage }) => {
      test.info().annotations.push({ type: 'provider', description: providerId });

      const page = authenticatedPage;
      const url = providerUrls[providerId as keyof typeof providerUrls];
      if (!url) {
        throw new Error(`No URL defined for provider "${providerId}"`);
      }

      await test.step('Navigate to provider page', async () => {
        await page.goto(url, { waitUntil: 'domcontentloaded' });
      });

      await test.step('Inject bridge runtime and wait for readiness', async () => {
        await page.addScriptTag({ path: bridgeScriptPath });
        await page.waitForFunction(
          () => ((window as unknown as BridgeWindow).__AI_HYBRID_HUB_INITIALIZED__ ?? false) === true,
          undefined,
          { timeout: 10_000 }
        );
      });

      const prompt = `Hello ${providerId}, this is an automated test. What is the capital of France?`;

      await test.step('Run automation workflow', async () => {
        await page.evaluate(async (args) => {
          const bridgeWindow = window as unknown as BridgeWindow;
          await bridgeWindow.startAutomation(args.providerId, args.prompt, '{}', 1.0);
        }, { providerId, prompt });
      });

      const response = await test.step('Extract final response', async () => {
        return page.evaluate(async () => {
          const bridgeWindow = window as unknown as BridgeWindow;
          return bridgeWindow.extractFinalResponse();
        });
      });

      await test.step('Validate response content', async () => {
        expect(response, `Response for ${providerId} should not be empty.`).toBeTruthy();
        expect(
          response.length,
          `Response for ${providerId} should have a reasonable length.`
        ).toBeGreaterThan(5);
        expect(
          response.toLowerCase(),
          `Response for ${providerId} should contain 'paris'.`
        ).toContain('paris');
      });
    });
  });
}

test.describe('E2E Workflow Validation for: kimi', () => {
  test.setTimeout(90 * 1000);

  test('should complete a full send-and-receive workflow', async ({ browser, contextOptions }) => {
    test.info().annotations.push({ type: 'provider', description: 'kimi' });

    const context = await test.step('Create authenticated context with clipboard permissions', async () => {
      const ctx = await browser.newContext({
        ...contextOptions,
        permissions: ['clipboard-read', 'clipboard-write'],
      });
      await applyAuthenticatedCookies(ctx);
      return ctx;
    });

    try {
      const page = await test.step('Open new page and register clipboard mocks', async () => {
        const newPage = await context.newPage();

        await context.exposeFunction('mockReadClipboard', async () => {
          return newPage.evaluate(() => navigator.clipboard.readText());
        });

        await context.exposeFunction('mockSetClipboard', async (text?: string) => {
          if (typeof text !== 'string') {
            return null;
          }

          return newPage.evaluate((value) => {
            if (typeof value !== 'string') {
              return null;
            }

            return navigator.clipboard.writeText(value);
          }, text);
        });

        await newPage.addInitScript(() => {
          (window as typeof window & {
            flutter_inappwebview: {
              callHandler: (handlerName: string, ...args: unknown[]) => Promise<unknown>;
            };
            mockReadClipboard?: () => Promise<string>;
            mockSetClipboard?: (value: string) => Promise<void>;
          }).flutter_inappwebview = {
            callHandler: async (handlerName: string, ...args: unknown[]): Promise<unknown> => {
              if (handlerName === 'readClipboard') {
                return (window as typeof window & {
                  mockReadClipboard: () => Promise<string>;
                }).mockReadClipboard();
              }

              if (handlerName === 'setClipboard') {
                const [value] = args;
                if (typeof value === 'string') {
                  return (window as typeof window & {
                    mockSetClipboard: (clipboardValue: string) => Promise<void>;
                  }).mockSetClipboard(value);
                }

                return null;
              }

              return null;
            },
          };
        });

        return newPage;
      });

      await test.step('Navigate to provider page', async () => {
        await page.goto(providerUrls.kimi, { waitUntil: 'domcontentloaded' });
      });

      await test.step('Inject bridge runtime and wait for readiness', async () => {
        await page.addScriptTag({ path: bridgeScriptPath });
        await page.waitForFunction(
          () => ((window as unknown as BridgeWindow).__AI_HYBRID_HUB_INITIALIZED__ ?? false) === true,
          undefined,
          { timeout: 10_000 }
        );
      });

      const prompt = 'Hello kimi, this is an automated test. What is the capital of France?';

      await test.step('Run automation workflow', async () => {
        await page.evaluate(async (args) => {
          const bridgeWindow = window as unknown as BridgeWindow;
          await bridgeWindow.startAutomation(args.providerId, args.prompt, '{}', 1.0);
        }, { providerId: 'kimi', prompt });
      });

      const response = await test.step('Extract final response', async () => {
        return page.evaluate(async () => {
          const bridgeWindow = window as unknown as BridgeWindow;
          return bridgeWindow.extractFinalResponse();
        });
      });

      await test.step('Validate response content', async () => {
        expect(response, 'Response for kimi should not be empty.').toBeTruthy();
        expect(
          response.length,
          'Response for kimi should have a reasonable length.'
        ).toBeGreaterThan(5);
        expect(
          response.toLowerCase(),
          "Response for kimi should contain 'paris'."
        ).toContain('paris');
      });
    } finally {
      await context.close();
    }
  });
});

