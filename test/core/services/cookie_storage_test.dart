import 'package:ai_hybrid_hub/core/services/cookie_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CookieStorage', () {
    // WHY: Test domain extraction logic which doesn't require Hive initialization.
    // The save/load round-trip will be verified in integration tests where Hive
    // can be properly initialized.
    test('extracts domain from URL correctly', () {
      expect(
        CookieStorage.extractDomain('https://aistudio.google.com/chat'),
        'aistudio.google.com',
      );
      expect(
        CookieStorage.extractDomain('https://www.kimi.com/chat'),
        'www.kimi.com',
      );
      expect(
        CookieStorage.extractDomain('https://kimi.com/chat'),
        'kimi.com',
      );
      expect(
        CookieStorage.extractDomain('aistudio.google.com'),
        'aistudio.google.com',
      );
      expect(
        CookieStorage.extractDomain('http://example.com/path'),
        'example.com',
      );
    });

    test('handles invalid URLs gracefully', () {
      // WHY: If URL parsing fails, should return original string as fallback
      expect(
        CookieStorage.extractDomain('not-a-url'),
        'not-a-url',
      );
      expect(
        CookieStorage.extractDomain(''),
        '',
      );
    });
  });
}
