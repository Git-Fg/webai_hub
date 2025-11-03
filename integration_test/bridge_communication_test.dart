// integration_test/bridge_communication_test.dart
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  // Initialise le binding pour les tests d'intégration
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Full Bridge Communication Test: Dart -> JS -> Dart',
    (WidgetTester tester) async {
      // 1. MISE EN PLACE
      // On prépare un ProviderContainer pour écouter les changements d'état
      // en dehors de l'arbre des widgets. C'est crucial pour nos assertions.
      final container = ProviderContainer();

      // On s'abonne à notre état d'automatisation. On veut voir s'il passe
      // de 'idle' à 'refining' après l'événement 'GENERATION_COMPLETE'.
      final automationStateListener = Listener<AutomationStatus>();
      container.listen<AutomationStatus>(
        automationStateProvider,
        automationStateListener,
        fireImmediately: true,
      );

      // 2. RENDU DU WIDGET
      // On affiche SEULEMENT l'écran du WebView dans un ProviderScope.
      // Cela isole complètement le composant que nous voulons tester.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AiWebviewScreen(), // On charge notre sandbox par défaut
          ),
        ),
      );

      // 3. ATTENTE DU CHARGEMENT COMPLET
      // On attend que le WebView soit créé, que la page HTML locale soit chargée,
      // que le script JS soit injecté et qu'il ait signalé "bridgeReady".
      print('[TEST] Attente du chargement du WebView et du bridge...');

      // On attend d'abord que l'UI soit stable
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Puis on attend activement que le bridge soit prêt avec un timeout
      bool bridgeReady = false;
      const maxWaitSeconds = 10;
      final startTime = DateTime.now();

      while (!bridgeReady &&
          DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
        await tester.pump(const Duration(milliseconds: 100));
        bridgeReady = container.read(bridgeReadyProvider);
        if (!bridgeReady) {
          print(
              '[TEST] Bridge pas encore prêt, attente... (${DateTime.now().difference(startTime).inSeconds}s)');
        }
      }

      // Vérification initiale : Le bridge doit être prêt.
      expect(bridgeReady, isTrue,
          reason:
              "Le bridge JS n'a jamais signalé être prêt après ${maxWaitSeconds}s. Vérifiez l'injection et l'appel à 'trySignalReady'.");
      print('[TEST] Bridge prêt. Le contrôleur WebView est disponible.');

      // On récupère le contrôleur du WebView via son provider pour pouvoir
      // interagir avec lui directement depuis le test.
      final webViewController = container.read(webViewControllerProvider);
      expect(webViewController, isNotNull,
          reason:
              "Le contrôleur du WebView n'a pas été défini dans le provider.");

      // 4. DÉCLENCHEMENT DE L'AUTOMATION (DART -> JS)
      print('[TEST] Déclenchement de startAutomation en JS...');
      // On simule l'appel qui serait fait par ConversationProvider.
      // L'appel est volontairement enveloppé dans un `try-catch` pour ne pas
      // faire échouer le test s'il y a une exception JS.
      try {
        await webViewController!.evaluateJavascript(
            source: "window.startAutomation('Test from Integration Test');");
      } catch (e) {
        fail(
            "L'appel à window.startAutomation a échoué avec une exception JS : $e");
      }

      print(
          '[TEST] Appel a startAutomation effectue. Attente de l\'evenement de retour...');

      // 5. ATTENTE ET VÉRIFICATION DU RETOUR (JS -> DART)
      // On donne jusqu'à 15 secondes au script JS pour s'exécuter et renvoyer
      // l'événement 'GENERATION_COMPLETE'.
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Assertion finale : L'état a-t-il bien changé ?
      // Le script du sandbox envoie 'GENERATION_COMPLETE', ce qui devrait
      // faire passer le `automationStateProvider` à `AutomationStatus.refining`.
      final finalStatus = container.read(automationStateProvider);
      expect(
        finalStatus,
        AutomationStatus.refining,
        reason:
            "L'état final de l'automatisation n'est pas 'refining'. L'événement 'GENERATION_COMPLETE' n'a probablement pas été reçu par Dart.",
      );

      print(
          '[TEST] Succès ! L\'état est passé à "refining". Le cycle de communication est complet.');
    },
  );

  testWidgets(
    'JavaScript automation correctly manipulates the sandbox DOM',
    (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AiWebviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      bool bridgeReady = false;
      const maxWaitSeconds = 10;
      final startTime = DateTime.now();

      while (!bridgeReady &&
          DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
        await tester.pump(const Duration(milliseconds: 100));
        bridgeReady = container.read(bridgeReadyProvider);
      }

      expect(bridgeReady, isTrue,
          reason:
              "Le bridge JS n'a jamais signalé être prêt après ${maxWaitSeconds}s.");

      final webViewController = container.read(webViewControllerProvider);
      expect(webViewController, isNotNull,
          reason:
              "Le contrôleur du WebView n'a pas été défini dans le provider.");

      const prompt = 'My test prompt';

      await webViewController!
          .evaluateJavascript(source: "window.startAutomation('$prompt');");

      // Attendre que le message utilisateur soit ajouté au DOM
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // High-fidelity: vérifier que le prompt a été ajouté dans le DOM de conversation
      // (le champ texte est vidé après le clic, donc on vérifie plutôt le message utilisateur)
      final userMessageText = await webViewController.evaluateJavascript(
          source:
              "const userTurn = document.querySelector('ms-chat-turn[data-turn-role=\"User\"]:last-of-type ms-cmark-node'); userTurn ? userTurn.innerText : '';");
      expect(userMessageText, contains(prompt),
          reason:
              "Le script JS n'a pas correctement ajouté le prompt dans le DOM de conversation.");

      // High-fidelity: vérifier que ms-thought-chunk existe (indicateur de génération)
      final thoughtChunkExists = await webViewController.evaluateJavascript(
          source: "document.querySelector('ms-thought-chunk') !== null;");
      expect(thoughtChunkExists, isTrue,
          reason:
              "L'indicateur de génération (ms-thought-chunk) n'est pas apparu après le clic.");

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // High-fidelity: utiliser le sélecteur ms-chat-turn avec data-turn-role="Model"
      final responseText = await webViewController.evaluateJavascript(
          source:
              "document.querySelector('ms-chat-turn[data-turn-role=\"Model\"]:last-of-type ms-cmark-node')?.innerText || '';");
      expect(responseText, contains(prompt),
          reason: "La réponse simulée n'a pas été injectée dans le DOM.");

      // High-fidelity: vérifier que ms-thought-chunk a disparu (display: none)
      final thoughtChunkHidden = await webViewController.evaluateJavascript(
          source:
              "const el = document.querySelector('ms-thought-chunk'); el && el.style.display === 'none';");
      expect(thoughtChunkHidden, isTrue,
          reason:
              "L'indicateur de génération (ms-thought-chunk) n'a pas disparu après la fin.");
    },
  );

  testWidgets(
      'Extraction Test: extractFinalResponse returns the correct string',
      (WidgetTester tester) async {
    // 1. MISE EN PLACE (similaire au test précédent)
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AiWebviewScreen(),
        ),
      ),
    );

    // Attendre que tout soit prêt
    print('[EXTRACT TEST] Attente du chargement du WebView et du bridge...');
    bool bridgeReady = false;
    const maxWaitSeconds = 10;
    final startTime = DateTime.now();

    while (!bridgeReady &&
        DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      await tester.pump(const Duration(milliseconds: 100));
      bridgeReady = container.read(bridgeReadyProvider);
    }

    expect(bridgeReady, isTrue, reason: "Le bridge n'est pas prêt.");

    final webViewController = container.read(webViewControllerProvider);
    expect(webViewController, isNotNull,
        reason:
            "Le contrôleur du WebView n'a pas été défini dans le provider.");

    final bridge = container.read(javaScriptBridgeProvider);

    // 2. SIMULER LE WORKFLOW
    // On déclenche l'automatisation pour que la page génère une réponse
    print(
        '[EXTRACT TEST] Déclenchement de startAutomation pour générer du contenu...');
    const testPrompt = 'Generate a response for extraction';
    await webViewController!
        .evaluateJavascript(source: "window.startAutomation('$testPrompt');");

    // On attend que la génération soit terminée (le setTimeout de 2s dans le sandbox + marge)
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 3. APPEL ET VÉRIFICATION DE L'EXTRACTION
    print('[EXTRACT TEST] Appel de extractFinalResponse...');
    String? extractedText;
    Object? extractionError;

    try {
      // C'est l'appel que nous testons !
      extractedText = await bridge.extractFinalResponse();
    } catch (e) {
      extractionError = e;
    }

    // 4. ASSERTIONS
    expect(extractionError, isNull,
        reason:
            "extractFinalResponse a levé une exception inattendue: $extractionError");

    expect(extractedText, isA<String>(),
        reason:
            "La valeur retournée n'est pas un String, mais un ${extractedText.runtimeType}");

    expect(extractedText, isNotNull, reason: "Le texte extrait est null.");

    expect(
      extractedText,
      contains('This is the high-fidelity response to: "$testPrompt"'),
      reason:
          "Le texte extrait ne correspond pas au contenu attendu du sandbox haute-fidélité.",
    );

    print('[EXTRACT TEST] Succès ! Le texte a été extrait correctement.');
  });
}

// Classe helper pour écouter les changements d'un provider
class Listener<T> {
  final List<T> values = [];

  void call(T? previous, T next) {
    values.add(next);
  }
}
