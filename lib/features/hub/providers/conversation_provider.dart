import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/message_service_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/conversation_service.dart';
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
    final messageService = ref.read(messageServiceProvider.notifier);
    final messageId = messageService.generateMessageId();
    final message = Message(
      id: messageId,
      text: text,
      isFromUser: isFromUser,
      status: status ?? MessageStatus.success,
    );
    await messageService.addMessage(message, conversationId);
    // Signal UI to scroll to bottom after adding message
    ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
  }

  Future<void> updateMessageContent(String messageId, String newText) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // Get current message to update (scoped to active conversation)
    final messageService = ref.read(messageServiceProvider.notifier);
    final message = await messageService.getMessageById(messageId, activeId);
    if (message == null) return;

    final updatedMessage = Message(
      id: message.id,
      text: newText,
      isFromUser: message.isFromUser,
      status: message.status,
    );
    await messageService.updateMessage(updatedMessage);
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

  // WHY: Centralizes all conversation-related message updates in ConversationActions
  // to maintain a single source of truth for mutations, replacing the previous
  // _updateLastMessage in AutomationOrchestrator.
  Future<void> updateLastAssistantMessage(
    String text,
    MessageStatus status,
  ) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null || !ref.mounted) return;

    final messageService = ref.read(messageServiceProvider.notifier);
    final lastMessage = await messageService.getLastAssistantMessage(activeId);

    if (lastMessage != null) {
      final updatedMessage = Message(
        id: lastMessage.id,
        text: text,
        isFromUser: false,
        status: status,
      );
      // Delegate to the service layer
      await messageService.updateMessage(updatedMessage);
      await ref
          .read(conversationServiceProvider.notifier)
          .updateTimestamp(activeId);
    }
  }
}
