import 'package:flutter_test/flutter_test.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';

void main() {
  group('AIProvider Tests', () {
    test('AIProvider enum has correct values', () {
      expect(AIProvider.values.length, 4);
      expect(AIProvider.aistudio.displayName, 'AI Studio');
      expect(AIProvider.qwen.displayName, 'Qwen');
      expect(AIProvider.zai.displayName, 'Z-ai');
      expect(AIProvider.kimi.displayName, 'Kimi');
    });

    test('AIProvider URLs are correct', () {
      expect(AIProvider.aistudio.url, 'https://aistudio.google.com/prompts/new_chat');
      expect(AIProvider.qwen.url, 'https://chat.qwen.ai/');
      expect(AIProvider.zai.url, 'https://chat.z.ai/');
      expect(AIProvider.kimi.url, 'https://www.kimi.com/');
    });

    test('fromIndex returns correct providers', () {
      expect(AIProvider.fromIndex(0), AIProvider.aistudio);
      expect(AIProvider.fromIndex(1), AIProvider.qwen);
      expect(AIProvider.fromIndex(2), AIProvider.zai);
      expect(AIProvider.fromIndex(3), AIProvider.kimi);
    });

    test('fromIndex handles out of range indices', () {
      expect(AIProvider.fromIndex(-1), AIProvider.aistudio);
      expect(AIProvider.fromIndex(4), AIProvider.aistudio);
      expect(AIProvider.fromIndex(999), AIProvider.aistudio);
    });

    test('Provider names are correct', () {
      expect(AIProvider.aistudio.name, 'aistudio');
      expect(AIProvider.qwen.name, 'qwen');
      expect(AIProvider.zai.name, 'zai');
      expect(AIProvider.kimi.name, 'kimi');
    });
  });
}