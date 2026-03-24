const test = require("node:test");
const assert = require("node:assert/strict");
const { runVersionCommand } = require("../../src/commands/version");
const { logger } = require("../../src/utils/logger");

test("runVersionCommand prints version string", () => {
  const calls = [];
  const originalPlain = logger.plain;
  logger.plain = (message) => calls.push(message);

  try {
    runVersionCommand("1.2.3");
  } finally {
    logger.plain = originalPlain;
  }

  assert.deepEqual(calls, ["1.2.3"]);
});
