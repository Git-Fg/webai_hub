// eslint_rules/enforce-structured-logging.mjs

/**
 * @type {import('eslint').Rule.RuleModule}
 */
const enforceStructuredLoggingRule = {
  meta: {
    type: 'problem',
    docs: {
      description: 'Enforce that console.log and console.error messages are prefixed with a scope (e.g., "[Scope] Message").',
      recommended: true,
    },
    schema: [],
    messages: {
      missingScope: 'Log message must be prefixed with a scope (e.g., "[Engine] Message").',
    },
  },
  create(context) {
    const SCOPE_REGEX = /^\[.+\] /;

    return {
      CallExpression(node) {
        const isConsoleCall =
          node.callee.type === 'MemberExpression' &&
          node.callee.object.type === 'Identifier' &&
          node.callee.object.name === 'console' &&
          (node.callee.property.name === 'log' || node.callee.property.name === 'error' || node.callee.property.name === 'warn');

        if (!isConsoleCall) {
          return;
        }

        const firstArg = node.arguments[0];

        if (!firstArg) {
          return; // Allow console.log() with no arguments
        }

        if (firstArg.type === 'Literal' && typeof firstArg.value === 'string') {
          if (!SCOPE_REGEX.test(firstArg.value)) {
            context.report({ node: firstArg, messageId: 'missingScope' });
          }
        } else if (firstArg.type === 'TemplateLiteral' && firstArg.quasis.length > 0) {
          const firstChunk = firstArg.quasis[0].value.raw;
          if (!SCOPE_REGEX.test(firstChunk)) {
            context.report({ node: firstArg, messageId: 'missingScope' });
          }
        }
      },
    };
  },
};

export default enforceStructuredLoggingRule;


