import 'dart:convert';
import 'package:flutter/services.dart';
import '../constants/selector_dictionary.dart';
import '../../shared/models/ai_provider.dart';

class AssetLoader {
  // Load selector configuration from assets
  static Future<Map<AIProvider, Map<String, List<String>>>> loadSelectorsFromAssets() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/json/selectors.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      return _parseSelectorConfig(jsonMap);
    } catch (e) {
      print('Warning: Failed to load selectors from assets: $e');
      print('Using embedded selector dictionary as fallback');
      return SelectorDictionary.selectors;
    }
  }

  // Parse selector configuration from JSON
  static Map<AIProvider, Map<String, List<String>>> _parseSelectorConfig(
    Map<String, dynamic> config,
  ) {
    final Map<AIProvider, Map<String, List<String>>> parsed = {};

    // Check if config has 'selectors' key
    if (!config.containsKey('selectors')) {
      print('Warning: No "selectors" key found in config');
      return SelectorDictionary.selectors;
    }

    final selectors = config['selectors'] as Map<String, dynamic>;

    for (final provider in AIProvider.values) {
      final providerName = provider.name;
      if (selectors.containsKey(providerName)) {
        final providerData = selectors[providerName] as Map<String, dynamic>;
        final Map<String, List<String>> providerSelectors = {};

        for (final entry in providerData.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is List) {
            providerSelectors[key] = List<String>.from(value);
          } else if (value is String) {
            providerSelectors[key] = [value];
          }
        }

        parsed[provider] = providerSelectors;
      }
    }

    return parsed;
  }

  // Get selectors for a specific provider from assets
  static Future<Map<String, List<String>>> getSelectorsForProvider(
    AIProvider provider,
  ) async {
    final allSelectors = await loadSelectorsFromAssets();
    return allSelectors[provider] ?? {};
  }

  // Get first available selector for action from assets
  static Future<String?> getSelector(
    AIProvider provider,
    String action,
  ) async {
    final allSelectors = await loadSelectorsFromAssets();
    final providerSelectors = allSelectors[provider] ?? {};
    final actionSelectors = providerSelectors[action];
    if (actionSelectors == null || actionSelectors.isEmpty) return null;
    return actionSelectors.first;
  }

  // Validate selectors in configuration
  static bool validateSelectors(Map<AIProvider, Map<String, List<String>>> selectors) {
    try {
      final requiredActions = [
        'wait_until_ready',
        'loginCheck',
        'promptTextarea',
        'sendButton',
        'isGenerating',
        'assistantResponse',
      ];

      for (final provider in AIProvider.values) {
        final providerSelectors = selectors[provider] ?? {};

        // Check if required actions exist
        for (final action in requiredActions) {
          if (!providerSelectors.containsKey(action)) {
            print('Warning: Missing required action "$action" for provider "${provider.name}"');
            return false;
          }

          final actionSelectors = providerSelectors[action] ?? [];
          if (actionSelectors.isEmpty) {
            print('Warning: Empty selectors for action "$action" in provider "${provider.name}"');
            return false;
          }

          // Validate each selector
          for (final selector in actionSelectors) {
            if (!SelectorDictionary.isValidSelector(selector)) {
              print('Warning: Invalid selector "$selector" for action "$action" in provider "${provider.name}"');
              return false;
            }
          }
        }
      }

      return true;
    } catch (e) {
      print('Error validating selectors: $e');
      return false;
    }
  }

  // Load and validate configuration
  static Future<Map<AIProvider, Map<String, List<String>>>> loadValidatedSelectors() async {
    final selectors = await loadSelectorsFromAssets();

    if (validateSelectors(selectors)) {
      return selectors;
    } else {
      print('Warning: Invalid selector configuration, falling back to embedded selectors');
      return SelectorDictionary.selectors;
    }
  }

  // Get configuration metadata
  static Future<Map<String, dynamic>?> getConfigMetadata() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/json/selectors.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      return {
        'version': jsonMap['version'],
        'lastUpdated': jsonMap['lastUpdated'],
        'description': jsonMap['description'],
        'providerCount': jsonMap['selectors']?.keys.length ?? 0,
      };
    } catch (e) {
      print('Warning: Failed to load config metadata: $e');
      return null;
    }
  }
}