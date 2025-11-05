import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scroll_request_provider.g.dart';

// WHY: A simple counter provider used to signal a scroll request. The HubScreen
// listens to this provider, and when the state changes, it triggers a scroll.
// This decouples the business logic (in ConversationProvider) from the UI logic
// (the ScrollController in HubScreen). It is autoDispose because the request
// is a transient, one-time event.
@riverpod
class ScrollToBottomRequest extends _$ScrollToBottomRequest {
  @override
  int build() => 0;

  void requestScroll() {
    state++;
  }
}
