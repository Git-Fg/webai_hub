import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_orchestrator.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_javascript_bridge.dart';

// Helper to allow providers to settle
extension PumpExtension on ProviderContainer {
  Future<void> pump() => Future<void>.delayed(Duration.zero);
}

// Test implementation of SelectedPresetIds to avoid Hive dependency
class _TestSelectedPresetIds extends SelectedPresetIds {
  _TestSelectedPresetIds(this._value);

  final List<int> _value;

  @override
  List<int> build() => _value;
}

void main() {
  late ProviderContainer container;
  late FakeJavaScriptBridge fakeBridge;
  late AppDatabase testDatabase;
  late int testPresetId1;
  late int testPresetId2;
  late ProviderSubscription<AsyncValue<List<Message>>> convSub;
  late ProviderSubscription<AsyncValue<List<dynamic>>> presetsSub;
  late ProviderSubscription<Map<int, StagedResponse>> stagedSub;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeBridge = FakeJavaScriptBridge();
    testDatabase = AppDatabase.test();

    testPresetId1 = await testDatabase.createPreset(
      PresetsCompanion.insert(
        name: 'Test Preset 1',
        providerId: const Value('ai_studio'),
        displayOrder: 1,
        settingsJson: '{"model": "test-model-1"}',
      ),
    );
    testPresetId2 = await testDatabase.createPreset(
      PresetsCompanion.insert(
        name: 'Test Preset 2',
        providerId: const Value('kimi'),
        displayOrder: 2,
        settingsJson: '{"model": "test-model-2"}',
      ),
    );

    container = ProviderContainer(
      overrides: [
        javaScriptBridgeProvider(testPresetId1).overrideWithValue(fakeBridge),
        javaScriptBridgeProvider(testPresetId2).overrideWithValue(fakeBridge),
        appDatabaseProvider.overrideWithValue(testDatabase),
        // Override selectedPresetIdsProvider to avoid Hive dependency in tests
        selectedPresetIdsProvider.overrideWith(
          () => _TestSelectedPresetIds([testPresetId1]),
        ),
      ],
    );

    final conversationId = await testDatabase.createConversation(
      ConversationsCompanion.insert(
        title: 'Test Conversation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    container.read(activeConversationIdProvider.notifier).set(conversationId);

    // Keep critical providers alive during async operations
    convSub = container.listen(conversationProvider, (_, next) {});
    presetsSub = container.listen(presetsProvider, (_, next) {});
    stagedSub = container.listen(stagedResponsesProvider, (_, next) {});
  });

  tearDown(() async {
    convSub.close();
    presetsSub.close();
    stagedSub.close();
    container.dispose();
    await testDatabase.close();
  });

  test(
    'sendPrompt (single preset) dispatches one automation request and adds messages',
    () async {
      final notifier = container.read(conversationActionsProvider.notifier);

      await notifier.sendPromptToAutomation(
        'Hello',
        selectedPresetIds: [testPresetId1],
      );
      await container.pump();

      // With sequential orchestration, requests are handled directly by the orchestrator
      // No need to check automationRequestProvider

      final conversation = await container.read(conversationProvider.future);
      expect(conversation.length, 1);
      expect(conversation[0].text, 'Hello');
      // With sequential orchestration, no "sending" message is added automatically
    },
  );

  test(
    'sendPrompt (multi preset) creates staged responses and dispatches requests',
    () async {
      final notifier = container.read(conversationActionsProvider.notifier);

      await notifier.sendPromptToAutomation(
        'Hello All',
        selectedPresetIds: [testPresetId1, testPresetId2],
      );
      await container.pump();
      // Give providers time to update
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final staged = container.read(stagedResponsesProvider);
      expect(staged.length, 2);
      expect(staged[testPresetId1]?.isLoading, isTrue);
      expect(staged[testPresetId2]?.isLoading, isTrue);

      // With sequential orchestration, requests are handled directly by the orchestrator
      // No need to check automationRequestProvider
    },
  );

  test('finalizeTurnWithResponse adds message and clears staging', () async {
    final orchestrator = container.read(
      automationOrchestratorProvider.notifier,
    );
    container
        .read(stagedResponsesProvider.notifier)
        .addOrUpdate(
          StagedResponse(
            presetId: testPresetId1,
            presetName: 'Test',
            text: 'Loading...',
            isLoading: true,
          ),
        );

    await orchestrator.finalizeTurnWithResponse('Final chosen response.');
    await container.pump();

    final conversation = await container.read(conversationProvider.future);
    expect(conversation.last.text, 'Final chosen response.');
    expect(conversation.last.isFromUser, isFalse);

    final staged = container.read(stagedResponsesProvider);
    expect(staged, isEmpty);
  });

  test('editAndResendPrompt truncates conversation and resends', () async {
    final notifier = container.read(conversationActionsProvider.notifier);

    // Add initial messages
    await notifier.addMessage(
      'First message',
      isFromUser: true,
      conversationId: container.read(activeConversationIdProvider)!,
    );
    await notifier.addMessage(
      'First response',
      isFromUser: false,
      conversationId: container.read(activeConversationIdProvider)!,
    );
    await notifier.addMessage(
      'Second message',
      isFromUser: true,
      conversationId: container.read(activeConversationIdProvider)!,
    );
    await container.pump();

    // Get the message ID of the first message
    final conversation = await container.read(conversationProvider.future);
    final firstMessageId = conversation[0].id;

    // Edit and resend the first message
    await notifier.editAndResendPrompt(firstMessageId, 'Edited first message');
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Verify conversation was truncated (only edited message remains)
    final updatedConversation = await container.read(
      conversationProvider.future,
    );
    expect(updatedConversation.length, 1);
    expect(updatedConversation[0].text, 'Edited first message');
    expect(updatedConversation[0].isFromUser, true);
  });
}
