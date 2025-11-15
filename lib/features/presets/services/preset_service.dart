import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/features/presets/models/preset_settings.dart';
import 'package:ai_hybrid_hub/features/presets/services/preset_service_interface.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preset_service.g.dart';

@Riverpod(keepAlive: true)
class PresetService extends _$PresetService implements IPresetService {
  @override
  void build() {} // No state needed

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// Creates a new preset or group in the database.
  /// Returns the ID of the newly created preset.
  @override
  Future<int> createPreset({
    required String name,
    required PresetSettings settings,
    required int displayOrder,
    String? providerId,
  }) async {
    final entry = PresetsCompanion.insert(
      name: name,
      providerId: providerId == null ? const Value.absent() : Value(providerId),
      displayOrder: displayOrder,
      settings: settings,
    );
    return _db.createPreset(entry);
  }

  /// Updates an existing preset or group.
  @override
  Future<void> updatePreset({
    required int id,
    String? name,
    String? providerId,
    PresetSettings? settings,
  }) async {
    final companion = PresetsCompanion(
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      providerId: providerId == null
          ? const Value<String>.absent()
          : Value(providerId),
      settings: settings != null ? Value(settings) : const Value.absent(),
    );
    return _db.updatePreset(companion);
  }

  /// Deletes a preset or group by ID.
  @override
  Future<void> deletePreset(int id) async {
    return _db.deletePreset(id);
  }

  /// Updates the display order of multiple presets in a batch operation.
  @override
  Future<void> updatePresetOrders(List<PresetData> reorderedPresets) async {
    final companions = reorderedPresets.asMap().entries.map((entry) {
      return PresetsCompanion(
        id: Value(entry.value.id),
        displayOrder: Value(entry.key),
      );
    }).toList();
    return _db.updatePresetOrders(companions);
  }

  /// Finds a preset and its parent group by iterating backwards from the preset index.
  /// Returns a tuple of (presetSettings, groupSettings?).
  /// WHY: This logic is extracted from PromptBuilder to centralize preset-related business logic.
  @override
  (PresetSettings, PresetSettings?) findPresetAndGroupSettings(
    List<PresetData> allPresets,
    int targetPresetId,
  ) {
    final presetIndex = allPresets.indexWhere((p) => p.id == targetPresetId);
    if (presetIndex == -1) {
      throw StateError('Preset with ID $targetPresetId not found.');
    }

    final presetData = allPresets[presetIndex];
    final presetSettings = presetData.settings;

    // Find parent group by iterating backwards
    PresetSettings? groupSettings;
    for (var i = presetIndex - 1; i >= 0; i--) {
      if (allPresets[i].providerId == null) {
        // It's a group
        groupSettings = allPresets[i].settings;
        break;
      }
    }
    return (presetSettings, groupSettings);
  }

  /// Calculates the next display order value for a new preset.
  /// WHY: This encapsulates the business logic for determining where to place new presets.
  @override
  Future<int> getNextDisplayOrder() async {
    final allPresets = await _db.watchAllPresets().first;
    if (allPresets.isEmpty) {
      return 0;
    }
    return allPresets
            .map((PresetData p) => p.displayOrder)
            .reduce((int a, int b) => a > b ? a : b) +
        1;
  }
}
