// ts_src/utils/notify-dart.ts

import { 
  AUTOMATION_HANDLER,
  EVENT_TYPE_AUTOMATION_FAILED,
  EVENT_TYPE_AUTOMATION_RETRY_REQUIRED,
  EVENT_TYPE_LOGIN_REQUIRED,
  EVENT_TYPE_NEW_RESPONSE
} from './bridge-constants';

interface FlutterInAppWebView {
  callHandler(handlerName: string, ...args: unknown[]): Promise<unknown>;
}

interface WindowWithFlutterInAppWebView extends Window {
  flutter_inappwebview?: FlutterInAppWebView;
}

export function notifyDart(event: { 
  type: typeof EVENT_TYPE_AUTOMATION_FAILED | typeof EVENT_TYPE_AUTOMATION_RETRY_REQUIRED | typeof EVENT_TYPE_LOGIN_REQUIRED | typeof EVENT_TYPE_NEW_RESPONSE, 
  payload?: string,
  errorCode?: string,
  location?: string,
  diagnostics?: Record<string, unknown>
}) {
  const windowWithFlutter = window as WindowWithFlutterInAppWebView;
  if (windowWithFlutter.flutter_inappwebview) {
    windowWithFlutter.flutter_inappwebview.callHandler(AUTOMATION_HANDLER, event);
  }
}

