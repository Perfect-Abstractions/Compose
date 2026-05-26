import test from "node:test";
import assert from "node:assert/strict";
import { validateTemplatesConfig } from "../../src/config/validateTemplatesConfig.js";

test("validateTemplatesConfig accepts current registry", () => {
  assert.equal(validateTemplatesConfig({
    templates: [
      {
        id: "default",
        name: "Counter",
        description: "Simple diamond with a counter facet",
        variants: [
          { id: "default-foundry", framework: "foundry", path: "templates/default/foundry" },
        ],
      },
    ],
    defaultTemplateId: "default",
  }), true);
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
