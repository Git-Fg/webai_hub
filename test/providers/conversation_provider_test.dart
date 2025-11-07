// test/providers/conversation_provider_test.dart

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/ephemeral_message_provider.dart';
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

    // WHY: Always reset the fake between tests to ensure a clean state
    // and prevent state leakage between test cases. This also ensures
    // the bridge starts in a "ready" state.
    fakeBridge.reset();

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

  group('ConversationProvider Unit Tests', () {
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
        'extractAndReturnToHub handles extraction errors gracefully via ephemeral message and stays refining',
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
      final ephemeral = container.read(ephemeralMessageProvider);

      // VERIFY: L'état d'automatisation reste en refining pour permettre un nouvel essai
      expect(
        finalState,
        const AutomationStateData.refining(messageCount: 1),
        reason: "L'état d'automatisation doit rester 'refining'",
      );

      // VERIFY: Un message éphémère d'erreur est présent
      expect(ephemeral, isNotNull);
      expect(ephemeral!.status, MessageStatus.error);
      expect(
        ephemeral.text,
        contains('Failed to extract response'),
      );

      // VERIFY: Le dernier message de l'assistant n'est pas écrasé
      final lastAiMessage = conversation.lastWhere((m) => !m.isFromUser);
      expect(lastAiMessage.status, MessageStatus.sending);
    });

    test(
        'extractAndReturnToHub handles AutomationError during extraction via ephemeral message and stays refining',
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
      final ephemeral = container.read(ephemeralMessageProvider);

      // VERIFY: L'état d'automatisation reste en refining
      expect(
        finalState,
        const AutomationStateData.refining(messageCount: 1),
        reason: "L'état d'automatisation doit rester 'refining'",
      );

      // VERIFY: Un message éphémère d'erreur est présent avec le code
      expect(ephemeral, isNotNull);
      expect(ephemeral!.status, MessageStatus.error);
      expect(ephemeral.text, contains('Extraction Error'));

      // VERIFY: Le dernier message de l'assistant n'est pas écrasé
      final lastAiMessage = conversation.lastWhere((m) => !m.isFromUser);
      expect(lastAiMessage.status, MessageStatus.sending);
    });

    test(
        'isExtracting state is true during extraction and false after completion or error',
        () async {
      final notifier = container.read(conversationProvider.notifier);
      final automationNotifier =
          container.read(automationStateProvider.notifier);
      final isExtractingHistory = <bool>[];

      // Listen to changes in the isExtracting state from automation state
      container.listen<AutomationStateData>(
        automationStateProvider,
        (_, next) {
          final isExtracting = next.maybeWhen(
            refining: (messageCount, isExtracting) => isExtracting,
            orElse: () => false,
          );
          isExtractingHistory.add(isExtracting);
        },
        fireImmediately: true,
      );

      // Setup initial state
      await notifier.sendPromptToAutomation('Test');
      automationNotifier.moveToRefining(messageCount: 1);

      // Initial state should be false
      expect(isExtractingHistory.last, isFalse);

      // --- Test success case ---
      final extractionFutureSuccess = notifier.extractAndReturnToHub();

      // Immediately after calling, should be true
      final stateAfterCall = container.read(automationStateProvider);
      expect(
        stateAfterCall.maybeWhen(
          refining: (messageCount, isExtracting) => isExtracting,
          orElse: () => false,
        ),
        isTrue,
      );

      await extractionFutureSuccess;

      // After completion, should be false
      final stateAfterSuccess = container.read(automationStateProvider);
      expect(
        stateAfterSuccess.maybeWhen(
          refining: (messageCount, isExtracting) => isExtracting,
          orElse: () => false,
        ),
        isFalse,
      );

      // --- Test error case ---
      fakeBridge.extractFinalResponseErrorType = ErrorType.genericException;
      final extractionFutureError = notifier.extractAndReturnToHub();

      // Immediately after calling, should be true
      final stateAfterErrorCall = container.read(automationStateProvider);
      expect(
        stateAfterErrorCall.maybeWhen(
          refining: (messageCount, isExtracting) => isExtracting,
          orElse: () => false,
        ),
        isTrue,
      );

      await extractionFutureError;

      // After error, should also be false
      final stateAfterError = container.read(automationStateProvider);
      expect(
        stateAfterError.maybeWhen(
          refining: (messageCount, isExtracting) => isExtracting,
          orElse: () => false,
        ),
        isFalse,
      );

      // Verify the full sequence of states
      // The listener fires on every automation state change, including:
      // - initial idle (false)
      // - sending (false)
      // - observing (false)
      // - refining with isExtracting=false (false)
      // - refining with isExtracting=true (true) - start success
      // - refining with isExtracting=false (false) - end success
      // - refining with isExtracting=true (true) - start error
      // - refining with isExtracting=false (false) - end error
      expect(isExtractingHistory.length, greaterThanOrEqualTo(6));
      expect(isExtractingHistory.last, isFalse); // Final state should be false
      // Verify the pattern: should have at least 2 true states (success and error extractions)
      final trueCount = isExtractingHistory.where((v) => v).length;
      expect(trueCount, greaterThanOrEqualTo(2));
      // Should end with false
      expect(isExtractingHistory.last, isFalse);
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
  group('ConversationProvider Resilience/Integration Tests', () {
    late ProviderContainer resilienceContainer;
    late MockInAppWebViewController resilienceMockWebViewController;
    late ProviderSubscription<List<Message>> resilienceConvSub;
    late ProviderSubscription<dynamic> resilienceAutoSub;
    late ProviderSubscription<int> resilienceTabSub;

    setUp(() {
      resilienceMockWebViewController = MockInAppWebViewController();
      resilienceContainer = ProviderContainer(
        overrides: [
          // WHY: Use the REAL JavaScriptBridge to test its interaction
          // with the mocked WebViewController.
          javaScriptBridgeProvider.overrideWith(
            JavaScriptBridge.new,
          ),
          webViewControllerProvider.overrideWithValue(
            resilienceMockWebViewController,
          ),
          // WHY: Don't override bridgeReadyProvider - let it use the real implementation
          // We'll control it via the notifier in each test as needed
        ],
      );

      // Bridge starts ready by default for most tests
      resilienceContainer.read(bridgeReadyProvider.notifier).markReady();

      // Keep critical providers alive during async orchestration
      resilienceConvSub = resilienceContainer.listen(
        conversationProvider,
        (p, n) {},
      );
      resilienceAutoSub = resilienceContainer.listen(
        automationStateProvider,
        (p, n) {},
      );
      resilienceTabSub = resilienceContainer.listen(
        currentTabIndexProvider,
        (p, n) {},
      );
    });

    tearDown(() {
      resilienceConvSub.close();
      resilienceAutoSub.close();
      resilienceTabSub.close();
      resilienceContainer.dispose();
    });

    test('sendPromptToAutomation successfully handles a page reload', () async {
      // For this test, the bridge is initially not ready
      resilienceContainer.read(bridgeReadyProvider.notifier).reset();

      when(
        resilienceMockWebViewController.loadUrl(
          urlRequest: anyNamed('urlRequest'),
        ),
      ).thenAnswer((_) async {});

      // Simulate the bridge becoming ready after a short delay
      Future.delayed(const Duration(milliseconds: 30), () {
        resilienceContainer.read(bridgeReadyProvider.notifier).markReady();
      });

      // Mocks for the rest of the flow
      when(
        resilienceMockWebViewController.evaluateJavascript(
          source: anyNamed('source'),
        ),
      ).thenAnswer((_) async => true);
      // Mock for callAsyncJavaScript - not needed for this test but included for completeness
      // The test doesn't actually call extractFinalResponse, so this mock won't be used

      await resilienceContainer
          .read(conversationProvider.notifier)
          .sendPromptToAutomation('Test');

      expect(
        resilienceContainer.read(automationStateProvider),
        const AutomationStateData.observing(),
      );
    });

    test(
        'sendPromptToAutomation reloads WebView with correct URL (interaction verification)',
        () async {
      var called = false;
      when(
        resilienceMockWebViewController.loadUrl(
          urlRequest: anyNamed('urlRequest'),
        ),
      ).thenAnswer((invocation) async {
        final req = invocation.namedArguments[#urlRequest] as URLRequest;
        expect(req.url.toString(), WebViewConstants.aiStudioUrl);
        called = true;
        // Mark bridge as ready immediately after loadUrl completes
        // to allow loadUrlAndWaitForReady to finish quickly
        resilienceContainer.read(bridgeReadyProvider.notifier).markReady();
      });

      // Mocks to allow the rest of the function to complete without error
      when(
        resilienceMockWebViewController.evaluateJavascript(
          source: anyNamed('source'),
        ),
      ).thenAnswer((_) async => true);

      await resilienceContainer
          .read(conversationProvider.notifier)
          .sendPromptToAutomation('Hello');

      expect(called, isTrue);
    });

    test('sendPromptToAutomation handles WebView loadUrl failure gracefully',
        () async {
      when(
        resilienceMockWebViewController.loadUrl(
          urlRequest: anyNamed('urlRequest'),
        ),
      ).thenAnswer((_) => Future.error(Exception('WebView failed to load')));

      await resilienceContainer
          .read(conversationProvider.notifier)
          .sendPromptToAutomation('This will fail');

      final conversation = resilienceContainer.read(conversationProvider);
      expect(
        resilienceContainer.read(automationStateProvider),
        const AutomationStateData.failed(),
      );
      expect(conversation.last.status, MessageStatus.error);
      expect(
        conversation.last.text,
        contains('An unexpected error occurred'),
      );
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
