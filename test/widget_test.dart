import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:multi_webview_tab_manager/main.dart';
import 'package:multi_webview_tab_manager/shared/models/ai_provider.dart';

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
    expect(find.text('AI Studio'), findsAtLeastNWidgets(1));
    expect(find.text('Qwen'), findsAtLeastNWidgets(1));
    expect(find.text('Z-ai'), findsAtLeastNWidgets(1));
    expect(find.text('Kimi'), findsAtLeastNWidgets(1));
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

    // Verify basic UI elements are present
    expect(find.byIcon(Icons.hub), findsOneWidget);

    // Verify we have provider cards (at least the provider names should appear)
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

    // Verify we're on the Hub tab initially
    expect(find.text('Hub'), findsOneWidget);
    expect(find.byIcon(Icons.hub), findsOneWidget);

    // Verify we can see all tabs
    expect(find.text('AI Studio'), findsAtLeastNWidgets(1));
    expect(find.text('Qwen'), findsAtLeastNWidgets(1));
    expect(find.text('Z-ai'), findsAtLeastNWidgets(1));
    expect(find.text('Kimi'), findsAtLeastNWidgets(1));

    // Note: We don't test WebView navigation in widget tests as it requires web content
    // Just verify tab structure is correct
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
