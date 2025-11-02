// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_script_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bridgeScript)
const bridgeScriptProvider = BridgeScriptProvider._();

final class BridgeScriptProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  const BridgeScriptProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bridgeScriptProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bridgeScriptHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return bridgeScript(ref);
  }
}

String _$bridgeScriptHash() => r'832d022fa4d378e1d3c379ed073f53a7ab0d76da';
