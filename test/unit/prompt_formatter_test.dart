import 'package:flutter_test/flutter_test.dart';
import 'package:multi_webview_tab_manager/core/utils/prompt_formatter.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';

void main() {
  group('PromptFormatter Tests', () {
    test('formatPrompt includes system instruction when provided', () {
      final formatted = PromptFormatter.formatPrompt(
        prompt: 'User prompt',
        contextFiles: [],
        options: {'systemInstruction': 'You are a helpful assistant'},
      );

      expect(formatted, contains('System: You are a helpful assistant'));
      expect(formatted, contains('User: User prompt'));
    });

    test('formatPrompt excludes system instruction when not provided', () {
      final formatted = PromptFormatter.formatPrompt(
        prompt: 'User prompt',
        contextFiles: [],
        options: {},
      );

      expect(formatted, isNot(contains('System:')));
      expect(formatted, contains('User: User prompt'));
    });

    test('formatPrompt includes context files', () {
      final formatted = PromptFormatter.formatPrompt(
        prompt: 'User prompt',
        contextFiles: ['file1.txt', 'file2.txt'],
        options: {},
      );

      expect(formatted, contains('Context:'));
      expect(formatted, contains('--- File: file1.txt ---'));
      expect(formatted, contains('--- File: file2.txt ---'));
      expect(formatted, contains('[Content of file1.txt]'));
      expect(formatted, contains('[Content of file2.txt]'));
    });

    test('formatPrompt handles empty context files', () {
      final formatted = PromptFormatter.formatPrompt(
        prompt: 'User prompt',
        contextFiles: [],
        options: {},
      );

      expect(formatted, isNot(contains('Context:')));
      expect(formatted, contains('User: User prompt'));
    });

    test('formatCWCStyle includes system prompt', () {
      final formatted = PromptFormatter.formatCWCStyle(
        prompt: 'User prompt',
        systemPrompt: 'System instruction',
      );

      expect(formatted, contains('SYSTEM: System instruction'));
      expect(formatted, contains('PROMPT:'));
      expect(formatted, contains('User prompt'));
    });

    test('formatCWCStyle excludes system prompt when not provided', () {
      final formatted = PromptFormatter.formatCWCStyle(
        prompt: 'User prompt',
      );

      expect(formatted, isNot(contains('SYSTEM:')));
      expect(formatted, contains('PROMPT:'));
    });

    test('formatCWCStyle includes context', () {
      final formatted = PromptFormatter.formatCWCStyle(
        prompt: 'User prompt',
        context: [
          {'title': 'File1', 'content': 'Content 1'},
          {'title': 'File2', 'content': 'Content 2'},
        ],
      );

      expect(formatted, contains('CONTEXT:'));
      expect(formatted, contains('--- File1 ---'));
      expect(formatted, contains('Content 1'));
      expect(formatted, contains('--- File2 ---'));
      expect(formatted, contains('Content 2'));
    });

    test('formatCWCStyle includes options', () {
      final formatted = PromptFormatter.formatCWCStyle(
        prompt: 'User prompt',
        options: {
          'temperature': 0.7,
          'maxTokens': 1000,
        },
      );

      expect(formatted, contains('OPTIONS:'));
      expect(formatted, contains('- temperature: 0.7'));
      expect(formatted, contains('- maxTokens: 1000'));
    });

    test('formatCWCStyle handles empty context and options', () {
      final formatted = PromptFormatter.formatCWCStyle(
        prompt: 'User prompt',
      );

      expect(formatted, isNot(contains('CONTEXT:')));
      expect(formatted, isNot(contains('OPTIONS:')));
      expect(formatted, contains('PROMPT:'));
    });

    test('extractUserPrompt extracts prompt from formatted content', () {
      const formatted = '''
SYSTEM: System instruction

CONTEXT:
--- File1 ---
Content

OPTIONS:
- temperature: 0.7

PROMPT:
User prompt here
''';

      final extracted = PromptFormatter.extractUserPrompt(formatted);

      expect(extracted, 'User prompt here');
    });

    test('extractUserPrompt handles prompt without sections', () {
      const formatted = '''
PROMPT:
Simple prompt
''';

      final extracted = PromptFormatter.extractUserPrompt(formatted);

      expect(extracted, 'Simple prompt');
    });

    test('extractUserPrompt handles multiple lines', () {
      const formatted = '''
PROMPT:
Line 1
Line 2
Line 3
''';

      final extracted = PromptFormatter.extractUserPrompt(formatted);

      expect(extracted, 'Line 1\nLine 2\nLine 3');
    });

    test('wrapWithCDATA wraps content correctly', () {
      const content = 'Some content';
      final wrapped = PromptFormatter.wrapWithCDATA(content);

      expect(wrapped, '<![CDATA[\nSome content\n]]>');
    });

    test('sanitizePrompt removes script tags', () {
      const prompt = 'Normal text <script>alert("xss")</script> more text';
      final sanitized = PromptFormatter.sanitizePrompt(prompt);

      expect(sanitized, isNot(contains('<script>')));
      expect(sanitized, contains('Normal text'));
      expect(sanitized, contains('more text'));
    });

    test('sanitizePrompt removes HTML tags', () {
      const prompt = '<div>Text</div><p>More</p>';
      final sanitized = PromptFormatter.sanitizePrompt(prompt);

      expect(sanitized, isNot(contains('<div>')));
      expect(sanitized, isNot(contains('<p>')));
      expect(sanitized, contains('Text'));
      expect(sanitized, contains('More'));
    });

    test('sanitizePrompt trims whitespace', () {
      const prompt = '   Text with spaces   ';
      final sanitized = PromptFormatter.sanitizePrompt(prompt);

      expect(sanitized, 'Text with spaces');
    });

    test('estimateTokenCount calculates approximate tokens', () {
      // ~4 characters per token
      const text = 'This is a test with 32 characters';
      
      final tokens = PromptFormatter.estimateTokenCount(text);

      expect(tokens, greaterThan(0));
      expect(tokens, lessThanOrEqualTo(text.length)); // Should be less than char count
    });

    test('estimateTokenCount handles empty string', () {
      final tokens = PromptFormatter.estimateTokenCount('');

      expect(tokens, 0);
    });

    test('exceedsTokenLimit returns true when over limit', () {
      const text = 'This is a very long text that should exceed the token limit';
      const limit = 5;

      final exceeds = PromptFormatter.exceedsTokenLimit(text, limit);

      expect(exceeds, true);
    });

    test('exceedsTokenLimit returns false when under limit', () {
      const text = 'Short';
      const limit = 100;

      final exceeds = PromptFormatter.exceedsTokenLimit(text, limit);

      expect(exceeds, false);
    });

    test('truncatePrompt returns original when under limit', () {
      const prompt = 'Short prompt';
      const limit = 100;

      final truncated = PromptFormatter.truncatePrompt(prompt, limit);

      expect(truncated, prompt);
    });

    test('truncatePrompt truncates when over limit', () {
      const prompt = 'This is a very long prompt that should be truncated when it exceeds the token limit';
      const limit = 10;

      final truncated = PromptFormatter.truncatePrompt(prompt, limit);

      expect(truncated, isNot(equals(prompt)));
      expect(truncated, contains('...[truncated]'));
      expect(truncated.length, lessThan(prompt.length));
    });

    test('truncatePrompt uses custom suffix', () {
      const prompt = 'This is a very long prompt that should definitely be truncated when it exceeds the token limit';
      const limit = 10;
      const customSuffix = '[...]';

      final truncated = PromptFormatter.truncatePrompt(prompt, limit, suffix: customSuffix);

      expect(truncated, contains(customSuffix));
      expect(truncated.length, lessThan(prompt.length));
    });

    test('truncatePrompt handles very small limit', () {
      const prompt = 'Very long prompt';
      const limit = 1;

      final truncated = PromptFormatter.truncatePrompt(prompt, limit);

      expect(truncated, '...[truncated]');
    });

    test('formatForProvider formats for AI Studio', () {
      final formatted = PromptFormatter.formatForProvider(
        prompt: 'Test prompt',
        provider: AIProvider.aistudio,
        options: {'temperature': 0.7},
      );

      expect(formatted, contains('Temperature: 0.7'));
      expect(formatted, contains('Test prompt'));
    });

    test('formatForProvider formats for Qwen', () {
      final formatted = PromptFormatter.formatForProvider(
        prompt: 'Test prompt',
        provider: AIProvider.qwen,
        options: {'model': 'qwen-turbo'},
      );

      expect(formatted, contains('Model: qwen-turbo'));
      expect(formatted, contains('Test prompt'));
    });

    test('formatForProvider formats for Z-AI', () {
      final formatted = PromptFormatter.formatForProvider(
        prompt: 'Test prompt',
        provider: AIProvider.zai,
        options: {'creativity': 0.8},
      );

      expect(formatted, contains('Creativity: 0.8'));
      expect(formatted, contains('Test prompt'));
    });

    test('formatForProvider formats for Kimi', () {
      final formatted = PromptFormatter.formatForProvider(
        prompt: 'Test prompt',
        provider: AIProvider.kimi,
        options: {'style': 'creative'},
      );

      expect(formatted, contains('Style: creative'));
      expect(formatted, contains('Test prompt'));
    });

    test('formatForProvider handles missing options', () {
      final formatted = PromptFormatter.formatForProvider(
        prompt: 'Test prompt',
        provider: AIProvider.aistudio,
      );

      expect(formatted, isNot(contains('Temperature:')));
      expect(formatted, contains('Test prompt'));
    });

    test('formatForProvider handles empty options', () {
      final formatted = PromptFormatter.formatForProvider(
        prompt: 'Test prompt',
        provider: AIProvider.qwen,
        options: {},
      );

      expect(formatted, isNot(contains('Model:')));
      expect(formatted, contains('Test prompt'));
    });
  });
}

