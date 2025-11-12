// lib/features/settings/models/browser_user_agent.dart

enum BrowserUserAgent {
  chromeIphone(
    name: 'Chrome/iPhone',
    value:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/87.0.4280.77 Mobile/15E148 Safari/604.1',
  ),
  chromeIphoneDesktop(
    name: 'Chrome/iPhone (request desktop)',
    value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/87 Version/11.1.1 Safari/605.1.15',
  ),
  chromeIpad(
    name: 'Chrome/iPad',
    value:
        'Mozilla/5.0 (iPad; CPU OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/87.0.4280.77 Mobile/15E148 Safari/604.1',
  ),
  chromeIpod(
    name: 'Chrome/iPod',
    value:
        'Mozilla/5.0 (iPod; CPU iPhone OS 14_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/87.0.4280.77 Mobile/15E148 Safari/604.1',
  ),
  chromeAndroid(
    name: 'Chrome/Android (Generic)',
    value:
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.101 Mobile Safari/537.36',
  ),
  chromeAndroidSamsung(
    name: 'Chrome/Android (Samsung SM-A205U)',
    value:
        'Mozilla/5.0 (Linux; Android 10; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.101 Mobile Safari/537.36',
  ),
  chromeAndroidLg(
    name: 'Chrome/Android (LG LM-Q720)',
    value:
        'Mozilla/5.0 (Linux; Android 10; LM-Q720) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.101 Mobile Safari/537.36',
  ),
  firefoxIphone(
    name: 'Firefox/iPhone',
    value:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 11_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/30.0 Mobile/15E148 Safari/605.1.15',
  ),
  firefoxIpad(
    name: 'Firefox/iPad',
    value:
        'Mozilla/5.0 (iPad; CPU OS 11_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/30.0 Mobile/15E148 Safari/605.1.15',
  ),
  firefoxAndroid(
    name: 'Firefox/Android',
    value: 'Mozilla/5.0 (Android 11; Mobile; rv:68.0) Gecko/68.0 Firefox/84.0',
  );

  // WHY: This constructor allows associating a human-readable name with the full UA string.
  const BrowserUserAgent({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}
