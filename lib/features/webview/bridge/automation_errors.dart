enum AutomationErrorCode {
  bridgeNotInitialized,
  bridgeTimeout,
  webViewNotReady,
  pageNotLoaded,
  scriptNotInjected,
  automationExecutionFailed,
  responseExtractionFailed,
  unknown,
}

class AutomationError extends StateError {
  final AutomationErrorCode errorCode;
  final String location;
  final Map<String, dynamic> diagnostics;
  final DateTime timestamp;
  final Object? originalError;
  @override
  final StackTrace? stackTrace;

  AutomationError({
    required this.errorCode,
    required this.location,
    required String message,
    this.diagnostics = const {},
    this.originalError,
    this.stackTrace,
  })  : timestamp = DateTime.now(),
        super(_buildErrorMessage(
            errorCode, location, message, diagnostics, originalError));

  static String _buildErrorMessage(
    AutomationErrorCode code,
    String location,
    String message,
    Map<String, dynamic> diagnostics,
    Object? originalError,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('[${code.name.toUpperCase()}] $message');
    buffer.writeln('Location: $location');

    if (diagnostics.isNotEmpty) {
      buffer.writeln('State:');
      diagnostics.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    if (originalError != null) {
      buffer.writeln('Original Error: $originalError');
    }

    return buffer.toString();
  }

  String getDiagnosticReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Automation Error Diagnostic Report ===');
    buffer.writeln('Error Code: ${errorCode.name}');
    buffer.writeln('Location: $location');
    buffer.writeln('Timestamp: ${timestamp.toIso8601String()}');
    buffer.writeln('Message: $message');

    if (diagnostics.isNotEmpty) {
      buffer.writeln('Diagnostics:');
      diagnostics.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    if (originalError != null) {
      buffer.writeln('Original Error: $originalError');
    }

    if (stackTrace != null) {
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace);
    }

    buffer.writeln('==========================================');
    return buffer.toString();
  }
}
