// integration_test/auth_test.dart

import 'package:ai_hybrid_hub/core/services/cookie_storage.dart';
import 'package:ai_hybrid_hub/core/services/webview_cookie_handler.dart';
import 'package:ai_hybrid_hub/features/webview/webview_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_helpers.dart';

// A minimal app widget that only displays the AI Studio WebView.
// This removes all other app complexity (Hub, Tabs, etc.) for a focused test.
class MinimalAuthTestApp extends StatefulWidget {
  const MinimalAuthTestApp({super.key});

  @override
  State<MinimalAuthTestApp> createState() => _MinimalAuthTestAppState();
}

class _MinimalAuthTestAppState extends State<MinimalAuthTestApp> {
  InAppWebViewController? _controller;
  final WebViewCookieHandler _cookieHandler = WebViewCookieHandler();
  bool _hasNavigatedInitially = false;
  bool _hasInjectedCookiesOnAccounts = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: InAppWebView(
          key: const ValueKey('auth_test_webview'),
          initialSettings: InAppWebViewSettings(),
          onWebViewCreated: (controller) {
            _controller = controller;
            // WHY: Inject cookies before navigation, same as main app
            final url = WebViewConstants.aiStudioUrl;
            _cookieHandler
                .injectSavedCookies(url)
                .then((_) {
                  if (mounted && !_hasNavigatedInitially) {
                    _hasNavigatedInitially = true;
                    controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                  }
                })
                .catchError((Object e) {
                  debugPrint(
                    '[AuthTest] Cookie injection failed, navigating anyway: $e',
                  );
                  if (mounted && !_hasNavigatedInitially) {
                    _hasNavigatedInitially = true;
                    controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                  }
                });
          },
          onLoadStop: (controller, url) async {
            // WHY: Also try injecting cookies again after page load, in case they were cleared
            if (url != null && 
                url.toString().contains('accounts.google.com') &&
                !_hasInjectedCookiesOnAccounts) {
              _hasInjectedCookiesOnAccounts = true;
              debugPrint('[AuthTest] Page loaded on accounts.google.com, re-injecting cookies...');
              
              // WHY: Try both CookieManager and JavaScript injection
              await _cookieHandler.injectSavedCookies(WebViewConstants.aiStudioUrl);
              
              // WHY: Also try JavaScript injection as workaround
              final domain = CookieStorage.extractDomain(WebViewConstants.aiStudioUrl);
              final cookies = await CookieStorage.loadCookies(domain);
              if (cookies.isNotEmpty) {
                debugPrint('[AuthTest] Attempting JavaScript cookie injection...');
                await _cookieHandler.injectCookiesViaJavaScript(controller, cookies);
                
                // WHY: Wait a moment for cookies to be processed, then navigate to AI Studio
                await Future<void>.delayed(const Duration(seconds: 2));
                debugPrint('[AuthTest] Navigating directly to AI Studio after cookie injection...');
                await controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(WebViewConstants.aiStudioUrl)),
                );
              }
            }
            
            // Advanced Debug: Dump all cookies after the page loads.
            // Check cookies for both the current URL and accounts.google.com
            final currentUrlCookies = await CookieManager.instance().getCookies(
              url: WebUri(url.toString()),
            );
            final aiStudioCookies = await CookieManager.instance().getCookies(
              url: WebUri(WebViewConstants.aiStudioUrl),
            );
            final accountsCookies = await CookieManager.instance().getCookies(
              url: WebUri('https://accounts.google.com'),
            );
            
            debugPrint('--- ADVANCED DEBUG: COOKIES AFTER PAGE LOAD ---');
            debugPrint('Current URL: $url');
            debugPrint('Cookies for current URL (${url.toString()}): ${currentUrlCookies.length}');
            debugPrint('Cookies for AI Studio: ${aiStudioCookies.length}');
            debugPrint('Cookies for accounts.google.com: ${accountsCookies.length}');
            
            if (accountsCookies.isNotEmpty) {
              debugPrint('Accounts cookies:');
              for (final cookie in accountsCookies) {
                final cookieValue = cookie.value?.toString() ?? '';
                final valuePreview = cookieValue.length > 30
                    ? '${cookieValue.substring(0, 30)}...'
                    : cookieValue;
                debugPrint(
                  '  Name: ${cookie.name}, Value: $valuePreview, Domain: ${cookie.domain}, Path: ${cookie.path}',
                );
              }
            }
            
            // WHY: Also check if we have any cookies with domain .google.com
            final allCookies = await CookieManager.instance().getCookies(
              url: WebUri('https://google.com'),
            );
            debugPrint('Cookies for google.com (base domain): ${allCookies.length}');
            debugPrint('---------------------------------------------');
          },
        ),
      ),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // This setup runs before the test, injecting the cookies.
  setUpAll(() async {
    await setupTestEnvironment();
  });

  testWidgets(
    'AI Studio login with pre-injected cookies is successful',
    (tester) async {
      // ARRANGE: Launch our minimal app. The `setUpAll` has already loaded cookies into storage.
      await tester.pumpWidget(
        const ProviderScope(
          child: MinimalAuthTestApp(),
        ),
      );

      // ACT: Wait for the page to fully load and settle.
      // Give it a generous timeout to handle network and rendering.
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // ASSERT: Verify that we are successfully logged in.
      // We do this by looking for an element that ONLY exists for logged-in users.
      // A great candidate is the "New chat" button or the main prompt input area.
      // Selector for the prompt input area: "ms-chunk-input textarea"
      final promptInputFinder = find.byWidgetPredicate(
        (widget) =>
            widget is InAppWebView &&
            widget.key == const ValueKey('auth_test_webview'),
      );
      expect(promptInputFinder, findsOneWidget);

      // WHY: Get the controller from the state, not from the widget
      final appState = tester.state<_MinimalAuthTestAppState>(
        find.byType(MinimalAuthTestApp),
      );
      final controller = appState._controller;

      expect(
        controller,
        isNotNull,
        reason: 'WebView controller should be available.',
      );

      // Poll the DOM for up to 30 seconds to find the logged-in element.
      // Give more time for Google's authentication flow to complete.
      const pollInterval = Duration(seconds: 1);
      const timeout = Duration(seconds: 30);
      bool isLoggedIn = false;
      final stopwatch = Stopwatch()..start();

      debugPrint(
        '[AuthTest] Starting to poll for logged-in indicator: ms-chunk-input textarea',
      );

      while (stopwatch.elapsed < timeout) {
        try {
          final currentUrl = await controller!.getUrl();
          final urlString = currentUrl?.toString() ?? '';
          
          // WHY: Check if we've been redirected to AI Studio (success!)
          if (urlString.contains('aistudio.google.com') &&
              !urlString.contains('accounts.google.com')) {
            debugPrint(
              '[AuthTest] ✅ Redirected to AI Studio after ${stopwatch.elapsed.inSeconds}s - checking for logged-in element...',
            );
            
            // Wait a bit for page to fully load
            await tester.pump(const Duration(seconds: 2));
            
            final result = await controller.evaluateJavascript(
              source: 'document.querySelector("ms-chunk-input textarea") !== null',
            );

            if (result == true) {
              isLoggedIn = true;
              debugPrint(
                '[AuthTest] ✅ Found logged-in indicator after ${stopwatch.elapsed.inSeconds}s',
              );
              break;
            }
          }

          // WHY: Also check for logged-in element on current page
          final result = await controller.evaluateJavascript(
            source: 'document.querySelector("ms-chunk-input textarea") !== null',
          );

          if (result == true) {
            isLoggedIn = true;
            debugPrint(
              '[AuthTest] ✅ Found logged-in indicator after ${stopwatch.elapsed.inSeconds}s',
            );
            break;
          }

          // WHY: Log URL every 5 seconds to track progress
          if (stopwatch.elapsed.inSeconds % 5 == 0) {
            debugPrint(
              '[AuthTest] Polling... (${stopwatch.elapsed.inSeconds}s) - URL: $urlString',
            );
            
            // WHY: Check cookies again periodically
            final accountsCookies = await CookieManager.instance().getCookies(
              url: WebUri('https://accounts.google.com'),
            );
            debugPrint(
              '[AuthTest] Cookies on accounts.google.com: ${accountsCookies.length}',
            );
            
            // WHY: Check page title and content for clues
            try {
              final title = await controller.evaluateJavascript(
                source: 'document.title',
              );
              final hasEmailInput = await controller.evaluateJavascript(
                source: 'document.querySelector("input[type=\\"email\\"]") !== null',
              );
              final hasPasswordInput = await controller.evaluateJavascript(
                source: 'document.querySelector("input[type=\\"password\\"]") !== null',
              );
              debugPrint(
                '[AuthTest] Page title: $title, Has email input: $hasEmailInput, Has password input: $hasPasswordInput',
              );
            } catch (e) {
              debugPrint('[AuthTest] Error checking page content: $e');
            }
          }
        } catch (e) {
          debugPrint('[AuthTest] Error polling DOM: $e');
        }

        await tester.pump(pollInterval);
      }

      // Final Assertion
      expect(
        isLoggedIn,
        isTrue,
        reason:
            'Expected to find the prompt input area ("ms-chunk-input textarea"), which confirms a successful login. If this fails, the cookie injection is not working.',
      );

      debugPrint('✅ Login verification successful!');
    },
  );
}

