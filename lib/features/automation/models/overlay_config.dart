import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_config.freezed.dart';

@freezed
sealed class OverlayConfig with _$OverlayConfig {
  const factory OverlayConfig({
    required Widget content,
    @Default(true) bool isDraggable,
    @Default(true) bool showHeader,
  }) = _OverlayConfig;
}
