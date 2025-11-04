import 'package:ai_hybrid_hub/features/webview/bridge/automation_errors.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge_interface.dart';

enum ErrorType {
  none,
  genericException,
  automationError,
}

class FakeJavaScriptBridge implements JavaScriptBridgeInterface {
  // Pour vérifier que les méthodes ont été appelées
  String? lastPromptSent;
  bool wasExtractCalled = false;

  // Pour simuler des erreurs - séparés par méthode
  ErrorType startAutomationErrorType = ErrorType.none;
  ErrorType extractFinalResponseErrorType = ErrorType.none;

  // Legacy support: si shouldThrowError est true, on lève une Exception générique
  bool get shouldThrowError =>
      startAutomationErrorType == ErrorType.genericException ||
      extractFinalResponseErrorType == ErrorType.genericException;

  set shouldThrowError(bool value) {
    if (value) {
      startAutomationErrorType = ErrorType.genericException;
      extractFinalResponseErrorType = ErrorType.genericException;
    } else {
      startAutomationErrorType = ErrorType.none;
      extractFinalResponseErrorType = ErrorType.none;
    }
  }

  @override
  Future<void> waitForBridgeReady() async {
    // Dans les tests, le bridge est toujours prêt immédiatement
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> startAutomation(String prompt) async {
    // Simuler un délai réseau
    await Future<void>.delayed(const Duration(milliseconds: 50));

    switch (startAutomationErrorType) {
      case ErrorType.genericException:
        throw Exception('Fake automation error');
      case ErrorType.automationError:
        throw AutomationError(
          errorCode: AutomationErrorCode.automationExecutionFailed,
          location: 'startAutomation',
          message: 'Fake automation execution failed for testing',
          diagnostics: {'prompt': prompt},
        );
      case ErrorType.none:
        // Enregistrer le prompt pour vérification
        lastPromptSent = prompt;
    }
  }

  @override
  Future<String> extractFinalResponse() async {
    // Simuler un délai réseau
    await Future<void>.delayed(const Duration(milliseconds: 50));

    switch (extractFinalResponseErrorType) {
      case ErrorType.genericException:
        throw Exception('Fake extraction error');
      case ErrorType.automationError:
        throw AutomationError(
          errorCode: AutomationErrorCode.responseExtractionFailed,
          location: 'extractFinalResponse',
          message: 'Fake response extraction failed for testing',
          diagnostics: {'wasExtractCalled': wasExtractCalled},
        );
      case ErrorType.none:
        wasExtractCalled = true;
        // Retourner une réponse prédictible
        return 'This is a fake AI response from the test bridge.';
    }
  }

  // SUPPRIMÉ : waitForResponseCompletion n'est plus nécessaire

  // Méthode pour simuler getCapturedLogs (utilisée par conversation_provider)
  Future<List<Map<String, dynamic>>> getCapturedLogs() async {
    return [];
  }

  // Méthode utilitaire pour réinitialiser l'état entre les tests
  void reset() {
    lastPromptSent = null;
    wasExtractCalled = false;
    startAutomationErrorType = ErrorType.none;
    extractFinalResponseErrorType = ErrorType.none;
  }
}
