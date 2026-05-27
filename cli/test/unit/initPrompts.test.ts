import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import os from "node:os";
import fs from "fs-extra";
import { assertDirectoryEmpty } from "../../src/scaffold/utils/fileManager.js";
import { validateProjectLocation } from "../../src/utils/prompts/initUtils.js";

test("validateProjectLocation returns true for non-dot names", async () => {
  const result = await validateProjectLocation("my-app");
  assert.equal(result, true);
});

test("validateProjectLocation accepts dot in logically empty directory", async () => {
  const tempDir = await fs.mkdtemp(
    path.join(os.tmpdir(), "compose-cli-init-")
  );
  const originalCwd = process.cwd();
  process.chdir(tempDir);

  try {
    await assertDirectoryEmpty(process.cwd());

    const result = await validateProjectLocation(".");
    assert.equal(result, true);
  } finally {
    process.chdir(originalCwd);
  }
});

test("validateProjectLocation rejects dot in non-empty directory", async () => {
  const tempDir = await fs.mkdtemp(
    path.join(os.tmpdir(), "compose-cli-init-")
  );
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
