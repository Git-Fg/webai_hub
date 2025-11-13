import path from 'path';
import { register as registerTsconfigPaths } from 'tsconfig-paths';
import { defineConfig } from '@playwright/test';

registerTsconfigPaths({
  baseUrl: __dirname,
  paths: {
    '~/*': ['../ts_src/*'],
  },
});

export default defineConfig({
  testDir: path.join(__dirname, 'tests'),
  timeout: 60 * 1000,
  expect: {
    timeout: 15 * 1000,
  },
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['html', { outputFolder: 'playwright-report' }]],

  use: {
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'Mobile WebView Emulation',
      use: {
        userAgent:
          'Mozilla/5.0 (Linux; Android 10; K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/125.0.0.0 Mobile Safari/537.36',
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
});

