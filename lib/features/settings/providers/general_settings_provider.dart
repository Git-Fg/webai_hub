import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/services/settings_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'general_settings_provider.g.dart';

const _settingsKey = 'general_settings';

@Riverpod(keepAlive: true)
class GeneralSettings extends _$GeneralSettings {
  // WHY: Helper to get the service, avoiding repeated SharedPreferences instantiation.
  Future<SettingsService> _getService() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{_settingsKey},
      ),
    );
    return SettingsService(prefs);
  }

  @override
  Future<GeneralSettingsData> build() async {
    // WHY: The build method handles the initial async loading.
    final service = await _getService();
    return service.loadSettings();
  }

  // WHY: Centralized update logic that handles loading state and error handling
  // via AsyncValue.guard, ensuring consistent behavior across all update methods.
  Future<void> _updateSettings(
    GeneralSettingsData Function(GeneralSettingsData) updater,
  ) async {
    final service = await _getService();
    final previousState = state.requireValue;
    final newState = updater(previousState);

    // Set loading state, then use guard for the async save operation.
    state = const AsyncLoading<GeneralSettingsData>();
    state = await AsyncValue.guard(() async {
      await service.saveSettings(newState);
      return newState;
    });
  }

  Future<void> toggleProvider(String providerId) async {
    await _updateSettings((currentSettings) {
      final currentProviders =
          List<String>.from(currentSettings.enabledProviders);
      if (currentProviders.contains(providerId)) {
        currentProviders.remove(providerId);
      } else {
        currentProviders.add(providerId);
      }
      return currentSettings.copyWith(enabledProviders: currentProviders);
    });
  }

  Future<void> toggleAdvancedPrompting() async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(
        useAdvancedPrompting: !currentSettings.useAdvancedPrompting,
      );
    });
  }

  // WHY: Allows users to customize the instruction that frames the conversation history.
  Future<void> updateHistoryContextInstruction(String newInstruction) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(
        historyContextInstruction: newInstruction,
      );
    });
  }

  // WHY: Reset the history context instruction to its default value.
  // We get the default value by creating a new default instance of the settings model
  // and accessing its property. This is the cleanest way to access the default.
  Future<void> resetHistoryContextInstruction() async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(
        historyContextInstruction:
            const GeneralSettingsData().historyContextInstruction,
      );
    });
  }
}
