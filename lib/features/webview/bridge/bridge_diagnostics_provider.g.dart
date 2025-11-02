// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_diagnostics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BridgeDiagnosticsState)
const bridgeDiagnosticsStateProvider = BridgeDiagnosticsStateProvider._();

final class BridgeDiagnosticsStateProvider
    extends $NotifierProvider<BridgeDiagnosticsState, BridgeDiagnostics> {
  const BridgeDiagnosticsStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bridgeDiagnosticsStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bridgeDiagnosticsStateHash();

  @$internal
  @override
  BridgeDiagnosticsState create() => BridgeDiagnosticsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BridgeDiagnostics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BridgeDiagnostics>(value),
    );
  }
}

String _$bridgeDiagnosticsStateHash() =>
    r'f75679c13d8b8c4b06ac60827b6a1fff7129f0f1';

abstract class _$BridgeDiagnosticsState extends $Notifier<BridgeDiagnostics> {
  BridgeDiagnostics build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<BridgeDiagnostics, BridgeDiagnostics>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<BridgeDiagnostics, BridgeDiagnostics>,
        BridgeDiagnostics,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
