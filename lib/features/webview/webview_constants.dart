class WebViewConstants {
  WebViewConstants._();

  static const String aiStudioUrl =
      'https://aistudio.google.com/prompts/new_chat';
  static const String aiStudioDomain = 'aistudio.google.com';

  static const String kimiUrl = 'https://kimi.com/';
  static const String kimiDomain = 'kimi.com';
  // WHY: Kimi redirects to www.kimi.com, so we need to support both domains
  static const String kimiDomainAlt = 'www.kimi.com';
}
