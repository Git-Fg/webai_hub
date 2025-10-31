import 'ai_provider.dart';

enum AutomationPhase {
  idle,           // No automation in progress
  sending,        // Phase 1: Sending prompt to provider
  observing,      // Phase 2: Observing generation
  refining,       // Phase 3: Manual refinement allowed
  extracting,     // Phase 4: Extracting final response
  error,          // Automation failed
}

enum ProviderStatus {
  unknown,        // Status not checked yet
  ready,          // ✅ Logged in and ready
  login,          // ❌ Login required
  loading,        // 🔄 Checking status
  error,          // ⚠️ Error occurred
  automation,     // 🤖 Automation in progress
}

class AutomationState {
  final AutomationPhase phase;
  final AIProvider? provider;
  final String? currentPrompt;
  final String? errorMessage;
  final bool canCancel;
  final bool canValidate;
  final DateTime? startTime;

  const AutomationState({
    this.phase = AutomationPhase.idle,
    this.provider,
    this.currentPrompt,
    this.errorMessage,
    this.canCancel = false,
    this.canValidate = false,
    this.startTime,
  });

  AutomationState copyWith({
    AutomationPhase? phase,
    AIProvider? provider,
    String? currentPrompt,
    String? errorMessage,
    bool? canCancel,
    bool? canValidate,
    DateTime? startTime,
  }) {
    return AutomationState(
      phase: phase ?? this.phase,
      provider: provider ?? this.provider,
      currentPrompt: currentPrompt ?? this.currentPrompt,
      errorMessage: errorMessage ?? this.errorMessage,
      canCancel: canCancel ?? this.canCancel,
      canValidate: canValidate ?? this.canValidate,
      startTime: startTime ?? this.startTime,
    );
  }

  bool get isIdle => phase == AutomationPhase.idle;
  bool get isActive => phase != AutomationPhase.idle && phase != AutomationPhase.error;
  bool get hasError => phase == AutomationPhase.error;

  String get statusText {
    switch (phase) {
      case AutomationPhase.idle:
        return '';
      case AutomationPhase.sending:
        return 'Envoi en cours...';
      case AutomationPhase.observing:
        return 'Génération en cours...';
      case AutomationPhase.refining:
        return 'Prêt pour raffinage';
      case AutomationPhase.extracting:
        return 'Extraction en cours...';
      case AutomationPhase.error:
        return 'Erreur: $errorMessage';
    }
  }
}