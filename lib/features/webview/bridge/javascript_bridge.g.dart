// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'javascript_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WebViewController)
const webViewControllerProvider = WebViewControllerProvider._();

final class WebViewControllerProvider
    extends $NotifierProvider<WebViewController, InAppWebViewController?> {
  const WebViewControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'webViewControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$webViewControllerHash();

  @$internal
  @override
  WebViewController create() => WebViewController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InAppWebViewController? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InAppWebViewController?>(value),
    );
  }
}

String _$webViewControllerHash() => r'5fc254eb0cadbff22ff27bf20cf9382d9d0296b1';

abstract class _$WebViewController extends $Notifier<InAppWebViewController?> {
  InAppWebViewController? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<InAppWebViewController?, InAppWebViewController?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<InAppWebViewController?, InAppWebViewController?>,
        InAppWebViewController?,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(BridgeReady)
const bridgeReadyProvider = BridgeReadyProvider._();

final class BridgeReadyProvider extends $NotifierProvider<BridgeReady, bool> {
  const BridgeReadyProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'bridgeReadyProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$bridgeReadyHash();

  @$internal
  @override
  BridgeReady create() => BridgeReady();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$bridgeReadyHash() => r'04a6d5d8db70cbb0f42310d5e824bbb0b154c331';

abstract class _$BridgeReady extends $Notifier<bool> {
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

@ProviderFor(javaScriptBridge)
const javaScriptBridgeProvider = JavaScriptBridgeProvider._();

final class JavaScriptBridgeProvider extends $FunctionalProvider<
    JavaScriptBridgeInterface,
    JavaScriptBridgeInterface,
    JavaScriptBridgeInterface> with $Provider<JavaScriptBridgeInterface> {
  const JavaScriptBridgeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'javaScriptBridgeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$javaScriptBridgeHash();

  @$internal
  @override
  $ProviderElement<JavaScriptBridgeInterface> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JavaScriptBridgeInterface create(Ref ref) {
    return javaScriptBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JavaScriptBridgeInterface value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JavaScriptBridgeInterface>(value),
    );
  }
}

String _$javaScriptBridgeHash() => r'4a4c0b20d3dd612c882c33572ce4503440b0c7f4';
