import test from "node:test";
import assert from "node:assert/strict";
import fs from "fs-extra";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";
import { loadTemplateConfig } from "../../src/scaffold/utils/templateLoader.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

test("template variants match snapshot", async () => {
  const snapshotPath = path.join(
    __dirname,
    "..",
    "fixtures",
    "template-variants.snapshot.json"
  );
  const snapshot: Record<string, string[]> = await fs.readJson(
    snapshotPath
  );
  const config = loadTemplateConfig();

  const actual: Record<string, string[]> = {};
  config.templates.forEach((template) => {
    actual[template.id] = template.variants.map((variant) => variant.id);
  });

  assert.deepEqual(actual, snapshot);
});
