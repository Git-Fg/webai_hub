import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bridge_diagnostics_provider.g.dart';

class BridgeDiagnostics {
  const BridgeDiagnostics({
    required this.webViewControllerExists,
    this.lastErrorTimestamp,
    this.lastErrorCode,
    this.lastErrorLocation,
    this.bridgeSignaledReadyTimestamp,
    this.webViewCreatedTimestamp,
  });
  final bool webViewControllerExists;
  final DateTime? lastErrorTimestamp;
  final String? lastErrorCode;
  final String? lastErrorLocation;
  final DateTime? bridgeSignaledReadyTimestamp;
  final DateTime? webViewCreatedTimestamp;

  BridgeDiagnostics copyWith({
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
    );
  }

  void recordWebViewCreated() {
    state = state.copyWith(
      webViewCreatedTimestamp: DateTime.now(),
      webViewControllerExists: true,
    );
  }

  void recordCompleterInitialized() {
    // This method is no longer needed as completerInitialized is removed.
    // Keeping it for now to avoid breaking existing calls, but it will do nothing.
  }

  void clearError() {
    state = state.copyWith(clearLastError: true);
  }
}
