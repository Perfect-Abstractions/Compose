const test = require("node:test");
const assert = require("node:assert/strict");
const templatesConfig = require("../../src/config/templates.json");
const { validateTemplatesConfig } = require("../../src/config/validateTemplatesConfig");

test("validateTemplatesConfig accepts current registry", () => {
  assert.equal(validateTemplatesConfig(templatesConfig), true);
});

test("validateTemplatesConfig rejects missing variants", () => {
  assert.throws(
    () =>
      validateTemplatesConfig({
        templates: [{ id: "default", name: "Default", variants: [] }],
        defaultTemplateId: "default",
      }),
    /variants must be a non-empty array/
  );
});
