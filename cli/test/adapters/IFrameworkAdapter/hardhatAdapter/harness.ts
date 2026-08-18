import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ComposeContext } from "../../../../src/context/types";
import { Context } from "../../../../src/context/context";
import { runCommand } from "../../../../src/utils/exec";

export type HardhatAdapterFixtureHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  cleanup(): Promise<void>;
};

const projectTemplateRoot = path.join(__dirname, "project");
const normalFixturePath = path.join(__dirname, "..", "fixtures", "normal", "Normal.sol");

/** Installs the fixture's locked local Hardhat dependency when needed. */
export async function ensureHardhatFixtureDependencies(): Promise<void> {
  try {
    await fs.access(path.join(projectTemplateRoot, "node_modules", "hardhat", "package.json"));
  } catch {
    await runCommand("npm", ["ci"], { cwd: projectTemplateRoot });
  }
}

/** Creates an isolated Hardhat project from the shared Solidity fixture. */
export async function createHardhatAdapterFixtureHarness(): Promise<HardhatAdapterFixtureHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-adapter-"));
  const ctx = Context.create();

  await fs.cp(projectTemplateRoot, projectRoot, {
    recursive: true,
    filter: (source) =>
      !["artifacts", "cache", "node_modules"].includes(path.basename(source)),
  });
  await fs.mkdir(path.join(projectRoot, "contracts"), { recursive: true });
  await fs.copyFile(normalFixturePath, path.join(projectRoot, "contracts", "Normal.sol"));
  await fs.symlink(
    path.join(projectTemplateRoot, "node_modules"),
    path.join(projectRoot, "node_modules"),
    process.platform === "win32" ? "junction" : "dir",
  );
  ctx.param.projectRoot = projectRoot;

  return {
    ctx,
    projectRoot,
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
