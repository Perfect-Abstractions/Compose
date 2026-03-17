const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const cliPath = path.join(__dirname, "..", "..", "index.js");

function runCli(args) {
  return spawnSync(process.execPath, [cliPath, ...args], {
    encoding: "utf8",
  });
}

test("compose --version prints version and exits cleanly", () => {
  const result = runCli(["--version"]);
  const packageJson = require("../../package.json");

  assert.equal(result.status, 0);
  assert.equal(result.stdout.trim(), packageJson.version);
});

test("compose --help prints usage text", () => {
  const result = runCli(["--help"]);

  assert.equal(result.status, 0);
  assert.equal(result.stdout.includes("Usage:"), true);
  assert.equal(result.stdout.includes("compose init [options]"), true);
});

test("compose unknown command exits with error", () => {
  const result = runCli(["does-not-exist"]);

  assert.equal(result.status, 1);
  assert.equal(result.stderr.includes("Unknown command"), true);
});
