// eslint_rules/no-jquery-selectors.mjs

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
    // Skip checking in ESLint config file and this rule file itself
    const filename = context.getFilename();
    if (filename.includes('eslint.config.mjs') || filename.includes('no-jquery-selectors.mjs')) {
      return {};
    }

    // Map of invalid selectors to their native CSS/programmatic alternatives.
    const invalidSelectorMap = {
      ':contains(': {
        reason: 'This is a jQuery extension and is not valid in `document.querySelector`.',
        suggestion: "There is no direct CSS equivalent. Programmatically filter elements using `element.textContent.includes('text')` after selecting a broader parent element.",
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

export default noJquerySelectorsRule;


