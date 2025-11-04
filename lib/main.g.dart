// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentTabIndex)
const currentTabIndexProvider = CurrentTabIndexProvider._();

final class CurrentTabIndexProvider
    extends $NotifierProvider<CurrentTabIndex, int> {
  const CurrentTabIndexProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentTabIndexProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentTabIndexHash();

  @$internal
  @override
  CurrentTabIndex create() => CurrentTabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$currentTabIndexHash() => r'9dc0c6ca8da906a155b2338ea38ecd1796e99174';

abstract class _$CurrentTabIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element = ref.element
        as $ClassProviderElement<AnyNotifier<int, int>, int, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
