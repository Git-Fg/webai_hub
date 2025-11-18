import 'dart:async';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_actions.dart';
import 'package:ai_hybrid_hub/features/automation/providers/sequential_orchestrator_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event.dart';
import 'package:ai_hybrid_hub/features/webview/providers/bridge_events_provider.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker_flutter/talker_flutter.dart';

part 'bridge_events_observer.g.dart';

@riverpod
void bridgeEventsObserver(Ref ref, int presetId) {
  ref.listen<AsyncValue<BridgeEvent>>(
    bridgeEventsProvider(presetId),
    (previous, next) {
      final event = next.value;
      if (event == null) return;

      final notifier = ref.read(conversationActionsProvider.notifier);
      final automationNotifier = ref.read(automationStateProvider.notifier);
      final automationActions = ref.read(
        automationActionsProvider.notifier,
      );

      switch (event.type) {
        case BridgeConstants.eventTypeNewResponse:
          _handleNewResponse(
            event,
            notifier,
            automationNotifier,
            automationActions,
            ref,
            presetId,
          );
          return;
        case BridgeConstants.eventTypeLoginRequired:
          _handleLoginRequired(event, automationNotifier, ref, presetId);
          return;
        case BridgeConstants.eventTypeAutomationFailed:
          _handleAutomationFailed(event, automationActions, ref);
          return;
        case BridgeConstants.eventTypeAutomationRetryRequired:
          _handleAutomationRetryRequired(ref);
          return;
        default:
          _handleUnknownEvent(event, ref);
          return;
      }
    },
  );
}

void _handleNewResponse(
  BridgeEvent event,
  ConversationActions notifier,
  AutomationState automationNotifier,
  AutomationActions automationActions,
  Ref ref,
  int presetId,
) {
  // WHY: With sequential orchestration, orchestrator handles all extraction.
  // This event is now just a notification that sendPrompt completed.
  // For single-provider workflows, we still need to handle state transitions.
  // WHY: Check orchestrator state to determine single vs multi-provider workflow.
  // The orchestrator pre-populates staged responses even for single presets,
  // so we can't rely on stagedResponses.isEmpty. Instead, check the queue length.
  final orchestratorState = ref.read(sequentialOrchestratorProvider);
  final isMultiProvider = orchestratorState.maybeWhen(
    running: (queue, currentIndex) => queue.length > 1,
    orElse: () => false,
  );

  if (!isMultiProvider) {
    // Single-provider workflow: transition to refining state
    final conversationAsync = ref.read(conversationProvider);
    final messageCount = conversationAsync.maybeWhen(
      data: (conversation) => conversation.length,
      orElse: () => 0,
    );
    automationNotifier.moveToRefining(
      activePresetId: presetId,
      messageCount: messageCount,
    );

    // Check if YOLO mode should proceed automatically.
    final yoloModeEnabled =
        ref.read(generalSettingsProvider).value?.yoloModeEnabled ?? true;

    if (yoloModeEnabled) {
      // Trigger automatic extraction for single-provider workflow
      unawaited(
        automationActions.extractAndReturnToHub(presetId),
      );
    }
  }
  // Multi-provider workflows are handled entirely by orchestrator
}

void _handleLoginRequired(
  BridgeEvent event,
  AutomationState automationNotifier,
  Ref ref,
  int presetId,
) {
  // Read prompt from automation state notifier
  // This works even if state has transitioned from sending to observing
  final automationState = ref.read(automationStateProvider.notifier);
  final pendingPrompt = automationState.currentPrompt;
  if (pendingPrompt != null) {
    // Pass the entire resumption logic as a callback.
    automationNotifier.moveToNeedsLogin(
      onResume: () async {
        // WHY: Ensure retry uses the correct (and only current) preset ID.
        // Treat as a resend to avoid duplicate user messages.
        await ref
            .read(automationActionsProvider.notifier)
            .sendPromptToAutomation(
              pendingPrompt,
              selectedPresetIds: [presetId],
              isResend: true,
            );
      },
    );
  } else {
    // If no pending prompt, still transition to needsLogin but without callback
    automationNotifier.moveToNeedsLogin();
  }
}

void _handleAutomationFailed(
  BridgeEvent event,
  AutomationActions automationActions,
  Ref ref,
) {
  final payload = event.payload ?? 'Unknown error';
  final errorCode = event.errorCode;
  final location = event.location;
  final diagnostics = event.diagnostics;

  var errorMessage = payload;
  if (errorCode != null && location != null) {
    errorMessage = '[$errorCode]\n$payload\nLocation: $location';
    if (diagnostics != null && diagnostics.isNotEmpty) {
      final stateInfo = diagnostics.entries
          .where((entry) => entry.key != 'timestamp')
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
      if (stateInfo.isNotEmpty) {
        errorMessage += '\nState: $stateInfo';
      }
    }
  }

  unawaited(automationActions.onAutomationFailed(errorMessage));
}

void _handleAutomationRetryRequired(Ref ref) {
  ref
      .read(talkerProvider)
      .warning(
        '[Bridge Handler] Retry requested but retry logic not implemented for presets.',
      );
}

void _handleUnknownEvent(BridgeEvent event, Ref ref) {
  // Handle any unexpected event types
  // WHY: Wrap talker access in try-catch to handle any provider access issues
  Talker? talker;
  try {
    talker = ref.read(talkerProvider);
    talker?.info(
      '[Bridge Handler] Unknown event type: ${event.type}',
    );
  } on Object catch (e) {
    debugPrint(
      '[Bridge Handler] Failed to log unknown event: $e',
    );
  }
}
