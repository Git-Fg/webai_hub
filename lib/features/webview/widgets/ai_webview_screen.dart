import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/core/services/cookie_storage.dart';
import 'package:ai_hybrid_hub/core/services/webview_cookie_handler.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/models/provider_type.dart';
import 'package:ai_hybrid_hub/features/settings/models/browser_user_agent.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event_handler.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/providers/webview_key_provider.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:ai_hybrid_hub/providers/bridge_script_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

class AiWebviewScreen extends ConsumerStatefulWidget {
  const AiWebviewScreen({required this.preset, super.key});

  final PresetData preset;

  @override
  ConsumerState<AiWebviewScreen> createState() => _AiWebviewScreenState();
}

class _AiWebviewScreenState extends ConsumerState<AiWebviewScreen>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<AiWebviewScreen> {
  InAppWebViewController? webViewController;
  double _progress = 0;
  String? _currentBridgeScript;
  final WebViewCookieHandler _cookieHandler = WebViewCookieHandler();
  BridgeEventHandler? _eventHandler;
  // WHY: Flag to prevent showing the notification multiple times for the same error.
  bool _isUserAgentNoticeShown = false;
  // WHY: Track if initial navigation has occurred to ensure cookies are injected first.
  bool _hasNavigatedInitially = false;

  @override
  bool get wantKeepAlive => true;

  // WHY: Helper method to resolve provider URL from providerId.
  // This encapsulates the conversion from providerId string to ProviderType enum
  // and then to the actual URL from providerDetails map.
  String _getProviderUrl() {
    final providerId = widget.preset.providerId;
    final providerType = ProviderType.values.firstWhere(
      (pt) => providerDetails[pt]!.id == providerId,
      orElse: () => ProviderType.aiStudio,
    );
    return providerDetails[providerType]!.url;
  }

  // WHY: Centralized domain verification logic to avoid duplication.
  // Checks if the URL belongs to a supported domain or is a local file.
  bool _isSupportedDomain(Uri? url) {
    if (url == null) return false;
    // The check for 'file://' is for initial loading from assets
    return url.host == WebViewConstants.aiStudioDomain ||
        url.host == WebViewConstants.kimiDomain ||
        url.host == WebViewConstants.kimiDomainAlt ||
        url.toString().startsWith('file://');
  }

  @override
  void initState() {
    super.initState();
    // WHY: Register lifecycle observer to detect app resume and check bridge health
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _startAutomation(AutomationRequest request) async {
    try {
      // Pass the preset ID to get the correct controller
      final bridge = ref.read(javaScriptBridgeProvider(widget.preset.id));
      await bridge.waitForBridgeReady();
      // Parse widget.preset.settingsJson into a map
      final settings =
          jsonDecode(widget.preset.settingsJson) as Map<String, dynamic>;
      final options = {
        'providerId': widget.preset.providerId,
        'prompt': request.promptWithContext,
        ...settings, // Add model, temperature etc.
      };
      await bridge.startAutomation(options);
    } on Object catch (e, st) {
      ref
          .read(talkerProvider)
          .handle(e, st, '[WebView-${widget.preset.name}] Automation failed.');
      // Update staging provider with error
      ref
          .read(stagedResponsesProvider.notifier)
          .addOrUpdate(
            StagedResponse(
              presetId: widget.preset.id,
              presetName: widget.preset.name,
              text: 'Error: $e',
            ),
          );
    }
  }

  @override
  void dispose() {
    // WHY: Unregister lifecycle observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    // Remove JavaScript handlers to prevent memory leaks
    webViewController?.removeJavaScriptHandler(
      handlerName: BridgeConstants.automationHandler,
    );
    webViewController?.removeJavaScriptHandler(
      handlerName: BridgeConstants.readyHandler,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WHY: On app resume, check bridge health and recover if needed
    // iOS WebViews often become "zombie" contexts after backgrounding
    if (state == AppLifecycleState.resumed) {
      // WHY: Fire-and-forget: recovery happens asynchronously, no need to await
      unawaited(_checkBridgeHealthOnResume());
    }
  }

  /// Injects cookies via JavaScript as a workaround for CookieManager persistence issues
  Future<void> _injectCookiesViaJavaScript(
    InAppWebViewController controller,
    String url,
  ) async {
    try {
      final domain = CookieStorage.extractDomain(url);
      final cookies = await CookieStorage.loadCookies(domain);
      
      if (cookies.isEmpty) return;
      
      await _cookieHandler.injectCookiesViaJavaScript(controller, cookies);
    } on Exception catch (e) {
      debugPrint(
        '[AiWebviewScreen] Failed to inject cookies via JavaScript: $e',
      );
    }
  }

  /// Checks bridge health after app resume and triggers recovery if needed
  Future<void> _checkBridgeHealthOnResume() async {
    final controller = webViewController;
    if (controller == null) return;

    try {
      final bridge = ref.read(javaScriptBridgeProvider(widget.preset.id));
      if (bridge is JavaScriptBridge) {
        final isAlive = await bridge.isBridgeAlive();
        if (!isAlive) {
          // WHY: Wrap talker access in try-catch to handle any provider access issues
          Talker? talker;
          try {
            if (!mounted) return;
            talker = ref.read(talkerProvider);
            talker?.warning(
              '[AiWebviewScreen] Bridge dead after resume, triggering recovery...',
            );
          } on Object catch (e) {
            debugPrint(
              '[AiWebviewScreen] Failed to access talker in bridge health check: $e',
            );
          }
          await _recoverFromDeadBridge(controller);
        }
      }
    } on Object catch (e) {
      // WHY: Wrap talker access in try-catch to handle any provider access issues
      Talker? talker;
      try {
        if (!mounted) return;
        talker = ref.read(talkerProvider);
        talker?.warning(
          '[AiWebviewScreen] Error checking bridge health on resume: $e',
        );
      } on Object catch (logError) {
        debugPrint(
          '[AiWebviewScreen] Failed to log bridge check error: $logError',
        );
      }
    }
  }

  // NEW HELPER METHOD: Encapsulates showing the detailed, actionable error notification.
  void _showUserAgentErrorNotification() {
    if (!mounted || _isUserAgentNoticeShown) return;

    setState(() {
      _isUserAgentNoticeShown = true;
    });

    ElegantNotification.error(
      title: const Text('⚠️ Google Login Blocked (Error 403)'),
      description: const Text(
        'Google detected an incompatible browser identity. This is normal for embedded apps.\n\nSolution: Go to Settings and select a standard browser User Agent (e.g., Chrome).',
      ),
      toastDuration: const Duration(seconds: 15),
      showProgressIndicator: false,
    ).show(context);

    // Show a SnackBar with action button to navigate to settings
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap to open Settings'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () {
              unawaited(context.router.push(const SettingsRoute()));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // REQUIRED call for AutomaticKeepAliveClientMixin
    final bridgeScriptAsync = ref.watch(bridgeScriptProvider);

    // WHY: This listener is CRITICAL. It watches for changes in the User Agent
    // settings and increments the webViewKey. This is the only reliable way
    // to force Flutter to destroy the old WebView and create a new one with
    // the updated initialSettings.
    ref.listen(generalSettingsProvider, (previous, next) {
      final prevData = previous?.maybeWhen(
        data: (data) => data,
        orElse: () => null,
      );
      final nextData = next.maybeWhen(
        data: (data) => data,
        orElse: () => null,
      );

      if (prevData != null && nextData != null) {
        final uaChanged =
            prevData.selectedUserAgent != nextData.selectedUserAgent;
        final customUaChanged =
            prevData.customUserAgent != nextData.customUserAgent;

        if (uaChanged || customUaChanged) {
          ref.read(webViewKeyProvider.notifier).incrementKey();
        }
      }
    });

    // WHY: Listen for automation requests in build method (ref.listen can only be used here).
    // This reacts to automation requests and starts the automation process for this preset's WebView.
    ref.listen<Map<int, AutomationRequest>>(automationRequestProvider, (
      _,
      next,
    ) {
      final myRequestId = widget.preset.id;
      final myRequest = next[myRequestId];
      if (myRequest != null) {
        final talker = ref.read(talkerProvider);
        talker.info(
          '[WebView-${widget.preset.name}] Received automation request.',
        );
        ref.read(automationRequestProvider.notifier).clearRequest(myRequestId);
        unawaited(_startAutomation(myRequest));
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final controller = webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.preset.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.green.shade600,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                if (webViewController == null) return;
                // WHY: Wrap talker access in try-catch to handle any provider access issues
                Talker? talker;
                try {
                  if (!mounted) return;
                  talker = ref.read(talkerProvider);
                  talker?.info('[DOM INSPECT] Requesting DOM analysis...');
                } on Object catch (e) {
                  debugPrint('[DOM INSPECT] Failed to access talker: $e');
                }
                try {
                  final result = await webViewController!.evaluateJavascript(
                    source: 'inspectDOMForSelectors();',
                  );
                  if (result != null) {
                    const encoder = JsonEncoder.withIndent('  ');
                    final prettyJson = encoder.convert(result);
                    if (talker != null) {
                      try {
                        talker.info('[DOM INSPECT] Result:\n$prettyJson');
                      } on Object catch (_) {
                        // Ignore logging errors
                      }
                    }
                  } else {
                    if (talker != null) {
                      try {
                        talker.info(
                          '[DOM INSPECT] inspectDOMForSelectors returned null.',
                        );
                      } on Object catch (_) {
                        // Ignore logging errors
                      }
                    }
                  }
                } on Object catch (e) {
                  if (talker != null) {
                    try {
                      talker.error('[DOM INSPECT] Error: $e');
                    } on Object catch (_) {
                      // Ignore logging errors
                    }
                  }
                }
              },
              tooltip: 'Inspect DOM for Selectors',
            ),
          ],
          bottom: _progress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.green.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        body: bridgeScriptAsync.when(
          data: _buildWebView,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Error loading bridge script: $err'),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(String bridgeScript) {
    // WHY: Store bridge script for use in recovery methods
    _currentBridgeScript = bridgeScript;
    final webViewKey = ref.watch(webViewKeyProvider);
    final settings = ref
        .watch(generalSettingsProvider)
        .maybeWhen(
          data: (data) => data,
          orElse: () => const GeneralSettingsData(),
        );

    // REVISED LOGIC: Determine the final User Agent string to apply.
    final String? userAgent;
    if (settings.selectedUserAgent == 'default') {
      userAgent = null; // Let flutter_inappwebview use its default.
    } else if (settings.selectedUserAgent == 'custom') {
      userAgent = settings.customUserAgent.isNotEmpty
          ? settings.customUserAgent
          : null;
    } else {
      // Find the corresponding enum value from the saved name.
      userAgent = BrowserUserAgent.values
          .firstWhere(
            (ua) => ua.name == settings.selectedUserAgent,
            // Fallback to a known good UA if something goes wrong.
            orElse: () => BrowserUserAgent.chromeWindows,
          )
          .value;
    }

    return InAppWebView(
      key: ValueKey('ai_webview_${widget.preset.id}_$webViewKey'),
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        applicationNameForUserAgent: 'AIHybridHub',
        supportZoom: settings.webViewSupportZoom, // Read from settings
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
        // WHY: Disable database APIs if not needed to reduce attack surface
        databaseEnabled: false,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        // WHY: Wrap talker access in try-catch to handle any provider access issues
        Talker? talker;
        try {
          if (!mounted) return NavigationActionPolicy.CANCEL;
          talker = ref.read(talkerProvider);
        } on Object catch (e) {
          debugPrint(
            '[WebView] Failed to access talker in shouldOverrideUrlLoading: $e',
          );
          // Continue without logging if talker access fails
        }
        final uri = navigationAction.request.url;
        if (talker != null) {
          try {
            talker.info('[WebView] Navigation request to: $uri');
          } on Object catch (_) {
            // Ignore logging errors
          }
        }
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (controller) {
        webViewController = controller;
        // WHY: Register controller with preset-specific provider to support multiple WebViews
        ref
            .read(webViewControllerProvider(widget.preset.id).notifier)
            .setController(controller);
        ref
            .read(bridgeDiagnosticsStateProvider.notifier)
            .recordWebViewCreated();

        // WHY: Initialize bridge event handler when WebView is created
        // This ensures it's ready before any events are received
        _eventHandler ??= BridgeEventHandler(
          ref,
          widget.preset.id,
          widget.preset.name,
        );

        // WHY: Inject saved cookies before page loads to ensure authenticated session.
        // This enables integration tests to use pre-captured "Golden Cookies".
        // We await cookie injection and then navigate programmatically to ensure
        // cookies are set before the page loads.
        final url = _getProviderUrl();
        _cookieHandler
            .injectSavedCookies(url)
            .then((_) {
              // WHY: Navigate after cookies are injected to ensure authenticated session.
              if (mounted && !_hasNavigatedInitially) {
                _hasNavigatedInitially = true;
                controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
              }
            })
            .catchError((Object e) {
              // WHY: Even if cookie injection fails, still navigate so the app can function.
              // User can manually log in if needed.
              debugPrint(
                '[AiWebviewScreen] Cookie injection failed, navigating anyway: $e',
              );
              if (mounted && !_hasNavigatedInitially) {
                _hasNavigatedInitially = true;
                controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
              }
            });

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.automationHandler,
          callback: (args) {
            // Logic is now cleanly delegated to BridgeEventHandler
            _eventHandler?.handle(args);
          },
        );

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.readyHandler,
          callback: (args) {
            // WHY: Wrap talker access in try-catch to handle any provider access issues
            Talker? talker;
            try {
              talker = ref.read(talkerProvider);
              talker?.info('[AiWebviewScreen] bridgeReady handler called');
            } on Object catch (e) {
              debugPrint(
                '[AiWebviewScreen] Failed to log bridge ready: $e',
              );
            }
            ref
              ..read(bridgeReadyProvider.notifier).markReady()
              ..read(
                bridgeDiagnosticsStateProvider.notifier,
              ).recordBridgeReady();
          },
        );
      },
      onProgressChanged: (controller, progress) {
        setState(() {
          _progress = progress / 100;
        });
      },
      onLoadStart: (controller, url) async {
        // Reset the notice flag on any new page load.
        if (_isUserAgentNoticeShown) {
          setState(() {
            _isUserAgentNoticeShown = false;
          });
        }
        setState(() {
          _progress = 0;
        });
        // WHY: This is critical to prevent race conditions. Whenever a new page starts
        // loading, we must consider the bridge not ready until the new page explicitly
        // signals its readiness via the 'bridgeReady' handler.
        ref.read(bridgeReadyProvider.notifier).reset();

        // WHY: Ensure cookies are injected before page loads, even if this is a reload.
        // This handles edge cases where cookies might not have been injected initially.
        if (url != null && _isSupportedDomain(url)) {
          unawaited(_cookieHandler.injectSavedCookies(url.toString()));
          
          // WHY: Also try JavaScript injection as workaround for CookieManager persistence issues
          // This is especially important for Google authentication flows
          if (url.host.contains('google.com')) {
            unawaited(_injectCookiesViaJavaScript(controller, url.toString()));
          }
        }
      },
      onLoadStop: (controller, url) async {
        setState(() {
          _progress = 1.0;
        });

        // WHY: Wrap talker access in try-catch to handle any provider access issues
        Talker? talker;
        try {
          if (!mounted) return;
          talker = ref.read(talkerProvider);
        } on Object catch (e) {
          debugPrint('[WebView] Failed to access talker in onLoadStop: $e');
        }
        final currentUrl = url?.toString() ?? 'unknown';
        if (talker != null) {
          try {
            talker.info('[WebView] Page finished loading: $currentUrl');
          } on Object catch (_) {
            // Ignore logging errors
          }
        }

        // WHY: This check is now stricter. It verifies the exact host of the URL,
        // preventing the bridge script from being injected into cross-origin
        // redirect pages like the Google login page.
        if (_isSupportedDomain(url)) {
          if (talker != null) {
            try {
              talker.info(
                '[WebView] URL matches supported domain, injecting bridge script...',
              );
            } on Object catch (_) {
              // Ignore logging errors
            }
          }
          await _injectBridgeScript(controller, bridgeScript);
        } else {
          if (talker != null) {
            try {
              talker.warning(
                '[WebView] URL does not match supported domain, bridge script NOT injected.',
              );
            } on Object catch (_) {
              // Ignore logging errors
            }
          }
        }

        final bridge = ref.read(javaScriptBridgeProvider(widget.preset.id));
        if (bridge is JavaScriptBridge) {
          await bridge.captureConsoleLogs();
        }

        // WHY: Capture cookies after page loads to update stored cookies if session is renewed.
        // This ensures cookies stay fresh during normal app usage.
        if (url != null) {
          unawaited(_cookieHandler.captureCookies(url.toString()));
        }
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) async {
        final newUrl = url?.toString() ?? '';
        ref.read(currentWebViewUrlProvider.notifier).updateUrl(newUrl);

        // Reset the notice flag if the user navigates away from the error page.
        if (!newUrl.contains('disallowed_useragent') &&
            _isUserAgentNoticeShown) {
          setState(() {
            _isUserAgentNoticeShown = false;
          });
        }

        // WHY: Applying the same strict host check here ensures that client-side
        // routing to an external page doesn't trigger a faulty bridge injection.
        if (_isSupportedDomain(url)) {
          try {
            final bridge = ref.read(javaScriptBridgeProvider(widget.preset.id));
            if (bridge is JavaScriptBridge) {
              final isAlive = await bridge.isBridgeAlive();
              if (!isAlive) {
                // WHY: Wrap talker access in try-catch to handle any provider access issues
                Talker? talker;
                try {
                  if (!mounted) return;
                  talker = ref.read(talkerProvider);
                  talker?.warning(
                    '[AiWebviewScreen] Bridge dead after SPA navigation, re-injecting...',
                  );
                } on Object catch (e) {
                  debugPrint(
                    '[AiWebviewScreen] Failed to log bridge dead warning: $e',
                  );
                }
                await _injectBridgeScript(controller, _currentBridgeScript);
              }
            }
          } on Object catch (e) {
            // WHY: Wrap talker access in try-catch to handle any provider access issues
            Talker? talker;
            try {
              if (!mounted) return;
              talker = ref.read(talkerProvider);
              talker?.warning(
                '[AiWebviewScreen] Error checking bridge after SPA navigation: $e',
              );
            } on Object catch (logError) {
              debugPrint(
                '[AiWebviewScreen] Failed to log bridge check error: $logError',
              );
            }
            // WHY: On error, attempt re-injection anyway as defensive measure
            await _injectBridgeScript(controller, _currentBridgeScript);
          }
        }
      },
      // WHY: Android renderer process crash is fatal - WebView instance becomes unusable
      // Recovery requires destroying and recreating the entire widget via key change
      onRenderProcessGone: (controller, details) {
        // WHY: Wrap talker access in try-catch to handle any provider access issues
        Talker? talker;
        try {
          talker = ref.read(talkerProvider);
          talker?.warning(
            '[AiWebviewScreen] Android renderer process crashed: ${details.didCrash}',
          );
        } on Object catch (e) {
          debugPrint(
            '[AiWebviewScreen] Failed to log renderer crash: $e',
          );
        }
        // Reset bridge state
        ref.read(bridgeReadyProvider.notifier).reset();
        // WHY: Increment key to trigger widget recreation (only way to recover on Android)
        ref.read(webViewKeyProvider.notifier).incrementKey();
      },
      // WHY: iOS content process crashes are handled via lifecycle observer (didChangeAppLifecycleState)
      // The heartbeat check on app resume will detect and recover from zombie contexts
      // iOS crashes often manifest as "zombie" contexts that hang on evaluateJavascript calls
      onConsoleMessage: (controller, consoleMessage) {
        // NEW: Robust error detection from console logs.
        if (consoleMessage.message.contains('disallowed_useragent')) {
          _showUserAgentErrorNotification();
        }

        // WHY: Wrap talker access in try-catch to handle any provider access issues
        Talker? talker;
        try {
          talker = ref.read(talkerProvider);
        } on Object catch (e) {
          debugPrint(
            '[AiWebviewScreen] Failed to access talker in console message: $e',
          );
        }
        final message = '[WebView CONSOLE] ${consoleMessage.message}';
        // WHY: Pipe WebView console messages to talker with appropriate log levels
        // This centralizes all logs from both Dart and WebView JavaScript contexts.
        if (talker != null) {
          try {
            switch (consoleMessage.messageLevel) {
              case ConsoleMessageLevel.ERROR:
                talker.error(message);
              case ConsoleMessageLevel.WARNING:
                talker.warning(message);
              default:
                talker.info(message);
            }
          } on Object catch (_) {
            // Ignore logging errors
          }
        }
      },
      // NEW: Robust error detection from web resource (network) errors.
      onReceivedError: (controller, request, error) {
        if (error.description.contains('disallowed_useragent')) {
          _showUserAgentErrorNotification();
        }
        setState(() {
          _progress = 1.0;
        });
      },
    );
  }

  /// WHY: Centralized bridge injection logic reused by onLoadStop and recovery paths
  Future<void> _injectBridgeScript(
    InAppWebViewController controller,
    String? bridgeScript,
  ) async {
    if (bridgeScript == null || bridgeScript.isEmpty) return;

    try {
      await controller.evaluateJavascript(source: bridgeScript);
      final currentUrl = await controller.getUrl();
      // WHY: Wrap talker access in try-catch to handle any provider access issues
      Talker? talker;
      try {
        if (!mounted) return;
        talker = ref.read(talkerProvider);
        talker?.info(
          '[AiWebviewScreen] Bridge script (re-)injected on ${currentUrl?.toString() ?? 'unknown'}.',
        );
      } on Object catch (e) {
        debugPrint(
          '[AiWebviewScreen] Failed to log bridge injection: $e',
        );
      }
    } on Object catch (e) {
      // WHY: Wrap talker access in try-catch to handle any provider access issues
      Talker? talker;
      try {
        if (!mounted) return;
        talker = ref.read(talkerProvider);
        talker?.warning('[AiWebviewScreen] Error injecting bridge script: $e');
      } on Object catch (logError) {
        debugPrint(
          '[AiWebviewScreen] Failed to log bridge injection error: $logError',
        );
      }
    }
  }

  /// WHY: Recovery method for dead bridge contexts (called after heartbeat failure)
  Future<void> _recoverFromDeadBridge(InAppWebViewController controller) async {
    try {
      final currentUrl = await controller.getUrl();

      // WHY: Only attempt recovery on supported domains. Using strict host check
      // prevents recovery attempts on cross-origin redirect pages.
      if (_isSupportedDomain(currentUrl)) {
        // Attempt to re-inject bridge script
        await _injectBridgeScript(controller, _currentBridgeScript);
      } else {
        // WHY: If on unsupported domain, reload to a known good state
        await controller.reload();
      }
    } on Object catch (e) {
      // WHY: Wrap talker access in try-catch to handle any provider access issues
      Talker? talker;
      try {
        if (!mounted) return;
        talker = ref.read(talkerProvider);
        talker?.warning('[AiWebviewScreen] Error during bridge recovery: $e');
      } on Object catch (logError) {
        debugPrint(
          '[AiWebviewScreen] Failed to log bridge recovery error: $logError',
        );
      }
    }
  }
}
