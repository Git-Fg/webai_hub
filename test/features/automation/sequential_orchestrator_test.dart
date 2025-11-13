import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/features/automation/providers/sequential_orchestrator_provider.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_javascript_bridge.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('SequentialOrchestrator', () {
    late ProviderContainer container;
    late FakeJavaScriptBridge fakeBridge;

    setUp(() {
      container = ProviderContainer();
      fakeBridge = FakeJavaScriptBridge();

      // Override bridge provider with fake
      container = ProviderContainer(
        overrides: [
          javaScriptBridgeProvider(1).overrideWithValue(fakeBridge),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('starts in idle state', () {
      final state = container.read(sequentialOrchestratorProvider);

      expect(state, const OrchestratorState.idle());
    });

    test('start creates staged responses for all presets', () async {
      // Arrange
      final presetIds = [1, 2];
      const prompt = 'Test prompt';
      const conversationId = 123;

      // Create test presets
      final testPresets = [
        createTestPreset(id: 1, name: 'Preset 1', providerId: 'provider1'),
        createTestPreset(id: 2, name: 'Preset 2', providerId: 'provider2'),
      ];

      // WHY: Create a broadcast stream controller to ensure proper stream emission
      // This avoids disposal issues - broadcast streams can have multiple listeners
      final streamController = StreamController<List<PresetData>>.broadcast();

      // WHY: Create a new container with all overrides for this test
      // to avoid provider disposal issues from the setUp container
      final testContainer = ProviderContainer(
        overrides: [
          javaScriptBridgeProvider(1).overrideWithValue(fakeBridge),
          presetsProvider.overrideWith(
            (ref) => streamController.stream,
          ),
        ],
      );

      // WHY: Start listening first, then add the value to ensure the stream is subscribed
      final subscription = testContainer.listen(
        presetsProvider,
        (previous, next) {},
      );
      // WHY: Add value after subscription is established
      streamController.add(testPresets);
      // WHY: Wait for presetsProvider to emit before using it
      await testContainer.read(presetsProvider.future);
      // WHY: Add a small delay to ensure Riverpod has fully processed the stream
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Get orchestrator from the test container
      final orchestrator = testContainer.read(
        sequentialOrchestratorProvider.notifier,
      );

      // Act
      await orchestrator.start(
        presetIds: presetIds,
        prompt: prompt,
        conversationId: conversationId,
      );

      // Assert - check staged responses were created
      final stagedResponses = testContainer.read(stagedResponsesProvider);
      expect(stagedResponses.length, 2);
      expect(stagedResponses[1]?.presetName, 'Preset 1');
      expect(stagedResponses[1]?.isLoading, true);
      expect(stagedResponses[1]?.text, 'Waiting in queue...');
      expect(stagedResponses[2]?.presetName, 'Preset 2');
      expect(stagedResponses[2]?.isLoading, true);
      expect(stagedResponses[2]?.text, 'Waiting in queue...');

      // Assert - check orchestrator state
      final state = testContainer.read(sequentialOrchestratorProvider);
      expect(state, isA<OrchestratorState>());
      state.maybeWhen(
        running: (queue, currentIndex) {
          expect(queue, presetIds);
          expect(currentIndex, 0);
        },
        orElse: () => fail('Expected running state'),
      );

      // WHY: Dispose test container first, then close subscription
      // WHY: Wait for Riverpod's async disposal to complete
      testContainer.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      subscription.close();
      await streamController.close();
    });

    test('cancel stops processing', () {
      // Arrange
      final orchestrator = container.read(
        sequentialOrchestratorProvider.notifier,
      );

      // Act
      orchestrator.cancel();

      // Assert
      final state = container.read(sequentialOrchestratorProvider);
      expect(state, const OrchestratorState.idle());
    });
  });
}
