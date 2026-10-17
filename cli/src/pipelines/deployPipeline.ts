import type { ComposeContext, ModuleState } from "../context/types";
import type { IHashingAdapter } from "../adapters/IHashingAdapter/interface";
import type { IFrameworkAdapter } from "../adapters/IFrameworkAdapter/interface";
import type { IRPCAdapter } from "../adapters/IRPCAdapter/interface";
import type { IDiamondAdapter } from "../adapters/IDiamondAdapter/interface";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { LockFileModule } from "../modules/lockFile/module";
import type { ComposeLock, DiamondDeployment } from "../modules/lockFile/types";
import { VERSION } from "../utils/metadata";
import { toProjectRelativePath } from "../utils/files";
import { isInteractive, loadPrompts } from "../utils/inquirer";
import { dim } from "../utils/terminal";
import { DeployPlanModule } from "../modules/deployPlan/module";
import type { DeployPlan } from "../modules/deployPlan/types";
import { showDeployPlan, showDiffStopped, showInSync } from "../modules/deployPlan/output";
import { DeployScriptModule } from "../modules/deployScript/module";
import type { ManagedScriptModel } from "../modules/deployScript/types";
import { showScriptPath, showScriptPreview, showScriptReady } from "../modules/deployScript/output";
import { DeployExecutionModule } from "../modules/deployExecution/module";
import type { DeployExecutionResult } from "../modules/deployExecution/types";
import { DeployVerificationModule } from "../modules/deployVerification/module";
import { showDeploySuccess } from "../modules/deployVerification/output";
import { loadValidationProject } from "../modules/validation/project";

function composeError(error: unknown) {
  return {
    code: typeof error === "object" && error && "code" in error
      ? String(error.code)
      : "DEPLOY_FAILED",
    message: error instanceof Error ? error.message : "Deploy failed.",
    nativeError: error,
  };
}

/**
 * Deploy pipeline.
 *
 * Orchestrates fresh deployments end to end: plan the composition against
 * compose.json and compose.lock, generate (or reuse) the managed framework
 * script, execute it under the framework, verify the result on-chain, and
 * record the verified deployment in compose.lock.
 *
 * The plan is never re-read from the chain before execution; verification is
 * the only consumer of chain state, so a failed deployment leaves the lock
 * untouched.
 */
export const DeployPipeline = {
  /**
   * Runs the deploy flow for the command parameters.
   *
   * @param ctx - The compose context with command parameters.
   * @returns The context with `state.deployPipeline` set on failure.
   */
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    let stage = "deployPlan";

    try {
      if (ctx.param.dryRun && ctx.param.broadcast) {
        throw new Error("Use either --dry-run or --broadcast, not both.");
      }

      // The project defines the framework, so load it before resolving any
      // adapter: the script path, renderer, and execution all follow the
      // framework recorded in compose.json.
      const project = await loadValidationProject(ctx);
      const framework = String(ctx.param.framework) as DependencyKey;
      const frameworkDependencies = await DependencyResolver.resolve([
        { key: DependencyKey.Hashing },
        { key: framework },
      ]);
      const adapter = frameworkDependencies[framework] as IFrameworkAdapter | undefined;
      const hashing = frameworkDependencies[DependencyKey.Hashing] as IHashingAdapter | undefined;
      if (!adapter || !hashing) throw new Error("Deploy dependencies were not resolved.");

      ctx = await DeployPlanModule.resolve(ctx, { project, adapter, hashing });
      const planState = ctx.state.deployPlan as ModuleState<DeployPlan>;
      const plan = planState.result;
      if (!plan) throw new Error("Deploy plan was not resolved.");

      if (plan.mode === "in-sync") {
        showInSync(plan);
        return ctx;
      }

      if (plan.mode === "diff") {
        showDiffStopped(plan);
        const error = {
          code: "COMPOSITION_CHANGED",
          message: `compose.json differs from the recorded deployment of '${plan.diamondName}'.`,
          nativeError: null,
        };
        ctx.state.deployPipeline = { success: false, result: { stage }, error };
        ctx.status = { success: false, stopped: true, failedAt: stage, error };
        return ctx;
      }

      showDeployPlan(plan);

      stage = "deployScript";
      ctx = await DeployScriptModule.buildModel(ctx, adapter);
      const scriptState = ctx.state.deployScript as ModuleState<{
        path: string;
        model: ManagedScriptModel;
      }>;
      const scriptPath = scriptState.result?.path;
      const model = scriptState.result?.model;
      if (!scriptPath || !model) throw new Error("Deploy script model was not resolved.");

      if (ctx.param.dryRun) {
        showScriptPreview(plan.projectRoot, scriptPath, await DeployScriptModule.render(model));
        console.log(dim("Dry run: no files were written."));
        return ctx;
      }

      const interactive = isInteractive();
      const broadcasting = Boolean(ctx.param.broadcast);
      const scriptMatchesPlan = (await DeployScriptModule.readPlanHash(scriptPath)) === model.planHash.toLowerCase();

      /**
       * Prints the managed script path so the run is tied to a concrete file
       * on disk (review the source there or via `--dry-run`).
       */
      const announceScript = (): void => {
        showScriptPath(plan.projectRoot, scriptPath);
      };

      /** Asks for confirmation before executing the managed script. */
      const confirmRun = async (): Promise<boolean> => {
        const { confirm } = await loadPrompts();
        return confirm({ message: "Run the deployment script now?", default: true });
      };

      if (!broadcasting) {
        if (!scriptMatchesPlan) {
          await DeployScriptModule.write(model);
        }
        if (!interactive) {
          showScriptReady(plan.projectRoot, scriptPath);
          return ctx;
        }

        announceScript();
        if (!(await confirmRun())) {
          showScriptReady(plan.projectRoot, scriptPath);
          return ctx;
        }
      } else if (!scriptMatchesPlan) {
        if (!interactive) {
          throw new Error(
            `The managed deploy script at ${toProjectRelativePath(plan.projectRoot, scriptPath)} is missing or stale. Run 'compose deploy' interactively to regenerate it.`,
          );
        }

        const { confirm } = await loadPrompts();
        const regenerate = await confirm({
          message: "The managed deploy script is missing or stale. Regenerate it?",
          default: true,
        });
        if (!regenerate) {
          throw new Error("Deployment cancelled: the managed deploy script does not match the current plan.");
        }
        await DeployScriptModule.write(model);

        announceScript();
        if (!(await confirmRun())) {
          showScriptReady(plan.projectRoot, scriptPath);
          return ctx;
        }
      }

      // Resolve the RPC endpoint before broadcasting so a chain mismatch
      // aborts before any transaction is sent.
      const chainDependencies = await DependencyResolver.resolve([
        { key: DependencyKey.RPC, params: { chainKey: plan.chain.chainKey, projectRoot: plan.projectRoot } },
        { key: DependencyKey.Diamond, params: { chainKey: plan.chain.chainKey, projectRoot: plan.projectRoot } },
      ]);
      const rpc = chainDependencies[DependencyKey.RPC] as IRPCAdapter | undefined;
      const diamond = chainDependencies[DependencyKey.Diamond] as IDiamondAdapter | undefined;
      if (!rpc || !diamond) throw new Error("Deploy chain dependencies were not resolved.");

      stage = "deployExecution";
      await adapter.compile(plan.projectRoot);

      ctx = await DeployExecutionModule.execute(ctx, plan, scriptPath, adapter);
      const executionState = ctx.state.deployExecution as ModuleState<DeployExecutionResult>;
      if (!executionState?.success || !executionState.result) {
        throw new Error(executionState?.error?.message ?? "Deployment failed.");
      }

      stage = "deployVerification";
      ctx = await DeployVerificationModule.verify(ctx, plan, executionState.result, {
        diamond,
        hashing,
        rpc,
      });
      const verificationState = ctx.state.deployVerification as ModuleState<DiamondDeployment>;
      if (!verificationState?.success || !verificationState.result) {
        ctx.status = {
          success: false,
          stopped: true,
          failedAt: stage,
          error: verificationState?.error ?? null,
        };
        return ctx;
      }

      stage = "lockFileWrite";
      const lockState = ctx.state.lockFile as ModuleState<{ path: string; lock: ComposeLock } | null>;
      const lock = lockState?.result?.lock ?? LockFileModule.createEmptyLock(VERSION);
      const nextLock = LockFileModule.setDeployment(
        lock,
        plan.diamondName,
        plan.chain.chainKey,
        plan.instance,
        verificationState.result,
      );
      ctx = await LockFileModule.writeLockFile(ctx, nextLock);
      const writeState = ctx.state.lockFileWrite as ModuleState<{ path: string }>;
      if (!writeState?.success || !writeState.result) {
        throw new Error(writeState?.error?.message ?? "Failed to write compose.lock.");
      }

      showDeploySuccess(plan, verificationState.result, writeState.result.path);
      return ctx;
    } catch (error) {
      const resolved = composeError(error);
      ctx.state.deployPipeline = { success: false, result: { stage }, error: resolved };
      ctx.status = { success: false, stopped: true, failedAt: stage, error: resolved };
      console.error(resolved.message);
      return ctx;
    }
  },
};
