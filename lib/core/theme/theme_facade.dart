import 'package:ai_hybrid_hub/core/theme/hub_theme_extension.dart';
import 'package:flutter/material.dart';

/// WHY: This extension provides a clean, type-safe way to access the custom
/// theme extension from any BuildContext. It eliminates the verbose
/// `Theme.of(context).extension<HubThemeExtension>()!` syntax and centralizes
/// the null assertion, making it fail-fast during development if the extension
/// isn't registered.
extension ThemeFacade on BuildContext {
  /// Access the custom Hub theme extension
  HubThemeExtension get hubTheme =>
      Theme.of(this).extension<HubThemeExtension>()!;
}
