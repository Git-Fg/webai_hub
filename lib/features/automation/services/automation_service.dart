import 'dart:async';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_service.g.dart';

@riverpod
class AutomationService extends _$AutomationService {
  @override
  void build() {
    // No state to build
  }

  Future<String> extractResponse(int presetId) async {
    final talker = ref.read(talkerProvider);
    talker.info(
      '[AutomationService] Extracting response for preset: $presetId',
    );
    final bridge = ref.read(javaScriptBridgeProvider(presetId));
    final automationNotifier = ref.read(automationStateProvider.notifier);

    automationNotifier.setExtracting(extracting: true);

    try {
      final responseText = await bridge.extractFinalResponse();
      talker.info('[AutomationService] Extraction successful.');
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

  Future<void> handleAutomationFailure(String error, int conversationId) async {
    await ref
        .read(conversationActionsProvider.notifier)
        .onAutomationFailed(error);
  }
}
