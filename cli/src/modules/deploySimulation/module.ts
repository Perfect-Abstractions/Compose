import fs from "node:fs/promises";
import type { ComposeContext } from "../../context/types";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import { runCommand } from "../../utils/exec";
import { toPassthroughArgs } from "../../utils/args";
import type { DeployPlan } from "../deployPlan/types";

/** Runs the managed deployment script on a local fork without broadcasting. */
export const DeploySimulationModule = {
  async simulate(
    ctx: ComposeContext,
    plan: DeployPlan,
    scriptPath: string,
    adapter: IFrameworkAdapter,
    forkBlockNumber: bigint,
    runnerPath: string | null = adapter.getManagedDeployRunnerPath(plan.projectRoot),
  ): Promise<ComposeContext> {
    try {
      const command = adapter.createDeployCommand({
        chainId: plan.chain.chainId,
        chainKey: plan.chain.chainKey,
        passthrough: toPassthroughArgs(ctx.param.passthrough),
        projectRoot: plan.projectRoot,
        rpcUrl: plan.chain.rpcUrl,
        account: plan.account,
        scriptPath,
        runnerPath,
        mode: "simulate",
        forkBlockNumber,
      });
      await runCommand(command.command, command.args, {
        cwd: plan.projectRoot,
        ...(command.env ? { env: command.env } : {}),
      });

      ctx.state.deploySimulation = {
        success: true,
        result: { forkBlockNumber },
        error: null,
      };
      return ctx;
    } catch (error) {
      const message = error instanceof Error ? error.message : "Deployment simulation failed.";
      ctx.state.deploySimulation = {
        success: false,
        result: null,
        error: { code: "DEPLOY_SIMULATION_FAILED", message, nativeError: error },
      };
      throw error;
    } finally {
      if (plan.framework === "hardhat" && runnerPath) {
        try {
          await fs.rm(runnerPath, { force: true });
        } catch {
          // The runner is ignored runtime glue; cleanup must not mask the simulation result.
        }
      }
    }
  },
};
