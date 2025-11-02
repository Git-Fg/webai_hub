import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';

part 'conversation_provider.g.dart';

@riverpod
class Conversation extends _$Conversation {
  @override
  List<Message> build() => [];

  void addMessage(String text, bool isFromUser, {MessageStatus? status}) {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isFromUser: isFromUser,
      status: status ?? MessageStatus.success,
    );
    state = [...state, message];
  }

  Future<void> sendPromptToAutomation(String prompt) async {
    addMessage(prompt, true);

    final assistantMessage = Message(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: "Sending...",
        isFromUser: false,
        status: MessageStatus.sending);
    state = [...state, assistantMessage];

    ref
        .read(automationStateProvider.notifier)
        .setStatus(AutomationStatus.sending);

    if (!ref.mounted) return;

    try {
      // Utilise le provider Riverpod qui EXISTE et FONCTIONNE
      ref.read(currentTabIndexProvider.notifier).changeTo(1);

      // Give Flutter time to build the WebView widget when tab switches
      // IndexedStack only builds visible widgets, so we need to wait
      await Future.delayed(const Duration(milliseconds: 1000));

      final bridge = ref.read(javaScriptBridgeProvider);

      // Wait for WebView to be created and bridge to be ready
      // This method handles all timing internally (WebView creation + JS bridge ready)
      await bridge.waitForBridgeReady();

      // Optional safety delay after bridge is ready for DOM framework initialization
      await Future.delayed(const Duration(milliseconds: 500));

      if (!ref.mounted) return;

      // Get console logs to debug selector issues (captured before automation starts)
      // Note: getCapturedLogs is only available on JavaScriptBridge, not on interface
      final jsBridge = bridge as JavaScriptBridge;
      final logs = await jsBridge.getCapturedLogs();
      if (logs.isNotEmpty) {
        // ignore: avoid_print
        print(
            '[ConversationProvider] JS Logs before automation: ${logs.map((log) => log['args']).toList()}');
      }

      await bridge.startAutomation(prompt);

      if (ref.mounted) {
        ref
            .read(automationStateProvider.notifier)
            .setStatus(AutomationStatus.observing);
      }
    } catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = "Error: ${e.message} (Code: ${e.errorCode.name})";
        } else {
          errorMessage = 'An unexpected error occurred: ${e.toString()}';
        }

        _updateLastMessage(errorMessage, MessageStatus.error);
        ref
            .read(automationStateProvider.notifier)
            .setStatus(AutomationStatus.failed);
      }
    }
  }

  void onGenerationComplete() {
    ref
        .read(automationStateProvider.notifier)
        .setStatus(AutomationStatus.refining);
  }

  Future<void> validateAndFinalizeResponse() async {
    final bridge = ref.read(javaScriptBridgeProvider);
    try {
      final responseText = await bridge.extractFinalResponse();
      if (ref.mounted) {
        _updateLastMessage(responseText, MessageStatus.success);

        ref
            .read(automationStateProvider.notifier)
            .setStatus(AutomationStatus.idle);

        ref.read(currentTabIndexProvider.notifier).changeTo(0);
      }
    } catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage =
              "Extraction Error: ${e.message} (Code: ${e.errorCode.name})";
        } else {
          errorMessage = 'Failed to extract response: ${e.toString()}';
        }

        _updateLastMessage(errorMessage, MessageStatus.error);
        ref
            .read(automationStateProvider.notifier)
            .setStatus(AutomationStatus.failed);
      }
    }
  }

  void cancelAutomation() {
    _updateLastMessage("Automation cancelled by user", MessageStatus.error);
    ref.read(automationStateProvider.notifier).setStatus(AutomationStatus.idle);

    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void onAutomationFailed(String error) {
    _updateLastMessage("Automation failed: $error", MessageStatus.error);
    ref
        .read(automationStateProvider.notifier)
        .setStatus(AutomationStatus.failed);
  }

  void _updateLastMessage(String text, MessageStatus status) {
    if (!ref.mounted) return;

    if (state.isNotEmpty) {
      final lastMessage = state.last;
      if (!lastMessage.isFromUser &&
          lastMessage.status == MessageStatus.sending) {
        final newMessages = List<Message>.from(state);
        newMessages[newMessages.length - 1] = lastMessage.copyWith(
          text: text,
          status: status,
        );
        state = newMessages;
      }
    }
  }
}
