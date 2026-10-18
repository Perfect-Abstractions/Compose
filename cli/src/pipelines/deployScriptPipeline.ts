import { Context } from "../context/context";
import type { ComposeContext, ChildPipelineState, ModuleState } from "../context/types";
import type { DeployScriptArtifact } from "../modules/deployScript/types";
import type { IFrameworkAdapter } from "../adapters/IFrameworkAdapter/interface";
import { DeployScriptModule } from "../modules/deployScript/module";
import { getDeployProject } from "../modules/deployScript/state";
import { ValidationModule } from "../modules/validation/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { ValidatePipeline } from "./validatePipeline";

/** Generate a deployment artifact without executing it or changing deployment state. */
export const DeployScriptPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    ctx = await DeployScriptModule.loadProject(ctx);
    const project = getDeployProject(ctx);
    const framework = project.framework as DependencyKey.Foundry | DependencyKey.Hardhat;
    const deps = await DependencyResolver.resolve([{ key: framework }, { key: DependencyKey.Hashing }]);
    const adapter = deps[framework] as IFrameworkAdapter | undefined;
    if (!adapter || !deps.hashing) throw new Error("Deployment framework and hashing adapters are required.");
    const child = Context.create();
    child.param = { projectRoot: project.projectRoot, diamond: project.diamondName };
    const validation = await ValidatePipeline.execute(child);
    ctx.state.deployValidation = {
      success: validation.state.validatePipeline?.success === true,
      state: validation.state, status: validation.status,
    } as ChildPipelineState;
    if (!ctx.state.deployValidation.success) {
      ctx.status = { ...validation.status, success: false, stopped: true, failedAt: "deployValidation" };
      ctx.state.deployScriptPipeline = { success: false, result: null, error: validation.status.error };
      return ctx;
    }
    const scans = ValidationModule.getFacetScanState(validation)?.result?.facets;
    if (!scans) throw new Error("Deployment generation requires source selector evidence from validation.");
    ctx = await DeployScriptModule.checkContracts(ctx, adapter);
    ctx = await DeployScriptModule.generate(ctx, adapter, deps.hashing, scans);
    const generated = ctx.state.deployScript as ModuleState<DeployScriptArtifact>;
    ctx.state.deployScriptPipeline = { success: true, result: generated.result, error: null };
    return ctx;
  },
};
