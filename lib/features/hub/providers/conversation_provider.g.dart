// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

String _$conversationHash() => r'4fd9b42c7937cb29d617e2c36a3bf3b061c25087';

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
