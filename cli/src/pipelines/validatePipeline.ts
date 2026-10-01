import { IFrameworkAdapter } from "../adapters/IFrameworkAdapter/interface";
import { ComposeContext } from "../context/types";
import { ValidationModule } from "../modules/validation/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { loadValidationProject } from "../modules/validation/project";
import { Context } from "../context/context";
import type { ModuleState } from "../context/types";
import { LockFileModule } from "../modules/lockFile/module";
import type { LockFileState } from "../modules/lockFile/types";
import { BytecodeValidationPipeline } from "./bytecodeValidationPipeline";
import { BytecodeValidationModule } from "../modules/bytecodeValidation/module";
import { showBytecodeValidationReport } from "../modules/bytecodeValidation/output";
import type { BytecodeValidationSummary } from "../modules/bytecodeValidation/types";
import type { VirtualStorageLayoutResult } from "../modules/validation/types";

/** Runs source-side validation directly from compiler AST output. */
export const ValidatePipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    const project = await loadValidationProject(ctx);
    const framework = String(ctx.param.framework ?? "foundry") as DependencyKey;
    const deps = await DependencyResolver.resolve([
      { key: DependencyKey.Hashing },
      { key: framework },
    ]);
    const adapter = deps[framework] as IFrameworkAdapter | undefined;

    if (!deps.hashing) {
      throw new Error("Hashing dependency was not resolved.");
    }
    if (!adapter) {
      throw new Error(`${framework} adapter was not resolved.`);
    }

    const sources = await adapter.compileAst(
      ctx,
      project.facetSources.map((facet) => facet.sourcePath),
    );
    const scopes = project.diamonds.map((diamond) => ({
      diamondName: diamond.name,
      facets: diamond.facets,
    }));

    ctx = ValidationModule.scanFacetSelectors(ctx, sources, project.facetSources);
    ctx = ValidationModule.buildVirtualStorageLayout(
      ctx,
      sources,
      project.facetSources,
      scopes,
    );
    ctx = await ValidationModule.validateSelectorExports(ctx);
    ctx = await ValidationModule.detectSelectorCollisions(ctx, {
      hashing: deps.hashing,
      scopes,
    });

    const selectorCollisions = ValidationModule.getSelectorCollisionValidationState(ctx);
    const virtualStorageLayout = ValidationModule.getVirtualStorageLayoutValidationState(ctx);
    const sourceSuccess = selectorCollisions?.success === true && virtualStorageLayout?.success === true;

    if (sourceSuccess) {
      ctx = await LockFileModule.readLockFile(ctx);
      const lockState = ctx.state.lockFile as ModuleState<LockFileState> | undefined;
      if (!lockState?.success) {
        ctx.state.bytecodeValidation = {
          success: false,
          result: null,
          error: lockState?.error ?? {
            code: "LOCK_FILE_INVALID",
            message: "Unable to read compose.lock.",
            nativeError: null,
          },
        };
      } else if (!lockState.result) {
        ctx = BytecodeValidationModule.mergeDeployments(ctx, [], true);
      } else {
        const records = (virtualStorageLayout.result as VirtualStorageLayoutResult).records;
        const childContexts: ComposeContext[] = [];
        for (const diamond of project.diamonds) {
          const chainDeployments = lockState.result.lock.deployments[diamond.name] ?? {};
          for (const [chainKey, deployment] of Object.entries(chainDeployments)) {
            const child = Context.create();
            child.param = {
              projectRoot: ctx.param.projectRoot,
              diamondName: diamond.name,
              chainKey,
              diamondAddress: deployment.diamond,
              virtualStorageRecords: records.filter((record) => record.diamondName === diamond.name),
            };
            childContexts.push(await BytecodeValidationPipeline.execute(child));
          }
        }
        ctx = BytecodeValidationModule.mergeDeployments(
          ctx,
          childContexts,
          childContexts.length === 0,
        );
      }
    } else {
      ctx = BytecodeValidationModule.mergeDeployments(ctx, [], true);
    }

    const bytecodeValidation = ctx.state.bytecodeValidation as
      | ModuleState<BytecodeValidationSummary>
      | undefined;
    const pipelineError = selectorCollisions?.error
      ?? virtualStorageLayout?.error
      ?? bytecodeValidation?.error
      ?? null;
    ctx.state.validatePipeline = {
      success: sourceSuccess && bytecodeValidation?.success === true,
      result: {
        checkedFacets: project.facetSources.length,
      },
      error: pipelineError,
    };

    if (!ctx.state.validatePipeline.success) {
      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "validatePipeline",
        error: pipelineError,
      };
    }

    ctx = await ValidationModule.showReport(ctx);
    showBytecodeValidationReport(ctx);

    if (ctx.state.validatePipeline.success) {
      if (bytecodeValidation?.result?.complete === false) {
        ValidationModule.showIncomplete();
      } else {
        ValidationModule.showSuccess();
      }
    }

    return ctx;
  },
};
