import 'dart:async';

import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/automation/services/orchestration_service.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sequential_orchestrator_provider.freezed.dart';
part 'sequential_orchestrator_provider.g.dart';

@freezed
sealed class OrchestratorState with _$OrchestratorState {
  const factory OrchestratorState.idle() = _Idle;
  const factory OrchestratorState.running({
    required List<int> queue,
    required int currentIndex,
  }) = _Running;
  const factory OrchestratorState.failed({required String error}) = _Failed;
}

@Riverpod(keepAlive: true)
class SequentialOrchestrator extends _$SequentialOrchestrator {
  @override
  OrchestratorState build() => const OrchestratorState.idle();

  Future<void> start({
    required List<int> presetIds,
    required String prompt,
    required int conversationId,
    String? excludeMessageId,
  }) async {
    if (state is _Running) {
      ref.read(talkerProvider).warning('Orchestrator already running.');
      return;
    }

    // WHY: Clear and pre-populate staged responses before starting the queue
    // This ensures the UI shows "waiting" placeholders for all presets in the queue
    ref.read(stagedResponsesProvider.notifier).clear();

    // Validate all presets exist before starting
    final orchestrationService = ref.read(
      orchestrationServiceProvider.notifier,
    );
    await orchestrationService.validatePresetsExist(presetIds);

    final allPresets = await ref.read(presetsProvider.future);
    for (final presetId in presetIds) {
      final presetIndex = orchestrationService.findPresetInList(
        allPresets,
        presetId,
      );
      final preset = allPresets[presetIndex];
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: presetId,
              presetName: preset.name,
              text: 'Waiting in queue...',
              isLoading: true,
            ),
          );
    }

    state = OrchestratorState.running(queue: presetIds, currentIndex: 0);
    unawaited(
      _runNext(
        prompt: prompt,
        conversationId: conversationId,
        excludeMessageId: excludeMessageId,
      ),
    );
  }

  Future<void> _runNext({
    required String prompt,
    required int conversationId,
    String? excludeMessageId,
  }) async {
    if (state is! _Running) return;
    final runningState = state as _Running;
    final queue = runningState.queue;
    final index = runningState.currentIndex;

    if (index >= queue.length) {
      state = const OrchestratorState.idle();
      ref.read(currentTabIndexProvider.notifier).changeTo(0); // Return to Hub
      return;
    }

    final presetId = queue[index];
    final allPresets = await ref.read(presetsProvider.future);
    if (!ref.mounted) return;

    // WHY: Read orchestration service fresh to avoid using disposed Ref
    final orchestrationService = ref.read(
      orchestrationServiceProvider.notifier,
    );

    // WHY: Handle case where preset was deleted during orchestration
    final presetIndexInUI = orchestrationService.findPresetInList(
      allPresets,
      presetId,
    );
    if (presetIndexInUI == -1) {
      // Preset was deleted - skip it and show error, then continue
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: presetId,
              presetName: 'Preset $presetId',
              text: 'Error: Preset not found. It may have been deleted.',
            ),
          );
      // Move to next item in queue
      if (ref.mounted && state is _Running) {
        final runningState = state as _Running;
        state = runningState.copyWith(currentIndex: index + 1);
        unawaited(
          _runNext(
            prompt: prompt,
            conversationId: conversationId,
            excludeMessageId: excludeMessageId,
          ),
        );
      }
      return;
    }

    final preset = allPresets[presetIndexInUI];

    try {
      if (!ref.mounted) return;
      // 1. Update UI to show progress
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: presetId,
              presetName: preset.name,
              text: 'Generating...',
              isLoading: true,
            ),
          );

      // 2. Switch to the correct WebView tab
      if (!ref.mounted) return;
      ref.read(currentTabIndexProvider.notifier).changeTo(presetIndexInUI + 1);
      // Give the UI a moment to switch the IndexedStack
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!ref.mounted) return;

      // 3. Build prompt with context
      if (!ref.mounted) return;
      // WHY: Read service fresh before async operations to avoid disposed Ref
      final orchestrationServiceForPrompt = ref.read(
        orchestrationServiceProvider.notifier,
      );
      final promptWithContext = await orchestrationServiceForPrompt
          .buildPromptForPreset(
            prompt: prompt,
            conversationId: conversationId,
            presetId: presetId,
            excludeMessageId: excludeMessageId,
          );
      if (!ref.mounted) return;

      // 4. Prepare automation parameters
      // WHY: Read service fresh again before async operations
      final orchestrationServiceForParams = ref.read(
        orchestrationServiceProvider.notifier,
      );
      orchestrationServiceForParams.validatePresetExists(preset, presetId);
      final (
        providerId,
        settingsJson,
        timeoutModifier,
      ) = await orchestrationServiceForParams.prepareAutomationParameters(
        preset,
      );
      if (!ref.mounted) return;

      // 5. Trigger and await entire automation cycle
      final bridge = ref.read(javaScriptBridgeProvider(presetId));
      await bridge.waitForBridgeReady();
      if (!ref.mounted) return;

      // WHY: Convert PresetSettings to JSON string for bridge call
      await bridge.startAutomation(
        providerId,
        promptWithContext,
        settingsJson,
        timeoutModifier,
      );
      if (!ref.mounted) return;

      // 6. Extract the response
      final responseText = await bridge.extractFinalResponse();
      if (!ref.mounted) return;

      // 7. Update UI with the result
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: presetId,
              presetName: preset.name,
              text: responseText,
            ),
          );
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      ref
          .read(talkerProvider)
          .handle(
            e,
            st,
            'Orchestration for preset ${preset.name} failed.',
          );
      if (!ref.mounted) return;
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: presetId,
              presetName: preset.name,
              text: 'Error: $e',
            ),
          );
    } finally {
      // 8. Move to the next item in the queue
      if (ref.mounted && state is _Running) {
        // Check if still running
        state = runningState.copyWith(currentIndex: index + 1);
        unawaited(
          _runNext(
            prompt: prompt,
            conversationId: conversationId,
            excludeMessageId: excludeMessageId,
          ),
        );
      }
    }
  }

  void cancel() {
    state = const OrchestratorState.idle();
  }
}
