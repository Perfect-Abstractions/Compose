import type { IFrameworkAdapter } from "../adapters/IFrameworkAdapter/interface";
import type { ComposeContext, ModuleState } from "../context/types";
import { AccountModule } from "../modules/accounts/module";
import type { AccountActionResult } from "../modules/accounts/types";
import type { Framework } from "../modules/framework/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { toComposeError } from "../utils/errors";

function requireFramework(
  composeJson: Record<string, unknown>,
  purpose: "checking" | "setting up",
): Framework {
  const framework = composeJson.framework;
  if (framework !== "foundry" && framework !== "hardhat") {
    throw new Error(`compose.json must select the 'foundry' or 'hardhat' framework before ${purpose} accounts.`);
  }
  return framework;
}

async function resolveFrameworkAdapter(framework: Framework): Promise<IFrameworkAdapter> {
  const key = framework === "foundry" ? DependencyKey.Foundry : DependencyKey.Hardhat;
  const dependencies = await DependencyResolver.resolve([{ key }]);
  const adapter = dependencies[key] as IFrameworkAdapter | undefined;
  if (!adapter) throw new Error(`The ${framework} framework adapter was not resolved.`);
  return adapter;
}

/** Account pipeline for setting up, checking, listing, and removing non-secret aliases. */
export const AccountPipeline = {
  /**
   * Loads the project, resolves the framework adapter when needed, and delegates
   * the requested action to the accounts module.
   *
   * Failures are recorded in `state.account` and `status` so the entrypoint can
   * exit non-zero without turning expected validation errors into crashes.
   *
   * @param ctx - The compose context with command parameters.
   * @returns The context after the account action completes.
   */
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    try {
      const project = await AccountModule.loadProject(ctx);
      const action = String(ctx.param.action ?? "");

      if (action !== "check" && action !== "setup") {
        return await AccountModule.execute(ctx, project);
      }

      const framework = requireFramework(
        project.composeJson,
        action === "check" ? "checking" : "setting up",
      );
      const adapter = await resolveFrameworkAdapter(framework);
      return await AccountModule.execute(ctx, project, { framework, adapter });
    } catch (error) {
      const resolved = toComposeError(error, "ACCOUNT_FAILED", "Account command failed.");
      const state: ModuleState<AccountActionResult> = {
        success: false,
        result: null,
        error: resolved,
      };
      ctx.state.account = state;
      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "account",
        error: resolved,
      };
      console.error(resolved.message);
      return ctx;
    }
  },
};
