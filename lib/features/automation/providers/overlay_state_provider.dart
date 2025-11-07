import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_state_provider.freezed.dart';
part 'overlay_state_provider.g.dart';

@freezed
abstract class OverlayState with _$OverlayState {
  const factory OverlayState({
    // WHY: Default position is now in the lower-middle of the screen,
    // which is a more intuitive starting point for a companion overlay.
    @Default(Offset(0, 150)) Offset position,
    @Default(false) bool isMinimized,
  }) = _OverlayState;
}

// (Bridge typedef removed after hard-rename)

// WHY: keepAlive is true because the overlay's position and state must be
// remembered even when the user switches back to the Hub tab.
@Riverpod(keepAlive: true)
class OverlayManager extends _$OverlayManager {
  @override
  OverlayState build() {
    return const OverlayState();
  }

  void updatePosition(Offset delta) {
    state = state.copyWith(position: state.position + delta);
  }

  // WHY: Ensure the overlay stays within screen bounds when dragged.
  // The Stack is center-aligned; offsets are relative to the center. The
  // maximum offset is half the screen minus half the widget size.
  void updateClampedPosition(Offset delta, Size screenSize, Size widgetSize) {
    final newPosition = state.position + delta;

    final horizontalBound = (screenSize.width / 2) - (widgetSize.width / 2);
    final verticalBound = (screenSize.height / 2) - (widgetSize.height / 2);

    final clampedDx = newPosition.dx.clamp(-horizontalBound, horizontalBound);
    final clampedDy = newPosition.dy.clamp(-verticalBound, verticalBound);

    state = state.copyWith(position: Offset(clampedDx, clampedDy));
  }

  void toggleMinimized() {
    state = state.copyWith(isMinimized: !state.isMinimized);
  }

  // WHY: Resets to the initial default state. This provides an escape hatch
  // for the user if they drag the overlay off-screen.
  void resetPosition() {
    state = state.copyWith(position: const Offset(0, 150));
  }
}
