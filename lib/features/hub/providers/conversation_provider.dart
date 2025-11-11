import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/services/automation_orchestrator.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
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
  // WHY: Using Stream.fromIterable ensures immediate emission and proper stream behavior
  // with Riverpod's stream provider handling.
  if (activeId == null) {
    return Stream.fromIterable([<Message>[]]);
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

    // Get selected preset IDs directly from the provider
    final selectedPresetIdsAsync = ref.read(selectedPresetIdsProvider);
    final selectedPresetIds = selectedPresetIdsAsync.maybeWhen(
      data: (ids) => ids,
      orElse: () => <int>[],
    );
    if (selectedPresetIds.isEmpty) {
      ref
          .read(talkerProvider)
          .warning('Edit & Resend failed: No preset selected.');
      return;
    }

    await sendPromptToAutomation(
      newText,
      selectedPresetIds: selectedPresetIds,
      isResend: true,
      excludeMessageId: messageId,
    );
  }

  Future<void> sendPromptToAutomation(
    String prompt, {
    required List<int> selectedPresetIds,
    bool isResend = false,
    String? excludeMessageId,
  }) async {
    final talker = ref.read(talkerProvider);
    if (selectedPresetIds.isEmpty) {
      talker.warning('sendPromptToAutomation called with no selected presets.');
      return;
    }

    var activeId = ref.read(activeConversationIdProvider);
    final db = ref.read(appDatabaseProvider);

    // Create conversation if it doesn't exist
    if (activeId == null) {
      final title = prompt.length > 30 ? prompt.substring(0, 30) : prompt;
      final newConversation = ConversationsCompanion.insert(
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      activeId = await db.createConversation(newConversation);
      if (!ref.mounted) return;
      ref.read(activeConversationIdProvider.notifier).set(activeId);
    }

    if (!ref.mounted) return;

    // Add user's prompt to the conversation history
    String? userMessageId;
    if (!isResend) {
      userMessageId = DateTime.now().microsecondsSinceEpoch.toString();
      final message = Message(
        id: userMessageId,
        text: prompt,
        isFromUser: true,
      );
      await db.insertMessage(message, activeId);
      await db.updateConversationTimestamp(activeId, DateTime.now());
      ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
    }

    // Delegate orchestration to dedicated service
    final orchestrator = AutomationOrchestrator(ref);
    await orchestrator.dispatch(
      prompt: prompt,
      conversationId: activeId,
      selectedPresetIds: selectedPresetIds,
      excludeMessageId: excludeMessageId ?? userMessageId,
      addMessage:
          ({
            required String text,
            required bool isFromUser,
            required int conversationId,
            MessageStatus? status,
          }) async {
            await addMessage(
              text,
              isFromUser: isFromUser,
              conversationId: conversationId,
              status: status,
            );
          },
    );
  }

  Future<void> finalizeTurnWithResponse(String responseText) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await addMessage(
      responseText,
      isFromUser: false,
      conversationId: activeId,
      status: MessageStatus.success,
    );
    ref.read(stagedResponsesProvider.notifier).clear();
    ref.read(automationStateProvider.notifier).returnToIdle();
  }

  // Extract and return to Hub without finalizing automation (for single-provider workflow)
  Future<void> extractAndReturnToHub(int presetId) async {
    final talker = ref.read(talkerProvider);
    talker.info(
      '[ConversationProvider] extractAndReturnToHub called for preset: $presetId',
    );
    final bridge = ref.read(javaScriptBridgeProvider(presetId));
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

  Future<void> cancelAutomation() async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await _updateLastMessage(
      'Automation cancelled by user.',
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
