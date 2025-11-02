import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);

class JavaScriptBridge {
  final Ref ref;
  JavaScriptBridge(this.ref);

  InAppWebViewController? get _controller => ref.read(webViewControllerProvider);

  Future<void> startAutomation(String prompt) async {
    if (_controller == null) {
      throw Exception("WebView not ready");
    }

    try {
      final isPageLoaded = await _controller!.evaluateJavascript(
        source: "document.readyState === 'complete'"
      );

      if (isPageLoaded != true) {
        throw Exception("WebView page not fully loaded");
      }

      final checkResult = await _controller!.evaluateJavascript(
        source: "typeof startAutomation !== 'undefined' && typeof extractFinalResponse !== 'undefined'"
      );

      if (checkResult != true) {
        throw Exception("Automation functions not available in WebView. Script may not be injected yet.");
      }

      final escapedPrompt = prompt
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');

      await _controller!.evaluateJavascript(
        source: "startAutomation('$escapedPrompt');"
      );
    } catch (e) {
      throw Exception("Failed to start automation: $e");
    }
  }

  Future<String> extractFinalResponse() async {
    if (_controller == null) throw Exception("WebView not ready");

    try {
      final result = await _controller!.evaluateJavascript(
        source: "typeof extractFinalResponse !== 'undefined' ? extractFinalResponse() : null"
      );

      if (result == null || result is! String) {
        throw Exception("No response available or extraction failed");
      }

      return result;
    } catch (e) {
      throw Exception("Failed to extract response: $e");
    }
  }
}

final javaScriptBridgeProvider = Provider((ref) => JavaScriptBridge(ref));