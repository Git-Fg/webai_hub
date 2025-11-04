enum AutomationErrorCode {
  bridgeNotInitialized,
  bridgeTimeout,
  webViewNotReady,
  pageNotLoaded,
  scriptNotInjected,
  automationExecutionFailed,
  responseExtractionFailed,
  responseObservationFailed,
  unknown,
}

class AutomationError extends StateError {
  AutomationError({
    required this.errorCode,
    required this.location,
    required String message,
    this.diagnostics = const {},
    this.originalError,
    this.stackTrace,
  })  : timestamp = DateTime.now(),
        super(
          _buildErrorMessage(
            errorCode,
            location,
            message,
            diagnostics,
            originalError,
          ),
        );
  final AutomationErrorCode errorCode;
  final String location;
  final Map<String, dynamic> diagnostics;
  final DateTime timestamp;
  final Object? originalError;
  @override
  final StackTrace? stackTrace;

  static String _buildErrorMessage(
    AutomationErrorCode code,
    String location,
    String message,
    Map<String, dynamic> diagnostics,
    Object? originalError,
  ) {
    final buffer = StringBuffer()
      ..writeln('[${code.name.toUpperCase()}] $message')
      ..writeln('Location: $location');

    if (diagnostics.isNotEmpty) {
      final diagText = diagnostics.entries
          .map((e) => '  ${e.key}: ${e.value}')
          .join('\n');
      buffer
        ..writeln('State:')
        ..writeln(diagText);
    }

    if (originalError != null) {
      buffer.writeln('Original Error: $originalError');
    }

    return buffer.toString();
  }

  String getDiagnosticReport() {
    final buffer = StringBuffer()
      ..writeln('=== Automation Error Diagnostic Report ===')
      ..writeln('Error Code: ${errorCode.name}')
      ..writeln('Location: $location')
      ..writeln('Timestamp: ${timestamp.toIso8601String()}')
      ..writeln('Message: $message');

    if (diagnostics.isNotEmpty) {
      final diagText = diagnostics.entries
          .map((e) => '  ${e.key}: ${e.value}')
          .join('\n');
      buffer
        ..writeln('Diagnostics:')
        ..writeln(diagText);
    }

    if (originalError != null) {
      buffer.writeln('Original Error: $originalError');
    }

    if (stackTrace != null) {
      buffer
        ..writeln('Stack Trace:')
        ..writeln(stackTrace);
    }

    buffer.writeln('==========================================');
    return buffer.toString();
  }
}
