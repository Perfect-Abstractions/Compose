import { ComposeContext } from "../../context/types";
import { isBinaryInPath } from "../../utils/exec";

/**
 * Pre-flight checks that verify required toolchain binaries are available.
 *
 * Before scaffolding begins, this module ensures the user's system has the
 * necessary binaries in `PATH` for the selected framework.
 */
export const PreflightModule = {
  /**
   * Verifies that the required binaries for the selected framework exist in PATH.
   *
   * - Foundry: checks for `forge`, plus `npm` when project dependencies
   *   (including the local Compose CLI) will be installed.
   * - Hardhat with `installDeps !== false`: checks for `npm`.
   *
   * Throws an error with an install suggestion if a binary is not found.
   *
   * @param ctx - The compose context with `param.framework` and `param.installDeps`.
   * @returns The context unchanged (validation is pass/fail via throw).
   */
  async check(ctx: ComposeContext): Promise<ComposeContext> {
    const framework = String(ctx.param.framework ?? "foundry").toLowerCase();
    const shouldInstallDeps = ctx.param.installDeps !== false;

    if (framework === "foundry") {
      await isBinaryInPath("forge");
      if (shouldInstallDeps) {
        await isBinaryInPath("npm");
      }
    } else if (framework === "hardhat") {
      if (shouldInstallDeps) {
        await isBinaryInPath("npm");
      }
    }

    return ctx;
  },
};