import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';

class FakeJavaScriptBridge implements JavaScriptBridgeInterface {
  // Pour vérifier que les méthodes ont été appelées
  String? lastPromptSent;
  bool wasExtractCalled = false;

  // Pour simuler des erreurs
  bool shouldThrowError = false;

  @override
  Future<void> startAutomation(String prompt) async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrowError) {
      throw Exception("Fake automation error");
    }
    // Enregistrer le prompt pour vérification
    lastPromptSent = prompt;
  }

  @override
  Future<String> extractFinalResponse() async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrowError) {
      throw Exception("Fake extraction error");
    }
    wasExtractCalled = true;
    // Retourner une réponse prédictible
    return "This is a fake AI response from the test bridge.";
  }

  // Méthode utilitaire pour réinitialiser l'état entre les tests
  void reset() {
    lastPromptSent = null;
    wasExtractCalled = false;
    shouldThrowError = false;
  }
}
