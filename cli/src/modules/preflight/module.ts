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
   * Verifies that the required binary for the selected framework exists in PATH.
   *
   * - Foundry: checks for `forge`.
   * - Hardhat with `installDeps !== false`: checks for `npm`.
   *
   * Throws an error with an install suggestion if the binary is not found.
   *
   * @param ctx - The compose context with `param.framework` and `param.installDeps`.
   * @returns The context unchanged (validation is pass/fail via throw).
   */
  async check(ctx: ComposeContext): Promise<ComposeContext> {
    const framework = String(ctx.param.framework ?? "foundry").toLowerCase();

    if (framework === "foundry") {
      await isBinaryInPath("forge");
    } else if (framework === "hardhat") {
      const shouldInstallDeps = ctx.param.installDeps !== false;
      if (shouldInstallDeps) {
        await isBinaryInPath("npm");
      }
    }

    return ctx;
  },
};