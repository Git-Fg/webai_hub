// eslint.config.mjs
// @ts-check

import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

// --- START: NEW CUSTOM RULE DEFINITION ---

/**
 * @type {import('eslint').Rule.RuleModule}
 */
const noJquerySelectorsRule = {
  meta: {
    type: 'problem',
    docs: {
      description: 'Disallow non-standard jQuery CSS pseudo-selectors in string literals, as they cause runtime DOMExceptions.',
      recommended: true,
    },
    schema: [],
  },
  create(context) {
    // Skip checking in ESLint config file itself
    if (context.getFilename().includes('eslint.config.mjs')) {
      return {};
    }
    
    // Map of invalid selectors to their native CSS/programmatic alternatives.
    const invalidSelectorMap = {
      ':contains(': {
        reason: 'This is a jQuery extension and is not valid in `document.querySelector`.',
        suggestion: 'There is no direct CSS equivalent. Programmatically filter elements using `element.textContent.includes(\'text\')` after selecting a broader parent element.',
      },
      ':eq(': {
        reason: 'This is a jQuery extension. CSS indices are 1-based, not 0-based.',
        suggestion: 'Use the standard CSS pseudo-class `:nth-child(n+1)`. For example, `:eq(0)` becomes `:nth-child(1)`.',
      },
      ':gt(': {
        reason: 'This is a jQuery extension and is not valid in standard CSS.',
        suggestion: 'Use the standard CSS pseudo-class `:nth-child(n + index)`. For example, `:gt(2)` becomes `:nth-child(n + 4)`.',
      },
      ':lt(': {
        reason: 'This is a jQuery extension and is not valid in standard CSS.',
        suggestion: 'Use the standard CSS pseudo-class `:nth-child(-n + index)`. For example, `:lt(2)` becomes `:nth-child(-n + 2)`.',
      },
      ':input': {
        reason: 'This is a jQuery extension.',
        suggestion: 'Use the standard CSS selector group `input, textarea, select, button`.',
      },
    };

    const invalidSelectorKeys = Object.keys(invalidSelectorMap);

    return {
      // We visit 'Literal' nodes in the AST, which represent strings, numbers, etc.
      Literal(node) {
        if (typeof node.value !== 'string') {
          return;
        }

        const selectorString = node.value;

        for (const invalid of invalidSelectorKeys) {
          if (selectorString.includes(invalid)) {
            const details = invalidSelectorMap[invalid];
            
            context.report({
              node,
              message: `Invalid selector '${invalid}'. ${details.reason} Suggestion: ${details.suggestion}`,
            });

            // Report only the first invalid selector found in the string.
            return;
          }
        }
      },
    };
  },
};

// --- END: NEW CUSTOM RULE DEFINITION ---

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
    // --- START: NEW PLUGIN AND RULE INTEGRATION ---
    // Define an inline plugin to host our custom rule
    plugins: {
      custom: {
        rules: {
          'no-jquery-selectors': noJquerySelectorsRule,
        },
      },
    },
    // Enable the custom rule with 'error' severity
    rules: {
      'custom/no-jquery-selectors': 'error',
    },
    // --- END: NEW PLUGIN AND RULE INTEGRATION ---
  },
  {
    ignores: [
      '**/build/**',
      '**/node_modules/**',
      '**/assets/js/bridge.js',
      '**/validation/**',
    ],
  },
);

