# [2025-11-14] - Service Consolidation, Performance Improvements & Persistent User Agent Error Dialog

- Consolidated duplicate preset logic into PresetService and converted OrchestrationService to Riverpod provider. Replaced polling waits with MutationObserver pattern for improved performance. Added graceful error handling for invalid preset configurations. Elevated Google OAuth "disallowed_useragent" error from ephemeral notification to persistent, non-draggable dialog with direct navigation to settings.
