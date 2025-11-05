import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/services/settings_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'general_settings_provider.g.dart';

@Riverpod(keepAlive: true)
class GeneralSettings extends _$GeneralSettings {
  Future<SettingsService> _getService() async {
    return ref.read(settingsServiceProvider.future);
  }

  @override
  GeneralSettingsData build() {
    final serviceAsync = ref.watch(settingsServiceProvider);
    return serviceAsync.when(
      data: (service) => service.loadSettings(),
      loading: () => const GeneralSettingsData(), // Provide default during load
      error: (_, __) => const GeneralSettingsData(), // Provide default on error
    );
  }

  Future<void> toggleProvider(String providerId) async {
    final service = await _getService();
    final currentProviders = List<String>.from(state.enabledProviders);

    if (currentProviders.contains(providerId)) {
      currentProviders.remove(providerId);
    } else {
      currentProviders.add(providerId);
    }

    final newState = state.copyWith(enabledProviders: currentProviders);
    state = newState;
    await service.saveSettings(newState);
  }
}
