// ts_src/utils/assertions.ts

/**
 * Asserts at runtime that an element is not null and is an instance
 * of the expected constructor type (e.g., HTMLButtonElement).
 * @throws An error if the element is null or of the wrong type.
 */
export function assertIsElement<T extends Element>(
  element: Element | null,
  // WHY: Constructor signature requires unknown[] for args - we can't know constructor parameters ahead of time
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  expectedType: new (...args: any[]) => T,
  context: string = 'DOM assertion'
): T {
  if (!element) {
    throw new Error(`[${context}] Assertion failed: Expected ${expectedType.name}, but the element is null.`);
  }
  if (!(element instanceof expectedType)) {
    throw new Error(`[${context}] Assertion failed: Expected ${expectedType.name}, but got ${element.constructor.name}.`);
  }
  return element as T;
}

