import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/models/provider_config.dart';
import 'package:ai_hybrid_hub/core/providers/provider_config_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/conversation_settings.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

/// Service class responsible for building prompts with conversation context.
/// WHY: Separating prompt-building logic from orchestration improves testability
/// and adheres to the Single Responsibility Principle.
class PromptBuilder {
  PromptBuilder({required this.ref, required this.db});

  final Ref ref;
  final AppDatabase db;

  /// Constructs the prompt with conversation context via selected strategy
  Future<String> buildPromptWithContext(
    String newPrompt, {
    required int conversationId,
    String? excludeMessageId,
  }) async {
    // 1. Fetch all necessary data and settings ONCE.
    final messagesData = await (db.select(
      db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).get();

    final history = messagesData
        .map(
          (m) => Message(
            id: m.id,
            text: m.content,
            isFromUser: m.isFromUser,
            status: m.status,
          ),
        )
        .where(
          (m) => m.id != excludeMessageId && m.status == MessageStatus.success,
        )
        .toList();

    // 2. DECISION POINT: Is this the first message of the conversation?
    if (history.isEmpty) {
      ref
          .read(talkerProvider)
          .info('First message in conversation. Using simple prompt.');
      // For the first message, always use the plain text prompt, regardless of settings.
      return newPrompt;
    }

    // 3. This is a follow-up message, use the configured strategy.
    final settingsAsync = ref.read(generalSettingsProvider);
    final generalSettings = settingsAsync.maybeWhen(
      data: (value) => value,
      // WHY: Default to simple prompting until settings are loaded to avoid
      // impacting tests and first-frame behavior.
      orElse: () => const GeneralSettingsData(),
    );
    final conversationSettings = ref.read(conversationSettingsProvider);

    if (generalSettings.useAdvancedPrompting) {
      ref
          .read(talkerProvider)
          .info('Follow-up message. Using Advanced (XML) prompt.');
      final providerConfig = ref.read(currentProviderConfigurationProvider);
      return _buildXmlPrompt(
        newPrompt,
        history: history,
        generalSettings: generalSettings,
        conversationSettings: conversationSettings,
        providerConfig: providerConfig,
      );
    } else {
      ref
          .read(talkerProvider)
          .info('Follow-up message. Using Simple (text) prompt.');
      return _buildSimplePrompt(
        newPrompt,
        history: history,
        systemPrompt: conversationSettings.systemPrompt,
      );
    }
  }

  // Preserve the current text-based prompt as the simple fallback
  String _buildSimplePrompt(
    String newPrompt, {
    required List<Message> history,
    required String systemPrompt,
  }) {
    final contextBuffer = StringBuffer();

    if (systemPrompt.isNotEmpty) {
      contextBuffer.writeln(systemPrompt);
      contextBuffer.writeln();
    }

    for (final message in history) {
      final prefix = message.isFromUser ? 'User:' : 'Assistant:';
      contextBuffer.writeln('$prefix ${message.text}');
      contextBuffer.writeln(); // Add a blank line between messages
    }

    // Use a more descriptive intro for clarity
    final fullPrompt =
        '''
Here is the conversation history for context:

$contextBuffer
---

Now, please respond to the following:

User: $newPrompt
''';

    return fullPrompt.trim();
  }

  String _buildXmlPrompt(
    String newPrompt, {
    required List<Message> history,
    required GeneralSettingsData generalSettings,
    required ConversationSettings conversationSettings,
    required ProviderConfig providerConfig,
  }) {
    try {
      final systemPrompt = conversationSettings.systemPrompt;
      final shouldInjectSystemPrompt =
          systemPrompt.isNotEmpty && !providerConfig.supportsNativeSystemPrompt;

      // WHY: Use StringBuffer for efficient string concatenation to build the template.
      final promptBuffer = StringBuffer();

      // --- Part 1: Initial Instruction ---
      promptBuffer.writeln(_buildUserInputXml(newPrompt));
      if (shouldInjectSystemPrompt) {
        promptBuffer.writeln(_buildSystemPromptXml(systemPrompt));
      }

      // --- Part 2: Context ---
      promptBuffer.writeln('\n${generalSettings.historyContextInstruction}');
      final historyText = _buildHistoryText(history);
      final historyBuilder = XmlBuilder();
      historyBuilder.element(
        'history',
        nest: () {
          historyBuilder.text(historyText);
        },
      );
      promptBuffer.writeln(
        historyBuilder.buildDocument().toXmlString(pretty: true),
      );

      // --- Part 3: Repeated Instruction for Focus ---
      // WHY: Duplicate the user prompt and system prompt at the end to ensure the AI model
      // focuses on the most recent user input rather than getting lost in the context.
      promptBuffer.writeln(_buildUserInputXml(newPrompt));
      if (shouldInjectSystemPrompt) {
        promptBuffer.writeln(_buildSystemPromptXml(systemPrompt));
      }

      final finalPrompt = promptBuffer.toString().trim();
      final talker = ref.read(talkerProvider);
      talker.info('Generated XML Prompt Template:\n---\n$finalPrompt\n---');
      return finalPrompt;
    } on XmlException catch (e, st) {
      final talker = ref.read(talkerProvider);
      talker.handle(
        e,
        st,
        'XML fragment build error: ${e.message}. Falling back to simple prompt.',
      );
      // Fallback to the simple text format if XML building fails.
      return _buildSimplePrompt(
        newPrompt,
        history: history,
        systemPrompt: conversationSettings.systemPrompt,
      );
    }
  }

  /// Helper to build the system XML node as a string fragment.
  String _buildSystemPromptXml(String systemPrompt) {
    final builder = XmlBuilder();
    builder.element(
      'system',
      nest: () {
        // Use .text() for automatic XML entity escaping.
        builder.text(systemPrompt);
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Helper to build the history as a flat, human-readable string.
  String _buildHistoryText(List<Message> history) {
    final buffer = StringBuffer();

    // WHY: This logic correctly pairs User/Assistant messages into turns
    // and safely handles any orphaned messages, ensuring a clean log format.
    for (var i = 0; i < history.length;) {
      if (history[i].isFromUser) {
        final userMessage = history[i];
        final assistantMessage =
            (i + 1 < history.length && !history[i + 1].isFromUser)
            ? history[i + 1]
            : null;

        buffer.writeln('User: ${userMessage.text}');
        if (assistantMessage != null) {
          buffer.writeln('Assistant: ${assistantMessage.text}');
        }
        // Add a blank line between turns for better readability
        buffer.writeln();

        i += (assistantMessage != null) ? 2 : 1;
      } else {
        // Skip orphaned assistant messages
        i++;
      }
    }
    return buffer.toString().trim();
  }

  /// Helper to build user_input XML node as a string fragment.
  String _buildUserInputXml(String userInput) {
    final builder = XmlBuilder();
    builder.element(
      'user_input',
      nest: () {
        builder.text(userInput);
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }
}
