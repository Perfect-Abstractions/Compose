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
import { assertSafeDeploymentPassthrough, toPassthroughArgs } from "../utils/args";
import { toProjectRelativePath } from "../utils/files";
import { DeployPlanModule } from "../modules/deployPlan/module";
import type { DeployPlan } from "../modules/deployPlan/types";
import { showDeployPlan, showDiffStopped, showInSync } from "../modules/deployPlan/output";
import { DeployScriptModule } from "../modules/deployScript/module";
import type { ManagedScriptModel } from "../modules/deployScript/types";
import { showScriptReady } from "../modules/deployScript/output";
import { DeployExecutionModule } from "../modules/deployExecution/module";
import type { DeployExecutionResult } from "../modules/deployExecution/types";
import { getIgnitionDeploymentId } from "../modules/deployScript/model";
import { DeployVerificationModule } from "../modules/deployVerification/module";
import { showDeploySuccess } from "../modules/deployVerification/output";
import { DeploySimulationModule } from "../modules/deploySimulation/module";
import { showDeploySimulationSuccess } from "../modules/deploySimulation/output";
import { loadValidationProject } from "../modules/validation/project";
import { toComposeError } from "../utils/errors";

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

      const deployMode = ctx.param.dryRun
        ? "simulate"
        : ctx.param.broadcast
          ? "broadcast"
          : "prepare";

      const frameworkDependencies = await DependencyResolver.resolve([
        { key: DependencyKey.Hashing },
        { key: framework },
      ]);

      const adapter = frameworkDependencies[framework] as IFrameworkAdapter | undefined;
      const hashing = frameworkDependencies[DependencyKey.Hashing] as IHashingAdapter | undefined;

      if (!adapter || !hashing) throw new Error("Deploy dependencies were not resolved.");

      adapter.assertSupportedProject(String(ctx.param.projectRoot));

      ctx = await DeployPlanModule.resolve(ctx, { project, adapter, hashing });

      const planState = ctx.state.deployPlan as ModuleState<DeployPlan>;
      const plan = planState.result;
      if (!plan) throw new Error("Deploy plan was not resolved.");

      assertSafeDeploymentPassthrough(
        ctx.param.passthrough,
        plan.framework,
        plan.account !== null,
        deployMode,
      );

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
      const expectedSource = await DeployScriptModule.render(model);

      const expectedScriptHash = hashing.keccak256(expectedSource);
      const scriptHash = await DeployScriptModule.readScriptHash(scriptPath, hashing);
      const scriptMatchesExpected = scriptHash === expectedScriptHash;

      if (deployMode === "prepare") {
        if (!scriptMatchesExpected) {
          await DeployScriptModule.writeSource(scriptPath, expectedSource);
        }
        showScriptReady(plan.projectRoot, scriptPath);
        return ctx;
      }

      if (!scriptMatchesExpected) {
        const modeFlag = deployMode === "simulate" ? "dry-run" : "broadcast";
        throw new Error(
          `The managed deployment artifact at ${toProjectRelativePath(plan.projectRoot, scriptPath)} is missing, modified, or stale. `
          + `Run 'compose deploy', review the generated artifact, then retry with --${modeFlag}.`,
        );
      }

      // Probe and pin the target before a fork simulation or live broadcast.
      const chainDependencies = await DependencyResolver.resolve([
        { key: DependencyKey.RPC, params: { resolvedChain: plan.chain } },
        ...(deployMode !== "simulate"
          ? [{ key: DependencyKey.Diamond, params: { resolvedChain: plan.chain } }]
          : []),
      ]);
      const rpc = chainDependencies[DependencyKey.RPC] as IRPCAdapter | undefined;
      if (!rpc) throw new Error("Deploy RPC dependency was not resolved.");

      if (deployMode === "simulate") {
        stage = "deploySimulation";
        // The Hardhat runner is invoked with `--no-compile`, so build the
        // production artifacts it will execute against.
        if (plan.framework === "hardhat") await adapter.compile(plan.projectRoot);
        const forkBlockNumber = await rpc.getBlockNumber();
        if (plan.framework === "hardhat") await DeployScriptModule.writeRunner(model);
        ctx = await DeploySimulationModule.simulate(
          ctx,
          plan,
          scriptPath,
          adapter,
          forkBlockNumber,
          model.runnerPath,
        );
        showDeploySimulationSuccess(plan, scriptPath, forkBlockNumber);
        return ctx;
      }

      const diamond = chainDependencies[DependencyKey.Diamond] as IDiamondAdapter | undefined;
      if (!diamond) throw new Error("Deploy diamond dependency was not resolved.");

      stage = "deployExecution";
      // `forge script` compiles the Foundry project itself. Hardhat's `run`
      // would also compile on its own, but building once here keeps the
      // production artifacts deterministic before the signer probe and runner,
      // which both pass `--no-compile`.
      if (plan.framework === "hardhat") await adapter.compile(plan.projectRoot);

      // Resolve the signer before generating the runtime wrapper so the
      // Ignition journal is scoped to the account that will actually sign,
      // including a framework-selected default.
      const expectedSigner = await adapter.resolveDeploySigner({
        projectRoot: plan.projectRoot,
        chainKey: plan.chain.chainKey,
        rpcUrl: plan.chain.rpcUrl,
        chainId: plan.chain.chainId,
        account: plan.account,
        passthrough: toPassthroughArgs(ctx.param.passthrough),
      });
      if (plan.framework === "hardhat") {
        await DeployScriptModule.writeRunner({
          ...model,
          ignitionDeploymentId: getIgnitionDeploymentId(plan, expectedSigner),
        });
      }
      ctx = await DeployExecutionModule.execute(
        ctx,
        plan,
        scriptPath,
        adapter,
        model.runnerPath,
        expectedSigner,
      );
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
        const error = verificationState?.error ?? null;
        ctx.state.deployPipeline = { success: false, result: { stage }, error };
        ctx.status = {
          success: false,
          stopped: true,
          failedAt: stage,
          error,
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
      const resolved = toComposeError(error, "DEPLOY_FAILED", "Deploy failed.");
      ctx.state.deployPipeline = { success: false, result: { stage }, error: resolved };
      ctx.status = { success: false, stopped: true, failedAt: stage, error: resolved };
      console.error(resolved.message);
      return ctx;
    }
  },
};
