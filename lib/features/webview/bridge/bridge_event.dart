class BridgeEvent {
  BridgeEvent({
    required this.type,
    this.payload,
    this.errorCode,
    this.location,
    this.diagnostics,
  });

  factory BridgeEvent.fromJson(Map<String, dynamic> json) {
    return BridgeEvent(
      type: json['type'] as String? ?? 'UNKNOWN',
      payload: json['payload'] as String?,
      errorCode: json['errorCode'] as String?,
      location: json['location'] as String?,
      diagnostics: json['diagnostics'] is Map
          ? Map<String, dynamic>.from(json['diagnostics'] as Map)
          : null,
    );
  }

  final String type;
  final String? payload;
  final String? errorCode;
  final String? location;
  final Map<String, dynamic>? diagnostics;
}
