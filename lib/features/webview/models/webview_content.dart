// lib/features/webview/models/webview_content.dart

// Un 'sealed class' ou un 'record' serait aussi possible, mais une classe simple suffit.
abstract class WebViewContent {}

class WebViewContentUrl extends WebViewContent {
  final String url;
  WebViewContentUrl(this.url);
}

class WebViewContentHtmlFile extends WebViewContent {
  final String assetPath;
  WebViewContentHtmlFile(this.assetPath);
}
