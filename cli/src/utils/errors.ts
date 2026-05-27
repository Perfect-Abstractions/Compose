import { logger } from "./logger.js";

function normalizeError(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }

  return new Error(String(error));
}

export function exitWithError(error: unknown): void {
  const normalized = normalizeError(error);
  logger.error(normalized.message);

  if (process.env.DEBUG === "1" && normalized.stack) {
    logger.plain(normalized.stack);
  }

  process.exitCode = 1;
}
