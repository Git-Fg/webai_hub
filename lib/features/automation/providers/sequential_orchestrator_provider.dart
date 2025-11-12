import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/prompt_builder.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_options.dart';
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
    final preset = allPresets.firstWhere((p) => p.id == presetId);
    final presetIndexInUI = allPresets.indexWhere((p) => p.id == presetId);

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
      final db = ref.read(appDatabaseProvider);
      final promptWithContext = await PromptBuilder(ref: ref, db: db)
          .buildPromptWithContext(
            prompt,
            conversationId: conversationId,
            presetId: presetId,
            excludeMessageId: excludeMessageId,
          );
      if (!ref.mounted) return;

      // 4. Build AutomationOptions
      final settings = jsonDecode(preset.settingsJson) as Map<String, dynamic>;
      final generalSettings = ref.read(generalSettingsProvider).value;
      final providerId = preset.providerId;
      if (providerId == null) {
        throw StateError(
          'Cannot start automation: preset ${preset.id} has no providerId (it may be a group)',
        );
      }
      final automationOptions = AutomationOptions(
        providerId: providerId,
        prompt: promptWithContext,
        model: settings['model'] as String?,
        systemPrompt: settings['systemPrompt'] as String?,
        temperature: settings['temperature'] != null
            ? (settings['temperature'] as num).toDouble()
            : null,
        topP: settings['topP'] != null
            ? (settings['topP'] as num).toDouble()
            : null,
        thinkingBudget: settings['thinkingBudget'] != null
            ? (settings['thinkingBudget'] as num).toInt()
            : null,
        useWebSearch: settings['useWebSearch'] as bool?,
        disableThinking: settings['disableThinking'] as bool?,
        urlContext: settings['urlContext'] as bool?,
        timeoutModifier: generalSettings?.timeoutModifier,
      );

      // 5. Trigger and await the entire automation cycle
      if (!ref.mounted) return;
      final bridge = ref.read(javaScriptBridgeProvider(presetId));
      await bridge.waitForBridgeReady();
      if (!ref.mounted) return;
      await bridge.startAutomation(automationOptions);
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
      ref
          .read(talkerProvider)
          .handle(
            e,
            st,
            'Orchestration for preset ${preset.name} failed.',
          );
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
