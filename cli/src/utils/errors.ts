import type { ComposeError } from "../context/types";

/**
 * Normalizes an unknown thrown value into a ComposeError, keeping any error
 * code exposed by the original value.
 * @param error
 * @param fallbackCode Code used when the error does not expose one
 * @param fallbackMessage Message used when the error is not an Error instance
 * @returns Normalized compose error
 */
function toComposeError(
  error: unknown,
  fallbackCode: string,
  fallbackMessage = "Operation failed.",
): ComposeError {
  return {
    code: typeof error === "object" && error !== null && "code" in error
      ? String(error.code)
      : fallbackCode,
    message: error instanceof Error ? error.message : fallbackMessage,
    nativeError: error,
  };
}

/**
 * Error normalizer
 * @param error 
 * @returns Normalized error
 */
function normalizeError(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }
  return new Error(String(error));
}

/**
 * Exit Process with Normalized Error
 * @param error 
 */
function exitWithError(error: unknown): void {
  const normalized = normalizeError(error);
  console.error(normalized.message);

  if (process.env.DEBUG === "1" && normalized.stack) {
    console.log(normalized.stack);
  }

  process.exitCode = 1;
}

export { normalizeError, exitWithError, toComposeError };