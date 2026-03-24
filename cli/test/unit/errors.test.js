const test = require("node:test");
const assert = require("node:assert/strict");
const { normalizeError, exitWithError } = require("../../src/utils/errors");
const { logger } = require("../../src/utils/logger");

test("normalizeError returns original Error instance", () => {
  const error = new Error("boom");
  assert.equal(normalizeError(error), error);
});

test("normalizeError wraps non-error values", () => {
  const normalized = normalizeError("boom");
  assert.equal(normalized instanceof Error, true);
  assert.equal(normalized.message, "boom");
});

test("exitWithError logs error and sets process.exitCode", () => {
  const calls = [];
  const originalError = logger.error;
  const originalPlain = logger.plain;
  const originalExitCode = process.exitCode;
  let exitCodeAfterCall;

  logger.error = (message) => calls.push(["error", message]);
  logger.plain = (message) => calls.push(["plain", message]);
  delete process.env.DEBUG;
  process.exitCode = 0;

  try {
    exitWithError("failure");
    exitCodeAfterCall = process.exitCode;
  } finally {
    logger.error = originalError;
    logger.plain = originalPlain;
    process.exitCode = originalExitCode;
  }

  assert.deepEqual(calls, [["error", "failure"]]);
  assert.equal(exitCodeAfterCall, 1);
});

test("exitWithError logs stack trace when DEBUG=1", () => {
  const calls = [];
  const originalError = logger.error;
  const originalPlain = logger.plain;
  const originalDebug = process.env.DEBUG;
  const originalExitCode = process.exitCode;
  let exitCodeAfterCall;

  logger.error = (message) => calls.push(["error", message]);
  logger.plain = (message) => calls.push(["plain", message]);
  process.env.DEBUG = "1";
  process.exitCode = 0;

  try {
    exitWithError(new Error("debug-failure"));
    exitCodeAfterCall = process.exitCode;
  } finally {
    logger.error = originalError;
    logger.plain = originalPlain;
    process.env.DEBUG = originalDebug;
    process.exitCode = originalExitCode;
  }

  assert.equal(calls[0][0], "error");
  assert.equal(calls[0][1], "debug-failure");
  assert.equal(calls[1][0], "plain");
  assert.equal(typeof calls[1][1], "string");
  assert.equal(calls[1][1].includes("debug-failure"), true);
  assert.equal(exitCodeAfterCall, 1);
});
