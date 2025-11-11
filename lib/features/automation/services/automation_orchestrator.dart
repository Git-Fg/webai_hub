import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/prompt_builder.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service responsible for orchestrating automation requests across providers.
/// WHY: Separating orchestration logic from ConversationActions improves
/// testability and adheres to the Single Responsibility Principle.
class AutomationOrchestrator {
  AutomationOrchestrator(this.ref);

  final Ref ref;

  /// Dispatches automation requests to the appropriate providers based on
  /// the number of selected presets.
  ///
  /// For single-provider workflows, adds a "sending" message and dispatches
  /// a single request. For multi-provider workflows, prepares staged responses
  /// and dispatches requests to all selected providers.
  ///
  /// [addMessage] is a callback to add messages to the conversation.
  /// This avoids circular dependencies with ConversationActions.
  Future<void> dispatch({
    required String prompt,
    required int conversationId,
    required List<int> selectedPresetIds,
    required Future<void> Function({
      required String text,
      required bool isFromUser,
      required int conversationId,
      MessageStatus? status,
    })
    addMessage,
    String? excludeMessageId,
  }) async {
    final talker = ref.read(talkerProvider);
    if (selectedPresetIds.isEmpty) {
      talker.warning(
        'AutomationOrchestrator.dispatch called with no selected presets.',
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);

    // --- CONDITIONAL WORKFLOW LOGIC ---
    if (selectedPresetIds.length == 1) {
      // --- Single Provider Workflow (Direct) ---
      talker.info('Starting single-provider workflow.');

      // Add a single "sending" message
      await addMessage(
        text: 'Sending...',
        isFromUser: false,
        status: MessageStatus.sending,
        conversationId: conversationId,
      );

      // This logic is now similar to the "command" pattern, but for one target
      final presetId = selectedPresetIds.first;
      // WHY: Exclude the just-added user message from history so it's treated as first message
      final promptWithContext = await PromptBuilder(ref: ref, db: db)
          .buildPromptWithContext(
            prompt,
            conversationId: conversationId,
            excludeMessageId: excludeMessageId,
          );

      ref.read(automationRequestProvider.notifier).addRequests({
        presetId: AutomationRequest(promptWithContext: promptWithContext),
      });
    } else {
      // --- Multi-Provider Workflow (Constructive) ---
      talker.info('Starting multi-provider constructive workflow.');
      ref.read(stagedResponsesProvider.notifier).clear();
      final allPresets = await ref.read(presetsProvider.future);
      final requests = <int, AutomationRequest>{};

      for (final presetId in selectedPresetIds) {
        final preset = allPresets.firstWhere((p) => p.id == presetId);
        // Add placeholder to staging area
        ref
            .read(stagedResponsesProvider.notifier)
            .addOrUpdate(
              StagedResponse(
                presetId: presetId,
                presetName: preset.name,
                text: 'Waiting to generate...',
                isLoading: true,
              ),
            );
        // WHY: Exclude the just-added user message from history so first message check works correctly
        final promptWithContext = await PromptBuilder(ref: ref, db: db)
            .buildPromptWithContext(
              prompt,
              conversationId: conversationId,
              excludeMessageId: excludeMessageId,
            );
        requests[presetId] = AutomationRequest(
          promptWithContext: promptWithContext,
        );
      }

      ref.read(automationRequestProvider.notifier).addRequests(requests);
    }
  }
}
