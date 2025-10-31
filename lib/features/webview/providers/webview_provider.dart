import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../shared/models/ai_provider.dart';
import '../../../core/utils/javascript_bridge.dart';

/// Provider for managing WebView controllers and bridges
class WebViewNotifier extends StateNotifier<Map<AIProvider, WebViewData>> {
  WebViewNotifier() : super({});

  /// Register a WebView controller for a provider
  void registerWebView({
    required AIProvider provider,
    required InAppWebViewController controller,
    required JavaScriptBridge bridge,
  }) {
    state = {
      ...state,
      provider: WebViewData(
        controller: controller,
        bridge: bridge,
        isReady: false,
        lastActivity: DateTime.now(),
      ),
    };

    debugPrint('WebView registered for ${provider.displayName}');
  }

  /// Mark WebView as ready
  void setWebViewReady(AIProvider provider, bool isReady) {
    final webViewData = state[provider];
    if (webViewData != null) {
      state = {
        ...state,
        provider: webViewData.copyWith(
          isReady: isReady,
          lastActivity: DateTime.now(),
        ),
      };
      debugPrint('WebView ready status for ${provider.displayName}: $isReady');
    }
  }

  /// Update last activity time
  void updateActivity(AIProvider provider) {
    final webViewData = state[provider];
    if (webViewData != null) {
      state = {
        ...state,
        provider: webViewData.copyWith(
          lastActivity: DateTime.now(),
        ),
      };
    }
  }

  /// Get WebView controller for provider
  InAppWebViewController? getController(AIProvider provider) {
    return state[provider]?.controller;
  }

  /// Get JavaScript bridge for provider
  JavaScriptBridge? getBridge(AIProvider provider) {
    return state[provider]?.bridge;
  }

  /// Check if WebView is ready
  bool isWebViewReady(AIProvider provider) {
    return state[provider]?.isReady ?? false;
  }

  /// Unregister WebView
  void unregisterWebView(AIProvider provider) {
    final newState = Map<AIProvider, WebViewData>.from(state);
    newState.remove(provider);
    state = newState;
    debugPrint('WebView unregistered for ${provider.displayName}');
  }

  /// Dispose all WebViews
  void disposeAll() {
    for (final webViewData in state.values) {
      try {
        webViewData.bridge.dispose();
      } catch (e) {
        debugPrint('Error disposing bridge: $e');
      }
    }
    state = {};
  }

  /// Get all ready providers
  List<AIProvider> getReadyProviders() {
    return state.entries
        .where((entry) => entry.value.isReady)
        .map((entry) => entry.key)
        .toList();
  }

  /// Check if any provider is ready
  bool get hasReadyProvider => state.values.any((data) => data.isReady);
}

/// Data class for WebView information
class WebViewData {
  final InAppWebViewController controller;
  final JavaScriptBridge bridge;
  final bool isReady;
  final DateTime lastActivity;

  WebViewData({
    required this.controller,
    required this.bridge,
    required this.isReady,
    required this.lastActivity,
  });

  WebViewData copyWith({
    InAppWebViewController? controller,
    JavaScriptBridge? bridge,
    bool? isReady,
    DateTime? lastActivity,
  }) {
    return WebViewData(
      controller: controller ?? this.controller,
      bridge: bridge ?? this.bridge,
      isReady: isReady ?? this.isReady,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

// Provider instances
final webviewProvider = StateNotifierProvider<WebViewNotifier, Map<AIProvider, WebViewData>>(
  (ref) => WebViewNotifier(),
);

/// Convenience providers
final readyWebViewsProvider = Provider<List<AIProvider>>(
  (ref) {
    final webviewNotifier = ref.watch(webviewProvider);
    return webviewNotifier.entries
        .where((entry) => entry.value.isReady)
        .map((entry) => entry.key)
        .toList();
  },
);

final hasReadyWebViewProvider = Provider<bool>(
  (ref) {
    final webviewNotifier = ref.watch(webviewProvider);
    return webviewNotifier.values.any((data) => data.isReady);
  },
);

/// Get WebView controller for specific provider
final webViewControllerProvider = Provider.family<InAppWebViewController?, AIProvider>(
  (ref, provider) {
    final webviewNotifier = ref.watch(webviewProvider);
    return webviewNotifier[provider]?.controller;
  },
);

/// Get JavaScript bridge for specific provider
final javascriptBridgeProvider = Provider.family<JavaScriptBridge?, AIProvider>(
  (ref, provider) {
    final webviewNotifier = ref.watch(webviewProvider);
    return webviewNotifier[provider]?.bridge;
  },
);

/// Check if WebView is ready for specific provider
final webviewReadyProvider = Provider.family<bool, AIProvider>(
  (ref, provider) {
    final webviewNotifier = ref.watch(webviewProvider);
    return webviewNotifier[provider]?.isReady ?? false;
  },
);