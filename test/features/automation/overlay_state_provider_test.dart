import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlayManager.updateClampedPosition', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('within-bounds delta adjusts position exactly', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      // Start from default Offset(0, 150)
      const screenSize = Size(400, 800);
      const widgetSize = Size(100, 100);

      notifier.updateClampedPosition(
        const Offset(10, 20),
        screenSize,
        widgetSize,
      );

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, 10);
      expect(state.position.dy, 170);
    });

    test('exceeding top/left clamps to negative bounds', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      const screenSize = Size(400, 800);
      const widgetSize = Size(100, 100);

      // Huge negative drag
      notifier.updateClampedPosition(
        const Offset(-10000, -10000),
        screenSize,
        widgetSize,
      );

      final state = container.read(overlayManagerProvider);
      // Bounds: width: (400/2 - 100/2) = 150, height: (800/2 - 100/2) = 350
      expect(state.position.dx, -150);
      expect(state.position.dy, -350);
    });

    test('exceeding bottom/right clamps to positive bounds', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      const screenSize = Size(400, 800);
      const widgetSize = Size(100, 100);

      // Move positively beyond bounds
      notifier.updateClampedPosition(
        const Offset(10000, 10000),
        screenSize,
        widgetSize,
      );

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, 150);
      expect(state.position.dy, 350);
    });

    test('zero-sized screen and widget clamps to (0, 0) without throwing', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      const screenSize = Size.zero;
      const widgetSize = Size.zero;

      // Any delta should clamp to 0 bounds
      notifier.updateClampedPosition(
        const Offset(5, 5),
        screenSize,
        widgetSize,
      );

      final state = container.read(overlayManagerProvider);
      expect(state.position, Offset.zero);
    });
  });
}
