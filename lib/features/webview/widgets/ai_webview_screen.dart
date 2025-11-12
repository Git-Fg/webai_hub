import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/automation/providers/automation_request_provider.dart';
import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:ai_hybrid_hub/features/hub/providers/staged_responses_provider.dart';
import 'package:ai_hybrid_hub/features/presets/models/provider_type.dart';
import 'package:ai_hybrid_hub/features/settings/models/browser_user_agent.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/automation_options.dart';
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
import 'package:flutter/services.dart';
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
  BridgeEventHandler? _eventHandler;
  // WHY: Flag to prevent showing the notification multiple times for the same error.
  bool _isUserAgentNoticeShown = false;
  // WHY: Flag to prevent infinite redirect loops when handling CookieMismatch
  bool _isHandlingCookieMismatch = false;

  @override
  bool get wantKeepAlive => true;

  // WHY: Helper method to resolve provider URL from providerId.
  // This encapsulates the conversion from providerId string to ProviderType enum
  // and then to the actual URL from providerDetails map.
  // WHY: Fail fast on invalid providerId to catch configuration errors early
  // instead of silently defaulting to AI Studio.
  String _getProviderUrl() {
    final providerId = widget.preset.providerId;
    final providerType = ProviderType.values.firstWhere(
      (pt) => providerDetails[pt]!.id == providerId,
      orElse: () => throw StateError(
        'Invalid or unsupported providerId: "$providerId" for preset "${widget.preset.name}". Check database seed or preset configuration.',
      ),
    );
    return providerDetails[providerType]!.url;
  }

  // WHY: Centralized domain verification logic to avoid duplication.
  // Checks if the URL belongs to a supported domain or is a local file.
  bool _isSupportedDomain(Uri? url) {
    if (url == null) return false;
    // The check for 'file://' is for initial loading from assets
    return WebViewConstants.supportedDomains.contains(url.host) ||
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
      final generalSettings = ref.read(generalSettingsProvider).value;

      // WHY: Construct typed AutomationOptions object to ensure type safety
      // and proper serialization when sending to TypeScript bridge.
      final providerId = widget.preset.providerId;
      if (providerId == null) {
        throw StateError(
          'Cannot start automation: preset ${widget.preset.id} has no providerId (it may be a group)',
        );
      }
      final options = AutomationOptions(
        providerId: providerId,
        prompt: request.promptWithContext,
        model: settings['model'] as String?,
        systemPrompt: settings['systemPrompt'] as String?,
        temperature: (settings['temperature'] as num?)?.toDouble(),
        topP: (settings['topP'] as num?)?.toDouble(),
        thinkingBudget: (settings['thinkingBudget'] as num?)?.toInt(),
        useWebSearch: settings['useWebSearch'] as bool?,
        disableThinking: settings['disableThinking'] as bool?,
        urlContext: settings['urlContext'] as bool?,
        timeoutModifier: generalSettings?.timeoutModifier,
      );
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
        'Google detected an incompatible browser. Go to Settings and select a standard browser User Agent (e.g., Chrome).',
      ),
      toastDuration: const Duration(seconds: 15),
      showProgressIndicator: false,
      action: InkWell(
        onTap: () {
          unawaited(context.router.push(const SettingsRoute()));
        },
        child: Text(
          'Settings',
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: Colors.blue.shade800,
          ),
        ),
      ),
    ).show(context);
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
    // WHY: Check current state first to handle requests that were created before this widget was built.
    // WHY: Wrap provider modification in post-frame callback to avoid modifying providers during build.
    final currentRequests = ref.read(automationRequestProvider);
    final myRequestId = widget.preset.id;
    final currentRequest = currentRequests[myRequestId];
    if (currentRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final talker = ref.read(talkerProvider);
        talker.info(
          '[WebView-${widget.preset.name}] Found existing automation request on build.',
        );
        ref.read(automationRequestProvider.notifier).clearRequest(myRequestId);
        unawaited(_startAutomation(currentRequest));
      });
    }

    // Listen for future automation requests
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
            orElse: () => BrowserUserAgent.chromeIphone,
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
        // WHY: Enable third-party cookies to allow Google services to work properly.
        // WHY: Explicitly set to true because Android disables this flag by default; retaining the value prevents CookieMismatch redirects.
        // ignore: avoid_redundant_argument_values
        thirdPartyCookiesEnabled: true,
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

        // WHY: Handle Google CookieMismatch redirect by navigating directly to login page
        // This bypasses the cookie error page that appears when third-party cookies are blocked
        if (uri != null &&
            uri.toString().contains('accounts.google.com/CookieMismatch') &&
            widget.preset.providerId == 'ai_studio' &&
            !_isHandlingCookieMismatch) {
          _isHandlingCookieMismatch = true;
          if (talker != null) {
            try {
              talker.warning(
                '[WebView] Detected CookieMismatch redirect, navigating to Google login...',
              );
            } on Object catch (_) {
              // Ignore logging errors
            }
          }
          // Navigate directly to Google login page, which will then redirect to AI Studio after login
          const loginUrl =
              'https://accounts.google.com/signin/v2/identifier?continue=https://aistudio.google.com/prompts/new_chat&flowName=GlifWebSignIn&flowEntry=ServiceLogin';
          unawaited(
            controller.loadUrl(urlRequest: URLRequest(url: WebUri(loginUrl))),
          );
          // Reset flag after a delay to allow navigation
          Future.delayed(const Duration(seconds: 2), () {
            _isHandlingCookieMismatch = false;
          });
          return NavigationActionPolicy.CANCEL;
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

        // Navigate to the provider URL when WebView is created
        final url = _getProviderUrl();
        unawaited(controller.loadUrl(urlRequest: URLRequest(url: WebUri(url))));

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

        controller.addJavaScriptHandler(
          handlerName: 'readClipboard',
          callback: (args) async {
            // Read from the system clipboard
            final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
            // Return the text to the JavaScript promise
            return clipboardData?.text ?? '';
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'setClipboard',
          callback: (args) async {
            if (args.isNotEmpty && args[0] is String) {
              await Clipboard.setData(ClipboardData(text: args[0] as String));
            }
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
