import 'dart:convert';
import '../../shared/models/ai_provider.dart';

/// Utility class for formatting prompts according to CWC structure
class PromptFormatter {
  /// Format prompt with context and options
  static String formatPrompt({
    required String prompt,
    required List<String> contextFiles,
    required Map<String, dynamic> options,
  }) {
    final buffer = StringBuffer();

    // Add system instruction if provided
    if (options.containsKey('systemInstruction')) {
      buffer.writeln('System: ${options['systemInstruction']}');
      buffer.writeln();
    }

    // Add context files
    if (contextFiles.isNotEmpty) {
      buffer.writeln('Context:');
      for (final filePath in contextFiles) {
        buffer.writeln('--- File: $filePath ---');
        buffer.writeln(_formatFileContent(filePath));
        buffer.writeln();
      }
      buffer.writeln();
    }

    // Add user prompt
    buffer.writeln('User: $prompt');

    return buffer.toString();
  }

  /// Format file content for inclusion in prompt
  static String _formatFileContent(String filePath) {
    // For now, return a placeholder
    // In a real implementation, this would read the actual file content
    return '[Content of $filePath]';
  }

  /// Format prompt with CWC-style structure
  static String formatCWCStyle({
    required String prompt,
    String? systemPrompt,
    List<Map<String, String>>? context,
    Map<String, dynamic>? options,
  }) {
    final buffer = StringBuffer();

    // Add system prompt
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.writeln('SYSTEM: $systemPrompt');
      buffer.writeln();
    }

    // Add context information
    if (context != null && context.isNotEmpty) {
      buffer.writeln('CONTEXT:');
      for (final item in context) {
        final title = item['title'] ?? 'Unknown';
        final content = item['content'] ?? '';

        buffer.writeln('--- $title ---');
        buffer.writeln(content);
        buffer.writeln();
      }
      buffer.writeln();
    }

    // Add options/parameters
    if (options != null && options.isNotEmpty) {
      buffer.writeln('OPTIONS:');
      options.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
      buffer.writeln();
    }

    // Add main prompt
    buffer.writeln('PROMPT:');
    buffer.writeln(prompt);

    return buffer.toString();
  }

  /// Extract just the user prompt from formatted content
  static String extractUserPrompt(String formattedPrompt) {
    final lines = formattedPrompt.split('\n');
    final promptLines = <String>[];
    bool inPromptSection = false;

    for (final line in lines) {
      if (line.toUpperCase().startsWith('PROMPT:')) {
        inPromptSection = true;
        continue;
      }

      if (inPromptSection) {
        promptLines.add(line);
      }
    }

    return promptLines.join('\n').trim();
  }

  /// Add CDATA wrapper for file content
  static String wrapWithCDATA(String content) {
    return '<![CDATA[\n$content\n]]>';
  }

  /// Sanitize prompt content
  static String sanitizePrompt(String prompt) {
    return prompt
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }

  /// Estimate token count (rough approximation)
  static int estimateTokenCount(String text) {
    // Rough estimation: ~4 characters per token
    return (text.length / 4).ceil();
  }

  /// Check if prompt exceeds token limit
  static bool exceedsTokenLimit(String prompt, int limit) {
    return estimateTokenCount(prompt) > limit;
  }

  /// Truncate prompt to fit within token limit
  static String truncatePrompt(String prompt, int limit, {String suffix = '...[truncated]'}) {
    if (!exceedsTokenLimit(prompt, limit)) {
      return prompt;
    }

    final targetTokens = limit - estimateTokenCount(suffix);
    final targetLength = targetTokens * 4;

    if (targetLength < 100) {
      return suffix;
    }

    return '${prompt.substring(0, targetLength)}$suffix';
  }

  /// Format prompt for specific AI provider
  static String formatForProvider({
    required String prompt,
    required AIProvider provider,
    Map<String, dynamic>? options,
  }) {
    switch (provider) {
      case AIProvider.aistudio:
        return _formatForAIStudio(prompt, options);
      case AIProvider.qwen:
        return _formatForQwen(prompt, options);
      case AIProvider.zai:
        return _formatForZAI(prompt, options);
      case AIProvider.kimi:
        return _formatForKimi(prompt, options);
    }
  }

  static String _formatForAIStudio(String prompt, Map<String, dynamic>? options) {
    // AI Studio specific formatting
    final buffer = StringBuffer();

    if (options?.containsKey('temperature') == true) {
      buffer.writeln('Temperature: ${options!['temperature']}');
    }

    buffer.writeln(prompt);
    return buffer.toString();
  }

  static String _formatForQwen(String prompt, Map<String, dynamic>? options) {
    // Qwen specific formatting
    final buffer = StringBuffer();

    if (options?.containsKey('model') == true) {
      buffer.writeln('Model: ${options!['model']}');
    }

    buffer.writeln(prompt);
    return buffer.toString();
  }

  static String _formatForZAI(String prompt, Map<String, dynamic>? options) {
    // Z-AI specific formatting
    final buffer = StringBuffer();

    if (options?.containsKey('creativity') == true) {
      buffer.writeln('Creativity: ${options!['creativity']}');
    }

    buffer.writeln(prompt);
    return buffer.toString();
  }

  static String _formatForKimi(String prompt, Map<String, dynamic>? options) {
    // Kimi specific formatting
    final buffer = StringBuffer();

    if (options?.containsKey('style') == true) {
      buffer.writeln('Style: ${options!['style']}');
    }

    buffer.writeln(prompt);
    return buffer.toString();
  }
}