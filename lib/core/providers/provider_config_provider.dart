import 'package:ai_hybrid_hub/core/models/provider_config.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider_config_provider.g.dart';

// A static list of all available provider configurations.
const _allProviders = [
  // Index 0 is the Hub, so it has no config. This is a placeholder.
  ProviderConfig(
    providerId: 'hub',
    displayName: 'AI Hybrid Hub',
    supportsNativeSystemPrompt: false,
  ),
  // Index 1
  ProviderConfig(
    providerId: 'ai_studio',
    displayName: 'Google AI Studio',
    supportsNativeSystemPrompt: false,
  ),
  // Future providers would be added here for indices 2, 3, etc.
];

@riverpod
ProviderConfig currentProviderConfiguration(Ref ref) {
  final currentIndex = ref.watch(currentTabIndexProvider);
  // Return the config for the active tab, defaulting to the hub if out of bounds.
  return (currentIndex >= 0 && currentIndex < _allProviders.length)
      ? _allProviders[currentIndex]
      : _allProviders[0];
}
