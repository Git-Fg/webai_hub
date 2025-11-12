import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/sequential_orchestrator_provider.dart';
import 'package:ai_hybrid_hub/features/automation/services/automation_service.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/message_service_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/selected_staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
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
    final db = ref.read(appDatabaseProvider);
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    // Delete the conversation (cascade deletes messages)
    await db.deleteConversation(activeId);
    ref.read(activeConversationIdProvider.notifier).set(null);
    ref.read(automationStateProvider.notifier).returnToIdle();
  }

  // WHY: This method allows updating the system prompt for the active conversation,
  // enabling persistent instructions that guide AI behavior across turns.
  Future<void> updateSystemPrompt(String newPrompt) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;
    await ref
        .read(appDatabaseProvider)
        .updateConversationSystemPrompt(
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

    // Pre-populate staged responses with "waiting" placeholders
    ref.read(stagedResponsesProvider.notifier).clear();
    final allPresets = await ref.read(presetsProvider.future);
    for (final presetId in selectedPresetIds) {
      final preset = allPresets.firstWhere((p) => p.id == presetId);
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: presetId,
              presetName: preset.name,
              text: 'Waiting in queue...',
              isLoading: true,
            ),
          );
    }

    // Start the sequential orchestrator
    unawaited(
      ref
          .read(sequentialOrchestratorProvider.notifier)
          .start(
            presetIds: selectedPresetIds,
            prompt: prompt,
            conversationId: activeId,
            excludeMessageId: excludeMessageId ?? userMessageId,
          ),
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

  // WHY: This method synthesizes multiple selected responses into a single,
  // superior answer by using an AI model to analyze and merge the best elements.
  Future<void> synthesizeResponses() async {
    final talker = ref.read(talkerProvider);
    final selectedIds = ref.read(selectedStagedResponsesProvider);
    if (selectedIds.length < 2) {
      talker.warning('Synthesis requires at least 2 selected responses.');
      return;
    }

    final allStaged = ref.read(stagedResponsesProvider);
    final selectedResponses = allStaged.values
        .where((r) => selectedIds.contains(r.presetId))
        .toList();

    // Get the original prompt from the last user message
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) {
      talker.error('Cannot synthesize: no active conversation.');
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final messages =
        await (db.select(db.messages)
              ..where((t) => t.conversationId.equals(activeId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    final lastUserMessage = messages.firstWhere(
      (m) => m.isFromUser,
      orElse: () => throw StateError('No user message found'),
    );
    final originalPrompt = lastUserMessage.content;

    // Get first available preset as synthesizer
    final allPresets = await ref.read(presetsProvider.future);
    final presetPresets = allPresets
        .where((p) => p.providerId != null)
        .toList();
    if (presetPresets.isEmpty) {
      talker.error('Cannot synthesize: no presets available.');
      return;
    }
    final synthesisPresetId = presetPresets.first.id;

    // Construct the meta-prompt
    final responsesText = selectedResponses
        .map((r) => '<response from="${r.presetName}">\n${r.text}\n</response>')
        .join('\n\n');
    final metaPrompt =
        '''
Based on the original prompt: "$originalPrompt"

Analyze the following AI-generated responses. Identify the strengths and weaknesses of each, and then synthesize them into a single, superior response that incorporates the best elements of all provided answers.

$responsesText
''';

    // Mark the new response as "Synthesizing..."
    ref
        .read(stagedResponsesProvider.notifier)
        .addOrUpdate(
          const StagedResponse(
            presetId: -1, // Special ID for synthesized response
            presetName: 'Synthesized',
            text: 'Synthesizing...',
            isLoading: true,
          ),
        );

    // Dispatch the new automation request
    await sendPromptToAutomation(
      metaPrompt,
      selectedPresetIds: [synthesisPresetId],
      isResend: true, // Prevents creating a new user message
    );

    // Clear selections
    ref.read(selectedStagedResponsesProvider.notifier).clear();
  }

  // Extract and return to Hub without finalizing automation (for single-provider workflow)
  Future<void> extractAndReturnToHub(int presetId) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    final responseText = await ref
        .read(automationServiceProvider.notifier)
        .extractResponse(presetId);

    if (ref.mounted) {
      await _updateLastMessage(
        responseText,
        MessageStatus.success,
        conversationId: activeId,
      );
      ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
      ref.read(currentTabIndexProvider.notifier).changeTo(0);
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

    final query = db.select(db.messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..where((t) => t.status.equals(MessageStatus.sending.name))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);

    final messageToUpdate = await query.getSingleOrNull();

    if (messageToUpdate != null) {
      final updatedMessage = Message(
        id: messageToUpdate.id,
        text: text,
        isFromUser: false,
        status: status,
      );
      await ref
          .read(messageServiceProvider.notifier)
          .updateMessage(updatedMessage);
      await db.updateConversationTimestamp(conversationId, DateTime.now());
    }
  }
}
