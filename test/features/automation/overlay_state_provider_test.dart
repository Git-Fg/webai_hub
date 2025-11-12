import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlayManager.updatePosition', () {
    late ProviderContainer container;
    const screenSize = Size(800, 600);
    const widgetSize = Size(200, 100);

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('delta adjusts position exactly', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      // Start from default Offset.zero
      notifier.updatePosition(const Offset(10, 20), screenSize, widgetSize);

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, 10);
      expect(state.position.dy, 20);
    });

    test('multiple updates accumulate position', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      notifier.updatePosition(const Offset(10, 20), screenSize, widgetSize);
      notifier.updatePosition(const Offset(5, -10), screenSize, widgetSize);

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, 15);
      expect(state.position.dy, 10);
    });

    test('negative delta adjusts position correctly', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      notifier.updatePosition(const Offset(-100, -200), screenSize, widgetSize);

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, -100);
      // WHY: Position is clamped to screen bounds. With screenSize 800x600, widgetSize 200x100,
      // and kToolbarHeight 56, maxY = (600 - 100) / 2 - 56 = 194, so -200 is clamped to -194.
      expect(state.position.dy, -194.0);
    });

    test('zero delta does not change position', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      notifier.updatePosition(Offset.zero, screenSize, widgetSize);

      final state = container.read(overlayManagerProvider);
      expect(state.position, Offset.zero);
    });
  });
}
