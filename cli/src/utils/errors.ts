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

export { normalizeError, exitWithError };