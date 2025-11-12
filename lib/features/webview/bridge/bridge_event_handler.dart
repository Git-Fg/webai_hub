import 'dart:async';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Handler for bridge events from the JavaScript automation engine.
/// WHY: Separating event handling logic from AiWebviewScreen improves
/// testability and adheres to the Single Responsibility Principle.
class BridgeEventHandler {
  BridgeEventHandler(this.ref, this.presetId, this.presetName);

  final WidgetRef ref;
  final int presetId;
  final String presetName;

  /// Handles bridge events from the JavaScript automation engine.
  /// Parses the event and routes it to the appropriate handler based on event type.
  void handle(List<dynamic> args) {
    if (args.isEmpty || args[0] is! Map) return;
    try {
      final json = Map<String, dynamic>.from(args[0] as Map);
      final event = BridgeEvent.fromJson(json);
      final notifier = ref.read(conversationActionsProvider.notifier);
      final automationNotifier = ref.read(
        automationStateProvider.notifier,
      );

      switch (event.type) {
        case BridgeConstants.eventTypeNewResponse:
          _handleNewResponse(event, notifier, automationNotifier);
          return;
        case BridgeConstants.eventTypeLoginRequired:
          _handleLoginRequired(event, automationNotifier);
          return;
        case BridgeConstants.eventTypeAutomationFailed:
          _handleAutomationFailed(event, notifier);
          return;
        case BridgeConstants.eventTypeAutomationRetryRequired:
          _handleAutomationRetryRequired();
          return;
        default:
          _handleUnknownEvent(event);
          return;
      }
    } on Object catch (e) {
      // WHY: Wrap talker access in try-catch to handle any provider access issues
      Talker? talker;
      try {
        talker = ref.read(talkerProvider);
        talker?.info('[Bridge Handler] Failed to parse event: $e');
      } on Object catch (logError) {
        debugPrint(
          '[Bridge Handler] Failed to log parse error: $logError',
        );
      }
    }
  }

  void _handleNewResponse(
    BridgeEvent event,
    ConversationActions notifier,
    AutomationState automationNotifier,
  ) {
    // WHY: With sequential orchestration, the orchestrator handles all extraction.
    // This event is now just a notification that sendPrompt completed.
    // For single-provider workflows, we still need to handle state transitions.
    final stagedResponses = ref.read(stagedResponsesProvider);
    final isMultiProvider = stagedResponses.isNotEmpty;

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
          notifier.extractAndReturnToHub(presetId),
        );
      }
    }
    // Multi-provider workflows are handled entirely by the orchestrator
  }

  void _handleLoginRequired(
    BridgeEvent event,
    AutomationState automationNotifier,
  ) {
    // Read the prompt from the automation state notifier
    // This works even if state has transitioned from sending to observing
    final automationState = ref.read(
      automationStateProvider.notifier,
    );
    final pendingPrompt = automationState.currentPrompt;
    if (pendingPrompt != null) {
      // Pass the entire resumption logic as a callback.
      automationNotifier.moveToNeedsLogin(
        onResume: () async {
          // WHY: Ensure the retry uses the correct (and only the current) preset ID.
          // Treat as a resend to avoid duplicate user messages.
          await ref
              .read(conversationActionsProvider.notifier)
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
    ConversationActions notifier,
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

    unawaited(notifier.onAutomationFailed(errorMessage));
  }

  void _handleAutomationRetryRequired() {
    ref
        .read(talkerProvider)
        .warning(
          '[Bridge Handler] Retry requested but retry logic not implemented for presets.',
        );
  }

  void _handleUnknownEvent(BridgeEvent event) {
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
}
