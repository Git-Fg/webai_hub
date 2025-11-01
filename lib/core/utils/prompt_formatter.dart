import '../../shared/models/ai_provider.dart';

/// Utility class for formatting prompts according to CWC structure
class PromptFormatter {
  /// Format prompt with context and options using CWC XML structure
  static String formatPrompt({
    required String prompt,
    required List<String> contextFiles,
    required Map<String, dynamic> options,
  }) {
    // Extract system instruction from options
    final systemInstruction = options['systemInstruction'] as String?;

    // Convert context files to the expected format
    final context = contextFiles.map((filePath) => {
      'title': filePath,
      'content': _formatFileContent(filePath),
    }).toList();

    // Use the CWC-style formatter
    return formatCWCStyle(
      prompt: prompt,
      systemPrompt: systemInstruction,
      context: context,
      options: options,
    );
  }

  /// Format file content for inclusion in prompt
  static String _formatFileContent(String filePath) {
    // For now, return a placeholder
    // In a real implementation, this would read the actual file content
    return '[Content of $filePath]';
  }

  /// Format prompt with CWC-style structure using XML tags
  static String formatCWCStyle({
    required String prompt,
    String? systemPrompt,
    List<Map<String, String>>? context,
    Map<String, dynamic>? options,
  }) {
    final buffer = StringBuffer();

    // First user prompt (before context)
    buffer.writeln(prompt);
    buffer.writeln();

    // System instructions (if provided)
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.writeln('<system>');
      buffer.writeln(systemPrompt);
      buffer.writeln('</system>');
      buffer.writeln();
    }

    // Context files with XML CDATA formatting
    if (context != null && context.isNotEmpty) {
      buffer.writeln('<files>');
      for (final item in context) {
        final title = item['title'] ?? 'Unknown';
        final content = item['content'] ?? '';

        buffer.writeln('  <file path="$title">');
        buffer.writeln('  <![CDATA[');
        buffer.writeln(content);
        buffer.writeln('  ]]>');
        buffer.writeln('  </file>');
      }
      buffer.writeln('</files>');
      buffer.writeln();
    }

    // Repeat user prompt (as per CWC specification)
    buffer.writeln(prompt);
    buffer.writeln();

    // Repeat system instructions (as per CWC specification)
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.writeln('<system>');
      buffer.writeln(systemPrompt);
      buffer.writeln('</system>');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Extract just the user prompt from formatted content
  /// For CWC XML format, extracts the first occurrence of the prompt (before XML tags)
  static String extractUserPrompt(String formattedPrompt) {
    // Handle legacy format with "PROMPT:" marker
    if (formattedPrompt.toUpperCase().contains('PROMPT:')) {
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

    // Handle CWC XML format: extract content before first XML tag
    final lines = formattedPrompt.split('\n');
    final promptLines = <String>[];

    for (final line in lines) {
      // Stop at first XML tag (<system>, <files>, etc.)
      if (line.trim().startsWith('<')) {
        break;
      }
      // Skip empty lines at the beginning
      if (promptLines.isEmpty && line.trim().isEmpty) {
        continue;
      }
      promptLines.add(line);
    }

    final extracted = promptLines.join('\n').trim();
    return extracted.isNotEmpty ? extracted : formattedPrompt.split('\n').first.trim();
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

  /// Format prompt for specific AI provider using CWC XML structure
  /// This method applies the CWC format (Section 5.3 and 5.4 of BLUEPRINT.md)
  /// regardless of provider, as the XML format maximizes AI comprehension
  static String formatForProvider({
    required String prompt,
    required AIProvider provider,
    Map<String, dynamic>? options,
    List<Map<String, String>>? context,
  }) {
    // Extract system instruction from options
    final systemInstruction = options?['systemInstruction'] as String?;

    // Format using CWC XML structure (as per BLUEPRINT Section 5.3 and 5.4)
    return formatCWCStyle(
      prompt: prompt,
      systemPrompt: systemInstruction,
      context: context,
      options: options,
    );
  }
}