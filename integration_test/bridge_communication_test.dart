// integration_test/bridge_communication_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/providers/webview_content_provider.dart';
import 'package:ai_hybrid_hub/features/webview/models/webview_content.dart';

// Helper pour attendre qu'un provider atteigne une certaine valeur
Future<void> waitUntilProvider<T>(
  WidgetTester tester,
  ProviderContainer container,
  dynamic provider,
  T expectedValue, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  bool isReady = false;
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
    isReady = container.read(provider) == expectedValue;
    if (isReady) return;
  }

  fail('Provider $provider did not reach value $expectedValue within $timeout');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // On définit le sandbox à utiliser pour ce groupe de tests
  const sandboxPath = 'assets/sandboxes/aistudio_sandbox.html';

  group('AI Studio Bridge Integration Tests', () {
    late ProviderContainer container;

    // Helper pour initialiser l'app avec le sandbox
    Future<void> pumpSandbox(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          initialWebViewContentProvider.overrideWithValue(
            WebViewContentHtmlFile(sandboxPath),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AiWebviewScreen()),
        ),
      );

      // Attendre que le bridge soit prêt
      print('[TEST] Waiting for WebView and bridge to be ready...');
      await waitUntilProvider(
        tester,
        container,
        bridgeReadyProvider,
        true,
        timeout: const Duration(seconds: 30),
      );
      print('[TEST] Bridge is ready.');
    }

    testWidgets(
      'Full Bridge Communication Cycle (Dart -> JS -> Dart)',
      (tester) async {
        await pumpSandbox(tester);

        final webViewController = container.read(webViewControllerProvider);

        // ACT: Déclencher l'automatisation
        await webViewController!.evaluateJavascript(
          source: "window.startAutomation('Test');",
        );

        // ASSERT: Attendre que l'état passe à 'refining'
        await waitUntilProvider(
          tester,
          container,
          automationStateProvider,
          AutomationStatus.refining,
          timeout: const Duration(seconds: 15),
        );

        print('[TEST] Success! State transitioned to refining.');
      },
    );

    testWidgets(
      'JavaScript automation correctly manipulates the sandbox DOM',
      (tester) async {
        await pumpSandbox(tester);

        final webViewController = container.read(webViewControllerProvider);
        const prompt = 'My test prompt';

        await webViewController!
            .evaluateJavascript(source: "window.startAutomation('$prompt');");

        // Attendre que le message utilisateur soit ajouté au DOM
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // High-fidelity: vérifier que le prompt a été ajouté dans le DOM de conversation
        final userMessageText = await webViewController.evaluateJavascript(
          source:
              "const userTurn = document.querySelector('ms-chat-turn[data-turn-role=\"User\"]:last-of-type ms-cmark-node'); userTurn ? userTurn.innerText : '';",
        );
        expect(
          userMessageText,
          contains(prompt),
          reason:
              "Le script JS n'a pas correctement ajouté le prompt dans le DOM de conversation.",
        );

        // High-fidelity: vérifier que ms-thought-chunk existe (indicateur de génération)
        final thoughtChunkExists = await webViewController.evaluateJavascript(
          source: "document.querySelector('ms-thought-chunk') !== null;",
        );
        expect(
          thoughtChunkExists,
          isTrue,
          reason:
              "L'indicateur de génération (ms-thought-chunk) n'est pas apparu après le clic.",
        );

        await tester.pumpAndSettle(const Duration(seconds: 3));

        // High-fidelity: utiliser le sélecteur ms-chat-turn avec data-turn-role="Model"
        final responseText = await webViewController.evaluateJavascript(
          source:
              "document.querySelector('ms-chat-turn[data-turn-role=\"Model\"]:last-of-type ms-cmark-node')?.innerText || '';",
        );
        expect(
          responseText,
          contains(prompt),
          reason: "La réponse simulée n'a pas été injectée dans le DOM.",
        );

        // High-fidelity: vérifier que ms-thought-chunk a disparu (display: none)
        final thoughtChunkHidden = await webViewController.evaluateJavascript(
          source:
              "const el = document.querySelector('ms-thought-chunk'); el && el.style.display === 'none';",
        );
        expect(
          thoughtChunkHidden,
          isTrue,
          reason:
              "L'indicateur de génération (ms-thought-chunk) n'a pas disparu après la fin.",
        );
      },
    );

    testWidgets(
      'Extraction Test: extractFinalResponse returns clean string',
      (tester) async {
        await pumpSandbox(tester);

        final webViewController = container.read(webViewControllerProvider);
        final bridge = container.read(javaScriptBridgeProvider);

        // ACT: Lancer l'automatisation pour générer du contenu
        const testPrompt = 'Generate for extraction';
        await webViewController!.evaluateJavascript(
          source: "window.startAutomation('$testPrompt');",
        );

        // Attendre la fin de la génération simulée
        await waitUntilProvider(
          tester,
          container,
          automationStateProvider,
          AutomationStatus.refining,
          timeout: const Duration(seconds: 15),
        );

        // ACT: Lancer l'extraction
        final extractedText = await bridge.extractFinalResponse();

        // ASSERT
        expect(extractedText, isA<String>());
        expect(
          extractedText,
          'This is the high-fidelity response to: "$testPrompt"',
          reason:
              "The extracted text does not match the cleaned sandbox content.",
        );

        print('[TEST] Success! Clean text was extracted correctly.');
      },
    );
  });
}
