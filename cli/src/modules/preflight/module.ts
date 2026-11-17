import { ComposeContext } from "../../context/types";
import { isBinaryInPath } from "../../utils/exec";
import { assertHardhatNodeVersion } from "../../utils/nodeVersion";

/**
 * Pre-flight checks that verify required toolchain binaries are available.
 *
 * Before scaffolding begins, this module ensures the user's system has the
 * necessary binaries in `PATH` for the selected framework.
 */
export const PreflightModule = {
  /**
   * Verifies the toolchain requirements for the selected framework.
   *
   * - Foundry: checks for `forge`, plus `npm` when project dependencies
   *   (including the local Compose CLI) will be installed.
   * - Hardhat: requires Node.js 22.13+, npm, git (the official template includes
   *   forge-std), and dependency installation because its non-interactive
   *   initializer installs the selected template.
   *
   * Throws an error with an install suggestion if a requirement is not met.
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
      assertHardhatNodeVersion();
      if (!shouldInstallDeps) {
        throw new Error(
          "Hardhat's official non-interactive initializer installs the selected template dependencies. "
          + "Use --install-deps for Hardhat projects.",
        );
      }
      await isBinaryInPath("npm");
      await isBinaryInPath("git");
    }

    return ctx;
  },
};
