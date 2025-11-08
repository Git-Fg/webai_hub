import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:hive/hive.dart';

const _settingsKey = 'general_settings';

class SettingsService {
  SettingsService(this._box);
  final Box<GeneralSettingsData> _box;

  GeneralSettingsData loadSettings() {
    // WHY: Hive provides the typed object directly, with a fallback to the
    // default constructor if no data exists. No manual JSON parsing is needed.
    return _box.get(_settingsKey) ?? const GeneralSettingsData();
  }

  Future<void> saveSettings(GeneralSettingsData settings) async {
    // WHY: Hive handles the binary serialization automatically via the generated adapter.
    await _box.put(_settingsKey, settings);
  }
}
