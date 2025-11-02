import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider pour exposer le contrôleur web à toute l'app
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
      print("🔄 Starting automation for prompt: $prompt");

      // Vérifier que la page est chargée
      final isPageLoaded = await _controller!.evaluateJavascript(
        source: "document.readyState === 'complete'"
      );

      if (isPageLoaded != true) {
        throw Exception("WebView page not fully loaded");
      }

      // Vérifier que les fonctions JavaScript sont disponibles
      final checkResult = await _controller!.evaluateJavascript(
        source: "typeof startAutomation !== 'undefined' && typeof extractFinalResponse !== 'undefined'"
      );

      print("🔍 JavaScript functions available: $checkResult");

      if (checkResult != true) {
        throw Exception("Automation functions not available in WebView. Script may not be injected yet.");
      }

      // Échapper le prompt pour éviter les erreurs JavaScript
      final escapedPrompt = prompt
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');

      print("📤 Calling JavaScript startAutomation...");
      await _controller!.evaluateJavascript(
        source: "startAutomation('$escapedPrompt');"
      );

      print("✅ JavaScript automation started successfully");
    } catch (e) {
      print("❌ Automation failed: $e");
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

      return result as String;
    } catch (e) {
      throw Exception("Failed to extract response: $e");
    }
  }
}

final javaScriptBridgeProvider = Provider((ref) => JavaScriptBridge(ref));