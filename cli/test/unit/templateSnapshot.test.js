const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs-extra");
const path = require("node:path");
const { loadTemplateConfig } = require("../../src/scaffold/utils/templateLoader");

test("template variants match snapshot", async () => {
  const snapshotPath = path.join(__dirname, "..", "fixtures", "template-variants.snapshot.json");
  const snapshot = await fs.readJson(snapshotPath);
  const config = await loadTemplateConfig();

  const actual = {};
  config.templates.forEach((template) => {
    actual[template.id] = template.variants.map((variant) => variant.id);
  });

  assert.deepEqual(actual, snapshot);
});
