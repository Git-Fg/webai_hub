// lib/features/hub/providers/staged_responses_provider.dart

import 'package:ai_hybrid_hub/features/hub/models/staged_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'staged_responses_provider.g.dart';

@riverpod
class StagedResponses extends _$StagedResponses {
  @override
  Map<int, StagedResponse> build() => {};

  void addOrUpdate(StagedResponse response) {
    state = {...state, response.presetId: response};
  }

  void clear() {
    state = {};
  }
}
