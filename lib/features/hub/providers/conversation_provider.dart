import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_orchestrator.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/message_service_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/conversation_service.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
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
  return db.watchMessagesForConversation(activeId).map((messageDataList) {
    return messageDataList.map((row) {
      return Message(
        id: row.id,
        text: row.content,
        isFromUser: row.isFromUser,
        status: row.status,
      );
    }).toList();
  });
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
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isFromUser: isFromUser,
      status: status ?? MessageStatus.success,
    );
    await ref
        .read(messageServiceProvider.notifier)
        .addMessage(message, conversationId);
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
    await ref.read(messageServiceProvider.notifier).updateMessage(message);
  }

  Future<void> clearConversation() async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // Delete the conversation (cascade deletes messages)
    await ref
        .read(conversationServiceProvider.notifier)
        .deleteConversation(activeId);
    ref.read(activeConversationIdProvider.notifier).set(null);
    ref.read(automationStateProvider.notifier).returnToIdle();
  }

  // WHY: This method allows updating the system prompt for the active conversation,
  // enabling persistent instructions that guide AI behavior across turns.
  Future<void> updateSystemPrompt(String newPrompt) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;
    await ref
        .read(conversationServiceProvider.notifier)
        .updateSystemPrompt(
          activeId,
          newPrompt.isEmpty ? null : newPrompt,
        );
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
    final selectedPresetIds = ref.read(selectedPresetIdsProvider);
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
      activeId = await ref
          .read(conversationServiceProvider.notifier)
          .createConversation(title);
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
      await ref
          .read(conversationServiceProvider.notifier)
          .updateTimestamp(activeId);
      ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
    }

    // DELEGATE to the new orchestrator provider
    await ref
        .read(automationOrchestratorProvider.notifier)
        .startMultiPresetAutomation(
          prompt: prompt,
          selectedPresetIds: selectedPresetIds,
          conversationId: activeId,
          excludeMessageId: excludeMessageId ?? userMessageId,
        );
  }
}
