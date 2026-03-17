const test = require("node:test");
const assert = require("node:assert/strict");
const { orderPackageJsonWithDepsBeforeDevDeps } = require("../../src/scaffold/utils/packageOrderer");

test("places dependencies before devDependencies", () => {
  const input = {
    name: "demo",
    version: "1.0.0",
    devDependencies: { b: "1.0.0" },
    dependencies: { a: "1.0.0" },
    scripts: { test: "node --test" },
  };

  const ordered = orderPackageJsonWithDepsBeforeDevDeps(input);
  assert.deepEqual(Object.keys(ordered), [
    "name",
    "version",
    "dependencies",
    "devDependencies",
    "scripts",
  ]);
});

test("adds missing dependency blocks when absent", () => {
  const ordered = orderPackageJsonWithDepsBeforeDevDeps({ name: "demo" });

  assert.deepEqual(Object.keys(ordered), ["name", "dependencies", "devDependencies"]);
  assert.deepEqual(ordered.dependencies, {});
  assert.deepEqual(ordered.devDependencies, {});
});
