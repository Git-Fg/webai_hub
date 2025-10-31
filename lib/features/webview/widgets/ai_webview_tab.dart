import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/ai_provider.dart';
import '../../../core/utils/javascript_bridge.dart';
import '../../automation/widgets/companion_overlay.dart';

class AIWebViewTab extends ConsumerStatefulWidget {
  final AIProvider provider;

  const AIWebViewTab({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  ConsumerState<AIWebViewTab> createState() => _AIWebViewTabState();
}

class _AIWebViewTabState extends ConsumerState<AIWebViewTab> {
  InAppWebViewController? _webViewController;
  JavaScriptBridge? _javaScriptBridge;
  bool _isLoading = true;
  String? _errorMessage;
  double _loadingProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView Content
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.provider.url),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              useShouldOverrideUrlLoading: true,
              javaScriptCanOpenWindowsAutomatically: false,
              mediaPlaybackRequiresUserGesture: false,
              // Security settings
              allowFileAccessFromFileURLs: false,
              allowUniversalAccessFromFileURLs: false,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _initializeBridge();
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _loadingProgress = 0.0;
              });
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              await _checkProviderStatus();
            },

            // Add JavaScript handler for bridge communication
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('WebView Console [${widget.provider.displayName}]: ${consoleMessage.message}');
            },

            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedError: (controller, request, error) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            },
            // Add JavaScript channel for bridge communication
            androidOnPermissionRequest: (controller, origin, resources) async {
              return PermissionRequestResponse(
                resources: resources,
                action: PermissionRequestResponseAction.GRANT,
              );
            },
          ),

          // Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _loadingProgress,
                      color: Colors.deepPurpleAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chargement ${widget.provider.displayName}...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_loadingProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error Display
          if (_errorMessage != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _reloadPage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recharger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Companion overlay
          _buildCompanionOverlay(),
        ],
      ),
    );
  }

  // Build companion overlay
  Widget _buildCompanionOverlay() {
    return const CompanionOverlay();
  }
}

  Future<void> _initializeBridge() async {
    try {
      debugPrint('Initializing JavaScript bridge for ${widget.provider.displayName}');

      // Create JavaScript bridge
      _javaScriptBridge = JavaScriptBridge(
        provider: widget.provider,
        webViewController: _webViewController!,
        onMessage: _handleBridgeMessage,
      );

      // Initialize the bridge
      await _javaScriptBridge!.initialize();

      debugPrint('JavaScript bridge initialized for ${widget.provider.displayName}');
    } catch (e) {
      debugPrint('Failed to initialize bridge: $e');
    }
  }

  void _handleBridgeMessage(String message) {
    debugPrint('Bridge message from ${widget.provider.displayName}: $message');
    // TODO: Handle bridge messages in automation workflow
    // This will be implemented in Phase 6
  }

  Future<void> _checkProviderStatus() async {
    try {
      if (_javaScriptBridge != null) {
        await _javaScriptBridge!.checkStatus();
      }
    } catch (e) {
      debugPrint('Failed to check provider status: $e');
    }
  }

  Future<void> _reloadPage() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    await _webViewController?.reload();
  }
}