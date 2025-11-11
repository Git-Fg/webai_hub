import 'package:ai_hybrid_hub/core/services/cookie_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// WHY: WebViewCookieHandler manages the injection and capture of cookies for
// WebView instances. This enables integration tests to use pre-captured
// authentication cookies and ensures cookies are refreshed during normal usage.
class WebViewCookieHandler {
  // WHY: Inject saved cookies into the WebView before the page loads.
  // This ensures the user is authenticated when the page first renders.
  Future<void> injectSavedCookies(String url) async {
    try {
      final domain = CookieStorage.extractDomain(url);
      final cookies = await CookieStorage.loadCookies(domain);

      if (cookies.isEmpty) {
        // WHY: No cookies saved for this domain - this is normal for first-time use
        // or when cookies haven't been captured yet. Log for debugging in tests.
        debugPrint(
          '[WebViewCookieHandler] No cookies found for domain: $domain',
        );
        return;
      }

      debugPrint(
        '[WebViewCookieHandler] Injecting ${cookies.length} cookies for domain: $domain',
      );

      // WHY: Debug - log first cookie details to verify they're loaded correctly
      if (cookies.isNotEmpty) {
        final firstCookie = cookies.first;
        debugPrint(
          '[WebViewCookieHandler] Sample cookie: name=${firstCookie.name}, domain=${firstCookie.domain}, expiresDate=${firstCookie.expiresDate}, isSecure=${firstCookie.isSecure}',
        );
      }

      final cookieManager = CookieManager.instance();

      // WHY: For Google services, inject cookies for the target domain first,
      // then for accounts.google.com. Use a specific order to avoid conflicts.
      final domainsToInject = <String>[];

      // WHY: Always inject for the target URL first
      domainsToInject.add(url);

      if (domain.contains('google.com')) {
        // WHY: For Google, also inject for accounts.google.com (where auth happens)
        // and the base domain
        domainsToInject.add('https://accounts.google.com');
        // WHY: Don't add aistudio.google.com separately if url already contains it
        if (!url.contains('aistudio.google.com')) {
          domainsToInject.add('https://aistudio.google.com');
        }
      }

      // WHY: Inject each cookie individually. CookieManager.setCookie() handles
      // the WebView-specific cookie storage mechanism.
      for (final cookie in cookies) {
        try {
          // WHY: Convert sameSite if available, otherwise use null
          HTTPCookieSameSitePolicy? sameSitePolicy;
          if (cookie.sameSite != null) {
            try {
              final sameSiteStr = cookie.sameSite.toString().toUpperCase();
              if (sameSiteStr.contains('NONE')) {
                sameSitePolicy = HTTPCookieSameSitePolicy.NONE;
              } else if (sameSiteStr.contains('LAX')) {
                sameSitePolicy = HTTPCookieSameSitePolicy.LAX;
              } else if (sameSiteStr.contains('STRICT')) {
                sameSitePolicy = HTTPCookieSameSitePolicy.STRICT;
              }
            } on Exception {
              // WHY: If sameSite conversion fails, use null
              // The cookie will still work, just without sameSite restriction
            }
          }

          // WHY: Inject cookie for each relevant domain to ensure it's available
          // when redirects happen (e.g., aistudio.google.com -> accounts.google.com)
          for (final injectionUrl in domainsToInject) {
            try {
              final injectionUri = Uri.parse(injectionUrl);

              // WHY: Workaround for Google subdomain cookies - if cookie has domain
              // like .aistudio.google.com, also inject with .google.com so it works
              // across all Google subdomains (accounts.google.com, aistudio.google.com, etc.)
              final domainsToTry = <String>[];

              if (cookie.domain != null) {
                domainsToTry.add(cookie.domain!);

                // WHY: If cookie domain is a Google subdomain, also try with .google.com
                if (cookie.domain!.contains('google.com')) {
                  // Extract base domain: .aistudio.google.com -> .google.com
                  final parts = cookie.domain!.split('.');
                  if (parts.length > 2) {
                    // Keep last two parts (.google.com)
                    final baseDomain =
                        '.${parts[parts.length - 2]}.${parts[parts.length - 1]}';
                    if (baseDomain != cookie.domain) {
                      domainsToTry.add(baseDomain);
                    }
                  }
                }
              } else {
                domainsToTry.add(injectionUri.host);
              }

              // WHY: Try multiple injection strategies:
              // 1. With original domain
              // 2. With .google.com base domain (for Google subdomains)
              // 3. Without domain (let WebView infer from URL)
              var successCount = 0;

              // Strategy 1 & 2: Try with domain variants
              for (final cookieDomain in domainsToTry) {
                try {
                  debugPrint(
                    '[WebViewCookieHandler] Injecting ${cookie.name} for $injectionUrl with domain: $cookieDomain',
                  );

                  // WHY: For __Secure- cookies, ensure Secure flag is set
                  final isSecureCookie = cookie.name.startsWith('__Secure-') ||
                      (cookie.isSecure ?? false);

                  await cookieManager.setCookie(
                    url: WebUri(injectionUrl),
                    name: cookie.name,
                    value: cookie.value.toString(),
                    domain: cookieDomain,
                    path: cookie.path ?? '/',
                    expiresDate: cookie.expiresDate,
                    isSecure: isSecureCookie,
                    isHttpOnly: cookie.isHttpOnly ?? false,
                    sameSite: sameSitePolicy,
                  );
                  successCount++;
                } on Exception catch (e) {
                  debugPrint(
                    '[WebViewCookieHandler] Failed to inject ${cookie.name} with domain $cookieDomain: $e',
                  );
                }
              }

              // Strategy 3: Try without domain (let WebView infer it)
              // This works better for some cookie managers
              if (cookie.domain != null &&
                  cookie.domain!.contains('google.com')) {
                try {
                  debugPrint(
                    '[WebViewCookieHandler] Injecting ${cookie.name} for $injectionUrl WITHOUT domain (let WebView infer)',
                  );

                  await cookieManager.setCookie(
                    url: WebUri(injectionUrl),
                    name: cookie.name,
                    value: cookie.value.toString(),
                    path: cookie.path ?? '/',
                    expiresDate: cookie.expiresDate,
                    isSecure: cookie.isSecure ?? false,
                    isHttpOnly: cookie.isHttpOnly ?? false,
                    sameSite: sameSitePolicy,
                  );
                  successCount++;
                } on Exception catch (e) {
                  debugPrint(
                    '[WebViewCookieHandler] Failed to inject ${cookie.name} without domain: $e',
                  );
                }
              }

              if (successCount == 0) {
                debugPrint(
                  '[WebViewCookieHandler] Failed to inject cookie ${cookie.name} for $injectionUrl with any strategy',
                );
              } else {
                debugPrint(
                  '[WebViewCookieHandler] Successfully injected ${cookie.name} with $successCount strategy/strategies',
                );
              }
            } on Exception catch (e) {
              // WHY: Log but continue - some domains might reject certain cookies
              debugPrint(
                '[WebViewCookieHandler] Failed to inject cookie ${cookie.name} for $injectionUrl: $e',
              );
            }
          }
          debugPrint(
            '[WebViewCookieHandler] Successfully injected cookie: ${cookie.name}',
          );
        } on Exception catch (e) {
          // WHY: Log but don't fail if a single cookie fails to inject.
          // Some cookies might be invalid or expired, but others may still work.
          debugPrint(
            '[WebViewCookieHandler] Failed to inject cookie ${cookie.name}: $e',
          );
        }
      }
      debugPrint('[WebViewCookieHandler] Cookie injection completed for: $url');
    } on Exception catch (e) {
      // WHY: Log but don't throw - cookie injection failure shouldn't crash the app.
      // The user can still manually log in if cookies fail to inject.
      debugPrint('[WebViewCookieHandler] Error injecting cookies: $e');
    }
  }

  // WHY: Inject cookies via JavaScript as a workaround for CookieManager issues.
  // This method sets cookies directly in the document, which can work when
  // CookieManager.setCookie() doesn't persist cookies correctly.
  Future<void> injectCookiesViaJavaScript(
    InAppWebViewController controller,
    List<Cookie> cookies,
  ) async {
    try {
      debugPrint(
        '[WebViewCookieHandler] Attempting to inject ${cookies.length} cookies via JavaScript',
      );

      for (final cookie in cookies) {
        try {
          // WHY: Build JavaScript cookie string
          // Format: name=value; domain=.google.com; path=/; secure; httponly; expires=...
          // NOTE: Cookies with __Secure- prefix MUST have Secure flag
          final cookieString = StringBuffer();
          cookieString.write('${cookie.name}=${cookie.value}');

          if (cookie.domain != null) {
            cookieString.write('; domain=${cookie.domain}');
          }

          if (cookie.path != null) {
            cookieString.write('; path=${cookie.path}');
          }

            // WHY: __Secure- cookies MUST be secure. Also set secure if cookie.isSecure is true
            final mustBeSecure = cookie.name.startsWith('__Secure-') ||
                (cookie.isSecure ?? false);
          if (mustBeSecure) {
            cookieString.write('; secure');
          }

          // WHY: HttpOnly cookies can't be set via JavaScript, but we try anyway
          // Note: JavaScript can't set HttpOnly cookies, but CookieManager can
          if (cookie.isHttpOnly != true) {
            // Only try JavaScript if not HttpOnly (HttpOnly cookies must use CookieManager)
            if (cookie.expiresDate != null) {
              final expiresDate = DateTime.fromMillisecondsSinceEpoch(
                cookie.expiresDate! * 1000,
              );
              cookieString.write(
                '; expires=${expiresDate.toUtc().toIso8601String()}',
              );
            }

            // WHY: SameSite attribute (if supported)
            if (cookie.sameSite != null) {
              final sameSiteStr = cookie.sameSite.toString().toUpperCase();
              if (sameSiteStr.contains('LAX')) {
                cookieString.write('; samesite=lax');
              } else if (sameSiteStr.contains('STRICT')) {
                cookieString.write('; samesite=strict');
              } else if (sameSiteStr.contains('NONE')) {
                cookieString.write('; samesite=none');
              }
            }
          } else {
            // WHY: Skip HttpOnly cookies for JavaScript injection
            debugPrint(
              '[WebViewCookieHandler] Skipping HttpOnly cookie ${cookie.name} for JS injection (use CookieManager)',
            );
            continue;
          }

          // WHY: Execute JavaScript to set cookie
          await controller.evaluateJavascript(
            source:
                'document.cookie = "${cookieString.toString().replaceAll('"', r'\"')}";',
          );

          debugPrint(
            '[WebViewCookieHandler] Set cookie via JS: ${cookie.name}',
          );
        } on Exception catch (e) {
          debugPrint(
            '[WebViewCookieHandler] Failed to set cookie ${cookie.name} via JS: $e',
          );
        }
      }

      debugPrint(
        '[WebViewCookieHandler] JavaScript cookie injection completed',
      );
    } on Exception catch (e) {
      debugPrint(
        '[WebViewCookieHandler] Error injecting cookies via JavaScript: $e',
      );
    }
  }

  // WHY: Capture cookies from the WebView after a page loads and save them to storage.
  // This ensures cookies are refreshed if the session is renewed during normal usage.
  Future<void> captureCookies(String url) async {
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri(url));

      if (cookies.isEmpty) {
        // WHY: No cookies present - this is normal for unauthenticated pages.
        // Don't log as an error.
        return;
      }

      final domain = CookieStorage.extractDomain(url);
      await CookieStorage.saveCookies(domain, cookies);
    } on Exception catch (e) {
      // WHY: Log but don't throw - cookie capture failure shouldn't crash the app.
      // The app can continue functioning without cookie persistence.
      debugPrint('[WebViewCookieHandler] Error capturing cookies: $e');
    }
  }
}
