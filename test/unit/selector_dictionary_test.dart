import 'package:flutter_test/flutter_test.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';
import 'package:multi_webview_tab_manager/core/constants/selector_dictionary.dart';

void main() {
  group('SelectorDictionary Tests', () {
    test('Selectors exist for all providers', () {
      for (final provider in AIProvider.values) {
        final selectors = SelectorDictionary.getSelectors(provider);
        expect(selectors, isNotEmpty);
      }
    });

    test('Required selectors exist for all providers', () {
      final requiredActions = [
        'wait_until_ready',
        'loginCheck',
        'promptTextarea',
        'sendButton',
        'isGenerating',
        'assistantResponse',
      ];

      for (final provider in AIProvider.values) {
        final selectors = SelectorDictionary.getSelectors(provider);

        for (final action in requiredActions) {
          expect(selectors.containsKey(action), true,
              reason: 'Missing selector for $action in ${provider.displayName}');

          final actionSelectors = selectors[action]!;
          expect(actionSelectors, isNotEmpty,
              reason: 'Empty selector list for $action in ${provider.displayName}');
        }
      }
    });

    test('Get selector returns first available selector', () {
      final selector = SelectorDictionary.getSelector(
        AIProvider.aistudio,
        'promptTextarea',
      );

      expect(selector, isNotNull);
      expect(selector!.contains('prompt-textarea'), true);
    });

    test('Get selector returns null for non-existent action', () {
      final selector = SelectorDictionary.getSelector(
        AIProvider.aistudio,
        'nonExistentAction',
      );

      expect(selector, isNull);
    });

    test('Get selectors for action returns all available selectors', () {
      final selectors = SelectorDictionary.getSelectorsForAction(
        AIProvider.aistudio,
        'sendButton',
      );

      expect(selectors, isNotEmpty);
      expect(selectors.length, greaterThanOrEqualTo(1));
    });

    test('ToJsSelector converts CSS selectors correctly', () {
      // Test basic CSS selector
      final cssSelector = 'textarea[placeholder*="Message"]';
      final jsSelector = SelectorDictionary.toJsSelector(cssSelector);
      expect(jsSelector, contains('document.querySelector("$cssSelector")'));

      // Test contains selector
      final containsSelector = 'button:contains("Send")';
      final jsContainsSelector = SelectorDictionary.toJsSelector(containsSelector);
      expect(jsContainsSelector, contains('find(el => el.textContent.includes("Send"))'));
    });

    test('Generate check JS works correctly', () {
      final js = SelectorDictionary.generateCheckJs(
        AIProvider.kimi,
        'promptTextarea',
      );

      expect(js, isNotNull);
      expect(js, contains('document.querySelector'));
      expect(js, contains('||')); // Should contain OR for multiple selectors
    });

    test('Selector validation works correctly', () {
      // Valid selectors
      expect(SelectorDictionary.isValidSelector('textarea'), true);
      expect(SelectorDictionary.isValidSelector('button:contains("Send")'), true);
      expect(SelectorDictionary.isValidSelector('.class-name'), true);
      expect(SelectorDictionary.isValidSelector('#id-name'), true);

      // Invalid selectors
      expect(SelectorDictionary.isValidSelector(''), false);
      expect(SelectorDictionary.isValidSelector('   '), false);
    });

    test('All provider selectors are valid', () {
      for (final provider in AIProvider.values) {
        final selectors = SelectorDictionary.getSelectors(provider);

        for (final action in selectors.keys) {
          final actionSelectors = selectors[action]!;
          for (final selector in actionSelectors) {
            expect(SelectorDictionary.isValidSelector(selector), true,
                reason: 'Invalid selector "$selector" for $action in ${provider.displayName}');
          }
        }
      }
    });
  });
}