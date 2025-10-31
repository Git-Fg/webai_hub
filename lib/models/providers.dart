import '../models/app_models.dart';

/// Constants for the 4 AI providers (MVP)
class Providers {
  static const aiStudio = ProviderConfig(
    id: 'aistudio',
    name: 'AI Studio',
    url: 'https://aistudio.google.com/prompts/new_chat',
    icon: 'auto_awesome',
  );
  
  static const qwen = ProviderConfig(
    id: 'qwen',
    name: 'Qwen',
    url: 'https://chat.qwen.ai/',
    icon: 'cloud',
  );
  
  static const zai = ProviderConfig(
    id: 'zai',
    name: 'Z-ai',
    url: 'https://chat.z.ai/',
    icon: 'flash_on',
  );
  
  static const kimi = ProviderConfig(
    id: 'kimi',
    name: 'Kimi',
    url: 'https://www.kimi.com/',
    icon: 'document_scanner',
  );
  
  /// List of all providers in order
  static const all = [
    aiStudio,
    qwen,
    zai,
    kimi,
  ];
  
  /// Get provider by ID
  static ProviderConfig? getById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
