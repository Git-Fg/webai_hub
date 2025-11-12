// eslint_rules/disallow-timeout-for-waits.mjs

/**
 * @type {import('eslint').Rule.RuleModule}
 */
const disallowTimeoutForWaitsRule = {
  meta: {
    type: 'suggestion',
    docs: {
      description: 'Disallow using setTimeout for arbitrary waits, suggesting project-specific utilities instead.',
      recommended: true,
    },
    schema: [],
    messages: {
      avoidTimeout: "Avoid setTimeout for UI waits. Use 'waitForActionableElement' or other promise-based utilities to prevent flaky automation.",
    },
  },
  create(context) {
    return {
      CallExpression(node) {
        // Check for both setTimeout and window.setTimeout
        let isSetTimeout = false;
        if (node.callee.type === 'Identifier' && node.callee.name === 'setTimeout') {
          isSetTimeout = true;
        } else if (
          node.callee.type === 'MemberExpression' &&
          node.callee.object.type === 'Identifier' &&
          node.callee.object.name === 'window' &&
          node.callee.property.type === 'Identifier' &&
          node.callee.property.name === 'setTimeout'
        ) {
          isSetTimeout = true;
        }

        if (!isSetTimeout) {
          return;
        }

        const delayArg = node.arguments[1];

        // Allow setTimeout(..., 0) as it's a valid pattern to yield to the event loop.
        if (delayArg && delayArg.type === 'Literal' && delayArg.value === 0) {
          return;
        }

        context.report({ node, messageId: 'avoidTimeout' });
      },
    };
  },
};

export default disallowTimeoutForWaitsRule;

