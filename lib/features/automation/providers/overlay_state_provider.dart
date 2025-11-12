import 'package:ai_hybrid_hub/shared/ui_constants.dart' as ui_constants;
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_state_provider.freezed.dart';
part 'overlay_state_provider.g.dart';

@freezed
sealed class OverlayState with _$OverlayState {
  const factory OverlayState({
    // WHY: The position is now a delta from the center. (0,0) means "centered".
    @Default(Offset.zero) Offset position,
    @Default(false) bool isMinimized,
  }) = _OverlayState;
}

// WHY: keepAlive is true because the overlay's position and state must be
// remembered even when the user switches back to the Hub tab.
@Riverpod(keepAlive: true)
class OverlayManager extends _$OverlayManager {
  @override
  OverlayState build() {
    return const OverlayState();
  }

  void updatePosition(Offset delta, Size screenSize, Size widgetSize) {
    final currentPosition = state.position;
    final newPosition = currentPosition + delta;

    // WHY: Clamp the position to keep the overlay within the screen bounds.
    // This prevents the user from dragging it off-screen and losing it.
    // We calculate the maximum allowable X and Y offsets.
    final maxX = (screenSize.width - widgetSize.width) / 2;
    final maxY =
        (screenSize.height - widgetSize.height) / 2 -
        ui_constants.kToolbarHeight; // Account for AppBar

    final clampedX = newPosition.dx.clamp(-maxX, maxX);
    final clampedY = newPosition.dy.clamp(-maxY, maxY);

    state = state.copyWith(position: Offset(clampedX, clampedY));
  }

  void toggleMinimized() {
    state = state.copyWith(isMinimized: !state.isMinimized);
  }

  // WHY: Resetting is now extremely simple. Just go back to a zero offset.
  void resetPosition() {
    state = state.copyWith(position: Offset.zero);
  }
}
