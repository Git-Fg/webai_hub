// test/providers/conversation_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart'; // Pour importer currentTabIndexProvider
import '../fakes/fake_javascript_bridge.dart';

void main() {
  group('ConversationProvider Tests', () {
    late ProviderContainer container;
    late FakeJavaScriptBridge fakeBridge;

    setUp(() {
      fakeBridge = FakeJavaScriptBridge();
      container = ProviderContainer(
        overrides: [
          javaScriptBridgeProvider.overrideWithValue(fakeBridge),
        ],
      );
      // Mark bridge as ready immediately for tests
      // We read it first to ensure it's created, then mark it ready
      final bridgeReadyNotifier = container.read(bridgeReadyProvider.notifier);
      bridgeReadyNotifier.markReady();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is correct', () {
      expect(container.read(conversationProvider), isEmpty);
      expect(container.read(automationStateProvider), AutomationStatus.idle);
      expect(container.read(currentTabIndexProvider), 0);
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
        await notifier.sendPromptToAutomation("Hello");
      } catch (e, stackTrace) {
        // If there's an error, we want to see it with stack trace
        conversationSub.close();
        tabIndexSub.close();
        fail(
            'sendPromptToAutomation threw an error: $e\nStack trace: $stackTrace');
      }

      // Assert
      final conversation = container.read(conversationProvider);
      expect(conversation.length, 2,
          reason:
              'Expected 2 messages (user + assistant), got ${conversation.length}: ${conversation.map((m) => "${m.text} (${m.status})").toList()}');
      expect(conversation[0].text, "Hello");
      expect(conversation[1].status, MessageStatus.sending);

      expect(fakeBridge.lastPromptSent, "Hello");
      expect(
          container.read(automationStateProvider), AutomationStatus.observing);

      // VERIFY: S'assurer que le provider de navigation a été mis à jour
      expect(container.read(currentTabIndexProvider), 1);

      conversationSub.close();
      tabIndexSub.close();
    });

    test(
        'validateAndFinalizeResponse updates message, state, and requests tab switch back',
        () async {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation("Hello");
      notifier.onGenerationComplete();

      await notifier.validateAndFinalizeResponse();

      final conversation = container.read(conversationProvider);
      expect(conversation.isNotEmpty, isTrue);
      expect(conversation.last.status, MessageStatus.success);
      expect(conversation.last.text,
          "This is a fake AI response from the test bridge.");

      expect(fakeBridge.wasExtractCalled, isTrue);
      expect(container.read(automationStateProvider), AutomationStatus.idle);

      // VERIFY: S'assurer que le retour à l'onglet Hub a été demandé
      expect(container.read(currentTabIndexProvider), 0);

      conversationSub.close();
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
      notifier.addMessage("Hello", true);
      notifier.addMessage("Sending...", false, status: MessageStatus.sending);

      // Set status to refining to simulate ongoing automation
      container
          .read(automationStateProvider.notifier)
          .setStatus(AutomationStatus.refining);

      notifier.cancelAutomation();

      final conversation = container.read(conversationProvider);
      expect(conversation.isNotEmpty, isTrue);
      expect(conversation.last.status, MessageStatus.error);
      expect(conversation.last.text, contains("cancelled"));
      expect(container.read(automationStateProvider), AutomationStatus.idle);

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

      await notifier.sendPromptToAutomation("a prompt that will fail");

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      expect(finalState, AutomationStatus.failed,
          reason: "L'état d'automatisation devrait être 'failed'");
      expect(conversation.last.status, MessageStatus.error,
          reason: "Le dernier message devrait avoir un statut d'erreur");
      expect(conversation.last.text, contains("An unexpected error occurred"),
          reason: "Le message d'erreur devrait être affiché");
      expect(conversation.last.text, contains("Fake automation error"),
          reason:
              "Le message d'erreur devrait contenir le détail de l'exception");

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

      await notifier.sendPromptToAutomation("a prompt that will fail");

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      expect(finalState, AutomationStatus.failed,
          reason: "L'état d'automatisation devrait être 'failed'");
      expect(conversation.last.status, MessageStatus.error,
          reason: "Le dernier message devrait avoir un statut d'erreur");
      expect(conversation.last.text, contains("Error:"),
          reason: "Le message d'erreur devrait commencer par 'Error:'");
      expect(conversation.last.text, contains("automationExecutionFailed"),
          reason: "Le message d'erreur devrait contenir le code d'erreur");

      conversationSub.close();
      tabIndexSub.close();
    });

    test('validateAndFinalizeResponse handles extraction errors gracefully',
        () async {
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      fakeBridge.extractFinalResponseErrorType = ErrorType.genericException;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation("Hello");
      notifier.onGenerationComplete();

      await notifier.validateAndFinalizeResponse();

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      expect(finalState, AutomationStatus.failed,
          reason: "L'état d'automatisation devrait être 'failed'");
      expect(conversation.last.status, MessageStatus.error,
          reason: "Le dernier message devrait avoir un statut d'erreur");
      expect(conversation.last.text, contains("Failed to extract response"),
          reason: "Le message d'erreur devrait indiquer l'échec d'extraction");
      expect(conversation.last.text, contains("Fake extraction error"),
          reason:
              "Le message d'erreur devrait contenir le détail de l'exception");

      conversationSub.close();
      tabIndexSub.close();
    });

    test(
        'validateAndFinalizeResponse handles AutomationError during extraction',
        () async {
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});
      final tabIndexSub =
          container.listen(currentTabIndexProvider, (previous, next) {});

      fakeBridge.extractFinalResponseErrorType = ErrorType.automationError;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation("Hello");
      notifier.onGenerationComplete();

      await notifier.validateAndFinalizeResponse();

      final finalState = container.read(automationStateProvider);
      final conversation = container.read(conversationProvider);

      expect(finalState, AutomationStatus.failed,
          reason: "L'état d'automatisation devrait être 'failed'");
      expect(conversation.last.status, MessageStatus.error,
          reason: "Le dernier message devrait avoir un statut d'erreur");
      expect(conversation.last.text, contains("Extraction Error:"),
          reason:
              "Le message d'erreur devrait commencer par 'Extraction Error:'");
      expect(conversation.last.text, contains("responseExtractionFailed"),
          reason: "Le message d'erreur devrait contenir le code d'erreur");

      conversationSub.close();
      tabIndexSub.close();
    });

    test('clearConversation resets the state to an empty list', () {
      // Keep providers alive by listening to them
      final conversationSub =
          container.listen(conversationProvider, (previous, next) {});

      // ARRANGE: Pré-peupler le provider avec des messages.
      final notifier = container.read(conversationProvider.notifier);

      notifier.addMessage("Message 1", true);
      notifier.addMessage("Message 2", false);

      // S'assurer que l'état n'est pas vide au départ.
      expect(container.read(conversationProvider), isNotEmpty);

      // ACT: Appeler la nouvelle méthode que nous allons créer.
      notifier.clearConversation();

      // ASSERT: Vérifier que l'état est maintenant une liste vide.
      expect(container.read(conversationProvider), isEmpty);

      // Vérifier aussi que l'automatisation est réinitialisée à idle
      expect(container.read(automationStateProvider), AutomationStatus.idle);

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
      notifier.addMessage("Original Prompt", true);
      final originalMessageId = notifier.state.last.id;
      notifier.addMessage("Original Response", false);
      notifier.addMessage("Another Prompt", true);
      notifier.addMessage("Another Response", false);
      expect(container.read(conversationProvider).length, 4,
          reason: "Initial conversation should have 4 messages.");

      // ACT
      const newPrompt = "Edited Prompt";
      await notifier.editAndResendPrompt(originalMessageId, newPrompt);

      // ASSERT
      final conversation = container.read(conversationProvider);

      // 1. La conversation doit avoir 2 messages : le prompt édité, et le message "Sending...".
      //    Les messages qui suivaient le prompt original ont été supprimés.
      expect(conversation.length, 2,
          reason:
              "Conversation should be truncated to 2 messages (edited + sending).");

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
