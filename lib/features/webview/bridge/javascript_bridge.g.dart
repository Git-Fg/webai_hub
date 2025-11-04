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
          isAutoDispose: false,
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

String _$webViewControllerHash() => r'78c66bf788fdb621012dfe541dbe395d9669e919';

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
          isAutoDispose: false,
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

String _$bridgeReadyHash() => r'97fb2cf8f0e3847b7da807973058f4ef81ec89f8';

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

@ProviderFor(CurrentWebViewUrl)
const currentWebViewUrlProvider = CurrentWebViewUrlProvider._();

final class CurrentWebViewUrlProvider
    extends $NotifierProvider<CurrentWebViewUrl, String> {
  const CurrentWebViewUrlProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentWebViewUrlProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentWebViewUrlHash();

  @$internal
  @override
  CurrentWebViewUrl create() => CurrentWebViewUrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$currentWebViewUrlHash() => r'dc925192d49cb48956a00205d5c16941dbcbb2cf';

abstract class _$CurrentWebViewUrl extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String, String>, String, Object?, Object?>;
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
