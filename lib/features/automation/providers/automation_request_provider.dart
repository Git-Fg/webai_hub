// lib/features/automation/providers/automation_request_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automation_request_provider.g.dart';

class AutomationRequest {
  const AutomationRequest({required this.promptWithContext});

  final String promptWithContext;
}

@Riverpod(keepAlive: true)
class AutomationRequestNotifier extends _$AutomationRequestNotifier {
  @override
  Map<int, AutomationRequest> build() => {};

  void addRequests(Map<int, AutomationRequest> requests) {
    state = {...state, ...requests};
  }

  void clearRequest(int presetId) {
    final newState = Map<int, AutomationRequest>.from(state);
    newState.remove(presetId);
    state = newState;
  }
}
