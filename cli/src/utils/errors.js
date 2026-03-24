const { logger } = require("./logger");

function normalizeError(error) {
  if (error instanceof Error) {
    return error;
  }

  return new Error(String(error));
}

function exitWithError(error) {
  const normalized = normalizeError(error);
  logger.error(normalized.message);

  if (process.env.DEBUG === "1" && normalized.stack) {
    logger.plain(normalized.stack);
  }

  process.exitCode = 1;
}

module.exports = {
  normalizeError,
  exitWithError,
};
