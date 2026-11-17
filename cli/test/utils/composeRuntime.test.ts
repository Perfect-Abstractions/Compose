import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  composeRuntimeDir,
  ensureComposeDirIgnored,
  ensureComposeRuntimeDir,
} from "../../src/utils/composeRuntime";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-runtime-"));
});

afterEach(async () => {
  await fs.rm(projectRoot, { recursive: true, force: true });
});

describe("composeRuntimeDir", () => {
  it("scopes the runtime directory by framework", () => {
    expect(composeRuntimeDir(projectRoot, "hardhat"))
      .toBe(path.join(projectRoot, ".compose", "hardhat"));
    expect(composeRuntimeDir(projectRoot, "foundry"))
      .toBe(path.join(projectRoot, ".compose", "foundry"));
  });
});

describe("ensureComposeDirIgnored", () => {
  it("creates a .gitignore when the project has none", async () => {
    await ensureComposeDirIgnored(projectRoot);

    await expect(fs.readFile(path.join(projectRoot, ".gitignore"), "utf8"))
      .resolves.toBe(".compose/\n");
  });

  it("appends the rule without dropping existing entries", async () => {
    await fs.writeFile(path.join(projectRoot, ".gitignore"), "node_modules/\n", "utf8");

    await ensureComposeDirIgnored(projectRoot);

    await expect(fs.readFile(path.join(projectRoot, ".gitignore"), "utf8"))
      .resolves.toBe("node_modules/\n.compose/\n");
  });

  it("leaves an already ignored project untouched", async () => {
    const gitignorePath = path.join(projectRoot, ".gitignore");
    await fs.writeFile(gitignorePath, "node_modules/\n.compose/\n", "utf8");
    const before = await fs.stat(gitignorePath);

    await ensureComposeDirIgnored(projectRoot);

    const after = await fs.stat(gitignorePath);
    expect(after.mtimeMs).toBe(before.mtimeMs);
    await expect(fs.readFile(gitignorePath, "utf8"))
      .resolves.toBe("node_modules/\n.compose/\n");
  });

  it("surfaces read errors other than a missing file", async () => {
    await fs.mkdir(path.join(projectRoot, ".gitignore"));

    await expect(ensureComposeDirIgnored(projectRoot)).rejects.toThrow();
  });
});

describe("ensureComposeRuntimeDir", () => {
  it("creates the ignored runtime directory", async () => {
    const runtimeDir = await ensureComposeRuntimeDir(projectRoot, "hardhat");

    expect(runtimeDir).toBe(path.join(projectRoot, ".compose", "hardhat"));
    await expect(fs.stat(runtimeDir)).resolves.toMatchObject({ mode: expect.any(Number) });
    await expect(fs.readFile(path.join(projectRoot, ".gitignore"), "utf8"))
      .resolves.toBe(".compose/\n");
  });
});
