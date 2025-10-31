import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/selector_dictionary.dart';
import '../../shared/models/ai_provider.dart';

class RemoteConfigService {
  static const String _configUrl = 'https://api.github.com/gists/'; // Placeholder
  static const String _cacheKey = 'selector_config_cache';
  static const String _lastUpdateKey = 'selector_config_last_update';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Fetch remote configuration with fallback to embedded selectors
  static Future<Map<AIProvider, Map<String, List<String>>>> fetchSelectors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if cache is still valid
      if (now - lastUpdate < _cacheExpiry.inMilliseconds) {
        final cachedConfig = prefs.getString(_cacheKey);
        if (cachedConfig != null) {
          return _parseRemoteConfig(jsonDecode(cachedConfig));
        }
      }

      // Try to fetch from remote
      final response = await http.get(
        Uri.parse('$_configUrl'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AI-Hybrid-Hub/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final remoteConfig = jsonDecode(response.body);

        // Cache the response
        await prefs.setString(_cacheKey, response.body);
        await prefs.setInt(_lastUpdateKey, now);

        return _parseRemoteConfig(remoteConfig);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      // On any error, fall back to embedded selectors
      print('Warning: Failed to fetch remote selector config: $e');
      print('Using embedded selector dictionary as fallback');
      return SelectorDictionary.selectors;
    }
  }

  // Parse remote configuration format
  static Map<AIProvider, Map<String, List<String>>> _parseRemoteConfig(
    Map<String, dynamic> remoteConfig,
  ) {
    final Map<AIProvider, Map<String, List<String>>> parsed = {};

    for (final provider in AIProvider.values) {
      final providerName = provider.name;
      if (remoteConfig.containsKey(providerName)) {
        final providerData = remoteConfig[providerName] as Map<String, dynamic>;
        final Map<String, List<String>> selectors = {};

        for (final entry in providerData.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is List) {
            selectors[key] = List<String>.from(value);
          } else if (value is String) {
            selectors[key] = [value];
          }
        }

        parsed[provider] = selectors;
      }
    }

    return parsed;
  }

  // Clear cached configuration
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastUpdateKey);
  }

  // Force refresh from remote
  static Future<Map<AIProvider, Map<String, List<String>>>> refreshSelectors() async {
    await clearCache();
    return fetchSelectors();
  }

  // Get selectors for a specific provider (with remote support)
  static Future<Map<String, List<String>>> getSelectorsForProvider(
    AIProvider provider,
  ) async {
    final allSelectors = await fetchSelectors();
    return allSelectors[provider] ?? {};
  }

  // Get first available selector for action (with remote support)
  static Future<String?> getSelector(
    AIProvider provider,
    String action,
  ) async {
    final allSelectors = await fetchSelectors();
    final providerSelectors = allSelectors[provider] ?? {};
    final actionSelectors = providerSelectors[action];
    if (actionSelectors == null || actionSelectors.isEmpty) return null;
    return actionSelectors.first;
  }

  // Generate JavaScript check (with remote support)
  static Future<String> generateCheckJs(
    AIProvider provider,
    String action,
  ) async {
    final allSelectors = await fetchSelectors();
    final providerSelectors = allSelectors[provider] ?? {};
    final selectors = providerSelectors[action] ?? [];

    if (selectors.isEmpty) return 'null';

    final jsSelectors = selectors.map(SelectorDictionary.toJsSelector).join(' || ');
    return '$jsSelectors';
  }

  // Validate remote configuration
  static bool _validateRemoteConfig(Map<String, dynamic> config) {
    try {
      // Basic structure validation
      if (!config.containsKey('selectors')) return false;

      final selectors = config['selectors'] as Map<String, dynamic>;

      // Validate each provider
      for (final provider in AIProvider.values) {
        final providerName = provider.name;
        if (selectors.containsKey(providerName)) {
          final providerData = selectors[providerName] as Map<String, dynamic>;

          // Validate required actions exist
          final requiredActions = [
            'wait_until_ready',
            'loginCheck',
            'promptTextarea',
            'sendButton',
            'isGenerating',
            'assistantResponse',
          ];

          for (final action in requiredActions) {
            if (!providerData.containsKey(action)) {
              print('Warning: Missing required action "$action" for provider "$providerName"');
              return false;
            }

            final actionData = providerData[action];
            if (actionData is! List && actionData is! String) {
              print('Warning: Invalid selector format for action "$action" in provider "$providerName"');
              return false;
            }
          }
        }
      }

      return true;
    } catch (e) {
      print('Error validating remote config: $e');
      return false;
    }
  }

  // Get cache status
  static Future<Map<String, dynamic>> getCacheStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
    final cachedConfig = prefs.getString(_cacheKey);

    return {
      'hasCachedConfig': cachedConfig != null,
      'lastUpdate': lastUpdate > 0 ? DateTime.fromMillisecondsSinceEpoch(lastUpdate) : null,
      'isExpired': DateTime.now().millisecondsSinceEpoch - lastUpdate > _cacheExpiry.inMilliseconds,
      'cacheAge': lastUpdate > 0
          ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastUpdate))
          : null,
    };
  }
}