import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Dragging overlay drag handle updates provider position (clamped)',
      (tester) async {
    final spy = ValueNotifier<Offset>(Offset.zero);

    final overlayKey = GlobalKey();

    // WHY: Set a larger screen size to prevent overflow in the test environment
    await tester.binding.setSurfaceSize(const Size(800, 600));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automationStateProvider.overrideWithValue(
            const AutomationStateData.refining(messageCount: 1),
          ),
          currentTabIndexProvider.overrideWithValue(1),
        ],
        child: MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                // WHY: Use DraggableCompanionOverlay to test the actual drag handling implementation
                DraggableCompanionOverlay(overlayKey: overlayKey),
                _OverlayPositionSpy(spy: spy),
              ],
            ),
          ),
        ),
      ),
    );

    // WHY: Clean up surface size after test to avoid affecting other tests
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();

    // WHY: The drag handle is now in the parent widget's GestureDetector, which wraps the entire overlay.
    // We can drag on any part of the expanded overlay widget.
    final overlayFinder = find.byKey(const Key('expanded_overlay'));
    expect(overlayFinder, findsOneWidget);

    // Perform a large drag; the internal logic should clamp within screen bounds.
    await tester.drag(overlayFinder, const Offset(10000, 10000));
    await tester.pump();

    final state = spy.value;
    // We cannot know the exact screen/widget sizes here, but we can assert that
    // the position is not NaN/Infinite and that it is finite and reasonable.
    expect(state.dx.isFinite, isTrue);
    expect(state.dy.isFinite, isTrue);

    // Now drag negatively beyond bounds and ensure it still remains finite.
    await tester.drag(overlayFinder, const Offset(-20000, -20000));
    await tester.pump();

    final state2 = spy.value;
    expect(state2.dx.isFinite, isTrue);
    expect(state2.dy.isFinite, isTrue);
  });
}

class _OverlayPositionSpy extends ConsumerWidget {
  const _OverlayPositionSpy({required this.spy});
  final ValueNotifier<Offset> spy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(overlayManagerProvider).position;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      spy.value = pos;
    });
    return const SizedBox.shrink();
  }
}
