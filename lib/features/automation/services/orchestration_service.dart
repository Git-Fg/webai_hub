import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/hub/services/prompt_builder.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orchestration_service.g.dart';

// WHY: KeepAlive ensures the provider persists across widget rebuilds during async operations
// to prevent "Ref disposed" errors when the service is used after async operations.
@Riverpod(keepAlive: true)
class OrchestrationService extends _$OrchestrationService {
  @override
  void build() {} // No state needed

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// Builds a prompt with context for a specific preset.
  /// WHY: This encapsulates prompt building logic that was in SequentialOrchestrator.
  Future<String> buildPromptForPreset({
    required String prompt,
    required int conversationId,
    required int presetId,
    String? excludeMessageId,
  }) async {
    return PromptBuilder(ref: ref, db: _db).buildPromptWithContext(
      prompt,
      conversationId: conversationId,
      presetId: presetId,
      excludeMessageId: excludeMessageId,
    );
  }

  /// Finds a preset in a list by ID and returns its index.
  /// Returns -1 if not found.
  /// WHY: This encapsulates preset finding logic that was repeated in SequentialOrchestrator.
  int findPresetInList(List<PresetData> allPresets, int presetId) {
    return allPresets.indexWhere((p) => p.id == presetId);
  }

  /// Validates that a preset exists and is not a group.
  /// Throws StateError if preset is not found or is a group.
  /// WHY: This centralizes preset validation logic.
  void validatePresetExists(PresetData? preset, int presetId) {
    if (preset == null) {
      throw StateError(
        'Preset $presetId not found. It may have been deleted.',
      );
    }
    if (preset.providerId == null) {
      throw StateError(
        'Cannot start automation: preset ${preset.id} has no providerId (it may be a group)',
      );
    }
  }

  /// Prepares automation parameters from a preset.
  /// Returns a tuple of (providerId, settingsJson, timeoutModifier).
  /// WHY: This encapsulates the parameter preparation logic.
  Future<(String, String, double)> prepareAutomationParameters(
    PresetData preset,
  ) async {
    final providerId = preset.providerId;
    if (providerId == null) {
      throw StateError(
        'Cannot prepare automation: preset ${preset.id} has no providerId (it may be a group)',
      );
    }

    final settingsJson = jsonEncode(preset.settings.toJson());
    final generalSettings = ref.read(generalSettingsProvider).value;
    final timeoutModifier = generalSettings?.timeoutModifier ?? 1.0;

    return (providerId, settingsJson, timeoutModifier);
  }

  /// Validates all presets exist before starting orchestration.
  /// WHY: This provides early validation to fail fast if presets are missing.
  Future<void> validatePresetsExist(List<int> presetIds) async {
    final allPresets = await ref.read(presetsProvider.future);
    for (final presetId in presetIds) {
      final presetIndex = allPresets.indexWhere((p) => p.id == presetId);
      if (presetIndex == -1) {
        throw StateError(
          'Preset $presetId not found. It may have been deleted.',
        );
      }
    }
  }
}
