import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';

part 'conversation_provider.g.dart';

@riverpod
class PendingPrompt extends _$PendingPrompt {
  @override
  String? build() => null;

  void set(String prompt) {
    state = prompt;
  }

  void clear() {
    state = null;
  }
}

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

  void clearConversation() {
    state = [];
    ref.read(automationStateProvider.notifier).setStatus(AutomationStatus.idle);
  }

  Future<void> editAndResendPrompt(String messageId, String newText) async {
    // Trouver l'index du message à éditer.
    final messageIndex = state.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return; // Message non trouvé

    // Tronquer la conversation jusqu'au message édité (inclus).
    final truncatedConversation = state.sublist(0, messageIndex + 1);

    // Mettre à jour le texte du message édité.
    final editedMessage = truncatedConversation.last.copyWith(text: newText);
    truncatedConversation[messageIndex] = editedMessage;
    // Mettre à jour l'état avec la conversation tronquée et éditée.
    state = truncatedConversation;

    // Renvoyer le prompt.
    // On peut réutiliser la logique existante.
    await sendPromptToAutomation(newText,
        isResend: true, excludeMessageId: messageId);
  }

  /// Construit le prompt avec le contexte de conversation
  String _buildPromptWithContext(String newPrompt, {String? excludeMessageId}) {
    // Si c'est le premier message, retourner juste le prompt
    if (state.isEmpty ||
        state.where((m) => m.status == MessageStatus.success).isEmpty) {
      return newPrompt;
    }

    // Construire le contexte à partir des messages précédents (en excluant les messages d'erreur/envoi)
    final previousMessages = state.where((m) {
      if (m.status != MessageStatus.success) return false;
      if (excludeMessageId != null && m.id == excludeMessageId) return false;
      return true;
    }).toList();

    if (previousMessages.isEmpty) {
      return newPrompt;
    }

    // Format simple : inclure les échanges précédents
    final contextBuffer = StringBuffer();
    for (final message in previousMessages) {
      if (message.isFromUser) {
        contextBuffer.writeln('User: ${message.text}');
      } else {
        contextBuffer.writeln('Assistant: ${message.text}');
      }
      contextBuffer.writeln(); // Ligne vide entre les messages
    }

    // Construire le prompt final avec contexte
    final fullPrompt = '''
Context from previous conversation:

$contextBuffer
Current message:
User: $newPrompt
''';

    return fullPrompt.trim();
  }

  Future<void> sendPromptToAutomation(String prompt,
      {bool isResend = false, String? excludeMessageId}) async {
    // Construire le prompt avec contexte
    final promptWithContext =
        _buildPromptWithContext(prompt, excludeMessageId: excludeMessageId);

    // Stocker le prompt original (sans contexte) pour pouvoir le reprendre après login
    ref.read(pendingPromptProvider.notifier).set(prompt);

    // Si ce n'est pas un "resend", on ajoute le message utilisateur.
    // Si c'est un "resend", le message est déjà dans la liste.
    if (!isResend) {
      addMessage(prompt, true);
    }

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

      // Let Flutter's render cycle complete to build the WebView widget
      // Duration.zero cedes control to the event loop, allowing Flutter to
      // process widget rebuilds (IndexedStack shows WebView, AiWebviewScreen is created)
      await Future.delayed(Duration.zero);

      if (!ref.mounted) return;

      final bridge = ref.read(javaScriptBridgeProvider);

      // Wait for WebView to be created and bridge to be ready
      // This method handles all timing internally (WebView creation + JS bridge ready)
      await bridge.waitForBridgeReady();

      // Coussin de sécurité: laisser le temps au JS de la page de s'initialiser
      await Future.delayed(const Duration(milliseconds: 500));

      if (!ref.mounted) return;

      // Get console logs to debug selector issues (captured before automation starts)
      // Note: getCapturedLogs is only available on JavaScriptBridge, not on interface
      try {
        final jsBridge = bridge as JavaScriptBridge;
        final logs = await jsBridge.getCapturedLogs();
        if (logs.isNotEmpty) {
          // ignore: avoid_print
          print(
              '[ConversationProvider] JS Logs before automation: ${logs.map((log) => log['args']).toList()}');
        }
      } catch (e) {
        // Ignore cast errors in tests - FakeJavaScriptBridge doesn't extend JavaScriptBridge
      }

      await bridge.startAutomation(promptWithContext);

      if (ref.mounted) {
        ref
            .read(automationStateProvider.notifier)
            .setStatus(AutomationStatus.observing);
        
        // Déclencher l'observation active
        await _observeForCompletion();
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

  Future<void> _observeForCompletion() async {
    try {
      final bridge = ref.read(javaScriptBridgeProvider);
      
      await bridge.waitForResponseCompletion(timeout: const Duration(seconds: 60));
      if (ref.mounted) {
        ref.read(automationStateProvider.notifier).setStatus(AutomationStatus.refining);
      }
    } catch (e) {
      if (ref.mounted) {
        onAutomationFailed('Timeout: The model response took too long to appear or was not detected.');
      }
    }
  }

  Future<void> validateAndFinalizeResponse() async {
    final bridge = ref.read(javaScriptBridgeProvider);

    // Mettre l'état à "chargement"
    ref.read(isExtractingProvider.notifier).state = true;

    try {
      final responseText = await bridge.extractFinalResponse();
      if (ref.mounted) {
        _updateLastMessage(responseText, MessageStatus.success);

        // Nettoyer le prompt en attente
        ref.read(pendingPromptProvider.notifier).clear();

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
    } finally {
      // TRES IMPORTANT : remettre l'état à "pas de chargement", même en cas d'erreur.
      if (ref.mounted) {
        ref.read(isExtractingProvider.notifier).state = false;
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

  Future<void> resumeAutomationAfterLogin() async {
    final pendingPrompt = ref.read(pendingPromptProvider);
    if (pendingPrompt == null) {
      // Pas de prompt en attente, on arrête
      ref
          .read(automationStateProvider.notifier)
          .setStatus(AutomationStatus.idle);
      return;
    }

    // Reconstruire le prompt avec contexte (car la conversation peut avoir changé)
    final promptWithContext = _buildPromptWithContext(pendingPrompt);

    // Mettre à jour le message "Sending..." pour indiquer qu'on reprend
    _updateLastMessage(
        "Resuming automation after login...", MessageStatus.sending);

    ref
        .read(automationStateProvider.notifier)
        .setStatus(AutomationStatus.sending);

    if (!ref.mounted) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);

      // Attendre que le bridge soit prêt (au cas où le WebView a été rechargé)
      await bridge.waitForBridgeReady();
      await Future.delayed(const Duration(milliseconds: 500));

      if (!ref.mounted) return;

      // Vérifier que l'utilisateur n'est plus sur la page de login
      // (on va laisser startAutomation le détecter à nouveau si nécessaire)

      // Reprendre l'automatisation avec le prompt reconstruit avec contexte
      await bridge.startAutomation(promptWithContext);

      if (ref.mounted) {
        ref
            .read(automationStateProvider.notifier)
            .setStatus(AutomationStatus.observing);
        
        // Déclencher l'observation active
        await _observeForCompletion();
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
