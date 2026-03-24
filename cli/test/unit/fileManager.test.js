const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const os = require("node:os");
const fs = require("fs-extra");
const {
  assertTargetDoesNotExist,
  appendLineIfMissing,
  assertDirectoryEmpty,
  getProjectDisplayName,
  getTemplateDisplayName,
} = require("../../src/scaffold/utils/fileManager");

test("assertTargetDoesNotExist throws when path already exists", async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-fm-"));
  await assert.rejects(() => assertTargetDoesNotExist(tempDir), /Target directory already exists/);
});

test("appendLineIfMissing creates file and avoids duplicate lines", async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-fm-"));
  const filePath = path.join(tempDir, ".gitignore");

  await appendLineIfMissing(filePath, "node_modules");
  await appendLineIfMissing(filePath, "node_modules");
  await appendLineIfMissing(filePath, "dist");

  const content = await fs.readFile(filePath, "utf8");
  assert.equal(content, "node_modules\ndist\n");
});

test("getTemplateDisplayName returns relative template path when inside templates root", () => {
  const templatePath = path.join(process.cwd(), "src", "templates", "default", "foundry");
  assert.equal(getTemplateDisplayName(templatePath), "default/foundry");
});

test("getTemplateDisplayName falls back to basename for external paths", () => {
  const templatePath = path.join(os.tmpdir(), "custom-template");
  assert.equal(getTemplateDisplayName(templatePath), "custom-template");
});

test("assertDirectoryEmpty allows only .git in directory", async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-fm-empty-"));

  // Empty directory is allowed
  await assert.doesNotReject(() => assertDirectoryEmpty(tempDir));

  // Directory with only .git is allowed
  const gitDir = path.join(tempDir, ".git");
  await fs.mkdir(gitDir);
  await assert.doesNotReject(() => assertDirectoryEmpty(tempDir));

  // Any additional entry should cause a failure
  const readmePath = path.join(tempDir, "README.md");
  await fs.writeFile(readmePath, "# demo\n");
  await assert.rejects(
    () => assertDirectoryEmpty(tempDir),
    /Target directory is not empty/
  );
});

test("getProjectDisplayName uses folder name for dot project", () => {
  const projectDir = path.join(os.tmpdir(), "compose-cli-project-dir");
  const name = getProjectDisplayName(".", projectDir);
  assert.equal(name, path.basename(projectDir));
});

test("getProjectDisplayName returns projectName for non-dot project", () => {
  const projectDir = path.join(os.tmpdir(), "compose-cli-project-dir");
  const name = getProjectDisplayName("my-app", projectDir);
  assert.equal(name, "my-app");
});
