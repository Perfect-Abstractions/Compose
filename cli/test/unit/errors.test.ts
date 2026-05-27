import test from "node:test";
import assert from "node:assert/strict";
import { exitWithError } from "../../src/utils/errors.js";
import { logger } from "../../src/utils/logger.js";

test("exitWithError logs error and sets process.exitCode", () => {
  const calls: [string, string][] = [];
  const originalError = logger.error;
  const originalPlain = logger.plain;
  const originalExitCode = process.exitCode;
  let exitCodeAfterCall: number | undefined;

  logger.error = (message: string) => calls.push(["error", message]);
  logger.plain = (message: string) => calls.push(["plain", message]);
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
  const calls: [string, string][] = [];
  const originalError = logger.error;
  const originalPlain = logger.plain;
  const originalDebug = process.env.DEBUG;
  const originalExitCode = process.exitCode;
  let exitCodeAfterCall: number | undefined;

  logger.error = (message: string) => calls.push(["error", message]);
  logger.plain = (message: string) => calls.push(["plain", message]);
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
  assert.equal((calls[1][1] as string).includes("debug-failure"), true);
  assert.equal(exitCodeAfterCall, 1);
});
