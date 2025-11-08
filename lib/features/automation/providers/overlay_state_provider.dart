import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_state_provider.freezed.dart';
part 'overlay_state_provider.g.dart';

@freezed
abstract class OverlayState with _$OverlayState {
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

  void updatePosition(Offset delta) {
    state = state.copyWith(position: state.position + delta);
  }

  void toggleMinimized() {
    state = state.copyWith(isMinimized: !state.isMinimized);
  }

  // WHY: Resetting is now extremely simple. Just go back to a zero offset.
  void resetPosition() {
    state = state.copyWith(position: Offset.zero);
  }
}
