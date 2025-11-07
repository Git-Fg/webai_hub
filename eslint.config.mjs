// eslint.config.mjs
// @ts-check

import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  // Base ESLint recommended rules
  eslint.configs.recommended,

  // TypeScript ESLint's "strict" configuration
  ...tseslint.configs.strict,

  // Custom project-specific rule overrides
  {
    rules: {
      // Allow @ts-ignore only if a descriptive reason is provided
      '@typescript-eslint/ban-ts-comment': [
        'error',
        {
          'ts-expect-error': 'allow-with-description',
          'ts-ignore': 'allow-with-description',
          'ts-nocheck': true,
          'ts-check': false,
          minimumDescriptionLength: 10,
        },
      ],
    },
  },

  // Files to ignore from linting
  {
    ignores: [
      '**/build/**',
      '**/node_modules/**',
      '**/assets/js/bridge.js',
      '**/validation/**',
    ],
  }
);

