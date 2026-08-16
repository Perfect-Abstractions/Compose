import { IFrameworkAdapter } from "../adapters/interface/IFrameworkAdapter";
import { ComposeContext } from "../context/types";
import { ValidationModule } from "../modules/validation/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { loadValidationProject } from "../modules/validation/project";

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

    ctx = ValidationModule.scanFacetSelectors(ctx, sources, project.facetNames);
    ctx = ValidationModule.buildVirtualStorageLayout(ctx, sources, project.facetNames);
    ctx = await ValidationModule.validateSelectorExports(ctx);
    ctx = await ValidationModule.detectSelectorCollisions(ctx, { hashing: deps.hashing });

    const selectorCollisions = ValidationModule.getSelectorCollisionValidationState(ctx);
    const virtualStorageLayout = ValidationModule.getVirtualStorageLayoutValidationState(ctx);
    const pipelineError = selectorCollisions?.error ?? virtualStorageLayout?.error ?? null;
    ctx.state.validatePipeline = {
      success: selectorCollisions?.success === true && virtualStorageLayout?.success === true,
      result: {
        checkedFacets: project.facetNames.length,
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

    if (ctx.state.validatePipeline.success) {
      ValidationModule.showSuccess();
    }

    return ctx;
  },
};
