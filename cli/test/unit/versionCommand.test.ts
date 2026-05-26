import test from "node:test";
import assert from "node:assert/strict";
import { runVersionCommand } from "../../src/commands/version.js";
import { logger } from "../../src/utils/logger.js";

test("runVersionCommand prints version string", () => {
  const calls: string[] = [];
  const originalPlain = logger.plain;
  logger.plain = (message: string) => calls.push(message);

  try {
    runVersionCommand("1.2.3");
  } finally {
    logger.plain = originalPlain;
  }

  assert.deepEqual(calls, ["1.2.3"]);
});
