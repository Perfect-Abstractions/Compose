const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const os = require("node:os");
const fs = require("fs-extra");

const { assertDirectoryEmpty } = require("../../src/scaffold/utils/fileManager");
const { validateProjectLocation } = require("../../src/utils/prompts/initUtils");

test("validateProjectLocation returns true for non-dot names", async () => {
  const result = await validateProjectLocation("my-app");
  assert.equal(result, true);
});

test("validateProjectLocation accepts dot in logically empty directory", async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-init-"));
  const originalCwd = process.cwd();
  process.chdir(tempDir);

  try {
    // Ensure our invariant helper agrees this directory is acceptable
    await assertDirectoryEmpty(process.cwd());

    const result = await validateProjectLocation(".");
    assert.equal(result, true);
  } finally {
    process.chdir(originalCwd);
  }
});

test("validateProjectLocation rejects dot in non-empty directory", async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-init-"));
  const originalCwd = process.cwd();
  process.chdir(tempDir);

  try {
    const readmePath = path.join(tempDir, "README.md");
    await fs.writeFile(readmePath, "# demo\n");

    const result = await validateProjectLocation(".");
    assert.equal(
      result,
      'Current directory must be empty (or only .git) when using ".".'
    );
  } finally {
    process.chdir(originalCwd);
  }
});

