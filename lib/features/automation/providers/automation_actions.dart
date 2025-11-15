import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/sequential_orchestrator_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/message_service_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/scroll_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/selected_staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/conversation_service.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_actions.g.dart';

@Riverpod(keepAlive: true)
class AutomationActions extends _$AutomationActions {
  @override
  void build() {} // No state needed

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

    final conversationService = ref.read(conversationServiceProvider.notifier);
    final activeId = await conversationService.getOrCreateActiveConversation(
      prompt,
    );
    if (!ref.mounted) return;

    String? userMessageId;
    if (!isResend) {
      final messageService = ref.read(messageServiceProvider.notifier);
      userMessageId = messageService.generateMessageId();
      final message = Message(
        id: userMessageId,
        text: prompt,
        isFromUser: true,
      );
      await messageService.addMessage(message, activeId);
      ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
    }

    await startMultiPresetAutomation(
      prompt: prompt,
      selectedPresetIds: selectedPresetIds,
      conversationId: activeId,
      excludeMessageId: excludeMessageId ?? userMessageId,
    );
  }

  Future<void> editAndResendPrompt(String messageId, String newText) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    final messageService = ref.read(messageServiceProvider.notifier);
    await messageService.truncateConversationFromMessage(messageId, activeId);

    // Delegate message update back to ConversationActions
    await ref
        .read(conversationActionsProvider.notifier)
        .updateMessageContent(
          messageId,
          newText,
        );

    final selectedPresetIds = ref.read(selectedPresetIdsProvider);
    if (selectedPresetIds.isEmpty) {
      ref
          .read(talkerProvider)
          .warning('Edit & Resend failed: No preset selected.');
      return;
    }

    // Call the method now local to this class
    await sendPromptToAutomation(
      newText,
      selectedPresetIds: selectedPresetIds,
      isResend: true,
      excludeMessageId: messageId,
    );
  }

  Future<void> startMultiPresetAutomation({
    required String prompt,
    required List<int> selectedPresetIds,
    required int conversationId,
    String? excludeMessageId,
  }) async {
    final talker = ref.read(talkerProvider);
    if (selectedPresetIds.isEmpty) {
      talker.warning(
        'startMultiPresetAutomation called with no selected presets.',
      );
      return;
    }

    // Start the sequential orchestrator
    unawaited(
      ref
          .read(sequentialOrchestratorProvider.notifier)
          .start(
            presetIds: selectedPresetIds,
            prompt: prompt,
            conversationId: conversationId,
            excludeMessageId: excludeMessageId,
          ),
    );
  }

  // WHY: This method synthesizes multiple selected responses into a single,
  // superior answer by using an AI model to analyze and merge best elements.
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
    await startMultiPresetAutomation(
      prompt: metaPrompt,
      selectedPresetIds: [synthesisPresetId],
      conversationId: activeId,
    );

    // Clear selections
    ref.read(selectedStagedResponsesProvider.notifier).clear();
  }

  // Extract and return to Hub without finalizing automation (for single-provider workflow)
  Future<void> extractAndReturnToHub(int presetId) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    final responseText = await _extractResponse(presetId);

    if (ref.mounted) {
      await ref
          .read(conversationActionsProvider.notifier)
          .updateLastAssistantMessage(
            responseText,
            MessageStatus.success,
          );
      ref.read(scrollToBottomRequestProvider.notifier).requestScroll();
      ref.read(currentTabIndexProvider.notifier).changeTo(0);
    }
  }

  // WHY: Finalizes a turn by adding the selected response to the conversation,
  // clearing staged responses, and returning automation to idle state.
  // This method belongs in AutomationActions as it orchestrates the
  // completion of an automation workflow.
  Future<void> finalizeTurnWithResponse(String responseText) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await ref
        .read(conversationActionsProvider.notifier)
        .addMessage(
          responseText,
          isFromUser: false,
          conversationId: activeId,
          status: MessageStatus.success,
        );
    ref.read(stagedResponsesProvider.notifier).clear();
    ref.read(automationStateProvider.notifier).returnToIdle();
  }

  Future<void> cancelAutomation() async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await ref
        .read(conversationActionsProvider.notifier)
        .updateLastAssistantMessage(
          'Automation cancelled by user.',
          MessageStatus.error,
        );
    ref.read(automationStateProvider.notifier).returnToIdle();

    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  Future<void> onAutomationFailed(String error) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    await ref
        .read(conversationActionsProvider.notifier)
        .updateLastAssistantMessage(
          'Automation failed: $error',
          MessageStatus.error,
        );
    ref.read(automationStateProvider.notifier).moveToFailed();
  }

  // NEW private helper method, moved from ConversationActions
  Future<String> _extractResponse(int presetId) async {
    final talker = ref.read(talkerProvider);
    talker.info(
      '[AutomationActions] Extracting response for preset: $presetId',
    );
    final bridge = ref.read(javaScriptBridgeProvider(presetId));
    final automationNotifier = ref.read(automationStateProvider.notifier);

    automationNotifier.setExtracting(extracting: true);

    try {
      final responseText = await bridge.extractFinalResponse();
      talker.info('[AutomationActions] Extraction successful.');
      return responseText;
    } on Object catch (e, st) {
      talker.handle(e, st, 'Response extraction failed.');
      if (e is AutomationError) rethrow;
      throw AutomationError(
        errorCode: AutomationErrorCode.responseExtractionFailed,
        location: 'extractResponse',
        message: 'An unexpected error occurred: $e',
      );
    } finally {
      if (ref.mounted) {
        automationNotifier.setExtracting(extracting: false);
      }
    }
  }
}
