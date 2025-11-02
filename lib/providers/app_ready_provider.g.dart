// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_ready_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppReady)
const appReadyProvider = AppReadyProvider._();

final class AppReadyProvider extends $NotifierProvider<AppReady, bool> {
  const AppReadyProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appReadyProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appReadyHash();

  @$internal
  @override
  AppReady create() => AppReady();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appReadyHash() => r'cac697eecd854e1652fcdfed713ce14810dfd262';

abstract class _$AppReady extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
