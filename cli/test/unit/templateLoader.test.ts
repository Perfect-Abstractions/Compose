import test from "node:test";
import assert from "node:assert/strict";
import {
  loadTemplateConfig,
  pickVariant,
  resolveTemplatePath,
} from "../../src/scaffold/utils/templateLoader.js";

test("pickVariant returns foundry variant", async () => {
  const config = await loadTemplateConfig();
  const variant = pickVariant(config, {
    template: "default",
    framework: "foundry",
  });

  assert.equal(variant.id, "default-foundry");
});

test("pickVariant returns hardhat minimal variant", async () => {
  const config = await loadTemplateConfig();
  const variant = pickVariant(config, {
    template: "default",
    framework: "hardhat",
    language: "typescript",
    projectType: "minimal",
  });

  assert.equal(variant.id, "default-hardhat-minimal");
});

test("pickVariant throws for unknown template", async () => {
  const config = await loadTemplateConfig();
  assert.throws(
    () =>
      pickVariant(config, {
        template: "does-not-exist",
        framework: "foundry",
      }),
    /Template not found/
  );
});

test("pickVariant throws when no variant matches", async () => {
  const config = await loadTemplateConfig();
  assert.throws(
    () =>
      pickVariant(config, {
        template: "default",
        framework: "hardhat",
        language: "javascript",
      }),
    /No template variant/
  );
});

test("resolveTemplatePath returns an absolute path in src", () => {
  const resolved = resolveTemplatePath({
    id: "test",
    framework: "foundry",
    path: "templates/default/foundry",
  });
  assert.equal(resolved.includes("/src/templates/default/foundry"), true);
});
