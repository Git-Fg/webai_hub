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
  });
}
