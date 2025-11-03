// lib/features/webview/providers/webview_content_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:ai_hybrid_hub/features/webview/models/webview_content.dart';

part 'webview_content_provider.g.dart';

@riverpod
WebViewContent initialWebViewContent(Ref ref) {
  // Par défaut, dans l'application réelle, on charge toujours l'URL de production.
  return WebViewContentUrl("https://aistudio.google.com/prompts/new_chat");
  // À l'avenir, ce provider pourrait lire le provider du chatbot sélectionné
  // pour retourner la bonne URL (ChatGPT, Claude, etc.).
}
