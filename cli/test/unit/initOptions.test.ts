import test from "node:test";
import assert from "node:assert/strict";
import { normalizeInitOptions } from "../../src/commands/init.js";

test("normalizeInitOptions sets defaults", () => {
  const options = normalizeInitOptions({});

  assert.equal(options.template, "");
  assert.equal(options.framework, "");
  assert.equal(options.installDeps, undefined);
});

test("normalizeInitOptions prioritizes explicit flags", () => {
  const options = normalizeInitOptions({
    name: "demo",
    template: "default",
    framework: "hardhat",
    language: "javascript",
    "install-deps": true,
  });

  assert.equal(options.projectName, "demo");
  assert.equal(options.framework, "hardhat");
  assert.equal(options.language, "javascript");
  assert.equal(options.installDeps, true);
});

test("normalizeInitOptions preserves no-install flag", () => {
  const options = normalizeInitOptions({
    "install-deps": false,
  });

  assert.equal(options.installDeps, false);
});
