// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PendingPrompt)
const pendingPromptProvider = PendingPromptProvider._();

final class PendingPromptProvider
    extends $NotifierProvider<PendingPrompt, String?> {
  const PendingPromptProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'pendingPromptProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pendingPromptHash();

  @$internal
  @override
  PendingPrompt create() => PendingPrompt();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingPromptHash() => r'7d18fb3842b65e5d916566f3c0c836255b35e54d';

abstract class _$PendingPrompt extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String?, String?>, String?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(Conversation)
const conversationProvider = ConversationProvider._();

final class ConversationProvider
    extends $NotifierProvider<Conversation, List<Message>> {
  const ConversationProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'conversationProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$conversationHash();

  @$internal
  @override
  Conversation create() => Conversation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Message> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Message>>(value),
    );
  }
}

String _$conversationHash() => r'f2cfe93158c2d4701c9eb2554ece0ccd1c9670ac';

abstract class _$Conversation extends $Notifier<List<Message>> {
  List<Message> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Message>, List<Message>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<Message>, List<Message>>,
        List<Message>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
