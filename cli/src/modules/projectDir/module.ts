import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import { pathExists, isDirectoryEmpty } from "../../utils/files";

/**
 * Resolves and validates the target project directory.
 *
 * Determines the output path from `outDir` and `projectName`, then ensures
 * the directory is either empty or non-existent before scaffolding begins.
 */
export const ProjectDirModule = {
  /**
   * Resolves the project root directory path.
   *
   * The root is resolved as `outDir/projectName` (defaulting to cwd and
   * `my-diamond` respectively).
   *
   * @param ctx - The compose context with `param.projectName` and `param.outDir`.
   * @returns The context with `param.projectRoot` set.
   */
  async resolve(ctx: ComposeContext): Promise<ComposeContext> {
    const projectName = String(ctx.param.projectName ?? "my-diamond");
    const outDir = String(ctx.param.outDir ?? process.cwd());
    ctx.param.projectRoot = path.resolve(outDir, projectName);

    return ctx;
  },

  /**
   * Validates that the resolved project root is empty or does not exist.
   *
   * If the directory does not exist it is created with `recursive: true`.
   * If it exists but contains non-`.git` entries, an error is thrown.
   *
   * @param ctx - The compose context with `param.projectRoot` already resolved.
   * @returns The context unchanged (validation is pass/fail via throw).
   */
  async validate(ctx: ComposeContext): Promise<ComposeContext> {
    const projectRoot = String(ctx.param.projectRoot ?? "");

    if (!projectRoot) {
      throw new Error("Project root is not defined.");
    }

    const exists = await pathExists(projectRoot);
    if (exists) {
      const isEmpty = await isDirectoryEmpty(projectRoot, [".git"]);
      if (!isEmpty) {
        throw new Error(`Target directory is not empty: ${projectRoot}`);
      }
    } else {
      await fs.mkdir(projectRoot, { recursive: true });
    }

    return ctx;
  },
};