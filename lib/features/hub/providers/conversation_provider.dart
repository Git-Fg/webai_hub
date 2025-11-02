import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
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
}