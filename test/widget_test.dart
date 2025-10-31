import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:multi_webview_tab_manager/main.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';
import 'package:multi_webview_tab_manager/features/hub/providers/conversation_provider.dart';

void main() {
  testWidgets('AI Hybrid Hub app builds correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AIHybridHubApp(),
      ),
    );

    // Verify that the app title is present
    expect(find.text('AI Hybrid Hub'), findsOneWidget);

    // Verify that all 5 tabs are present
    expect(find.text('Hub'), findsOneWidget);
    expect(find.text('AI Studio'), findsOneWidget);
    expect(find.text('Qwen'), findsOneWidget);
    expect(find.text('Z-ai'), findsOneWidget);
    expect(find.text('Kimi'), findsOneWidget);

    // Verify that we're on the Hub tab initially
    expect(find.text('AI Hybrid Hub'), findsOneWidget);
    expect(find.text('Assistant intelligent multi-providers'), findsOneWidget);
  });

  testWidgets('Welcome screen displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AIHybridHubApp(),
      ),
    );

    // Wait for the welcome screen to load
    await tester.pumpAndSettle();

    // Verify welcome elements
    expect(find.byIcon(Icons.hub), findsOneWidget);
    expect(find.text('AI Hybrid Hub'), findsOneWidget);
    expect(find.text('Assistant intelligent multi-providers'), findsOneWidget);
    expect(find.text('Statut des Providers'), findsOneWidget);
    expect(find.text('Commencer une conversation'), findsOneWidget);

    // Verify provider status cards
    expect(find.text('AI Studio'), findsAtLeastNWidgets(1));
    expect(find.text('Qwen'), findsAtLeastNWidgets(1));
    expect(find.text('Z-ai'), findsAtLeastNWidgets(1));
    expect(find.text('Kimi'), findsAtLeastNWidgets(1));
  });

  testWidgets('Tab navigation works correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AIHybridHubApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on AI Studio tab
    await tester.tap(find.text('AI Studio'));
    await tester.pumpAndSettle();

    // Verify we're on the AI Studio tab (should show WebView)
    expect(find.byType(InAppWebView), findsOneWidget);

    // Tap back to Hub tab
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();

    // Verify we're back on the Hub
    expect(find.text('AI Hybrid Hub'), findsOneWidget);
  });

  testWidgets('AIProvider enum works correctly', (WidgetTester tester) async {
    // Test AIProvider enum functionality
    expect(AIProvider.values.length, 4);
    expect(AIProvider.aistudio.displayName, 'AI Studio');
    expect(AIProvider.qwen.displayName, 'Qwen');
    expect(AIProvider.zai.displayName, 'Z-ai');
    expect(AIProvider.kimi.displayName, 'Kimi');

    expect(AIProvider.aistudio.url, 'https://aistudio.google.com/prompts/new_chat');
    expect(AIProvider.qwen.url, 'https://chat.qwen.ai/');
    expect(AIProvider.zai.url, 'https://chat.z.ai/');
    expect(AIProvider.kimi.url, 'https://www.kimi.com/');

    // Test fromIndex method
    expect(AIProvider.fromIndex(0), AIProvider.aistudio);
    expect(AIProvider.fromIndex(1), AIProvider.qwen);
    expect(AIProvider.fromIndex(2), AIProvider.zai);
    expect(AIProvider.fromIndex(3), AIProvider.kimi);
    expect(AIProvider.fromIndex(99), AIProvider.aistudio); // Default fallback
  });
}
