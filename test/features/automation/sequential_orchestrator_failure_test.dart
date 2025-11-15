import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/sequential_orchestrator_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_javascript_bridge.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('SequentialOrchestrator Failure Scenarios', () {
    late ProviderContainer container;
    late FakeJavaScriptBridge fakeBridge1;
    late FakeJavaScriptBridge fakeBridge2;
    late StreamController<List<PresetData>> presetsController;
    late AppDatabase testDatabase;
    late ProviderSubscription<AsyncValue<List<PresetData>>> presetsSub;
    late ProviderSubscription<Map<int, StagedResponse>> stagedSub;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      testDatabase = AppDatabase.test();
      fakeBridge1 = FakeJavaScriptBridge();
      fakeBridge2 = FakeJavaScriptBridge();
      presetsController = StreamController<List<PresetData>>.broadcast();

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          presetsProvider.overrideWith((ref) => presetsController.stream),
          javaScriptBridgeProvider(1).overrideWithValue(fakeBridge1),
          javaScriptBridgeProvider(2).overrideWithValue(fakeBridge2),
        ],
      );

      // WHY: Keep presetsProvider alive during async operations to prevent
      // "provider disposed during loading state" errors
      presetsSub = container.listen(presetsProvider, (_, next) {});
      // WHY: Keep stagedResponsesProvider alive to track updates during tests
      stagedSub = container.listen(stagedResponsesProvider, (_, next) {});
    });

    tearDown(() async {
      // WHY: Close subscriptions before disposing container to ensure clean teardown
      presetsSub.close();
      stagedSub.close();
      container.dispose();
      // WHY: Close the stream controller after disposing the container
      // to ensure all provider subscriptions are cleaned up first
      await presetsController.close();
      await testDatabase.close();
    });

    test('skips deleted preset and continues queue', () async {
      // ARRANGE
      final orchestrator = container.read(
        sequentialOrchestratorProvider.notifier,
      );
      final initialPresets = [
        createTestPreset(id: 1, name: 'Preset 1', providerId: 'p1'),
        createTestPreset(id: 2, name: 'Preset 2', providerId: 'p2'),
      ];
      presetsController.add(initialPresets);
      await container.pump();

      // WHY: Wait for presetsProvider to emit and be available before starting orchestration
      // The start() method calls presetsProvider.future which needs the stream to have emitted
      final presetsBeforeStart = await container.read(presetsProvider.future);
      expect(
        presetsBeforeStart.length,
        2,
        reason: 'Presets should be available before starting orchestration',
      );
      expect(
        presetsBeforeStart.any((p) => p.id == 1),
        isTrue,
        reason: 'Preset 1 should be in the list',
      );
      expect(
        presetsBeforeStart.any((p) => p.id == 2),
        isTrue,
        reason: 'Preset 2 should be in the list',
      );

      // Create a conversation for the test
      final conversationId = await testDatabase.createConversation(
        ConversationsCompanion.insert(
          title: 'Test Conversation',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // ACT
      // Start orchestration with both presets
      try {
        await orchestrator.start(
          presetIds: [1, 2],
          prompt: 'test',
          conversationId: conversationId,
        );
      } catch (e, stackTrace) {
        fail('orchestrator.start() threw an error: $e\n$stackTrace');
      }
      await container.pump();

      // WHY: Give providers time to update after start() completes
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await container.pump();

      // Verify staged responses were created for both presets
      var stagedResponses = container.read(stagedResponsesProvider);
      expect(
        stagedResponses.containsKey(1),
        isTrue,
        reason:
            'Staged response for preset 1 should exist. Actual keys: ${stagedResponses.keys.toList()}',
      );
      expect(
        stagedResponses.containsKey(2),
        isTrue,
        reason:
            'Staged response for preset 2 should exist. Actual keys: ${stagedResponses.keys.toList()}',
      );

      // Simulate preset 1 being deleted after orchestration has started
      // The orchestrator should detect this when processing preset 1
      final updatedPresets = [
        createTestPreset(id: 2, name: 'Preset 2', providerId: 'p2'),
      ];
      presetsController.add(updatedPresets);
      await container.pump();

      // Wait for orchestration to process both presets
      // The orchestrator will detect the deleted preset and skip it, then continue to preset 2
      var attempts = 0;
      while (attempts < 50) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await container.pump();
        stagedResponses = container.read(stagedResponsesProvider);
        // Wait until we have responses for both presets and preset 2 has been processed
        if (stagedResponses.containsKey(1) &&
            stagedResponses.containsKey(2) &&
            fakeBridge2.startAutomationCallCount > 0) {
          break;
        }
        attempts++;
      }

      // ASSERT
      stagedResponses = container.read(stagedResponsesProvider);
      expect(stagedResponses.containsKey(1), isTrue);
      // WHY: The error message may come from early detection or from database lookup
      // Both indicate the preset was not found
      expect(
        stagedResponses[1]?.text,
        anyOf(
          contains('Error: Preset not found'),
          contains('Preset with ID 1 not found'),
        ),
      );
      expect(stagedResponses.containsKey(2), isTrue);
      expect(stagedResponses[2]?.text, isNot(contains('Error')));
      expect(
        fakeBridge1.startAutomationCallCount,
        0,
        reason: 'Preset 1 should be skipped due to deletion',
      );
      expect(
        fakeBridge2.startAutomationCallCount,
        greaterThan(0),
        reason: 'Preset 2 should be processed after preset 1 fails',
      );
    });
  });
}
