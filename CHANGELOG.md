# [2025-11-15] - Native Optimized Design System Implementation

Complete UI architecture refactoring to centralized, semantic theme system. Migrated from scattered hardcoded styles to Flutter's native ThemeExtension API with full support for animated theme transitions.

# [2025-11-14] - Service Consolidation, Performance Improvements & Persistent User Agent Error Dialog

- Consolidated duplicate preset logic into PresetService and converted OrchestrationService to Riverpod provider. Replaced polling waits with MutationObserver pattern for improved performance. Added graceful error handling for invalid preset configurations. Elevated Google OAuth "disallowed_useragent" error from ephemeral notification to persistent, non-draggable dialog with direct navigation to settings.
