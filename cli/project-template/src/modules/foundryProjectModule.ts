import path from "node:path";
import { ComposeContext } from "../context/types";
import { pathExists } from "../utils/files";

// =====================
// Modules
// =====================

export const FoundryProjectModule = {
  // Resolve whether init should write into the current Foundry project or a new folder.
  async resolveProjectRoot(ctx: ComposeContext): Promise<ComposeContext> {
    const projectName = String(ctx.param.projectName ?? "my-diamond");
    const outDir = String(ctx.param.outDir ?? process.cwd());
    const currentFoundryToml = path.resolve(process.cwd(), "foundry.toml");
    const projectRoot = (await pathExists(currentFoundryToml))
      ? process.cwd()
      : path.resolve(outDir, projectName);

    ctx.param.projectRoot = projectRoot;
    ctx.state.foundryProject = {
      success: true,
      result: {
        projectName,
        outDir,
        projectRoot,
        usedCurrentDirectory: projectRoot === process.cwd(),
      },
      error: null,
    };

    return ctx;
  },
};
