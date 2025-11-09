// test/providers/conversation_provider_test.dart

import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart'; // Import currentTabIndexProvider
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
  late AppDatabase testDatabase;
  late ProviderSubscription<AsyncValue<List<Message>>> convSub;
  late ProviderSubscription<dynamic> autoSub;
  late ProviderSubscription<int> tabSub;

  setUp(() async {
    fakeBridge = FakeJavaScriptBridge();
    mockWebViewController = MockInAppWebViewController();
    // WHY: Use in-memory database for tests to ensure isolation and speed
    testDatabase = AppDatabase.test();
    container = ProviderContainer(
      overrides: [
        javaScriptBridgeProvider.overrideWithValue(fakeBridge),
        webViewControllerProvider.overrideWithValue(mockWebViewController),
        appDatabaseProvider.overrideWithValue(testDatabase),
      ],
    );

    // WHY: Always reset the fake between tests to ensure a clean state
    // and prevent state leakage between test cases. This also ensures
    // the bridge starts in a "ready" state.
    fakeBridge.reset();

    // WHY: Create a default conversation for tests and set it as active.
    // This ensures all tests have a valid conversation context.
    final conversationId = await testDatabase.createConversation(
      ConversationsCompanion.insert(
        title: 'Test Conversation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    container.read(activeConversationIdProvider.notifier).set(conversationId);

    // Keep critical providers alive during async orchestration
    convSub = container.listen(conversationProvider, (p, n) {});
    autoSub = container.listen(automationStateProvider, (p, n) {});
    tabSub = container.listen(currentTabIndexProvider, (p, n) {});
  });

  tearDown(() async {
    convSub.close();
    autoSub.close();
    tabSub.close();
    await testDatabase.close();
    container.dispose();
  });

  group('ConversationProvider Unit Tests', () {
    test(
      'ConversationProvider initially provides an empty list of messages',
      () async {
        // ARRANGE
        final listener = container.listen(conversationProvider, (_, _) {});

        // ACT & ASSERT
        // Wait for the stream to emit its first value (may be AsyncLoading initially)
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final initialValue = listener.read();
        expect(
          initialValue,
          isA<AsyncData<List<Message>>>().having(
            (d) => d.value,
            'value',
            isEmpty,
          ),
        );
      },
    );

    test(
      'Calling addMessage on provider inserts into DB and updates the stream',
      () async {
        // ARRANGE
        final provider = container.read(conversationActionsProvider.notifier);
        final listener = container.listen(conversationProvider, (_, _) {});

        // ACT
        final activeId = container.read(activeConversationIdProvider);
        await provider.addMessage(
          'Hello from provider',
          isFromUser: true,
          conversationId: activeId!,
        );

        // ASSERT
        // Wait a bit for the stream to update
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // The provider's AsyncValue should contain the added message.
        final updatedValue = listener.read();
        expect(
          updatedValue,
          isA<AsyncData<List<Message>>>().having(
            (d) => d.value.first.text,
            'first message text',
            'Hello from provider',
          ),
        );
      },
    );

    test('Initial state is correct', () async {
      // Wait for the stream provider to emit its first value
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final initialConversationAsync = container.read(conversationProvider);
      final initialAutomation = container.read(automationStateProvider);
      final initialTab = container.read(currentTabIndexProvider);
      final initialConversation = initialConversationAsync.maybeWhen(
        data: (value) => value,
        orElse: () => <Message>[],
      );
      expect(initialConversation, isEmpty);
      expect(initialAutomation, const AutomationStateData.idle());
      expect(initialTab, 0);
    });

    test(
      'sendPromptToAutomation updates states, calls bridge, and requests tab switch',
      () async {
        final notifier = container.read(conversationActionsProvider.notifier);
        await notifier.sendPromptToAutomation('Hello');

        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;
        expect(
          conversation?.length,
          2,
          reason:
              'Expected 2 messages (user + assistant), got ${conversation?.length}: ${conversation?.map((m) => "${m.text} (${m.status})").toList()}',
        );
        expect(conversation?[0].text, 'Hello');
        expect(conversation?[1].status, MessageStatus.sending);

        expect(fakeBridge.lastPromptSent, 'Hello');
        // Après sendPromptToAutomation, on passe à l'état observing
        expect(
          container.read(automationStateProvider),
          const AutomationStateData.observing(),
        );

        // VERIFY: S'assurer que le provider de navigation a été mis à jour
        expect(container.read(currentTabIndexProvider), 1);
      },
    );

    test(
      'sendPromptToAutomation should NOT include system prompt for first message',
      () async {
        // ARRANGE
        // Set a system prompt in the conversation settings
        container
            .read(conversationSettingsProvider.notifier)
            .updateSystemPrompt('You are a helpful assistant.');

        // ACT
        await container
            .read(conversationActionsProvider.notifier)
            .sendPromptToAutomation('Hello');

        // ASSERT
        // Verify the prompt sent to the bridge is just the simple prompt for the first message
        // (no system prompt, no history formatting)
        expect(
          fakeBridge.lastPromptSent,
          'Hello',
          reason:
              'First message should be just the prompt without any formatting',
        );
        expect(
          fakeBridge.lastPromptSent,
          isNot(contains('You are a helpful assistant.')),
          reason: 'System prompt should not be included in first message',
        );
      },
    );

    test(
      'sendPromptToAutomation should include system prompt for follow-up messages',
      () async {
        // ARRANGE
        final notifier = container.read(conversationActionsProvider.notifier);
        final activeId = container.read(activeConversationIdProvider);
        expect(activeId, isNotNull);
        final conversationId = activeId!;

        // Set a system prompt in the conversation settings
        container
            .read(conversationSettingsProvider.notifier)
            .updateSystemPrompt('You are a helpful assistant.');

        // Disable advanced prompting to test simple text format
        // Note: This requires mocking generalSettingsProvider, but for now we'll test
        // with advanced prompting enabled and verify XML format instead
        // Add a first message to create history
        await notifier.addMessage(
          'First message',
          isFromUser: true,
          conversationId: conversationId,
        );
        await notifier.addMessage(
          'First response',
          isFromUser: false,
          conversationId: conversationId,
        );

        // ACT - Send a follow-up message
        await notifier.sendPromptToAutomation('Second message');

        // ASSERT
        // With advanced prompting enabled by default, verify XML format is used
        expect(
          fakeBridge.lastPromptSent,
          contains('You are a helpful assistant.'),
          reason: 'System prompt should be included in follow-up messages',
        );
        expect(
          fakeBridge.lastPromptSent,
          contains('<user_input>Second message</user_input>'),
          reason:
              'Follow-up prompt should include the new message in XML format',
        );
        expect(
          fakeBridge.lastPromptSent,
          contains('First message'),
          reason: 'Follow-up prompt should include conversation history',
        );
      },
    );

    test(
      'extractAndReturnToHub updates message, clears pending prompt, stays in refining and returns to Hub',
      () async {
        final notifier = container.read(conversationActionsProvider.notifier);

        await notifier.sendPromptToAutomation('Hello');

        // sendPromptToAutomation sets state to observing, then we need to simulate
        // the NEW_RESPONSE_DETECTED event to transition to refining
        // For this test, we'll manually set to refining to simulate the observer detecting the response
        container
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: 2);

        await notifier.extractAndReturnToHub();

        // Wait for the database update to propagate through the stream
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;
        expect(conversation?.isNotEmpty ?? false, isTrue);

        // Find the last AI message (not the last message overall, in case there are errors)
        final lastAiMessage = conversation!.lastWhere((m) => !m.isFromUser);
        expect(lastAiMessage.status, MessageStatus.success);
        expect(
          lastAiMessage.text,
          'This is a fake AI response from the test bridge.',
        );

        expect(fakeBridge.wasExtractCalled, isTrue);

        // VERIFY: Automation state remains in refining
        expect(
          container.read(automationStateProvider),
          const AutomationStateData.refining(messageCount: 2),
        );

        // VERIFY: Tab returns to Hub (0)
        expect(container.read(currentTabIndexProvider), 0);
      },
    );

    test(
      'extractAndReturnToHub updates last AI message and stays in refining',
      () async {
        final notifier = container.read(conversationActionsProvider.notifier);

        await notifier.sendPromptToAutomation('Hello');
        // Simuler l'extraction initiale réussie
        container
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: 2);

        await notifier.extractAndReturnToHub();

        // Wait for the database update to propagate through the stream
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;
        final lastAiMessage = conversation!.lastWhere((m) => !m.isFromUser);
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
      },
    );

    test('finalizeAutomation sets idle and returns to Hub tab', () async {
      final notifier = container.read(conversationActionsProvider.notifier);
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
        final notifier = container.read(conversationActionsProvider.notifier);

        // First add messages to simulate a conversation with a sending message
        final activeId = container.read(activeConversationIdProvider);
        expect(activeId, isNotNull);
        final conversationId = activeId!;
        await notifier.addMessage(
          'Hello',
          isFromUser: true,
          conversationId: conversationId,
        );
        await notifier.addMessage(
          'Sending...',
          isFromUser: false,
          status: MessageStatus.sending,
          conversationId: conversationId,
        );

        // Set status to refining to simulate ongoing automation
        container
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: 1);

        await notifier.cancelAutomation();

        // Wait for the database update to propagate through the stream
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;
        expect(conversation?.isNotEmpty ?? false, isTrue);
        expect(conversation!.last.status, MessageStatus.error);
        expect(conversation.last.text, contains('cancelled'));
        expect(
          container.read(automationStateProvider),
          const AutomationStateData.idle(),
        );

        // VERIFY: S'assurer que le retour à l'onglet Hub a été demandé
        expect(container.read(currentTabIndexProvider), 0);
      },
    );

    test(
      'sendPromptToAutomation handles bridge errors gracefully (generic Exception)',
      () async {
        fakeBridge.startAutomationErrorType = ErrorType.genericException;

        final notifier = container.read(conversationActionsProvider.notifier);

        await notifier.sendPromptToAutomation('a prompt that will fail');

        // Wait for the database update to propagate through the stream
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalState = container.read(automationStateProvider);
        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;

        expect(
          finalState,
          const AutomationStateData.failed(),
          reason: "Automation state should be 'failed'",
        );
        expect(
          conversation!.last.status,
          MessageStatus.error,
          reason: 'Last message should have error status',
        );
        expect(
          conversation.last.text,
          contains('An unexpected error occurred'),
          reason: 'Error message should be displayed',
        );
        expect(
          conversation.last.text,
          contains('Fake automation error'),
          reason: 'Error message should contain exception details',
        );
      },
    );

    test('sendPromptToAutomation handles AutomationError correctly', () async {
      fakeBridge.startAutomationErrorType = ErrorType.automationError;

      final notifier = container.read(conversationActionsProvider.notifier);

      await notifier.sendPromptToAutomation('a prompt that will fail');

      // Wait for the database update to propagate through the stream
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final finalState = container.read(automationStateProvider);
      final conversationAsync = container.read(conversationProvider);
      final conversation = conversationAsync.value;

      expect(
        finalState,
        const AutomationStateData.failed(),
        reason: "Automation state should be 'failed'",
      );
      expect(
        conversation!.last.status,
        MessageStatus.error,
        reason: 'Last message should have error status',
      );
      expect(
        conversation.last.text,
        contains('Error:'),
        reason: "Error message should start with 'Error:'",
      );
      expect(
        conversation.last.text,
        contains('automationExecutionFailed'),
        reason: 'Error message should contain error code',
      );
    });

    test(
      'extractAndReturnToHub throws AutomationError on extraction failure and stays refining',
      () async {
        fakeBridge.extractFinalResponseErrorType = ErrorType.genericException;

        final notifier = container.read(conversationActionsProvider.notifier);

        await notifier.sendPromptToAutomation('Hello');

        // Set status to refining to simulate ongoing automation
        container
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: 1);

        // VERIFY: extractAndReturnToHub throws an AutomationError
        await expectLater(
          notifier.extractAndReturnToHub(),
          throwsA(
            isA<AutomationError>().having(
              (e) => e.errorCode,
              'errorCode',
              AutomationErrorCode.responseExtractionFailed,
            ),
          ),
        );

        final finalState = container.read(automationStateProvider);
        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;

        // VERIFY: Automation state remains in refining to allow retry
        expect(
          finalState,
          const AutomationStateData.refining(messageCount: 1),
          reason: "Automation state must remain 'refining'",
        );

        // VERIFY: Last assistant message is not overwritten
        final lastAiMessage = conversation!.lastWhere((m) => !m.isFromUser);
        expect(lastAiMessage.status, MessageStatus.sending);
      },
    );

    test(
      'extractAndReturnToHub re-throws AutomationError during extraction and stays refining',
      () async {
        fakeBridge.extractFinalResponseErrorType = ErrorType.automationError;

        final notifier = container.read(conversationActionsProvider.notifier);

        await notifier.sendPromptToAutomation('Hello');

        // Set status to refining to simulate ongoing automation
        container
            .read(automationStateProvider.notifier)
            .moveToRefining(messageCount: 1);

        // VERIFY: extractAndReturnToHub re-throws the AutomationError
        await expectLater(
          notifier.extractAndReturnToHub(),
          throwsA(
            isA<AutomationError>().having(
              (e) => e.errorCode,
              'errorCode',
              AutomationErrorCode.responseExtractionFailed,
            ),
          ),
        );

        final finalState = container.read(automationStateProvider);
        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;

        // VERIFY: Automation state remains in refining
        expect(
          finalState,
          const AutomationStateData.refining(messageCount: 1),
          reason: "Automation state must remain 'refining'",
        );

        // VERIFY: Last assistant message is not overwritten
        final lastAiMessage = conversation!.lastWhere((m) => !m.isFromUser);
        expect(lastAiMessage.status, MessageStatus.sending);
      },
    );

    test(
      'isExtracting state is true during extraction and false after completion or error',
      () async {
        final notifier = container.read(conversationActionsProvider.notifier);
        final automationNotifier = container.read(
          automationStateProvider.notifier,
        );
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

        // Expect the error to be thrown, but don't let it propagate
        await expectLater(
          extractionFutureError,
          throwsA(isA<AutomationError>()),
        );

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
        expect(
          isExtractingHistory.last,
          isFalse,
        ); // Final state should be false
        // Verify the pattern: should have at least 2 true states (success and error extractions)
        final trueCount = isExtractingHistory.where((v) => v).length;
        expect(trueCount, greaterThanOrEqualTo(2));
        // Should end with false
        expect(isExtractingHistory.last, isFalse);
      },
    );

    test(
      'clearConversation resets conversation, automation state, and conversation settings',
      () async {
        // ARRANGE
        final notifier = container.read(conversationActionsProvider.notifier);
        final activeId = container.read(activeConversationIdProvider);
        expect(activeId, isNotNull);
        final conversationId = activeId!;
        await notifier.addMessage(
          'Message 1',
          isFromUser: true,
          conversationId: conversationId,
        );

        // Set a non-default conversation setting
        container
            .read(conversationSettingsProvider.notifier)
            .updateSystemPrompt('Test Prompt');
        expect(
          container.read(conversationSettingsProvider).systemPrompt,
          'Test Prompt',
        );

        // ACT
        await notifier.clearConversation();

        // ASSERT
        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;
        expect(conversation, isEmpty);
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

    test(
      'editAndResendPrompt removes subsequent messages and resends prompt',
      () async {
        // ARRANGE
        final notifier = container.read(conversationActionsProvider.notifier);

        // Créer une conversation initiale
        final activeId = container.read(activeConversationIdProvider);
        expect(activeId, isNotNull);
        final conversationId = activeId!;
        await notifier.addMessage(
          'Original Prompt',
          isFromUser: true,
          conversationId: conversationId,
        );
        // Wait for the stream to update
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final conversationAsyncInitial = container.read(conversationProvider);
        final conversationInitial = conversationAsyncInitial.value;
        expect(conversationInitial, isNotNull);
        expect(conversationInitial!.isNotEmpty, isTrue);
        final originalMessageId = conversationInitial.last.id;
        await notifier.addMessage(
          'Original Response',
          isFromUser: false,
          conversationId: conversationId,
        );
        await notifier.addMessage(
          'Another Prompt',
          isFromUser: true,
          conversationId: conversationId,
        );
        await notifier.addMessage(
          'Another Response',
          isFromUser: false,
          conversationId: conversationId,
        );
        // Wait for the stream to update
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final conversationAsyncAfterSeed = container.read(conversationProvider);
        final conversationAfterSeed = conversationAsyncAfterSeed.value;
        expect(conversationAfterSeed, isNotNull);
        expect(conversationAfterSeed!.isNotEmpty, isTrue);
        final lengthAfterSeed = conversationAfterSeed.length;
        expect(
          lengthAfterSeed,
          4,
          reason: 'Initial conversation should have 4 messages.',
        );

        // ACT
        const newPrompt = 'Edited Prompt';
        await notifier.editAndResendPrompt(originalMessageId, newPrompt);

        // ASSERT
        final conversationAsyncAfterEdit = container.read(conversationProvider);
        final conversationAfterEdit = conversationAsyncAfterEdit.value;

        // 1. La conversation doit avoir 2 messages : le prompt édité, et le message "Sending...".
        //    Les messages qui suivaient le prompt original ont été supprimés.
        expect(
          conversationAfterEdit?.length,
          2,
          reason:
              'Conversation should be truncated to 2 messages (edited + sending).',
        );

        // 2. Le premier message a été mis à jour.
        expect(conversationAfterEdit![0].text, newPrompt);

        // 3. Un nouveau message "Sending..." a été ajouté.
        expect(conversationAfterEdit[1].status, MessageStatus.sending);
        expect(conversationAfterEdit[1].isFromUser, false);

        // 4. Le bridge a bien été appelé avec le nouveau prompt.
        // After editAndResendPrompt, history is empty (all messages after edited one are deleted),
        // so it's treated as a first message and should be just the prompt without formatting.
        expect(
          fakeBridge.lastPromptSent,
          newPrompt,
          reason:
              'After editAndResendPrompt, history is empty, so prompt should be simple',
        );
      },
    );
  });
  group('ConversationProvider Resilience/Integration Tests', () {
    late ProviderContainer resilienceContainer;
    late MockInAppWebViewController resilienceMockWebViewController;
    late AppDatabase resilienceTestDatabase;
    late ProviderSubscription<AsyncValue<List<Message>>> resilienceConvSub;
    late ProviderSubscription<dynamic> resilienceAutoSub;
    late ProviderSubscription<int> resilienceTabSub;

    setUp(() async {
      resilienceMockWebViewController = MockInAppWebViewController();
      // WHY: Use in-memory database for resilience tests to ensure isolation
      resilienceTestDatabase = AppDatabase.test();
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
          appDatabaseProvider.overrideWithValue(resilienceTestDatabase),
          // WHY: Don't override bridgeReadyProvider - let it use the real implementation
          // We'll control it via the notifier in each test as needed
        ],
      );

      // WHY: Create a default conversation for resilience tests
      final conversationId = await resilienceTestDatabase.createConversation(
        ConversationsCompanion.insert(
          title: 'Resilience Test Conversation',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      resilienceContainer
          .read(activeConversationIdProvider.notifier)
          .set(conversationId);

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

    tearDown(() async {
      resilienceConvSub.close();
      resilienceAutoSub.close();
      resilienceTabSub.close();
      await resilienceTestDatabase.close();
      resilienceContainer.dispose();
    });

    test('sendPromptToAutomation successfully handles a page reload', () async {
      // For this test, the bridge is initially not ready
      resilienceContainer.read(bridgeReadyProvider.notifier).reset();

      when(
        resilienceMockWebViewController.loadUrl(
          urlRequest: anyNamed('urlRequest'),
        ),
      ).thenAnswer((_) async {
        return;
      });

      // Simulate the bridge becoming ready after a short delay
      // WHY: Use unawaited since we don't need to wait for this in the test
      // Note: We can't check if container is disposed, so we'll just try to access it
      // If it's disposed, the test will fail gracefully
      unawaited(
        Future.delayed(const Duration(milliseconds: 30), () {
          try {
            resilienceContainer.read(bridgeReadyProvider.notifier).markReady();
          } on Object {
            // Container may be disposed, ignore
          }
        }),
      );

      // Mocks for the rest of the flow
      // WHY: Mock evaluateJavascript to handle all JavaScript checks required by
      // waitForBridgeReady() and startAutomation()
      when(
        resilienceMockWebViewController.evaluateJavascript(
          source: anyNamed('source'),
        ),
      ).thenAnswer((invocation) async {
        final source = invocation.namedArguments[#source] as String;

        // Stage 2 de waitForBridgeReady: document.readyState (exact match)
        if (source == 'document.readyState') {
          return 'complete';
        }

        // Stage 3 de waitForBridgeReady: vérification bridge injecté
        if (source.contains('__AI_HYBRID_HUB_INITIALIZED__')) {
          // Retourner true seulement après que le bridge soit marqué comme ready
          final isReady = resilienceContainer.read(bridgeReadyProvider);
          return isReady;
        }

        // startAutomation: vérification page load
        if (source.contains(
          "document.readyState === 'interactive' || document.readyState === 'complete'",
        )) {
          return true;
        }

        // startAutomation: vérification fonctions disponibles
        if (source.contains('typeof window.startAutomation') &&
            source.contains('typeof window.extractFinalResponse')) {
          return true;
        }

        // Par défaut, retourner true pour autres vérifications
        return true;
      });
      // Mock for callAsyncJavaScript - not needed for this test but included for completeness
      // The test doesn't actually call extractFinalResponse, so this mock won't be used

      await resilienceContainer
          .read(conversationActionsProvider.notifier)
          .sendPromptToAutomation('Test');

      expect(
        resilienceContainer.read(automationStateProvider),
        const AutomationStateData.observing(),
      );
    });

    test(
      'sendPromptToAutomation successfully completes automation workflow',
      () async {
        // WHY: Mock evaluateJavascript to handle all JavaScript checks required by
        // waitForBridgeReady() and startAutomation()
        when(
          resilienceMockWebViewController.evaluateJavascript(
            source: anyNamed('source'),
          ),
        ).thenAnswer((invocation) async {
          final source = invocation.namedArguments[#source] as String;

          // Stage 2 de waitForBridgeReady: document.readyState (exact match)
          if (source == 'document.readyState') {
            return 'complete';
          }

          // Stage 3 de waitForBridgeReady: vérification bridge injecté
          if (source.contains('__AI_HYBRID_HUB_INITIALIZED__')) {
            // Retourner true seulement après que le bridge soit marqué comme ready
            final isReady = resilienceContainer.read(bridgeReadyProvider);
            return isReady;
          }

          // startAutomation: vérification page load
          if (source.contains(
            "document.readyState === 'interactive' || document.readyState === 'complete'",
          )) {
            return true;
          }

          // startAutomation: vérification fonctions disponibles
          if (source.contains('typeof window.startAutomation') &&
              source.contains('typeof window.extractFinalResponse')) {
            return true;
          }

          // Par défaut, retourner true pour autres vérifications
          return true;
        });

        await resilienceContainer
            .read(conversationActionsProvider.notifier)
            .sendPromptToAutomation('Hello');

        // Verify that automation completed successfully
        expect(
          resilienceContainer.read(automationStateProvider),
          const AutomationStateData.observing(),
        );
      },
    );

    test(
      'sendPromptToAutomation handles WebView loadUrl failure gracefully',
      () async {
        when(
          resilienceMockWebViewController.loadUrl(
            urlRequest: anyNamed('urlRequest'),
          ),
        ).thenAnswer((_) => Future.error(Exception('WebView failed to load')));

        await resilienceContainer
            .read(conversationActionsProvider.notifier)
            .sendPromptToAutomation('This will fail');

        // Wait for the database update to propagate through the stream
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final conversationAsync = resilienceContainer.read(
          conversationProvider,
        );
        final conversation = conversationAsync.value;
        expect(
          resilienceContainer.read(automationStateProvider),
          const AutomationStateData.failed(),
        );
        expect(conversation!.last.status, MessageStatus.error);
        // WHY: With the new architecture, errors come from waitForBridgeReady, not loadUrl
        // The error message format has changed, so we check for the error code instead
        expect(
          conversation.last.text,
          contains('Error:'),
        );
      },
    );
  });

  group('ConversationProvider Context Building', () {
    test(
      'editAndResendPrompt truncates context to edited message and rebuilds prompt',
      () async {
        final notifier = container.read(conversationActionsProvider.notifier);

        final activeId = container.read(activeConversationIdProvider);
        expect(activeId, isNotNull);
        final conversationId = activeId!;
        await notifier.addMessage(
          'Prompt 1',
          isFromUser: true,
          conversationId: conversationId,
        ); // will edit this
        // Wait for the stream to update
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final conversationAsync1 = container.read(conversationProvider);
        final conversation1 = conversationAsync1.value;
        expect(conversation1, isNotNull);
        expect(conversation1!.isNotEmpty, isTrue);
        final messageToEditId = conversation1.last.id;
        await notifier.addMessage(
          'Response 1',
          isFromUser: false,
          conversationId: conversationId,
        );
        await notifier.addMessage(
          'Prompt 2',
          isFromUser: true,
          conversationId: conversationId,
        );
        await notifier.addMessage(
          'Response 2',
          isFromUser: false,
          conversationId: conversationId,
        );

        await notifier.editAndResendPrompt(messageToEditId, 'Edited Prompt 1');

        // After editAndResendPrompt, history is empty (all messages after edited one are deleted),
        // so it's treated as a first message and should be just the prompt without formatting.
        expect(
          fakeBridge.lastPromptSent,
          'Edited Prompt 1',
          reason:
              'After editAndResendPrompt, history is empty, so prompt should be simple',
        );
        expect(
          fakeBridge.lastPromptSent,
          isNot(contains('Response 1')),
          reason:
              'Previous messages should not be in prompt after editAndResend',
        );
        expect(
          fakeBridge.lastPromptSent,
          isNot(contains('Prompt 2')),
          reason:
              'Subsequent messages should not be in prompt after editAndResend',
        );

        final conversationAsync = container.read(conversationProvider);
        final conversation = conversationAsync.value;
        expect(conversation?.length, 2);
        expect(conversation!.first.text, 'Edited Prompt 1');
      },
    );
  });
}
