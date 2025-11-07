import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'webview_key_provider.g.dart';

/// WHY: Manages a dynamic key for the WebView widget to enable recreation on crashes.
/// On Android, when the renderer process crashes (onRenderProcessGone), the WebView
/// instance becomes unusable and must be destroyed and recreated. Changing the widget's
/// Key is the most reliable way to trigger Flutter to recreate the widget.
@Riverpod(keepAlive: true)
class WebViewKey extends _$WebViewKey {
  @override
  int build() => 0;

  /// Increments the key value, causing Flutter to recreate the WebView widget.
  /// This is called when Android renderer process crashes to recover from fatal errors.
  void incrementKey() {
    state = state + 1;
  }
}
