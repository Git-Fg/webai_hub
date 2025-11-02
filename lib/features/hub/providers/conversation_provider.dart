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

  void addMessage(String text, bool isFromUser) {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isFromUser: isFromUser,
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
      final tabController = ref.read(tabControllerProvider);
      if (tabController != null) {
        ref.read(currentTabIndexProvider.notifier).changeTo(1);
        tabController.animateTo(1);
      }

      await ref.read(bridgeReadyProvider).future;

      if (!ref.mounted) return;

      final bridge = ref.read(javaScriptBridgeProvider);
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

        final tabController = ref.read(tabControllerProvider);
        tabController?.animateTo(0);
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

    final tabController = ref.read(tabControllerProvider);
    tabController?.animateTo(0);
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
