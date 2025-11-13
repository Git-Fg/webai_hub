import 'dart:async';

import 'package:ai_hybrid_hub/features/webview/bridge/bridge_event.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bridge_events_provider.g.dart';

// This provider holds the StreamController
@Riverpod(keepAlive: true)
class BridgeEventController extends _$BridgeEventController {
  @override
  StreamController<BridgeEvent> build(int presetId) {
    final controller = StreamController<BridgeEvent>.broadcast();
    ref.onDispose(controller.close);
    return controller;
  }
}

// This provider exposes the stream
@riverpod
Stream<BridgeEvent> bridgeEvents(Ref ref, int presetId) {
  return ref.watch(bridgeEventControllerProvider(presetId)).stream;
}
