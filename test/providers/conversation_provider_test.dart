// test/providers/conversation_provider_test.dart

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart'; // Pour importer currentTabIndexProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_javascript_bridge.dart';

// Mock Notifier pour les tests qui retourne toujours true
class AlwaysReadyBridge extends BridgeReady {
  @override
  bool build() => true;
}

void main() {
  group('ConversationProvider Tests', () {
    late ProviderContainer container;
    late FakeJavaScriptBridge fakeBridge;

    setUp(() {
      fakeBridge = FakeJavaScriptBridge();
      container = ProviderContainer(
        overrides: [
          javaScriptBridgeProvider.overrideWithValue(fakeBridge),
          // Forcer le bridge à être toujours prêt dans cet environnement de test unitaire.
          // Cela isole le test de la logique de cycle de vie de la WebView.
          bridgeReadyProvider.overrideWith(AlwaysReadyBridge.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is correct', () {
      final initialConversation = container.read(conversationProvider);
      final initialAutomation = container.read(automationStateProvider);
      final initialTab = container.read(currentTabIndexProvider);
      expect(initialConversation, isEmpty);
      expect(initialAutomation, const AutomationStateData.idle());
      expect(initialTab, 0);
    });

    test(
        'sendPromptToAutomation updates states, calls bridge, and requests tab switch',
        () async {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      // Ensure provider is initialized by reading it first
      final notifier = container.read(conversationProvider.notifier);

      // Act
      try {
        await notifier.sendPromptToAutomation('Hello');
      } catch (e, stackTrace) {
        // If there's an error, we want to see it with stack trace
        conversationSub.close();
        tabIndexSub.close();
        fail(
          'sendPromptToAutomation threw an error: $e\nStack trace: $stackTrace',
        );
      }

      // Assert
      final conversation = container.read(conversationProvider);
      expect(
        conversation.length,
        2,
        reason:
            'Expected 2 messages (user + assistant), got ${conversation.length}: ${conversation.map((m) => "${m.text} (${m.status})").toList()}',
      );
      expect(conversation[0].text, 'Hello');
      expect(conversation[1].status, MessageStatus.sending);

      expect(fakeBridge.lastPromptSent, 'Hello');
      // Après sendPromptToAutomation, on passe à l'état observing
      expect(
        container.read(automationStateProvider),
        const AutomationStateData.observing(),
      );

      // VERIFY: S'assurer que le provider de navigation a été mis à jour
      expect(container.read(currentTabIndexProvider), 1);

      conversationSub.close();
      tabIndexSub.close();
    });

    test(
        'extractAndReturnToHub updates message, clears pending prompt, stays in refining and returns to Hub',
        () async {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');

      // sendPromptToAutomation sets state to observing, then we need to simulate
      // the NEW_RESPONSE_DETECTED event to transition to refining
      // For this test, we'll manually set to refining to simulate the observer detecting the response
      container.read(automationStateProvider.notifier).setStatus(
            const AutomationStateData.refining(messageCount: 2),
          );

      await notifier.extractAndReturnToHub();

      final conversation = container.read(conversationProvider);
      expect(conversation.isNotEmpty, isTrue);

      // Find the last AI message (not the last message overall, in case there are errors)
      final lastAiMessage = conversation.lastWhere((m) => !m.isFromUser);
      expect(lastAiMessage.status, MessageStatus.success);
      expect(
        lastAiMessage.text,
        'This is a fake AI response from the test bridge.',
      );

      expect(fakeBridge.wasExtractCalled, isTrue);

      // VERIFY: L'état d'automatisation reste en refining
      expect(
        container.read(automationStateProvider),
        const AutomationStateData.refining(messageCount: 2),
      );

      // VERIFY: L'onglet retourne au Hub (0)
      expect(container.read(currentTabIndexProvider), 0);

      // VERIFY: Le pending prompt est effacé
      expect(container.read(pendingPromptProvider), isNull);

      conversationSub.close();
      tabIndexSub.close();
    });

    test('extractAndReturnToHub updates last AI message and stays in refining',
        () async {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');
      // Simuler l'extraction initiale réussie
      container.read(automationStateProvider.notifier).setStatus(
            const AutomationStateData.refining(messageCount: 2),
          );

      await notifier.extractAndReturnToHub();

      final conversation = container.read(conversationProvider);
      final lastAiMessage = conversation.lastWhere((m) => !m.isFromUser);
      expect(lastAiMessage.status, MessageStatus.success);
      expect(
        lastAiMessage.text,
        'This is a fake AI response from the test bridge.',
      );

      expect(
        container.read(automationStateProvider),
        const AutomationStateData.refining(messageCount: 2),
      );

      // Onglet retourne au Hub
      expect(container.read(currentTabIndexProvider), 0);

      conversationSub.close();
      tabIndexSub.close();
    });

    test('finalizeAutomation sets idle and returns to Hub tab', () async {
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      final notifier = container.read(conversationProvider.notifier);
      // Simuler un état de raffinement
      container.read(automationStateProvider.notifier).setStatus(
            const AutomationStateData.refining(messageCount: 2),
          );

      notifier.finalizeAutomation();

      expect(
        container.read(automationStateProvider),
        const AutomationStateData.idle(),
      );
      expect(container.read(currentTabIndexProvider), 0);

      tabIndexSub.close();
    });

    test(
        'cancelAutomation updates message, state, and requests tab switch back',
        () async {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      final notifier = container.read(conversationProvider.notifier);

      // First add messages to simulate a conversation with a sending message
      notifier
        ..addMessage('Hello', true)
        ..addMessage('Sending...', false, status: MessageStatus.sending);

      // Set status to refining to simulate ongoing automation
      container.read(automationStateProvider.notifier).setStatus(
            const AutomationStateData.refining(messageCount: 1),
          );

      notifier.cancelAutomation();

      final conversation = container.read(conversationProvider);
      expect(conversation.isNotEmpty, isTrue);
      expect(conversation.last.status, MessageStatus.error);
      expect(conversation.last.text, contains('cancelled'));
      expect(
        container.read(automationStateProvider),
        const AutomationStateData.idle(),
      );

      // VERIFY: S'assurer que le retour à l'onglet Hub a été demandé
      expect(container.read(currentTabIndexProvider), 0);

      conversationSub.close();
      tabIndexSub.close();
    });

    test(
        'sendPromptToAutomation handles bridge errors gracefully (generic Exception)',
        () async {
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      fakeBridge.startAutomationErrorType = ErrorType.genericException;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('a prompt that will fail');

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      expect(
        finalState,
        const AutomationStateData.failed(),
        reason: "L'état d'automatisation devrait être 'failed'",
      );
      expect(
        conversation.last.status,
        MessageStatus.error,
        reason: "Le dernier message devrait avoir un statut d'erreur",
      );
      expect(
        conversation.last.text,
        contains('An unexpected error occurred'),
        reason: "Le message d'erreur devrait être affiché",
      );
      expect(
        conversation.last.text,
        contains('Fake automation error'),
        reason: "Le message d'erreur devrait contenir le détail de l'exception",
      );

      conversationSub.close();
      tabIndexSub.close();
    });

    test('sendPromptToAutomation handles AutomationError correctly', () async {
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      fakeBridge.startAutomationErrorType = ErrorType.automationError;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('a prompt that will fail');

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      expect(
        finalState,
        const AutomationStateData.failed(),
        reason: "L'état d'automatisation devrait être 'failed'",
      );
      expect(
        conversation.last.status,
        MessageStatus.error,
        reason: "Le dernier message devrait avoir un statut d'erreur",
      );
      expect(
        conversation.last.text,
        contains('Error:'),
        reason: "Le message d'erreur devrait commencer par 'Error:'",
      );
      expect(
        conversation.last.text,
        contains('automationExecutionFailed'),
        reason: "Le message d'erreur devrait contenir le code d'erreur",
      );

      conversationSub.close();
      tabIndexSub.close();
    });

    test(
        'extractAndReturnToHub handles extraction errors gracefully and sets state to failed',
        () async {
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      fakeBridge.extractFinalResponseErrorType = ErrorType.genericException;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');

      // Set status to refining to simulate ongoing automation
      container.read(automationStateProvider.notifier).setStatus(
            const AutomationStateData.refining(messageCount: 1),
          );

      await notifier.extractAndReturnToHub();

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      // VERIFY: L'état d'automatisation passe à failed
      expect(
        finalState,
        const AutomationStateData.failed(),
        reason: "L'état d'automatisation devrait passer à 'failed'",
      );

      // VERIFY: Le message est mis à jour avec l'erreur
      final lastAiMessage = conversation.lastWhere((m) => !m.isFromUser);
      expect(
        lastAiMessage.status,
        MessageStatus.error,
        reason: 'Le message devrait être en état error',
      );
      expect(
        lastAiMessage.text,
        contains('Failed to extract response'),
        reason: "Le message devrait contenir le texte d'erreur",
      );

      conversationSub.close();
      tabIndexSub.close();
    });

    test(
        'extractAndReturnToHub handles AutomationError during extraction and sets state to failed',
        () async {
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      fakeBridge.extractFinalResponseErrorType = ErrorType.automationError;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');

      // Set status to refining to simulate ongoing automation
      container.read(automationStateProvider.notifier).setStatus(
            const AutomationStateData.refining(messageCount: 1),
          );

      await notifier.extractAndReturnToHub();

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      // VERIFY: L'état d'automatisation passe à failed
      expect(
        finalState,
        const AutomationStateData.failed(),
        reason: "L'état d'automatisation devrait passer à 'failed'",
      );

      // VERIFY: Le message est mis à jour avec l'erreur
      final lastAiMessage = conversation.lastWhere((m) => !m.isFromUser);
      expect(
        lastAiMessage.status,
        MessageStatus.error,
        reason: 'Le message devrait être en état error',
      );
      expect(
        lastAiMessage.text,
        contains('Extraction Error'),
        reason: "Le message devrait contenir le texte d'erreur avec le code",
      );

      conversationSub.close();
      tabIndexSub.close();
    });

    test('clearConversation resets the state to an empty list', () {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});

      // ARRANGE: Pré-peupler le provider avec des messages.
      final notifier = container.read(conversationProvider.notifier);

      notifier
        ..addMessage('Message 1', true)
        ..addMessage('Message 2', false);

      // S'assurer que l'état n'est pas vide au départ.
      final convBefore = container.read(conversationProvider);
      expect(convBefore, isNotEmpty);

      // ACT: Appeler la nouvelle méthode que nous allons créer.
      notifier.clearConversation();

      // ASSERT: Vérifier que l'état est maintenant une liste vide.
      final convAfter = container.read(conversationProvider);
      expect(convAfter, isEmpty);

      // Vérifier aussi que l'automatisation est réinitialisée à idle
      final automationAfter = container.read(automationStateProvider);
      expect(automationAfter, const AutomationStateData.idle());

      conversationSub.close();
    });

    test('editAndResendPrompt removes subsequent messages and resends prompt',
        () async {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      // ARRANGE
      final notifier = container.read(conversationProvider.notifier);

      // Créer une conversation initiale
      notifier.addMessage('Original Prompt', true);
      final originalMessageId = notifier.state.last.id;
      notifier
        ..addMessage('Original Response', false)
        ..addMessage('Another Prompt', true)
        ..addMessage('Another Response', false);
      final lengthAfterSeed = container.read(conversationProvider).length;
      expect(
        lengthAfterSeed,
        4,
        reason: 'Initial conversation should have 4 messages.',
      );

      // ACT
      const newPrompt = 'Edited Prompt';
      await notifier.editAndResendPrompt(originalMessageId, newPrompt);

      // ASSERT
      final conversation = container.read(conversationProvider);

      // 1. La conversation doit avoir 2 messages : le prompt édité, et le message "Sending...".
      //    Les messages qui suivaient le prompt original ont été supprimés.
      expect(
        conversation.length,
        2,
        reason:
            'Conversation should be truncated to 2 messages (edited + sending).',
      );

      // 2. Le premier message a été mis à jour.
      expect(conversation[0].text, newPrompt);

      // 3. Un nouveau message "Sending..." a été ajouté.
      expect(conversation[1].status, MessageStatus.sending);
      expect(conversation[1].isFromUser, false);

      // 4. Le bridge a bien été appelé avec le nouveau prompt.
      expect(fakeBridge.lastPromptSent, newPrompt);

      conversationSub.close();
      tabIndexSub.close();
    });
  });
}
