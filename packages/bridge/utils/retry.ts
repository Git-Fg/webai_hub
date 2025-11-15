/**
 * Retries an async operation with exponential backoff for resilience.
 * @param operation The async function to execute.
 * @param operationName A descriptive name for logging.
 * @param maxRetries The maximum number of retry attempts.
 * @param delayMs The initial delay in milliseconds.
 * @param shouldRetry Optional predicate to determine if an error is retryable. Defaults to retrying all errors.
 * @returns The result of the operation.
 */
export async function retryOperation<T>(
  operation: () => Promise<T>,
  operationName: string,
  maxRetries = 2,
  delayMs = 300,
  shouldRetry: (error: Error) => boolean = () => true,
): Promise<T> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      if (!shouldRetry(lastError) || attempt >= maxRetries) {
        const context = `Retries=${maxRetries}, Attempt=${attempt + 1}`;
        const fullMessage = `${operationName} failed: ${lastError.message}\nContext: ${context}`;
        throw new Error(fullMessage);
      }

      const backoffDelay = delayMs * Math.pow(2, attempt);
      console.log(
        `[Retry] ${operationName} failed, retrying ${attempt + 1}/${maxRetries} after ${backoffDelay}ms. Error: ${lastError.message.split('\n')[0]}`,
      );
      // WHY: Exponential backoff delay for retry mechanism, not a UI wait
      await new Promise(resolve => setTimeout(resolve, backoffDelay));
    }
  }

  throw lastError || new Error(`${operationName} failed after ${maxRetries} retries.`);
}

