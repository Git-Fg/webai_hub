import 'dart:convert';

import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_service.g.dart';

const _settingsKey = 'general_settings';

class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferencesWithCache _prefs;

  GeneralSettingsData loadSettings() {
    final settingsString = _prefs.getString(_settingsKey);
    if (settingsString != null) {
      try {
        final json = jsonDecode(settingsString) as Map<String, dynamic>;
        return GeneralSettingsData.fromJson(json);
      } on Object {
        return const GeneralSettingsData(); // Return default on error
      }
    }
    return const GeneralSettingsData(); // Return default if not found
  }

  Future<void> saveSettings(GeneralSettingsData settings) async {
    final settingsString = jsonEncode(settings.toJson());
    await _prefs.setString(_settingsKey, settingsString);
  }
}

@Riverpod(keepAlive: true)
Future<SettingsService> settingsService(Ref ref) async {
  // WHY: We use SharedPreferencesWithCache for persistence. After the initial async load,
  // the service can be used synchronously for reads. We cache only the settings key
  // for optimal performance.
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: <String>{_settingsKey},
    ),
  );
  return SettingsService(prefs);
}
