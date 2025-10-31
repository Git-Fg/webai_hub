/// Service to format prompts following CWC structure
/// Implements Section 5.3 of BLUEPRINT.md
class PromptFormatter {
  /// Format a prompt with optional context and system instructions
  /// Following the CWC structure with prompt repetition
  static String format({
    required String userPrompt,
    String? systemInstructions,
    List<ContextFile>? contextFiles,
  }) {
    final buffer = StringBuffer();
    
    // First occurrence of prompt
    buffer.writeln(userPrompt);
    
    // System instructions (if provided)
    if (systemInstructions != null && systemInstructions.isNotEmpty) {
      buffer.writeln('<system>');
      buffer.writeln(systemInstructions);
      buffer.writeln('</system>');
    }
    
    // Context files (if provided)
    if (contextFiles != null && contextFiles.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('<files>');
      for (final file in contextFiles) {
        buffer.writeln('  <file path="${file.path}">');
        buffer.writeln('  <![CDATA[');
        buffer.writeln(file.content);
        buffer.writeln('  ]]>');
        buffer.writeln('  </file>');
      }
      buffer.writeln('</files>');
    }
    
    // Repeat prompt (critical for long contexts)
    buffer.writeln();
    buffer.writeln(userPrompt);
    
    // Repeat system instructions
    if (systemInstructions != null && systemInstructions.isNotEmpty) {
      buffer.writeln('<system>');
      buffer.writeln(systemInstructions);
      buffer.writeln('</system>');
    }
    
    return buffer.toString();
  }
}

/// Represents a context file to be included in the prompt
class ContextFile {
  final String path;
  final String content;
  
  const ContextFile({
    required this.path,
    required this.content,
  });
}
