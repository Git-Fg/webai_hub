import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import '../fakes/fake_javascript_bridge.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([TabController])
import 'conversation_provider_test.mocks.dart';

void main() {
  group('ConversationProvider Tests', () {
    late ProviderContainer container;
    late FakeJavaScriptBridge fakeBridge;
    late MockTabController mockTabController;

    setUp(() {
      fakeBridge = FakeJavaScriptBridge();
      mockTabController = MockTabController();
      fakeBridge.reset();
      container = ProviderContainer(
        overrides: [
          javaScriptBridgeProvider.overrideWithValue(fakeBridge),
          tabControllerProvider.overrideWithValue(mockTabController),
        ],
      );
    });

    tearDown(() {
      reset(mockTabController);
      fakeBridge.reset();
      container.dispose();
    });

    test('Initial state is correct', () {
      final subscription =
          container.listen(conversationProvider, (previous, next) {});
      expect(container.read(conversationProvider), isEmpty);
      expect(container.read(automationStateProvider), AutomationStatus.idle);
      subscription.close();
    });

    test(
        'sendPromptToAutomation updates states, calls bridge, and switches tab',
        () async {
      final subscription =
          container.listen(conversationProvider, (previous, next) {});
      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation("Hello");

      final conversation = container.read(conversationProvider);
      expect(conversation.length, 2);
      expect(conversation[0].text, "Hello");
      expect(conversation[1].status, MessageStatus.sending);

      expect(fakeBridge.lastPromptSent, "Hello");
      expect(
          container.read(automationStateProvider), AutomationStatus.observing);

      verify(mockTabController.animateTo(1)).called(1);

      subscription.close();
    });

    test('onGenerationComplete updates automation state to refining', () async {
      final subscription =
          container.listen(conversationProvider, (previous, next) {});
      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation("Hello");
      notifier.onGenerationComplete();

      expect(
          container.read(automationStateProvider), AutomationStatus.refining);

      subscription.close();
    });

    test(
        'validateAndFinalizeResponse updates message, state, and switches tab back',
        () async {
      final subscription =
          container.listen(conversationProvider, (previous, next) {});
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

      verify(mockTabController.animateTo(0)).called(1);

      subscription.close();
    });

    test('cancelAutomation updates message, state, and switches tab back',
        () async {
      final subscription =
          container.listen(conversationProvider, (previous, next) {});
      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation("Hello");
      notifier.onGenerationComplete();
      notifier.cancelAutomation();

      final conversation = container.read(conversationProvider);
      expect(conversation.isNotEmpty, isTrue);
      expect(conversation.last.status, MessageStatus.error);
      expect(conversation.last.text, contains("cancelled"));
      expect(container.read(automationStateProvider), AutomationStatus.idle);

      verify(mockTabController.animateTo(0)).called(1);

      subscription.close();
    });

    test('Failure during startAutomation is handled gracefully', () async {
      final subscription =
          container.listen(conversationProvider, (previous, next) {});
      final notifier = container.read(conversationProvider.notifier);

      fakeBridge.shouldThrowError = true;

      await notifier.sendPromptToAutomation("This will fail");

      final conversation = container.read(conversationProvider);
      expect(conversation.isNotEmpty, isTrue);
      expect(conversation.last.status, MessageStatus.error);
      expect(conversation.last.text, contains("Fake automation error"));
      expect(container.read(automationStateProvider), AutomationStatus.failed);

      subscription.close();
    });
  });
}
