import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_javascript_bridge.dart';

// Helper to allow providers to settle
extension PumpExtension on ProviderContainer {
  Future<void> pump() => Future<void>.delayed(Duration.zero);
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
        providerId: 'ai_studio',
        displayOrder: 1,
        settingsJson: '{"model": "test-model-1"}',
      ),
    );
    testPresetId2 = await testDatabase.createPreset(
      PresetsCompanion.insert(
        name: 'Test Preset 2',
        providerId: 'kimi',
        displayOrder: 2,
        settingsJson: '{"model": "test-model-2"}',
      ),
    );

    container = ProviderContainer(
      overrides: [
        javaScriptBridgeProvider(testPresetId1).overrideWithValue(fakeBridge),
        javaScriptBridgeProvider(testPresetId2).overrideWithValue(fakeBridge),
        appDatabaseProvider.overrideWithValue(testDatabase),
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
    convSub = container.listen(conversationProvider, (_, __) {});
    presetsSub = container.listen(presetsProvider, (_, __) {});
    stagedSub = container.listen(stagedResponsesProvider, (_, __) {});
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

      final requests = container.read(automationRequestProvider);
      expect(requests.length, 1);
      expect(requests.containsKey(testPresetId1), isTrue);

      final conversation = await container.read(conversationProvider.future);
      expect(conversation.length, 2);
      expect(conversation[0].text, 'Hello');
      expect(conversation[1].status, MessageStatus.sending);
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

      final requests = container.read(automationRequestProvider);
      expect(requests.length, 2);
    },
  );

  test('finalizeTurnWithResponse adds message and clears staging', () async {
    final notifier = container.read(conversationActionsProvider.notifier);
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

    await notifier.finalizeTurnWithResponse('Final chosen response.');
    await container.pump();

    final conversation = await container.read(conversationProvider.future);
    expect(conversation.last.text, 'Final chosen response.');
    expect(conversation.last.isFromUser, isFalse);

    final staged = container.read(stagedResponsesProvider);
    expect(staged, isEmpty);
  });
}
