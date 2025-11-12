// lib/features/hub/providers/selected_staged_responses_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_staged_responses_provider.g.dart';

// WHY: This provider tracks which staged responses are selected for synthesis,
// enabling users to choose multiple responses to combine into a superior answer.
@riverpod
class SelectedStagedResponses extends _$SelectedStagedResponses {
  @override
  Set<int> build() => {};

  void toggle(int presetId) {
    if (state.contains(presetId)) {
      state = {...state}..remove(presetId);
    } else {
      state = {...state, presetId};
    }
  }

  void clear() {
    state = {};
  }
}


