import 'dart:convert';

import 'package:ai_hybrid_hub/core/services/cookie_parser.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';

// WHY: CookieStorage provides persistent storage for authentication cookies per domain.
// This enables integration tests to use pre-captured "Golden Cookies" without
// requiring login automation, which is fragile and unreliable.
class CookieStorage {
  CookieStorage._();

  static const String _boxName = 'cookies_box';
  static Box<String>? _box;

  // WHY: Initialize the Hive box for cookie storage. Must be called before
  // any other methods, typically in main() after Hive.initFlutter().
  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  // WHY: Save cookies for a specific domain. The domain is extracted from the URL
  // and used as the storage key. Cookies are serialized to JSON for persistence.
  static Future<void> saveCookies(String domain, List<Cookie> cookies) async {
    if (_box == null) {
      throw StateError('CookieStorage not initialized. Call init() first.');
    }

    final cookiesJson = jsonEncode(
      cookies.map((c) => c.toJson()).toList(),
    );
    await _box!.put(domain, cookiesJson);
  }

  // WHY: Load cookies for a specific domain. Returns an empty list if no cookies
  // are stored for that domain. Cookies are deserialized from JSON.
  static Future<List<Cookie>> loadCookies(String domain) async {
    if (_box == null) {
      throw StateError('CookieStorage not initialized. Call init() first.');
    }

    final cookiesJson = _box!.get(domain);
    if (cookiesJson == null) {
      return [];
    }

    try {
      final cookiesList = jsonDecode(cookiesJson) as List;
      // WHY: Delegate parsing to the robust CookieParser helper.
      // This ensures consistent handling of type conversions and enum mapping.
      return cookiesList
          .map((c) => CookieParser.parseCookie(c as Map<String, dynamic>))
          .toList();
    } on Exception {
      // WHY: If deserialization fails, return empty list rather than crashing.
      // This allows the app to recover gracefully from corrupted cookie data.
      return [];
    }
  }

  // WHY: Extract domain from URL for use as storage key. Handles both
  // full URLs and domain strings.
  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      // WHY: Uri.parse() doesn't throw for invalid URLs, it returns a Uri with
      // empty host. Check if host is empty and fall back to original input.
      if (uri.host.isNotEmpty) {
        return uri.host;
      }
      // WHY: If host is empty, the input might already be a domain string.
      // Return it as-is.
      return url;
    } on Exception {
      // WHY: If URL parsing fails with an exception, return the original string
      // as fallback. This handles edge cases where the input might already be a domain.
      return url;
    }
  }
}
