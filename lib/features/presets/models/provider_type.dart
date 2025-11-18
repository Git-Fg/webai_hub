// lib/features/presets/models/provider_type.dart

import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider_type.g.dart';

enum ProviderType {
  aiStudio,
  kimi,
  zAi,
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

@riverpod
Map<ProviderType, ProviderMetadata> providerMetadata(Ref ref) {
  return {
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
      configurableSettings: ['useWebSearch', 'disableThinking'],
    ),
    ProviderType.zAi: const ProviderMetadata(
      id: 'z_ai',
      name: 'Z.ai',
      url: WebViewConstants.zAiUrl,
      configurableSettings: ['model', 'useWebSearch', 'disableThinking'],
    ),
  };
}
