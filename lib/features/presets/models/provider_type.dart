// lib/features/presets/models/provider_type.dart

import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';

enum ProviderType {
  aiStudio,
  kimi,
}

class ProviderMetadata {
  const ProviderMetadata({
    required this.id,
    required this.name,
    required this.url,
    required this.configurableSettings,
  });

  final String id;
  final String name;
  final String url;
  final List<String> configurableSettings;
}

final Map<ProviderType, ProviderMetadata> providerDetails = {
  ProviderType.aiStudio: const ProviderMetadata(
    id: 'ai_studio',
    name: 'Google AI Studio',
    url: WebViewConstants.aiStudioUrl,
    configurableSettings: ['model', 'temperature', 'topP'],
  ),
  ProviderType.kimi: const ProviderMetadata(
    id: 'kimi',
    name: 'Kimi',
    url: WebViewConstants.kimiUrl,
    configurableSettings: [], // Kimi has no configurable settings in the UI yet
  ),
};
