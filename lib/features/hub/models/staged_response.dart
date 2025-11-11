// lib/features/hub/models/staged_response.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'staged_response.freezed.dart';

@freezed
sealed class StagedResponse with _$StagedResponse {
  const factory StagedResponse({
    required int presetId,
    required String presetName,
    required String text,
    @Default(false) bool isLoading,
  }) = _StagedResponse;
}
