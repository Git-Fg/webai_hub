import 'package:ai_hybrid_hub/core/models/provider_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider_config_provider.g.dart';

@riverpod
ProviderConfig currentProviderConfiguration(Ref ref) {
  // For MVP, hardcode AI Studio. In v2, this will reflect the active tab.
  return const ProviderConfig(
    providerId: 'ai_studio',
    displayName: 'Google AI Studio',
    supportsNativeSystemPrompt: false,
  );
}
