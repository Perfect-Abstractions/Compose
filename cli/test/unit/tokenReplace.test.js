const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const os = require("node:os");
const fs = require("fs-extra");
const { replaceTokensRecursively } = require("../../src/scaffold/utils/tokenReplace");

test("replaceTokensRecursively updates supported text files recursively", async () => {
  const rootDir = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-tr-"));
  const nestedDir = path.join(rootDir, "nested");
  await fs.ensureDir(nestedDir);

  const readmePath = path.join(rootDir, "README.md");
  const jsonPath = path.join(nestedDir, "package.json");
  const pngPath = path.join(rootDir, "image.png");

  await fs.writeFile(readmePath, "Project {{projectName}}");
  await fs.writeFile(jsonPath, '{"name":"{{projectName}}"}');
  await fs.writeFile(pngPath, "binary-{{projectName}}");

  await replaceTokensRecursively(rootDir, { "{{projectName}}": "demo-app" });

  assert.equal(await fs.readFile(readmePath, "utf8"), "Project demo-app");
  assert.equal(await fs.readFile(jsonPath, "utf8"), '{"name":"demo-app"}');
  assert.equal(await fs.readFile(pngPath, "utf8"), "binary-{{projectName}}");
});
