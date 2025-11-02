import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'dart:math';

part 'conversation_provider.g.dart';

@riverpod
class Conversation extends _$Conversation {
  @override
  List<Message> build() => [];

  void addMessage(String text, bool isFromUser) {
    final message = Message(
      id: Random().nextDouble().toString(),
      text: text,
      isFromUser: isFromUser,
    );
    state = [...state, message];
  }

  Future<void> sendPromptToAutomation(String prompt) async {
    addMessage(prompt, true);

    final assistantMessageId = Random().nextDouble().toString();
    state = [
      ...state,
      Message(id: assistantMessageId, text: "Sending...", isFromUser: false, status: MessageStatus.sending)
    ];

    // Switch to WebView tab when automation starts
    final tabController = ref.read(tabControllerProvider);
    tabController?.animateTo(1); // Index 1 for WebView tab

    try {
      final bridge = ref.read(javaScriptBridgeProvider);
      await bridge.startAutomation(prompt);
    } catch (e) {
      state = state.map((m) {
        if (m.id == assistantMessageId) {
          return m.copyWith(text: "Automation error: ${e.toString()}", status: MessageStatus.error);
        }
        return m;
      }).toList();
    }
  }

  void onGenerationComplete() async {
    final bridge = ref.read(javaScriptBridgeProvider);
    try {
      final responseText = await bridge.extractFinalResponse();
      _updateLastMessage(responseText, MessageStatus.success);
    } catch (e) {
      _updateLastMessage("Failed to extract response: ${e.toString()}", MessageStatus.error);
    }
  }

  void onAutomationFailed(String error) {
    _updateLastMessage("Automation failed: $error", MessageStatus.error);
  }

  void _updateLastMessage(String text, MessageStatus status) {
    if (state.isNotEmpty) {
      final lastMessage = state.last;
      if (!lastMessage.isFromUser && lastMessage.status == MessageStatus.sending) {
        // Create a new list to ensure immutability
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