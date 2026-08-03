import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ComposeContext } from "../../../src/context/types";
import { Context } from "../../../src/context/context";

export type LockFileHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  cleanup(): Promise<void>;
};

/**
 * Creates a test harness for lock file tests.
 *
 * Sets up a temporary directory and a fresh ComposeContext with
 * the project root pointing to the temp directory.
 */
export async function createLockFileHarness(): Promise<LockFileHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-cli-lockfile-"));
  const ctx = Context.create();
  ctx.param.projectRoot = projectRoot;

  return {
    ctx,
    projectRoot,
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
