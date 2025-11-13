// @ts-check

import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import noJquerySelectorsRule from './eslint_rules/no-jquery-selectors.mjs';
import enforceStructuredLoggingRule from './eslint_rules/enforce-structured-logging.mjs';
import disallowTimeoutForWaitsRule from './eslint_rules/disallow-timeout-for-waits.mjs';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strict,
  {
    rules: {
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
    plugins: {
      custom: {
        rules: {
          'no-jquery-selectors': noJquerySelectorsRule,
          'enforce-structured-logging': enforceStructuredLoggingRule,
          'disallow-timeout-for-waits': disallowTimeoutForWaitsRule,
        },
      },
    },
    rules: {
      'custom/no-jquery-selectors': 'error',
      'custom/enforce-structured-logging': 'error',
    },
  },
  {
    files: ['**/chatbots/**/*.ts'],
    rules: {
      'custom/disallow-timeout-for-waits': 'warn',
    },
  },
  {
    ignores: [
      '**/build/**',
      '**/node_modules/**',
      '**/assets/js/bridge.js',
      '**/manual_validation/**',
      '**/eslint_rules/**',
    ],
  },
);

