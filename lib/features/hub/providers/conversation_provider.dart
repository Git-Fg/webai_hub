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
    // 1. Ajouter le message de l'utilisateur
    addMessage(prompt, true);

    // 2. Ajouter un message "envoi en cours"
    final assistantMessageId = Random().nextDouble().toString();
    state = [
      ...state,
      Message(id: assistantMessageId, text: "Envoi en cours...", isFromUser: false, status: MessageStatus.sending)
    ];

    // 3. Appeler le pont
    try {
      print("🤖 Calling automation bridge...");
      final bridge = ref.read(javaScriptBridgeProvider);
      await bridge.startAutomation(prompt);
      print("✅ Automation bridge call completed");
    } catch (e) {
      print("❌ Automation bridge failed: $e");
      // Gérer l'échec de l'automatisation
      state = state.map((m) {
        if (m.id == assistantMessageId) {
          return m.copyWith(text: "Erreur d'automatisation: ${e.toString()}", status: MessageStatus.error);
        }
        return m;
      }).toList();
    }
  }
}