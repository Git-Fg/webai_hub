// lib/features/webview/models/webview_content.dart

// Un 'sealed class' ou un 'record' serait aussi possible, mais une classe simple suffit.
abstract class WebViewContent {}

class WebViewContentUrl extends WebViewContent {
  WebViewContentUrl(this.url);
  final String url;
}

class WebViewContentHtmlFile extends WebViewContent {
  WebViewContentHtmlFile(this.assetPath);
  final String assetPath;
}
