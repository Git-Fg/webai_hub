import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/features/presets/models/preset_settings.dart';

abstract class IPresetService {
  Future<int> createPreset({
    required String name,
    required PresetSettings settings,
    required int displayOrder,
    String? providerId,
  });

  Future<void> updatePreset({
    required int id,
    String? name,
    String? providerId,
    PresetSettings? settings,
  });

  Future<void> deletePreset(int id);

  Future<void> updatePresetOrders(List<PresetData> reorderedPresets);

  (PresetSettings, PresetSettings?) findPresetAndGroupSettings(
    List<PresetData> allPresets,
    int targetPresetId,
  );

  Future<int> getNextDisplayOrder();
}
