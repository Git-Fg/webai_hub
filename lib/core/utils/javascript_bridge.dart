import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants/selector_dictionary.dart';
import '../utils/asset_loader.dart';
import '../../shared/models/ai_provider.dart';
import '../../shared/models/automation_state.dart';

/// JavaScript Bridge for AI provider automation
class JavaScriptBridge {
  final AIProvider provider;
  final InAppWebViewController webViewController;
  final Function(String) onMessage;

  JavaScriptBridge({
    required this.provider,
    required this.webViewController,
    required this.onMessage,
  });

  /// Initialize the JavaScript bridge
  Future<void> initialize() async {
    try {
      debugPrint('JavaScriptBridge: Initializing bridge for ${provider.displayName}');

      // Load and inject automation scripts
      await _injectAutomationScripts();

      // Initialize the provider-specific bridge
      await _initializeProviderBridge();

      debugPrint('JavaScriptBridge: Bridge initialized successfully for ${provider.displayName}');
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to initialize bridge: $e');
      rethrow;
    }
  }

  /// Inject automation scripts into the WebView
  Future<void> _injectAutomationScripts() async {
    try {
      // Load the base automation script
      final String baseScript = await _loadScriptContent('assets/js/automation_base.js');

      // Inject the script
      await webViewController.evaluateJavascript(source: baseScript);

      debugPrint('JavaScriptBridge: Automation scripts injected');
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to inject scripts: $e');
      rethrow;
    }
  }

  /// Initialize the provider-specific bridge
  Future<void> _initializeProviderBridge() async {
    final String bridgeName = _getBridgeName();

    await webViewController.evaluateJavascript(source: '''
      if (window.$bridgeName) {
        window.$bridgeName.init();
      }
    ''');

    debugPrint('JavaScriptBridge: Provider bridge $bridgeName initialized');
  }

  /// Check if the provider is ready (logged in and page loaded)
  Future<bool> checkStatus() async {
    try {
      final String bridgeName = _getBridgeName();
      final selectors = await _getSelectors();

      final String checkScript = '''
        if (window.$bridgeName) {
          window.$bridgeName.checkStatus($selectors);
        }
      ''';

      await webViewController.evaluateJavascript(source: checkScript);
      return true;
    } catch (e) {
      debugPrint('JavaScriptBridge: Status check failed: $e');
      return false;
    }
  }

  /// Start automation workflow
  Future<void> startAutomation(String prompt, Map<String, dynamic> options) async {
    try {
      final String bridgeName = _getBridgeName();
      final selectors = await _getSelectors();
      final optionsJson = jsonEncode(options);

      final String startScript = '''
        if (window.$bridgeName) {
          window.$bridgeName.start(
            ${_escapeJavaScriptString(prompt)},
            JSON.parse('$optionsJson'),
            $selectors
          );
        }
      ''';

      await webViewController.evaluateJavascript(source: startScript);
      debugPrint('JavaScriptBridge: Automation started for ${provider.displayName}');
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to start automation: $e');
      rethrow;
    }
  }

  /// Extract the final response
  Future<String?> extractResponse() async {
    try {
      final String bridgeName = _getBridgeName();
      final selectors = await _getSelectors();

      final String extractScript = '''
        if (window.$bridgeName) {
          return window.$bridgeName.getFinalResponse($selectors);
        }
        return null;
      ''';

      final result = await webViewController.evaluateJavascript(source: extractScript);

      debugPrint('JavaScriptBridge: Response extracted: ${result?.toString().substring(0, 100)}...');
      return result?.toString();
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to extract response: $e');
      return null;
    }
  }

  /// Cancel current automation
  Future<void> cancelAutomation() async {
    try {
      final String bridgeName = _getBridgeName();

      await webViewController.evaluateJavascript(source: '''
        if (window.$bridgeName) {
          window.$bridgeName.cancel();
        }
      ''');

      debugPrint('JavaScriptBridge: Automation cancelled for ${provider.displayName}');
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to cancel automation: $e');
    }
  }

  /// Handle incoming JavaScript messages
  void handleJavaScriptMessage(String message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String event = data['event'] ?? '';
      final Map<String, dynamic> payload = data['payload'] ?? {};

      debugPrint('JavaScriptBridge: Received event: $event from ${provider.displayName}');

      switch (event) {
        case 'onBridgeReady':
          onMessage(jsonEncode({
            'event': 'bridgeReady',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onStatusResult':
          onMessage(jsonEncode({
            'event': 'statusResult',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onAutomationStarted':
          onMessage(jsonEncode({
            'event': 'automationStarted',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onGenerationStarted':
          onMessage(jsonEncode({
            'event': 'generationStarted',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onGenerationComplete':
          onMessage(jsonEncode({
            'event': 'generationComplete',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onExtractionResult':
          onMessage(jsonEncode({
            'event': 'extractionResult',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onAutomationFailed':
        case 'onExtractionFailed':
          onMessage(jsonEncode({
            'event': 'automationFailed',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        case 'onAutomationCancelled':
          onMessage(jsonEncode({
            'event': 'automationCancelled',
            'provider': provider.name,
            'payload': payload,
          }));
          break;

        default:
          debugPrint('JavaScriptBridge: Unknown event: $event');
          onMessage(jsonEncode({
            'event': 'unknown',
            'provider': provider.name,
            'payload': data,
          }));
      }
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to handle message: $e');
    }
  }

  /// Get bridge name for the provider
  String _getBridgeName() {
    switch (provider) {
      case AIProvider.aistudio:
        return 'aistudioBridge';
      case AIProvider.qwen:
        return 'qwenBridge';
      case AIProvider.zai:
        return 'zaibridge';
      case AIProvider.kimi:
        return 'kimibridge';
    }
  }

  /// Get selectors for the provider
  Future<Map<String, List<String>>> _getSelectors() async {
    try {
      // Try to load from assets first
      final assetSelectors = await AssetLoader.getSelectorsForProvider(provider);
      if (assetSelectors.isNotEmpty) {
        return assetSelectors;
      }

      // Fallback to embedded selectors
      return SelectorDictionary.getSelectors(provider);
    } catch (e) {
      debugPrint('JavaScriptBridge: Failed to get selectors: $e');
      return SelectorDictionary.getSelectors(provider);
    }
  }

  /// Load script content from assets
  Future<String> _loadScriptContent(String assetPath) async {
    // For now, return the script content directly
    // In a real implementation, you would load from assets
    switch (assetPath) {
      case 'assets/js/automation_base.js':
        return await _getBaseAutomationScript();
      default:
        throw Exception('Unknown script: $assetPath');
    }
  }

  /// Get base automation script content
  Future<String> _getBaseAutomationScript() async {
    // This would normally be loaded from assets, but for now we'll use a simplified version
    return '''
      class HubBridge {
        constructor(channelName) {
          this.channelName = channelName;
          this.messageQueue = [];
          this.isBridgeReady = false;
          this.observers = [];
          this.currentObserver = null;
          this.isGenerating = false;
          this.lastResponseElement = null;
        }

        init() {
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            this.isBridgeReady = true;
            this.flushMessageQueue();
            this.postMessage({
              event: 'onBridgeReady',
              payload: { channelName: this.channelName, timestamp: Date.now() }
            });
            console.log(\`HubBridge [\${this.channelName}]: Bridge initialized\`);
          } else {
            setTimeout(() => this.init(), 1000);
          }
        }

        postMessage(message) {
          if (this.isBridgeReady && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler(this.channelName, JSON.stringify(message));
          } else {
            this.messageQueue.push(message);
          }
        }

        flushMessageQueue() {
          while (this.messageQueue.length > 0) {
            const message = this.messageQueue.shift();
            this.postMessage(message);
          }
        }

        async checkStatus(selectors) {
          try {
            const loginSelectors = selectors.loginCheck || [];
            let isLoggedIn = true;
            for (const selector of loginSelectors) {
              const element = document.querySelector(selector);
              if (element) {
                isLoggedIn = false;
                break;
              }
            }

            const promptSelectors = selectors.wait_until_ready || [];
            let isReady = false;
            if (isLoggedIn) {
              for (const selector of promptSelectors) {
                const element = document.querySelector(selector);
                if (element && element.offsetParent !== null) {
                  isReady = true;
                  break;
                }
              }
            }

            const status = isLoggedIn ? (isReady ? 'ready' : 'login') : 'login';
            this.postMessage({
              event: 'onStatusResult',
              payload: { status: status, isLoggedIn: isLoggedIn, isReady: isReady, timestamp: Date.now() }
            });
            return status;
          } catch (error) {
            this.postMessage({
              event: 'onStatusResult',
              payload: { status: 'error', error: error.message, timestamp: Date.now() }
            });
            return 'error';
          }
        }

        cancel() {
          if (this.currentObserver) {
            this.currentObserver.disconnect();
            this.currentObserver = null;
          }
          this.isGenerating = false;
          this.postMessage({
            event: 'onAutomationCancelled',
            payload: { timestamp: Date.now() }
          });
        }
      }
    ''';
  }

  /// Escape string for JavaScript
  String _escapeJavaScriptString(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Dispose the bridge
  void dispose() {
    cancelAutomation();
    debugPrint('JavaScriptBridge: Bridge disposed for ${provider.displayName}');
  }
}