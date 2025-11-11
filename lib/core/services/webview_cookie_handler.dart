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

      // WHY: For Google services, we need to inject cookies for both the target domain
      // and accounts.google.com, since authentication redirects happen there.
      // Cookies with domain .google.com should work for all subdomains, but we inject
      // them explicitly for both domains to ensure they're available.
      final domainsToInject = <String>{url};
      if (domain.contains('google.com')) {
        domainsToInject.add('https://accounts.google.com');
        domainsToInject.add('https://aistudio.google.com');
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
              // WHY: Use the cookie's original domain if available, otherwise use the URL's host.
              // Cookies with domain .google.com should work for all subdomains when injected correctly.
              final injectionUri = Uri.parse(injectionUrl);
              final cookieDomain = cookie.domain ?? injectionUri.host;
              
              debugPrint(
                '[WebViewCookieHandler] Injecting ${cookie.name} for $injectionUrl with domain: $cookieDomain (original: ${cookie.domain})',
              );
              
              await cookieManager.setCookie(
                url: WebUri(injectionUrl),
                name: cookie.name,
                value: cookie.value.toString(),
                domain: cookieDomain,
                path: cookie.path ?? '/',
                expiresDate: cookie.expiresDate,
                isSecure: cookie.isSecure ?? false,
                isHttpOnly: cookie.isHttpOnly ?? false,
                sameSite: sameSitePolicy,
              );
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
