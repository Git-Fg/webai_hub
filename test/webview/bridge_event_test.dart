import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BridgeEvent.fromJson parses fields safely', () {
    final event = BridgeEvent.fromJson({
      'type': 'AUTOMATION_FAILED',
      'payload': 'Something went wrong',
      'errorCode': 'E123',
      'location': 'automation_engine.ts:42',
      'diagnostics': {
        'ready': true,
        'timestamp': 123456,
      },
    });

    expect(event.type, 'AUTOMATION_FAILED');
    expect(event.payload, 'Something went wrong');
    expect(event.errorCode, 'E123');
    expect(event.location, 'automation_engine.ts:42');
    expect(event.diagnostics, isNotNull);
    expect(event.diagnostics!['ready'], true);
  });
}
