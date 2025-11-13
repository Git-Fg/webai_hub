// ts_src/utils/bridge-constants.ts

/**
 * Constants for JavaScript bridge handlers and event types.
 * 
 * These constants centralize all magic strings used in the communication
 * between TypeScript and Dart, preventing typos and making
 * the code more maintainable.
 * 
 * IMPORTANT: These values must match exactly with BridgeConstants in Dart.
 */

export const AUTOMATION_HANDLER = 'automationBridge';
export const READY_HANDLER = 'bridgeReady';

export const EVENT_TYPE_NEW_RESPONSE = 'NEW_RESPONSE_DETECTED';
export const EVENT_TYPE_LOGIN_REQUIRED = 'LOGIN_REQUIRED';
export const EVENT_TYPE_AUTOMATION_FAILED = 'AUTOMATION_FAILED';
export const EVENT_TYPE_AUTOMATION_RETRY_REQUIRED = 'AUTOMATION_RETRY_REQUIRED';

