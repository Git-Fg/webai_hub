import 'package:ai_hybrid_hub/features/presets/providers/selected_presets_provider.dart';
import 'package:ai_hybrid_hub/features/settings/models/browser_user_agent.dart';
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
    final loadedSettings = service.loadSettings();

    // WHY: Migrate old user agent names to new ones to prevent dropdown errors.
    // This handles cases where users have saved values that no longer match enum names.
    final migratedSettings = _migrateUserAgentIfNeeded(loadedSettings);

    // WHY: If migration occurred, save the updated settings back to storage.
    if (migratedSettings != loadedSettings) {
      await service.saveSettings(migratedSettings);
    }

    return migratedSettings;
  }

  // WHY: Maps old user agent names to new ones to preserve user intent after enum changes.
  // Returns the same settings if no migration is needed, or updated settings if migration occurred.
  GeneralSettingsData _migrateUserAgentIfNeeded(GeneralSettingsData settings) {
    final selectedUA = settings.selectedUserAgent;

    // WHY: If it's 'default' or 'custom', no migration needed.
    if (selectedUA == 'default' || selectedUA == 'custom') {
      return settings;
    }

    // WHY: Check if the saved value matches any current enum name.
    final isValidUA = BrowserUserAgent.values.any(
      (ua) => ua.name == selectedUA,
    );
    if (isValidUA) {
      return settings;
    }

    // WHY: Migration map for old user agent names to new ones.
    // Maps old names (that users might have saved) to their closest new equivalent.
    const migrationMap = <String, String>{
      // Old desktop user agents → map to mobile equivalents
      'Chrome 131 (Windows)': 'Chrome/Android (Generic)',
      'Chrome 131 (macOS)': 'Chrome/iPhone',
      'Safari 18 (macOS)': 'Chrome/iPhone',
      'Firefox 141 (Windows)': 'Firefox/Android',
      'Edge 131 (Windows)': 'Chrome/Android (Generic)',
      // Old mobile user agent name (if it existed)
      'Chrome/Android': 'Chrome/Android (Generic)',
    };

    final migratedUA = migrationMap[selectedUA];
    if (migratedUA != null) {
      return settings.copyWith(selectedUserAgent: migratedUA);
    }

    // WHY: If no migration mapping exists, fall back to default to prevent errors.
    return settings.copyWith(selectedUserAgent: 'default');
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

  Future<void> updateSelectedUserAgent(String selection) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(selectedUserAgent: selection);
    });
  }

  // WHY: Allows users to set a custom User Agent for the WebView with validation.
  // Basic validation prevents malformed or excessively long user agents.
  Future<void> updateCustomUserAgent(String userAgent) async {
    final trimmedAgent = userAgent.trim();
    // WHY: Basic validation to prevent malformed or excessively long user agents.
    if (trimmedAgent.isNotEmpty && !trimmedAgent.startsWith('Mozilla/')) {
      throw ArgumentError('Invalid User Agent: Must start with "Mozilla/".');
    }
    if (trimmedAgent.length > 500) {
      throw ArgumentError('User Agent is too long (max 500 characters).');
    }

    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(customUserAgent: trimmedAgent);
    });
  }

  // WHY: Allows users to control whether the WebView supports zoom gestures.
  // This makes the WebView configuration more flexible and user-configurable.
  Future<void> toggleWebViewZoom({required bool value}) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(webViewSupportZoom: value);
    });
  }

  // WHY: This new method manages the multi-preset mode toggle and ensures
  // the selected presets state remains consistent. If multi-preset is disabled
  // while multiple presets are selected, it intelligently reduces the selection to one.
  Future<void> toggleMultiPresetMode({required bool value}) async {
    await _updateSettings((currentSettings) {
      return currentSettings.copyWith(enableMultiPresetMode: value);
    });

    // If we are disabling multi-preset mode, ensure only one preset is selected.
    if (!value) {
      final selectedIds = ref.read(selectedPresetIdsProvider);
      if (selectedIds.length > 1) {
        // Keep only the first selected preset to maintain a valid state.
        ref
            .read(selectedPresetIdsProvider.notifier)
            .setSingle(selectedIds.first);
      }
    }
  }
}
