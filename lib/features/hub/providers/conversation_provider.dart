import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/provider_config_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/target_provider_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/prompt_builder.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_provider.g.dart';

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
// WHY: KeepAlive ensures the provider persists across widget rebuilds during async operations.
@Riverpod(keepAlive: true)
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
    // Signal UI to scroll to bottom after adding message
    ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
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

  /// Builds the automation options map from conversation settings and provider configuration.
  Map<String, dynamic> _buildAutomationOptions(String promptWithContext) {
    final conversationSettings = ref.read(conversationSettingsProvider);
    final providerConfig = ref.read(currentProviderConfigurationProvider);
    // WHY: Use maybeWhen to safely access AsyncValue in non-reactive context.
    // This prevents exceptions if the state is AsyncLoading or AsyncError.
    final generalSettings = ref
        .read(generalSettingsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const GeneralSettingsData(),
        );

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
    required String targetProviderId,
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    final talker = ref.read(talkerProvider);
    talker.info(
      '[Orchestration] Delegating full automation cycle to TypeScript...',
    );

    final db = ref.read(appDatabaseProvider);

    // WHY: Delegating prompt creation to a dedicated class cleans up this
    // method, allowing it to focus solely on orchestration.
    final promptBuilder = PromptBuilder(ref: ref, db: db);
    final promptWithContext = await promptBuilder.buildPromptWithContext(
      promptForContext,
      excludeMessageId: excludeMessageId,
      conversationId: conversationId,
    );

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

    // WHY: Store the prompt in the automation state so it can be retried after login
    ref
        .read(automationStateProvider.notifier)
        .moveToSending(prompt: promptForContext);

    if (!ref.mounted) {
      talker.warning(
        '[Orchestration] Bailed out: ref is not mounted after setting state.',
      );
      return;
    }

    try {
      // Step 1: Switch to the target provider's WebView tab
      // WHY: Each tab has its own WebView instance, so we must switch before accessing the bridge.
      final tabIndexMap = ref.read(providerTabIndexMapProvider);
      final tabIndex = tabIndexMap[targetProviderId];
      if (tabIndex == null) {
        throw StateError('No tab index found for provider: $targetProviderId');
      }

      ref.read(currentTabIndexProvider.notifier).changeTo(tabIndex);
      talker.info(
        '[Orchestration] Tab switch to index $tabIndex requested for provider $targetProviderId.',
      );

      // TIMING: Allow widget tree to update and WebView to initialize
      await Future<void>.delayed(Duration.zero);
      if (!ref.mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!ref.mounted) return;

      // Step 2: Reset bridge ready state
      // WHY: Ensure we wait for the bridge in the new tab, not the old one.
      ref.read(bridgeReadyProvider.notifier).reset();

      // Step 3: Trigger bridge ready signal if bridge is already injected
      // WHY: After reset, the bridge may be ready but hasn't signaled yet. Trigger it manually.
      final bridge = ref.read(javaScriptBridgeProvider);
      final controller = ref.read(webViewControllerProvider);
      if (controller != null) {
        try {
          await controller
              .evaluateJavascript(
                source: '''
            if (window.__AI_HYBRID_HUB_INITIALIZED__ && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('bridgeReady');
            }
          ''',
              )
              .timeout(const Duration(milliseconds: 500));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } on Object catch (e) {
          talker.debug(
            '[Orchestration] Could not trigger ready signal, will wait: $e',
          );
        }
      }

      // Step 4: Wait for bridge to be ready
      // WHY: Ensure the bridge in the new WebView instance is ready before proceeding.
      await bridge.waitForBridgeReady();
      if (!ref.mounted) return;

      // Step 5: Build automation options
      final automationOptions = _buildAutomationOptions(promptWithContext);
      talker.info(
        '[ConversationProvider LOG] Sending automation options to bridge: $automationOptions',
      );

      // Step 6: Delegate automation cycle to TypeScript
      // WHY: TypeScript handles resetState, waitForReady, applyAllSettings,
      // sendPrompt, and startObserving in a single autonomous cycle.
      await bridge.startAutomation(automationOptions);

      talker.info('[Orchestration] Full cycle delegated successfully.');

      if (ref.mounted) {
        await _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
          conversationId: conversationId,
        );

        ref.read(automationStateProvider.notifier).moveToObserving();
      }
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      // talker is already defined at the start of the method
      talker.handle(
        e,
        st,
        '[Orchestration] CRITICAL FAILURE during orchestration.',
      );
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

    // Get the target provider from the state
    final targetProviderId = ref.read(targetProviderIdProvider);
    if (targetProviderId == null) {
      // This should not happen if the UI is working correctly, but it's a safe fallback.
      ref
          .read(talkerProvider)
          .error('Send action triggered but no target provider was selected.');
      return;
    }

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
      if (!ref.mounted) return;
      ref.read(activeConversationIdProvider.notifier).set(activeId);
    }
    await _orchestrateAutomation(
      prompt,
      activeId,
      targetProviderId: targetProviderId,
      isResend: isResend,
      excludeMessageId: excludeMessageId,
    );
  }

  // Extract and return to Hub without finalizing automation
  Future<void> extractAndReturnToHub() async {
    final talker = ref.read(talkerProvider);
    talker.info('[ConversationProvider] extractAndReturnToHub called');
    final bridge = ref.read(javaScriptBridgeProvider);
    final automationNotifier = ref.read(automationStateProvider.notifier);
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    automationNotifier.setExtracting(extracting: true);

    try {
      talker.info(
        '[ConversationProvider] Calling bridge.extractFinalResponse()...',
      );
      final responseText = await bridge.extractFinalResponse();

      talker.info(
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
    } on Object catch (e, st) {
      if (ref.mounted) {
        ref
            .read(automationStateProvider.notifier)
            .setExtracting(extracting: false);
      }
      final talker = ref.read(talkerProvider);
      talker.handle(e, st, 'Response extraction failed.');
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

  Future<void> retryLastAutomation() async {
    final talker = ref.read(talkerProvider);
    talker.warning(
      '[ConversationProvider] Received retry request from bridge.',
    );

    final automationNotifier = ref.read(automationStateProvider.notifier);
    final lastPrompt = automationNotifier.currentPrompt;
    final activeId = ref.read(activeConversationIdProvider);

    if (lastPrompt != null && activeId != null) {
      talker.info('Retrying automation with prompt: "$lastPrompt"');
      await _updateLastMessage(
        'A transient error occurred. Retrying...',
        MessageStatus.sending,
        conversationId: activeId,
      );
      // Get the target provider for retry
      final targetProviderId = ref.read(targetProviderIdProvider);
      if (targetProviderId == null) {
        talker.error('Could not retry: no target provider selected.');
        await onAutomationFailed(
          'Could not perform automatic retry: no provider selected.',
        );
        return;
      }
      // Re-run the full orchestration logic from the start.
      await _orchestrateAutomation(
        lastPrompt,
        activeId,
        targetProviderId: targetProviderId,
        isResend: true,
      );
    } else {
      talker.error(
        'Could not retry: last prompt or active conversation ID is null.',
      );
      await onAutomationFailed('Could not perform automatic retry.');
    }
  }

  Future<void> _updateLastMessage(
    String text,
    MessageStatus status, {
    required int conversationId,
  }) async {
    if (!ref.mounted) return;

    final db = ref.read(appDatabaseProvider);

    // WHY: This query is more efficient as it fetches only the single last
    // message from the database instead of loading the entire list.
    // WHY: Order by createdAt timestamp instead of ID to ensure reliable ordering,
    // independent of ID generation timing or potential clock adjustments.
    final lastMessageQuery = db.select(db.messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);

    final lastMessageData = await lastMessageQuery.getSingleOrNull();

    // WHY: Explicitly check that a message exists and it is an assistant's "sending" message.
    // This prevents errors if the state is cleared while an async operation is in flight.
    if (lastMessageData != null) {
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
