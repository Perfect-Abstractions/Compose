import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { createRequire } from "node:module";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);

const cliPath = resolve(__dirname, "..", "..", "bin", "compose.ts");
const pkg = require(resolve(__dirname, "..", "..", "package.json")) as {
  version: string;
};

function runCli(args: string[]) {
  return spawnSync("npx", ["tsx", cliPath, ...args], {
    encoding: "utf8",
  });
}

test("compose --version prints version and exits cleanly", () => {
  const result = runCli(["--version"]);

  assert.equal(result.status, 0);
  assert.equal(result.stdout.trim(), pkg.version);
});

test("compose --help prints usage text", () => {
  const result = runCli(["--help"]);

  assert.equal(result.status, 0);
  assert.equal(result.stdout.includes("Usage:"), true);
  assert.equal(result.stdout.includes("init"), true);
});

test("compose unknown command exits with error", () => {
  const result = runCli(["does-not-exist"]);

  assert.equal(result.status, 1);
  assert.equal(result.stderr.length > 0 || result.stdout.includes("error"), true);
});
