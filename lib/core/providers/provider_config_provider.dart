import 'package:ai_hybrid_hub/core/models/provider_config.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider_config_provider.g.dart';

// WHY: A map of all available provider configurations, keyed by providerId.
// This decouples provider configuration from UI tab order, making the system
// more maintainable and less brittle.
const _allProviders = <String, ProviderConfig>{
  'hub': ProviderConfig(
    providerId: 'hub',
    displayName: 'AI Hybrid Hub',
    supportsNativeSystemPrompt: false,
  ),
  'ai_studio': ProviderConfig(
    providerId: 'ai_studio',
    displayName: 'Google AI Studio',
    supportsNativeSystemPrompt: false,
  ),
  // Future providers would be added here with their unique providerId keys.
};

// WHY: Maps the current tab index to a providerId. This is the only place
// where tab order is coupled to provider identity, making it easy to maintain.
@riverpod
String currentProviderId(Ref ref) {
  final index = ref.watch(currentTabIndexProvider);
  switch (index) {
    case 0:
      return 'hub';
    case 1:
      return 'ai_studio';
    default:
      return 'hub'; // Default to hub for any unexpected index
  }
}

@riverpod
ProviderConfig currentProviderConfiguration(Ref ref) {
  final providerId = ref.watch(currentProviderIdProvider);
  // Return the config for the active provider, defaulting to hub if not found.
  return _allProviders[providerId] ?? _allProviders['hub']!;
}
