import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlayManager.updatePosition', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('delta adjusts position exactly', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      // Start from default Offset.zero
      notifier.updatePosition(const Offset(10, 20));

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, 10);
      expect(state.position.dy, 20);
    });

    test('multiple updates accumulate position', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      notifier.updatePosition(const Offset(10, 20));
      notifier.updatePosition(const Offset(5, -10));

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, 15);
      expect(state.position.dy, 10);
    });

    test('negative delta adjusts position correctly', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      notifier.updatePosition(const Offset(-100, -200));

      final state = container.read(overlayManagerProvider);
      expect(state.position.dx, -100);
      expect(state.position.dy, -200);
    });

    test('zero delta does not change position', () {
      final notifier = container.read(overlayManagerProvider.notifier);

      notifier.updatePosition(Offset.zero);

      final state = container.read(overlayManagerProvider);
      expect(state.position, Offset.zero);
    });
  });
}
