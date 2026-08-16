import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ComposeContext } from "../../../../src/context/types";
import { Context } from "../../../../src/context/context";

export type FoundryAdapterFixtureHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  cleanup(): Promise<void>;
};

/** Creates an isolated Foundry project from the shared Solidity fixture. */
export async function createFoundryAdapterFixtureHarness(): Promise<FoundryAdapterFixtureHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-foundry-adapter-"));
  const projectTemplateRoot = path.join(__dirname, "project");
  const normalFixturePath = path.join(__dirname, "..", "fixtures", "normal", "Normal.sol");
  const ctx = Context.create();

  await fs.cp(projectTemplateRoot, projectRoot, {
    recursive: true,
    filter: (source) => !["cache", "node_modules"].includes(path.basename(source)),
  });
  await fs.mkdir(path.join(projectRoot, "src"), { recursive: true });
  await fs.copyFile(normalFixturePath, path.join(projectRoot, "src", "Normal.sol"));
  ctx.param.projectRoot = projectRoot;

  return {
    ctx,
    projectRoot,
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
