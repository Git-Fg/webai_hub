import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  // ignore: avoid_positional_boolean_parameters, reason: Compact API for widget call sites
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
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.idle());
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
    await sendPromptToAutomation(
      newText,
      isResend: true,
      excludeMessageId: messageId,
    );
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

  Future<void> sendPromptToAutomation(
    String prompt, {
    bool isResend = false,
    String? excludeMessageId,
  }) async {
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
      text: 'Sending...',
      isFromUser: false,
      status: MessageStatus.sending,
    );
    state = [...state, assistantMessage];

    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.sending());

    if (!ref.mounted) return;

    try {
      // Utilise le provider Riverpod qui EXISTE et FONCTIONNE
      ref.read(currentTabIndexProvider.notifier).changeTo(1);

      // Let Flutter's render cycle complete to build the WebView widget
      // Duration.zero cedes control to the event loop, allowing Flutter to
      // process widget rebuilds (IndexedStack shows WebView, AiWebviewScreen is created)
      await Future<void>.delayed(Duration.zero);

      if (!ref.mounted) return;

      final bridge = ref.read(javaScriptBridgeProvider);

      // Wait for WebView to be created and bridge to be ready
      // This method handles all timing internally (WebView creation + JS bridge ready)
      await bridge.waitForBridgeReady();

      // TIMING: plus de délai fixe; la détection se fait côté JS par notification immédiate

      if (!ref.mounted) return;

      // Get console logs to debug selector issues (captured before automation starts)
      // Note: getCapturedLogs is only available on JavaScriptBridge, not on interface
      try {
        final jsBridge = bridge as JavaScriptBridge;
        final logs = await jsBridge.getCapturedLogs();
        if (logs.isNotEmpty) {
          debugPrint(
            '[ConversationProvider] JS Logs before automation: ${logs.map((log) => log['args']).toList()}',
          );
        }
      } on Object catch (_) {
        // Ignore cast errors in tests - FakeJavaScriptBridge doesn't extend JavaScriptBridge
      }

      await bridge.startAutomation(promptWithContext);

      // --- MODIFICATION CRUCIALE ---
      if (ref.mounted) {
        // Mettre à jour le message placeholder
        _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
        );

        // Passer à l'état "observing"
        ref.read(automationStateProvider.notifier).setStatus(
              const AutomationStateData.observing(),
            );

        // Démarrer l'observateur côté JavaScript
        await bridge.startResponseObserver();
      }

      // --- SUPPRIMÉ ---
      // Toute la logique d'attente de complétion est retirée.
      // await bridge.waitForResponseCompletion(...);
    } on Object catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = 'Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'An unexpected error occurred: $e';
        }

        _updateLastMessage(errorMessage, MessageStatus.error);
        ref
            .read(automationStateProvider.notifier)
            .setStatus(const AutomationStateData.failed());
      }
    }
  }

  // Extraire et revenir au Hub sans finaliser l'automatisation
  Future<void> extractAndReturnToHub() async {
    final bridge = ref.read(javaScriptBridgeProvider);
    // On active l'indicateur de chargement
    ref.read(isExtractingProvider.notifier).state = true;

    try {
      // On attend le résultat de l'extraction.
      final responseText = await bridge.extractFinalResponse();

      // Si on arrive ici, l'extraction a réussi, même si des erreurs non critiques
      // ont été loguées côté JS. Le plus important est que la Promise a retourné une valeur.
      if (ref.mounted) {
        _updateLastMessage(responseText, MessageStatus.success);
        ref.read(pendingPromptProvider.notifier).clear();
        ref.read(currentTabIndexProvider.notifier).changeTo(0);
      }
    } on Object catch (e) {
      // Si on arrive ici, c'est qu'une VRAIE exception a été levée,
      // empêchant la Promise de retourner une valeur.
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage =
              'Extraction Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'Failed to extract response: $e';
        }
        _updateLastMessage(errorMessage, MessageStatus.error);
        // On passe à l'état failed SEULEMENT si l'extraction échoue.
        ref.read(automationStateProvider.notifier).setStatus(
              const AutomationStateData.failed(),
            );
      }
    } finally {
      // Ce bloc s'exécute après le try OU le catch, garantissant que
      // l'indicateur de chargement est toujours désactivé.
      if (ref.mounted) {
        ref.read(isExtractingProvider.notifier).state = false;
      }
    }
  }

  // Finalise l'automatisation et retourne au Hub
  void finalizeAutomation() {
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.idle());
    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void cancelAutomation() {
    _updateLastMessage('Automation cancelled by user', MessageStatus.error);
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.idle());

    ref.read(currentTabIndexProvider.notifier).changeTo(0);
  }

  void onAutomationFailed(String error) {
    _updateLastMessage('Automation failed: $error', MessageStatus.error);
    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.failed());
  }

  Future<void> resumeAutomationAfterLogin() async {
    final pendingPrompt = ref.read(pendingPromptProvider);
    if (pendingPrompt == null) {
      // Pas de prompt en attente, on arrête
      ref
          .read(automationStateProvider.notifier)
          .setStatus(const AutomationStateData.idle());
      return;
    }

    // Reconstruire le prompt avec contexte (car la conversation peut avoir changé)
    final promptWithContext = _buildPromptWithContext(pendingPrompt);

    // Mettre à jour le message "Sending..." pour indiquer qu'on reprend
    _updateLastMessage(
      'Resuming automation after login...',
      MessageStatus.sending,
    );

    ref
        .read(automationStateProvider.notifier)
        .setStatus(const AutomationStateData.sending());

    if (!ref.mounted) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider);

      // Attendre que le bridge soit prêt (au cas où le WebView a été rechargé)
      await bridge.waitForBridgeReady();

      if (!ref.mounted) return;

      // Vérifier que l'utilisateur n'est plus sur la page de login
      // (on va laisser startAutomation le détecter à nouveau si nécessaire)

      // Reprendre l'automatisation avec le prompt reconstruit avec contexte
      await bridge.startAutomation(promptWithContext);

      if (ref.mounted) {
        // Mettre à jour le message "placeholder" pour inviter l'utilisateur à valider
        _updateLastMessage(
          'Assistant is responding in the WebView...',
          MessageStatus.sending,
        );

        // Passer directement à l'état "refining"
        ref.read(automationStateProvider.notifier).setStatus(
              AutomationStateData.refining(
                messageCount: state.length,
              ),
            );
      }
    } on Object catch (e) {
      if (ref.mounted) {
        String errorMessage;
        if (e is AutomationError) {
          errorMessage = 'Error: ${e.message} (Code: ${e.errorCode.name})';
        } else {
          errorMessage = 'An unexpected error occurred: $e';
        }

        _updateLastMessage(errorMessage, MessageStatus.error);
        ref
            .read(automationStateProvider.notifier)
            .setStatus(const AutomationStateData.failed());
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
