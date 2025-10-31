import '../../../shared/models/ai_provider.dart';

class SelectorDictionary {
  // Fallback selectors embedded in the app
  static const Map<AIProvider, Map<String, List<String>>> selectors = {
    AIProvider.aistudio: {
      'wait_until_ready': ['[data-testid="prompt-textarea"]', 'textarea'],
      'loginCheck': ['input[type="password"]', 'button:contains("Sign in")'],
      'promptTextarea': ['[data-testid="prompt-textarea"]', 'textarea'],
      'sendButton': ['button[data-testid="send-button"]', 'button:contains("Send")'],
      'isGenerating': ['[data-testid="stop-button"]', 'button:contains("Stop")'],
      'assistantResponse': ['[data-testid="conversation-turn-1"]', '.markdown-content'],
    },
    AIProvider.qwen: {
      'wait_until_ready': ['textarea[placeholder*="Message"]', 'textarea'],
      'loginCheck': ['input[type="password"]', '.sign-in-form'],
      'promptTextarea': ['textarea[placeholder*="Message"]', 'textarea'],
      'sendButton': ['button[type="submit"]', '.send-button'],
      'isGenerating': ['.generating-indicator', '.loading-dots'],
      'assistantResponse': ['.message-assistant', '.assistant-response'],
    },
    AIProvider.zai: {
      'wait_until_ready': ['textarea', '.message-input'],
      'loginCheck': ['input[type="password"]', '.login-form'],
      'promptTextarea': ['textarea', '.message-input'],
      'sendButton': ['button[type="submit"]', '.send-btn'],
      'isGenerating': ['.generating', '.loading'],
      'assistantResponse': ['.ai-response', '.response-content'],
    },
    AIProvider.kimi: {
      'wait_until_ready': ['textarea[placeholder*="Kimi"]', 'textarea'],
      'loginCheck': ['input[type="password"]', '.login-container'],
      'promptTextarea': ['textarea[placeholder*="Kimi"]', 'textarea'],
      'sendButton': ['button[data-testid="send-button"]', '.send-btn'],
      'isGenerating': ['.chat-interlude-stop-btn', '.generating'],
      'assistantResponse': ['[data-message-role="assistant"]', '.assistant-message'],
    },
  };

  // Get selectors for a specific provider
  static Map<String, List<String>> getSelectors(AIProvider provider) {
    return selectors[provider] ?? {};
  }

  // Get first available selector for a specific action
  static String? getSelector(AIProvider provider, String action) {
    final providerSelectors = getSelectors(provider);
    final actionSelectors = providerSelectors[action];
    if (actionSelectors == null || actionSelectors.isEmpty) return null;
    return actionSelectors.first;
  }

  // Get all selectors for a specific action (for fallback)
  static List<String> getSelectorsForAction(AIProvider provider, String action) {
    final providerSelectors = getSelectors(provider);
    return providerSelectors[action] ?? [];
  }

  // Convert selectors to JavaScript format
  static String toJsSelector(String selector) {
    // Convert CSS selectors to JavaScript querySelector format
    if (selector.startsWith('[') || selector.startsWith('.') || selector.startsWith('#')) {
      return 'document.querySelector("$selector")';
    }
    // Handle special cases like button:contains("text")
    if (selector.contains(':contains(')) {
      final match = RegExp(r'(.+?):contains\("(.+?)"\)').firstMatch(selector);
      if (match != null) {
        final tag = match.group(1);
        final text = match.group(2);
        return 'Array.from(document.querySelectorAll("$tag")).find(el => el.textContent.includes("$text"))';
      }
    }
    return 'document.querySelector("$selector")';
  }

  // Generate JavaScript for checking multiple selectors
  static String generateCheckJs(AIProvider provider, String action) {
    final selectors = getSelectorsForAction(provider, action);
    if (selectors.isEmpty) return 'null';

    final jsSelectors = selectors.map(toJsSelector).join(' || ');
    return '$jsSelectors';
  }

  // Validate selector format
  static bool isValidSelector(String selector) {
    if (selector.isEmpty) return false;

    // Basic validation for CSS selectors
    if (selector.contains(':contains(')) {
      return RegExp(r'.+?:contains\(".+?"\)$').hasMatch(selector);
    }

    return true;
  }
}