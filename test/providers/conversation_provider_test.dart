// test/providers/conversation_provider_test.dart

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:ai_hybrid_hub/main.dart'; // Pour importer currentTabIndexProvider
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../fakes/fake_javascript_bridge.dart';
import 'conversation_provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<InAppWebViewController>(),
])
void main() {
  late ProviderContainer container;
  late FakeJavaScriptBridge fakeBridge;
  late MockInAppWebViewController mockWebViewController;
  late ProviderSubscription<List<Message>> convSub;
  late ProviderSubscription<dynamic> autoSub;
  late ProviderSubscription<int> tabSub;

  setUp(() {
    fakeBridge = FakeJavaScriptBridge();
    mockWebViewController = MockInAppWebViewController();
    container = ProviderContainer(
      overrides: [
        javaScriptBridgeProvider.overrideWithValue(fakeBridge),
        webViewControllerProvider.overrideWithValue(mockWebViewController),
      ],
    );

    // Keep critical providers alive during async orchestration
    convSub = container.listen(conversationProvider, (p, n) {});
    autoSub = container.listen(automationStateProvider, (p, n) {});
    tabSub = container.listen(currentTabIndexProvider, (p, n) {});
  });

  tearDown(() {
    convSub.close();
    autoSub.close();
    tabSub.close();
    container.dispose();
  });

  group('ConversationProvider Tests', () {
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
      final notifier = container.read(conversationProvider.notifier);
      await notifier.sendPromptToAutomation('Hello');

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
    });

    test(
      'sendPromptToAutomation should include system prompt when one is set',
      () async {
        // ARRANGE
        // Set a system prompt in the conversation settings
        container
            .read(conversationSettingsProvider.notifier)
            .updateSystemPrompt('You are a helpful assistant.');

        // ACT
        await container
            .read(conversationProvider.notifier)
            .sendPromptToAutomation('Hello');

        // ASSERT
        // Verify the prompt sent to the bridge contains the system prompt.
        expect(
          fakeBridge.lastPromptSent,
          contains('You are a helpful assistant.'),
        );
        expect(
          fakeBridge.lastPromptSent,
          contains('User: Hello'),
        );
      },
    );

    test(
        'extractAndReturnToHub updates message, clears pending prompt, stays in refining and returns to Hub',
        () async {
      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');

      // sendPromptToAutomation sets state to observing, then we need to simulate
      // the NEW_RESPONSE_DETECTED event to transition to refining
      // For this test, we'll manually set to refining to simulate the observer detecting the response
      container
          .read(automationStateProvider.notifier)
          .moveToRefining(messageCount: 2);

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
    });

    test('extractAndReturnToHub updates last AI message and stays in refining',
        () async {
      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');
      // Simuler l'extraction initiale réussie
      container
          .read(automationStateProvider.notifier)
          .moveToRefining(messageCount: 2);

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
    });

    test('finalizeAutomation sets idle and returns to Hub tab', () async {
      final notifier = container.read(conversationProvider.notifier);
      // Simuler un état de raffinement
      container
          .read(automationStateProvider.notifier)
          .moveToRefining(messageCount: 2);

      notifier.finalizeAutomation();

      expect(
        container.read(automationStateProvider),
        const AutomationStateData.idle(),
      );
      expect(container.read(currentTabIndexProvider), 0);
    });

    test(
        'cancelAutomation updates message, state, and requests tab switch back',
        () async {
      final notifier = container.read(conversationProvider.notifier);

      // First add messages to simulate a conversation with a sending message
      notifier
        ..addMessage('Hello', true)
        ..addMessage('Sending...', false, status: MessageStatus.sending);

      // Set status to refining to simulate ongoing automation
      container
          .read(automationStateProvider.notifier)
          .moveToRefining(messageCount: 1);

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
    });

    test(
        'sendPromptToAutomation handles bridge errors gracefully (generic Exception)',
        () async {
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
    });

    test('sendPromptToAutomation handles AutomationError correctly', () async {
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
    });

    test(
        'extractAndReturnToHub handles extraction errors gracefully and sets state to failed',
        () async {
      fakeBridge.extractFinalResponseErrorType = ErrorType.genericException;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');

      // Set status to refining to simulate ongoing automation
      container
          .read(automationStateProvider.notifier)
          .moveToRefining(messageCount: 1);

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
    });

    test(
        'extractAndReturnToHub handles AutomationError during extraction and sets state to failed',
        () async {
      fakeBridge.extractFinalResponseErrorType = ErrorType.automationError;

      final notifier = container.read(conversationProvider.notifier);

      await notifier.sendPromptToAutomation('Hello');

      // Set status to refining to simulate ongoing automation
      container
          .read(automationStateProvider.notifier)
          .moveToRefining(messageCount: 1);

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
    });

    test(
      'clearConversation resets conversation, automation state, and conversation settings',
      () {
        // ARRANGE
        final notifier = container.read(conversationProvider.notifier);
        notifier.addMessage('Message 1', true);

        // Set a non-default conversation setting
        container
            .read(conversationSettingsProvider.notifier)
            .updateSystemPrompt('Test Prompt');
        expect(
          container.read(conversationSettingsProvider).systemPrompt,
          'Test Prompt',
        );

        // ACT
        notifier.clearConversation();

        // ASSERT
        expect(container.read(conversationProvider), isEmpty);
        expect(
          container.read(automationStateProvider),
          const AutomationStateData.idle(),
        );
        // Verify that the settings have been reset to their default state
        expect(
          container.read(conversationSettingsProvider).systemPrompt,
          '',
        );
      },
    );

    test('editAndResendPrompt removes subsequent messages and resends prompt',
        () async {
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
    });
  });
  group('ConversationProvider Resilience Tests', () {
    test('sendPromptToAutomation successfully handles a page reload', () async {
      // Arrange: bridge not ready initially
      fakeBridge.simulateReload();

      when(
        mockWebViewController.loadUrl(urlRequest: anyNamed('urlRequest')),
      ).thenAnswer((_) async {});

      // Simulate onLoadStop + bridge reinjection making it ready shortly after
      Future<void>.delayed(const Duration(milliseconds: 30), () {
        fakeBridge.markAsReady();
      });

      await container
          .read(conversationProvider.notifier)
          .sendPromptToAutomation('Test');

      expect(fakeBridge.lastPromptSent, contains('Test'));
      expect(
        container.read(automationStateProvider),
        const AutomationStateData.observing(),
      );
    });

    test(
        'sendPromptToAutomation reloads WebView with correct URL (interaction verification)',
        () async {
      var called = false;
      when(
        mockWebViewController.loadUrl(urlRequest: anyNamed('urlRequest')),
      ).thenAnswer((invocation) async {
        final req = invocation.namedArguments[#urlRequest] as URLRequest;
        expect(req.url.toString(), WebViewConstants.aiStudioUrl);
        called = true;
      });

      await container
          .read(conversationProvider.notifier)
          .sendPromptToAutomation('Hello');

      expect(called, isTrue);
    });

    test('sendPromptToAutomation handles WebView loadUrl failure gracefully',
        () async {
      when(
        mockWebViewController.loadUrl(urlRequest: anyNamed('urlRequest')),
      ).thenAnswer((_) async => throw Exception('WebView failed to load'));

      await container
          .read(conversationProvider.notifier)
          .sendPromptToAutomation('This will fail');

      final conversation = container.read(conversationProvider);
      expect(
        container.read(automationStateProvider),
        const AutomationStateData.failed(),
      );
      expect(conversation.last.status, MessageStatus.error);
      expect(conversation.last.text, contains('An unexpected error occurred'));
      expect(conversation.last.text, contains('WebView failed to load'));
    });
  });

  group('ConversationProvider Context Building', () {
    test(
        'editAndResendPrompt truncates context to edited message and rebuilds prompt',
        () async {
      final notifier = container.read(conversationProvider.notifier);

      notifier.addMessage('Prompt 1', true); // will edit this
      final messageToEditId = notifier.state.last.id;
      notifier.addMessage('Response 1', false);
      notifier.addMessage('Prompt 2', true);
      notifier.addMessage('Response 2', false);

      await notifier.editAndResendPrompt(messageToEditId, 'Edited Prompt 1');

      expect(fakeBridge.lastPromptSent, contains('Edited Prompt 1'));
      expect(fakeBridge.lastPromptSent, isNot(contains('Response 1')));
      expect(fakeBridge.lastPromptSent, isNot(contains('Prompt 2')));

      final conversation = container.read(conversationProvider);
      expect(conversation.length, 2);
      expect(conversation.first.text, 'Edited Prompt 1');
    });
  });
}
