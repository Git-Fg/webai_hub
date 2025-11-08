import 'dart:developer';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/provider_config_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

part 'conversation_provider.g.dart';

@riverpod
class PendingPrompt extends _$PendingPrompt {
  @override
  String? build() => null;

  void set(String prompt) {
    state = prompt;
  }

  void clear() {
    state = null;
  }
}

// WHY: This provider streams messages for the currently active conversation.
// It reacts to changes in activeConversationIdProvider to show the correct messages.
@riverpod
Stream<List<Message>> conversation(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final activeId = ref.watch(activeConversationIdProvider);

  // If no conversation is active, return an empty list.
  if (activeId == null) {
    return Stream.value([]);
  }

  // Otherwise, stream the messages for the active conversation.
  return db.watchMessagesForConversation(activeId);
}

// WHY: This NotifierProvider handles all actions that modify conversation state.
// Separating actions from data streaming provides a cleaner architecture.
@riverpod
class ConversationActions extends _$ConversationActions {
  @override
  void build() {} // No state to build

  Future<void> addMessage(
    String text, {
    required bool isFromUser,
    required int conversationId,
    MessageStatus? status,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isFromUser: isFromUser,
      status: status ?? MessageStatus.success,
    );
    await db.insertMessage(message, conversationId);
    // Update conversation timestamp
    await db.updateConversationTimestamp(conversationId, DateTime.now());
  }

  Future<void> updateMessageContent(String messageId, String newText) async {
    final db = ref.read(appDatabaseProvider);
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // Get current message to update (scoped to active conversation)
    final messages = await (db.select(
      db.messages,
    )..where((t) => t.conversationId.equals(activeId))).get();
    final messageData = messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw StateError('Message not found: $messageId'),
    );
    final message = Message(
      id: messageData.id,
      text: newText,
      isFromUser: messageData.isFromUser,
      status: messageData.status,
    );
    await db.updateMessage(message);
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

  Future<void> clearConversation() async {
    final db = ref.read(appDatabaseProvider);
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // Delete the conversation (cascade deletes messages)
    await db.deleteConversation(activeId);
    ref.read(activeConversationIdProvider.notifier).set(null);
    ref.read(automationStateProvider.notifier).returnToIdle();
    // WHY: When a new chat starts, we reset its specific settings to default.
    ref.invalidate(conversationSettingsProvider);
  }

  Future<void> editAndResendPrompt(String messageId, String newText) async {
    final db = ref.read(appDatabaseProvider);
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // Get messages scoped to active conversation
    final messages = await (db.select(
      db.messages,
    )..where((t) => t.conversationId.equals(activeId))).get();
    final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    // WHY: Truncate conversation to the edited message (inclusive) to maintain context consistency
    // Delete all messages after the edited one
    final messagesToDelete = messages.sublist(messageIndex + 1);
    for (final msg in messagesToDelete) {
      await (db.delete(db.messages)..where((f) => f.id.equals(msg.id))).go();
    }

    // Update the edited message
    await updateMessageContent(messageId, newText);

    await sendPromptToAutomation(
      newText,
      isResend: true,
      excludeMessageId: messageId,
    );
  }

  // Preserve the current text-based prompt as the simple fallback
  Future<String> _buildSimplePrompt(
    String newPrompt, {
    required int conversationId,
    String? excludeMessageId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final settings = ref.read(conversationSettingsProvider);
    final systemPrompt = settings.systemPrompt;
    final contextBuffer = StringBuffer();

    if (systemPrompt.isNotEmpty) {
      contextBuffer.writeln(systemPrompt);
      contextBuffer.writeln();
    }

    // Get messages scoped to conversation
    final messages = await (db.select(
      db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    final previousMessages = messages
        .map(
          (m) => Message(
            id: m.id,
            text: m.content,
            isFromUser: m.isFromUser,
            status: m.status,
          ),
        )
        .where((m) {
          return m.status == MessageStatus.success &&
              (excludeMessageId == null || m.id != excludeMessageId);
        })
        .toList();

    if (previousMessages.isEmpty) {
      // If no history, it's just system prompt + new prompt
      if (systemPrompt.isNotEmpty) {
        return '$systemPrompt\n\nUser: $newPrompt';
      }
      return newPrompt;
    }

    // This part is now cleaner
    for (final message in previousMessages) {
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

  Future<String> _buildXmlPrompt(
    String newPrompt, {
    required int conversationId,
    String? excludeMessageId,
  }) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final settingsAsync = ref.read(generalSettingsProvider);
      // Use .value to get the data, with a fallback to the default constructor.
      final generalSettings =
          settingsAsync.value ?? const GeneralSettingsData();

      final settings = ref.read(conversationSettingsProvider);
      final systemPrompt = settings.systemPrompt;
      final providerConfig = ref.read(currentProviderConfigurationProvider);

      // Get messages scoped to conversation
      final messages = await (db.select(
        db.messages,
      )..where((t) => t.conversationId.equals(conversationId))).get();
      final history = messages
          .map(
            (m) => Message(
              id: m.id,
              text: m.content,
              isFromUser: m.isFromUser,
              status: m.status,
            ),
          )
          .where(
            (m) =>
                m.id != excludeMessageId && m.status == MessageStatus.success,
          )
          .toList();

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
      if (history.isNotEmpty) {
        // Use the instruction from the settings object instead of a hardcoded string.
        promptBuffer.writeln('\n${generalSettings.historyContextInstruction}');

        // 1. Generate the history as a flat string.
        final historyText = _buildHistoryText(history);

        // 2. Build a simple XML block that contains the flat string.
        final historyBuilder = XmlBuilder();
        historyBuilder.element(
          'history',
          nest: () {
            // Use .text() to safely wrap the entire multi-line string.
            // This will handle any special characters correctly.
            historyBuilder.text(historyText);
          },
        );
        promptBuffer.writeln(
          historyBuilder.buildDocument().toXmlString(pretty: true),
        );
      }
      // Future <files> context would be added here.

      // --- Part 3: Repeated Instruction for Focus ---
      // WHY: Duplicate the user prompt and system prompt at the end to ensure the AI model
      // focuses on the most recent user input rather than getting lost in the context.
      promptBuffer.writeln(_buildUserInputXml(newPrompt));
      if (shouldInjectSystemPrompt) {
        promptBuffer.writeln(_buildSystemPromptXml(systemPrompt));
      }

      final finalPrompt = promptBuffer.toString().trim();
      log('Generated Prompt Template:\n---\n$finalPrompt\n---');
      return finalPrompt;
    } on XmlException catch (e) {
      log(
        'XML fragment build error: ${e.message}. Falling back to simple prompt.',
        error: e,
      );
      // WHY: On any XML failure, we fall back to the reliable simple prompt.
      return _buildSimplePrompt(
        newPrompt,
        excludeMessageId: excludeMessageId,
        conversationId: conversationId,
      );
    }
  }

  /// Constructs the prompt with conversation context via selected strategy
  Future<String> _buildPromptWithContext(
    String newPrompt, {
    required int conversationId,
    String? excludeMessageId,
  }) async {
    final settingsAsync = ref.read(generalSettingsProvider);
    final useAdvanced = settingsAsync.maybeWhen(
      data: (s) => s.useAdvancedPrompting,
      // WHY: Default to simple prompting until settings are loaded to avoid
      // impacting tests and first-frame behavior.
      orElse: () => false,
    );
    if (useAdvanced) {
      return _buildXmlPrompt(
        newPrompt,
        excludeMessageId: excludeMessageId,
        conversationId: conversationId,
      );
    } else {
      return _buildSimplePrompt(
        newPrompt,
        excludeMessageId: excludeMessageId,
        conversationId: conversationId,
      );
    }
  }

  /// Builds the automation options map from conversation settings and provider configuration.
  Map<String, dynamic> _buildAutomationOptions(String promptWithContext) {
    final conversationSettings = ref.read(conversationSettingsProvider);
    final providerConfig = ref.read(currentProviderConfigurationProvider);
    // Read the general settings
    final generalSettings =
        ref.read(generalSettingsProvider).value ?? const GeneralSettingsData();

    final automationOptions = <String, dynamic>{
      'prompt': promptWithContext,
      'model': conversationSettings.model,
      'temperature': conversationSettings.temperature,
      'topP': conversationSettings.topP,
      'thinkingBudget': conversationSettings.thinkingBudget,
      'disableThinking': conversationSettings.disableThinking,
      'useWebSearch': conversationSettings.useWebSearch,
      'urlContext': conversationSettings.urlContext,
      'timeoutModifier': generalSettings.timeoutModifier,
    };

    // Conditionally add system prompt based on provider capability
    if (conversationSettings.systemPrompt.isNotEmpty &&
        !providerConfig.supportsNativeSystemPrompt) {
      automationOptions['systemPrompt'] = conversationSettings.systemPrompt;
    }

    return automationOptions;
  }

  Future<void> _orchestrateAutomation(
    String promptForContext,
    int conversationId, {
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final promptWithContext = await _buildPromptWithContext(
      promptForContext,
      excludeMessageId: excludeMessageId,
      conversationId: conversationId,
    );

    // WHY: Store original prompt (without context) to resume after login
    ref.read(pendingPromptProvider.notifier).set(promptForContext);

    final assistantMessageId = DateTime.now().microsecondsSinceEpoch.toString();

    // WHY: The logic to add the user prompt and the assistant's placeholder is wrapped
    // in a transaction. This guarantees that both operations either succeed together or
    // fail together, preventing an inconsistent database state.
    await db.transaction(() async {
      if (!isResend) {
        await db.insertMessage(
          Message(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: promptForContext,
            isFromUser: true,
          ),
          conversationId,
        );
      }

      await db.insertMessage(
        Message(
          id: assistantMessageId,
          text: 'Sending...',
          isFromUser: false,
          status: MessageStatus.sending,
        ),
        conversationId,
      );
    });

    // Update conversation timestamp
    await db.updateConversationTimestamp(conversationId, DateTime.now());

    ref.read(automationStateProvider.notifier).moveToSending();

    if (!ref.mounted) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);

      // Switch to the WebView tab
      ref.read(currentTabIndexProvider.notifier).changeTo(1);

      // TIMING: Yield to event loop to ensure widget tree updates before WebView is touched.
      await Future<void>.delayed(Duration.zero);
      if (!ref.mounted) return;

      // WHY: A single, declarative call that handles everything.
      // This replaces loadUrl, the Completer, and the direct call to waitForBridgeReady.
      // The bridge encapsulates the entire load-and-wait cycle: reset state, load URL,
      // and poll until the bridge is ready (page loaded, script injected, JS signaled ready).
      await bridge.loadUrlAndWaitForReady(
        URLRequest(url: WebUri(WebViewConstants.aiStudioUrl)),
      );

      if (!ref.mounted) return;

      // Get console logs to debug selector issues (captured before automation starts)
      // Note: getCapturedLogs is only available on JavaScriptBridge, not on interface
      try {
        final jsBridge = bridge as JavaScriptBridge;
        final logs = await jsBridge.getCapturedLogs();
        if (logs.isNotEmpty) {
          debugPrint(
            '[ConversationProvider] JS Logs before automation: ${logs.map((log) => log['args']).toList()}',
          );
        }
      } on Object catch (_) {
        // Ignore cast errors in tests - FakeJavaScriptBridge doesn't extend JavaScriptBridge
      }

      final automationOptions = _buildAutomationOptions(promptWithContext);

      // DART-SIDE LOGGING FOR VERIFICATION
      log(
        '[ConversationProvider LOG] Sending automation options to bridge:',
        error: automationOptions,
      );

      // Start the automation with all configuration options.
      await bridge.startAutomation(automationOptions);

      if (ref.mounted) {
        await _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
          conversationId: conversationId,
        );

        ref.read(automationStateProvider.notifier).moveToObserving();

        await bridge.startResponseObserver();
      }
    } on Object catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = 'Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'An unexpected error occurred: $e';
        }

        await _updateLastMessage(
          errorMessage,
          MessageStatus.error,
          conversationId: conversationId,
        );
        ref.read(automationStateProvider.notifier).moveToFailed();
      }
    }
  }

  Future<void> sendPromptToAutomation(
    String prompt, {
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    var activeId = ref.read(activeConversationIdProvider);

    // If no conversation is active, create one.
    if (activeId == null) {
      final title = prompt.length > 30 ? prompt.substring(0, 30) : prompt;
      final newConversation = ConversationsCompanion.insert(
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // Drift returns the ID of the new row.
      activeId = await db.createConversation(newConversation);
      ref.read(activeConversationIdProvider.notifier).set(activeId);
    }

    // Now, proceed with orchestration using the activeId.
    await _orchestrateAutomation(
      prompt,
      activeId,
      isResend: isResend,
      excludeMessageId: excludeMessageId,
    );
  }

  // Extract and return to Hub without finalizing automation
  Future<void> extractAndReturnToHub() async {
    log('[ConversationProvider] extractAndReturnToHub called');
    final bridge = ref.read(javaScriptBridgeProvider);
    final automationNotifier = ref.read(automationStateProvider.notifier);
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    automationNotifier.setExtracting(extracting: true);

    try {
      log('[ConversationProvider] Calling bridge.extractFinalResponse()...');
      final responseText = await bridge.extractFinalResponse();

      log(
        '[ConversationProvider] Extraction successful, received ${responseText.length} chars',
      );

      // WHY: If we reach here, extraction succeeded even if non-critical errors were logged on JS side.
      // The important thing is that the Promise returned a value.
      if (ref.mounted) {
        await _updateLastMessage(
          responseText,
          MessageStatus.success,
          conversationId: activeId,
        );
        ref.read(pendingPromptProvider.notifier).clear();
        ref.read(currentTabIndexProvider.notifier).changeTo(0);
        // Signal UI to scroll to bottom after successful extraction
        ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
      }
      // WHY: Reset extracting state after successful extraction
      if (ref.mounted) {
        ref
            .read(automationStateProvider.notifier)
            .setExtracting(extracting: false);
      }
    } on Object catch (e) {
      if (ref.mounted) {
        ref
            .read(automationStateProvider.notifier)
            .setExtracting(extracting: false);
      }
      // WHY: The provider's responsibility is to manage state, not trigger UI.
      // By re-throwing the error, we let the UI layer decide how to present it.
      if (e is AutomationError) {
        rethrow; // Re-throw the specific error.
      }
      // Wrap other exceptions in a generic AutomationError.
      throw AutomationError(
        errorCode: AutomationErrorCode.responseExtractionFailed,
        location: 'extractAndReturnToHub',
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // Finalize automation and return to Hub
  void finalizeAutomation() {
    ref.read(automationStateProvider.notifier).returnToIdle();
    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  Future<void> cancelAutomation() async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await _updateLastMessage(
      'Automation cancelled by user',
      MessageStatus.error,
      conversationId: activeId,
    );
    ref.read(automationStateProvider.notifier).returnToIdle();

    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  Future<void> onAutomationFailed(String error) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await _updateLastMessage(
      'Automation failed: $error',
      MessageStatus.error,
      conversationId: activeId,
    );
    ref.read(automationStateProvider.notifier).moveToFailed();
  }

  Future<void> resumeAutomationAfterLogin() async {
    final pendingPrompt = ref.read(pendingPromptProvider);
    if (pendingPrompt == null) {
      ref.read(automationStateProvider.notifier).returnToIdle();
      return;
    }

    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // WHY: Rebuild prompt with context (conversation may have changed)
    final promptWithContext = await _buildPromptWithContext(
      pendingPrompt,
      conversationId: activeId,
    );

    await _updateLastMessage(
      'Resuming automation after login...',
      MessageStatus.sending,
      conversationId: activeId,
    );

    ref.read(automationStateProvider.notifier).moveToSending();

    if (!ref.mounted) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);

      // WHY: Wait for bridge to be ready (WebView may have been reloaded)
      await bridge.waitForBridgeReady();

      if (!ref.mounted) return;

      final automationOptions = _buildAutomationOptions(promptWithContext);

      // WHY: Let startAutomation detect login page again if necessary
      await bridge.startAutomation(automationOptions);

      if (ref.mounted) {
        await _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
          conversationId: activeId,
        );

        final db = ref.read(appDatabaseProvider);
        final messages = await (db.select(
          db.messages,
        )..where((t) => t.conversationId.equals(activeId))).get();
        ref
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: messages.length);
      }
    } on Object catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = 'Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'An unexpected error occurred: $e';
        }

        await _updateLastMessage(
          errorMessage,
          MessageStatus.error,
          conversationId: activeId,
        );
        ref.read(automationStateProvider.notifier).moveToFailed();
      }
    }
  }

  Future<void> _updateLastMessage(
    String text,
    MessageStatus status, {
    required int conversationId,
  }) async {
    if (!ref.mounted) return;

    final db = ref.read(appDatabaseProvider);
    final messages = await (db.select(
      db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).get();

    // WHY: Explicitly check that messages list is not empty and the last message is an assistant's "sending" message.
    // This prevents errors if the state is cleared while an async operation is in flight.
    if (messages.isNotEmpty) {
      final lastMessageData = messages.last;
      final lastMessage = Message(
        id: lastMessageData.id,
        text: lastMessageData.content,
        isFromUser: lastMessageData.isFromUser,
        status: lastMessageData.status,
      );

      if (!lastMessage.isFromUser &&
          lastMessage.status == MessageStatus.sending) {
        final updatedMessage = lastMessage.copyWith(text: text, status: status);
        await db.updateMessage(updatedMessage);
        // Update conversation timestamp
        await db.updateConversationTimestamp(conversationId, DateTime.now());
      }
    }
  }
}
