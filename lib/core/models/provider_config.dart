import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_config.freezed.dart';

@freezed
sealed class ProviderConfig with _$ProviderConfig {
  const factory ProviderConfig({
    required String providerId,
    required String displayName,
    // WHY: Determines if the system prompt is injected natively by the provider UI
    // or should be embedded into the prompt body built in-app.
    required bool supportsNativeSystemPrompt,
  }) = _ProviderConfig;
}
