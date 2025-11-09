import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/services/settings_service.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'general_settings_provider.g.dart';

const _settingsBoxName = 'general_settings_box';

@Riverpod(keepAlive: true)
class GeneralSettings extends _$GeneralSettings {
  // WHY: The service now depends on a Hive Box, which we can get synchronously
  // because it was opened during app initialization in main.dart.
  SettingsService _getService() {
    final box = Hive.box<GeneralSettingsData>(_settingsBoxName);
    return SettingsService(box);
  }

  @override
  Future<GeneralSettingsData> build() async {
    // WHY: The loading logic is now simpler and synchronous.
    final service = _getService();
    return service.loadSettings();
  }

  // WHY: Centralized update logic that handles loading state and error handling
  // via AsyncValue.guard, ensuring consistent behavior across all update methods.
  Future<void> _updateSettings(
    GeneralSettingsData Function(GeneralSettingsData) updater,
  ) async {
    final service = _getService();
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
      final currentProviders = List<String>.from(
        currentSettings.enabledProviders,
      );
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

  Future<void> toggleYoloMode() async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(
        yoloModeEnabled: !currentSettings.yoloModeEnabled,
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

  // WHY: Allows users to adjust timeout modifier for TypeScript automation.
  // This makes the automation engine adaptable to slower devices and networks.
  Future<void> updateTimeoutModifier(double modifier) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(timeoutModifier: modifier);
    });
  }

  // WHY: Allows users to control whether the app restores the last active conversation
  // on app restart. This gives users control over session persistence behavior.
  Future<void> togglePersistSession({required bool value}) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(persistSessionOnRestart: value);
    });
  }

  // WHY: Allows users to set the maximum number of conversations kept in history.
  // This prevents database bloat while maintaining a useful conversation history.
  Future<void> updateMaxConversationHistory(int max) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(maxConversationHistory: max);
    });
  }

  // WHY: Allows users to set a custom User Agent for the WebView.
  Future<void> updateCustomUserAgent(String userAgent) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(customUserAgent: userAgent);
    });
  }

  // WHY: Allows users to control whether the WebView supports zoom gestures.
  // This makes the WebView configuration more flexible and user-configurable.
  Future<void> toggleWebViewZoom({required bool value}) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(webViewSupportZoom: value);
    });
  }
}
