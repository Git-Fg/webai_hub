// ts_src/utils/notify-dart.ts

interface FlutterInAppWebView {
  callHandler(handlerName: string, ...args: unknown[]): void;
}

interface WindowWithFlutterInAppWebView extends Window {
  flutter_inappwebview?: FlutterInAppWebView;
}

export function notifyDart(event: { 
  type: 'GENERATION_COMPLETE' | 'AUTOMATION_FAILED' | 'LOGIN_REQUIRED', 
  payload?: string,
  errorCode?: string,
  location?: string,
  diagnostics?: Record<string, unknown>
}) {
  const windowWithFlutter = window as WindowWithFlutterInAppWebView;
  if (windowWithFlutter.flutter_inappwebview) {
    windowWithFlutter.flutter_inappwebview.callHandler('automationBridge', event);
  }
}

