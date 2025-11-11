// lib/features/settings/models/browser_user_agent.dart

enum BrowserUserAgent {
  chromeWindows(
    name: 'Chrome 131 (Windows)',
    value:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  ),
  chromeMac(
    name: 'Chrome 131 (macOS)',
    value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  ),
  safariMac(
    name: 'Safari 18 (macOS)',
    value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15',
  ),
  firefoxWindows(
    name: 'Firefox 141 (Windows)',
    value:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0',
  ),
  edgeWindows(
    name: 'Edge 131 (Windows)',
    value:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
  );

  // WHY: This constructor allows associating a human-readable name with the full UA string.
  const BrowserUserAgent({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}
