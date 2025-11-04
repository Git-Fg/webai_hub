import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bridge_diagnostics_provider.g.dart';

class BridgeDiagnostics {
  const BridgeDiagnostics({
    required this.completerInitialized,
    required this.completerCompleted,
    required this.webViewControllerExists,
    this.lastErrorTimestamp,
    this.lastErrorCode,
    this.lastErrorLocation,
    this.bridgeSignaledReadyTimestamp,
    this.webViewCreatedTimestamp,
  });
  final bool completerInitialized;
  final bool completerCompleted;
  final bool webViewControllerExists;
  final DateTime? lastErrorTimestamp;
  final String? lastErrorCode;
  final String? lastErrorLocation;
  final DateTime? bridgeSignaledReadyTimestamp;
  final DateTime? webViewCreatedTimestamp;

  BridgeDiagnostics copyWith({
    bool? completerInitialized,
    bool? completerCompleted,
    bool? webViewControllerExists,
    DateTime? lastErrorTimestamp,
    String? lastErrorCode,
    String? lastErrorLocation,
    DateTime? bridgeSignaledReadyTimestamp,
    DateTime? webViewCreatedTimestamp,
    bool clearLastError = false,
    bool clearBridgeReady = false,
    bool clearWebViewCreated = false,
  }) {
    return BridgeDiagnostics(
      completerInitialized: completerInitialized ?? this.completerInitialized,
      completerCompleted: completerCompleted ?? this.completerCompleted,
      webViewControllerExists:
          webViewControllerExists ?? this.webViewControllerExists,
      lastErrorTimestamp: clearLastError
          ? null
          : (lastErrorTimestamp ?? this.lastErrorTimestamp),
      lastErrorCode:
          clearLastError ? null : (lastErrorCode ?? this.lastErrorCode),
      lastErrorLocation:
          clearLastError ? null : (lastErrorLocation ?? this.lastErrorLocation),
      bridgeSignaledReadyTimestamp: clearBridgeReady
          ? null
          : (bridgeSignaledReadyTimestamp ?? this.bridgeSignaledReadyTimestamp),
      webViewCreatedTimestamp: clearWebViewCreated
          ? null
          : (webViewCreatedTimestamp ?? this.webViewCreatedTimestamp),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'completerInitialized': completerInitialized,
      'completerCompleted': completerCompleted,
      'webViewControllerExists': webViewControllerExists,
      'lastErrorTimestamp': lastErrorTimestamp?.toIso8601String(),
      'lastErrorCode': lastErrorCode,
      'lastErrorLocation': lastErrorLocation,
      'bridgeSignaledReadyTimestamp':
          bridgeSignaledReadyTimestamp?.toIso8601String(),
      'webViewCreatedTimestamp': webViewCreatedTimestamp?.toIso8601String(),
    };
  }
}

@riverpod
class BridgeDiagnosticsState extends _$BridgeDiagnosticsState {
  @override
  BridgeDiagnostics build() {
    return const BridgeDiagnostics(
      completerInitialized: false,
      completerCompleted: false,
      webViewControllerExists: false,
    );
  }

  void updateDiagnostics(
    BridgeDiagnostics Function(BridgeDiagnostics) updater,
  ) {
    state = updater(state);
  }

  void recordError(String errorCode, String location) {
    state = state.copyWith(
      lastErrorTimestamp: DateTime.now(),
      lastErrorCode: errorCode,
      lastErrorLocation: location,
    );
  }

  void recordBridgeReady() {
    state = state.copyWith(
      bridgeSignaledReadyTimestamp: DateTime.now(),
      completerCompleted: true,
    );
  }

  void recordWebViewCreated() {
    state = state.copyWith(
      webViewCreatedTimestamp: DateTime.now(),
      webViewControllerExists: true,
    );
  }

  void recordCompleterInitialized() {
    state = state.copyWith(
      completerInitialized: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearLastError: true);
  }
}
