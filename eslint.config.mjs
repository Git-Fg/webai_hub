// eslint.config.mjs
// @ts-check

import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  // Base ESLint recommended rules
  eslint.configs.recommended,

  // TypeScript ESLint's "strict" configuration, which forbids `any`
  ...tseslint.configs.strict,

  // Custom rule overrides for this project
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
  {
    ignores: [
      '**/build/**',
      '**/node_modules/**',
      '**/assets/js/bridge.js',
      '**/validation/**',
    ],
  }
);

