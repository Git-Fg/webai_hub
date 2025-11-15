import 'dart:async';
import 'dart:convert';

import 'package:ai_hybrid_hub/core/database/database.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/theme/theme_facade.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/presets/models/provider_type.dart';
import 'package:ai_hybrid_hub/features/settings/models/browser_user_agent.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_constants.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_diagnostics_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/providers/bridge_events_observer.dart';
import 'package:ai_hybrid_hub/features/webview/providers/bridge_events_provider.dart';
import 'package:ai_hybrid_hub/features/webview/providers/webview_key_provider.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:ai_hybrid_hub/providers/bridge_script_provider.dart';
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
  // WHY: Flag to prevent infinite redirect loops when handling CookieMismatch
  bool _isHandlingCookieMismatch = false;
  // WHY: Flag to prevent multiple hashchange triggers for zai OAuth
  bool _isProcessingZaiOAuth = false;

  @override
  bool get wantKeepAlive => true;

  // WHY: Helper method to resolve provider URL from providerId.
  // This encapsulates the conversion from providerId string to ProviderType enum
  // and then to the actual URL from providerMetadataProvider.
  // WHY: Return null on invalid providerId to gracefully handle configuration errors
  // instead of crashing the app.
  String? _getProviderUrl() {
    try {
      final providerId = widget.preset.providerId;
      final allMetadata = ref.read(providerMetadataProvider);
      final metadata = allMetadata.values.firstWhere(
        (p) => p.id == providerId,
        orElse: () => throw StateError(
          'Invalid or unsupported providerId: "$providerId" for preset "${widget.preset.name}". Check provider_type.dart.',
        ),
      );
      return metadata.url;
    } on Object catch (e, st) {
      ref.read(talkerProvider).handle(e, st, 'Failed to get provider URL');
      return null;
    }
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

  // WHY: Transition to persistent needsUserAgentChange state instead of ephemeral notification.
  // This ensures the error cannot be missed and provides direct navigation to settings.
  void _handleUserAgentError() {
    if (!mounted) return;
    ref.read(automationStateProvider.notifier).moveToNeedsUserAgentChange();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // REQUIRED call for AutomaticKeepAliveClientMixin
    final bridgeScriptAsync = ref.watch(bridgeScriptProvider);

    // ADD this line to activate the observer:
    ref.watch(bridgeEventsObserverProvider(widget.preset.id));

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final controller = webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        }
      },
      child: Builder(
        builder: (context) {
          final theme = context.hubTheme;
          return Scaffold(
            backgroundColor: theme.surfaceColor,
            appBar: AppBar(
              title: Text(
                widget.preset.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.appBarTextColor,
                ),
              ),
              backgroundColor: theme.webViewAppBarColor,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: theme.appBarIconColor),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  color: theme.appBarIconColor,
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
                      final result = await webViewController!
                          .evaluateJavascript(
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
                        backgroundColor: theme.webViewProgressIndicatorColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.appBarTextColor!,
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
          );
        },
      ),
    );
  }

  Widget _buildWebView(String bridgeScript) {
    final url = _getProviderUrl();
    if (url == null) {
      return Builder(
        builder: (context) {
          final theme = context.hubTheme;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error: Invalid provider configuration for this preset.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.messageErrorColor),
              ),
            ),
          );
        },
      );
    }

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
        // WHY: Enable JavaScript window opening to allow OAuth popups and authentication flows
        // This is critical for Google login buttons that use window.open() or target="_blank"
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
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
        final navigationType = navigationAction.navigationType;
        if (talker != null) {
          try {
            talker.info(
              '[WebView] Navigation request to: $uri (type: $navigationType)',
            );
          } on Object catch (_) {
            // Ignore logging errors
          }
        }

        // WHY: Explicitly allow Google authentication URLs to ensure they load in the webview
        // This is critical for OAuth flows where clicking "Log in with Google" must stay in the webview
        if (uri != null && uri.host.contains('accounts.google.com')) {
          if (talker != null) {
            try {
              talker.info(
                '[WebView] Allowing Google authentication URL: $uri',
              );
            } on Object catch (_) {
              // Ignore logging errors
            }
          }
          // WHY: Always allow Google authentication URLs to load in the webview
          // This ensures OAuth flows complete within the app instead of opening externally
          return NavigationActionPolicy.ALLOW;
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

        // Navigate to the provider URL when WebView is created
        unawaited(controller.loadUrl(urlRequest: URLRequest(url: WebUri(url))));

        controller.addJavaScriptHandler(
          handlerName: BridgeConstants.automationHandler,
          callback: (args) {
            // NEW SIMPLIFIED LOGIC:
            if (args.isEmpty || args[0] is! Map) return;
            try {
              final json = Map<String, dynamic>.from(args[0] as Map);
              final event = BridgeEvent.fromJson(json);
              ref
                  .read(bridgeEventControllerProvider(widget.preset.id))
                  .add(event);
            } on Object {
              // handle parse error
            }
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

        // WHY: Handle zai OAuth callback - trigger hashchange event to process token
        // When zai redirects back with #token=..., the page needs to process it
        if (url != null &&
            url.host == 'chat.z.ai' &&
            url.path == '/auth' &&
            url.fragment.startsWith('token=') &&
            !_isProcessingZaiOAuth) {
          _isProcessingZaiOAuth = true;
          if (talker != null) {
            try {
              talker.info(
                '[WebView] Detected zai OAuth token callback, triggering hashchange...',
              );
            } on Object catch (_) {
              // Ignore logging errors
            }
          }
          // WHY: Trigger hashchange event to allow zai's JavaScript to process the token
          // This is necessary because the page might have already loaded before the hash was set
          try {
            await controller.evaluateJavascript(source: '''
              (function() {
                console.log('[Z.ai OAuth] Processing token from hash:', window.location.hash);
                // Trigger hashchange event multiple times to ensure it's caught
                for (var i = 0; i < 3; i++) {
                  setTimeout(function() {
                    window.dispatchEvent(new HashChangeEvent('hashchange', {
                      oldURL: window.location.href.split('#')[0],
                      newURL: window.location.href
                    }));
                    window.dispatchEvent(new PopStateEvent('popstate'));
                  }, i * 100);
                }
                // Also try directly accessing the token and triggering any auth handlers
                setTimeout(function() {
                  var token = window.location.hash.match(/token=([^&]+)/);
                  if (token && token[1]) {
                    console.log('[Z.ai OAuth] Token found, attempting to process...');
                    // Try to find and trigger any auth processing functions
                    if (window.processAuthToken) {
                      window.processAuthToken(token[1]);
                    }
                    // Try localStorage or sessionStorage if zai uses that
                    try {
                      localStorage.setItem('auth_token', token[1]);
                      sessionStorage.setItem('auth_token', token[1]);
                    } catch(e) {
                      console.log('[Z.ai OAuth] Could not set storage:', e);
                    }
                  }
                }, 500);
              })();
            ''');
            // Reset flag after a delay to allow retry if needed
            Future.delayed(const Duration(seconds: 3), () {
              _isProcessingZaiOAuth = false;
            });
          } on Object catch (e) {
            _isProcessingZaiOAuth = false;
            if (talker != null) {
              try {
                talker.warning(
                  '[WebView] Error triggering hashchange for zai OAuth: $e',
                );
              } on Object catch (_) {
                // Ignore logging errors
              }
            }
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

        // WHY: Check for disallowed_useragent in URL and transition to persistent state.
        if (newUrl.contains('disallowed_useragent')) {
          _handleUserAgentError();
        }

        // WHY: Handle zai OAuth callback when hash changes
        // This is called when the URL hash changes (e.g., when token is added to URL)
        // Only process if not already processing to avoid duplicate triggers
        if (url != null &&
            url.host == 'chat.z.ai' &&
            url.path == '/auth' &&
            url.fragment.startsWith('token=') &&
            !_isProcessingZaiOAuth) {
          _isProcessingZaiOAuth = true;
          // WHY: Wrap talker access in try-catch to handle any provider access issues
          Talker? talker;
          try {
            if (!mounted) {
              _isProcessingZaiOAuth = false;
              return;
            }
            talker = ref.read(talkerProvider);
          } on Object catch (e) {
            _isProcessingZaiOAuth = false;
            debugPrint(
              '[WebView] Failed to access talker in onUpdateVisitedHistory: $e',
            );
          }
          if (talker != null) {
            try {
              talker.info(
                '[WebView] Detected zai OAuth token in hash, triggering processing...',
              );
            } on Object catch (_) {
              // Ignore logging errors
            }
          }
          // WHY: Trigger hashchange event to allow zai's JavaScript to process the token
          try {
            await controller.evaluateJavascript(source: '''
              (function() {
                console.log('[Z.ai OAuth] Processing token from hash:', window.location.hash);
                // Trigger hashchange event multiple times to ensure it's caught
                for (var i = 0; i < 3; i++) {
                  setTimeout(function() {
                    window.dispatchEvent(new HashChangeEvent('hashchange', {
                      oldURL: window.location.href.split('#')[0],
                      newURL: window.location.href
                    }));
                    window.dispatchEvent(new PopStateEvent('popstate'));
                  }, i * 100);
                }
                // Also try directly accessing the token and triggering any auth handlers
                setTimeout(function() {
                  var token = window.location.hash.match(/token=([^&]+)/);
                  if (token && token[1]) {
                    console.log('[Z.ai OAuth] Token found, attempting to process...');
                    // Try to find and trigger any auth processing functions
                    if (window.processAuthToken) {
                      window.processAuthToken(token[1]);
                    }
                    // Try localStorage or sessionStorage if zai uses that
                    try {
                      localStorage.setItem('auth_token', token[1]);
                      sessionStorage.setItem('auth_token', token[1]);
                    } catch(e) {
                      console.log('[Z.ai OAuth] Could not set storage:', e);
                    }
                  }
                }, 500);
              })();
            ''');
            // Reset flag after a delay to allow retry if needed
            Future.delayed(const Duration(seconds: 3), () {
              _isProcessingZaiOAuth = false;
            });
          } on Object catch (e) {
            _isProcessingZaiOAuth = false;
            if (talker != null) {
              try {
                talker.warning(
                  '[WebView] Error triggering hashchange for zai OAuth in onUpdateVisitedHistory: $e',
                );
              } on Object catch (_) {
                // Ignore logging errors
              }
            }
          }
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
        // WHY: Robust error detection from console logs.
        if (consoleMessage.message.contains('disallowed_useragent')) {
          _handleUserAgentError();
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
      // WHY: Robust error detection from web resource (network) errors.
      onReceivedError: (controller, request, error) {
        if (error.description.contains('disallowed_useragent')) {
          _handleUserAgentError();
        }
        setState(() {
          _progress = 1.0;
        });
      },
      // WHY: Handle JavaScript window.open() calls for OAuth popups
      // When Google login uses window.open(), we need to load the URL in the current webview
      // instead of trying to create a new window (which WebView doesn't support well)
      onCreateWindow: (controller, createWindowAction) async {
        // WHY: Wrap talker access in try-catch to handle any provider access issues
        Talker? talker;
        try {
          if (!mounted) return false;
          talker = ref.read(talkerProvider);
        } on Object catch (e) {
          debugPrint(
            '[WebView] Failed to access talker in onCreateWindow: $e',
          );
        }
        final url = createWindowAction.request.url;
        if (talker != null) {
          try {
            talker.info(
              '[WebView] JavaScript window.open() called for: $url',
            );
          } on Object catch (_) {
            // Ignore logging errors
          }
        }
        // WHY: Load the URL in the current webview instead of creating a new window
        // This is the standard approach for OAuth flows in WebView
        if (url != null) {
          unawaited(
            controller.loadUrl(urlRequest: URLRequest(url: url)),
          );
        }
        // WHY: Return true to indicate we handled the window creation
        return true;
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
