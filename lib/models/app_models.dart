/// Represents the status of an AI provider
enum ProviderStatus {
  unknown,
  ready,
  needsLogin,
  error,
}

/// Represents a provider configuration
class ProviderConfig {
  final String id; // 'kimi', 'qwen', etc.
  final String name; // Display name
  final String url; // Base URL
  final String icon; // Icon name
  
  const ProviderConfig({
    required this.id,
    required this.name,
    required this.url,
    required this.icon,
  });
}

/// State of the companion overlay
enum OverlayState {
  hidden,
  automating, // Phase 1-2: "Automatisation en cours..."
  waitingForValidation, // Phase 3: Ready for refinement
}

/// Overlay UI state
class OverlayUIState {
  final OverlayState state;
  final String message;
  final bool showValidateButton;
  final bool showCancelButton;
  
  const OverlayUIState({
    required this.state,
    required this.message,
    this.showValidateButton = false,
    this.showCancelButton = false,
  });
  
  factory OverlayUIState.hidden() {
    return const OverlayUIState(
      state: OverlayState.hidden,
      message: '',
    );
  }
  
  factory OverlayUIState.automating() {
    return const OverlayUIState(
      state: OverlayState.automating,
      message: 'Automatisation en cours...',
      showCancelButton: true,
    );
  }
  
  factory OverlayUIState.waitingForValidation() {
    return const OverlayUIState(
      state: OverlayState.waitingForValidation,
      message: 'Prêt pour raffinage',
      showValidateButton: true,
      showCancelButton: true,
    );
  }
  
  factory OverlayUIState.error(String error) {
    return OverlayUIState(
      state: OverlayState.hidden,
      message: '⚠️ Automatisation échouée. $error',
    );
  }
}
